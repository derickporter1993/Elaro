/**
 * Manages SEC disclosure workflow lifecycle including creation, multi-step
 * approval status transitions, and EDGAR filing recording. Supports both
 * 8-K (incident disclosure) and 10-K (annual governance) form types with
 * a defined approval chain: Drafting > Legal_Review > CFO_Review >
 * CEO_Approval > Board_Review > Ready_To_File > Filed.
 *
 * @author Elaro Team
 * @since v3.1.0 (Spring '26)
 * @group SEC Module
 * @see MaterialityAssessmentService
 * @see Disclosure_Workflow__c
 */
public inherited sharing class DisclosureWorkflowService {

    /**
     * Ordered approval workflow statuses and their valid next states.
     */
    private static final Map<String, List<String>> STATUS_TRANSITIONS = new Map<String, List<String>>{
        'Drafting' => new List<String>{ 'Legal_Review' },
        'Legal_Review' => new List<String>{ 'CFO_Review', 'Drafting' },
        'CFO_Review' => new List<String>{ 'CEO_Approval', 'Legal_Review' },
        'CEO_Approval' => new List<String>{ 'Board_Review', 'CFO_Review' },
        'Board_Review' => new List<String>{ 'Ready_To_File', 'CEO_Approval' },
        'Ready_To_File' => new List<String>{ 'Filed', 'Board_Review' },
        'Filed' => new List<String>{ 'Amended' },
        'Amended' => new List<String>{ 'Legal_Review' }
    };

    /**
     * Creates a new disclosure workflow record linked to a materiality assessment.
     *
     * @param assessmentId The parent Materiality_Assessment__c record Id
     * @param formType The SEC form type (e.g., '8-K', '10-K')
     * @return The newly inserted Disclosure_Workflow__c record
     * @throws AuraHandledException if creation fails
     */
    public static Disclosure_Workflow__c createWorkflow(Id assessmentId, String formType) {
        Disclosure_Workflow__c workflow = new Disclosure_Workflow__c(
            Materiality_Assessment__c = assessmentId,
            Form_Type__c = formType,
            Status__c = 'Drafting'
        );

        try {
            insert as user workflow;
            ElaroLogger.info(
                'DisclosureWorkflowService.createWorkflow',
                'Created disclosure workflow ' + workflow.Id
                    + ' for assessment ' + assessmentId
                    + ' (Form: ' + formType + ')'
            );
        } catch (Exception e) {
            ElaroLogger.error(
                'DisclosureWorkflowService.createWorkflow',
                e.getMessage(),
                e.getStackTraceString()
            );
            throw new AuraHandledException('Failed to create disclosure workflow. Please verify permissions and try again.');
        }

        return workflow;
    }

    /**
     * Advances a disclosure workflow to the next status in the approval chain.
     * Validates that the transition is allowed before applying.
     *
     * @param workflowId The Disclosure_Workflow__c record Id
     * @param newStatus The target status to transition to
     * @param reviewNotes Optional reviewer notes for this transition
     * @throws AuraHandledException if workflow not found or transition is invalid
     */
    public static void advanceWorkflow(Id workflowId, String newStatus, String reviewNotes) {
        List<Disclosure_Workflow__c> workflows = [
            SELECT Id, Status__c, Materiality_Assessment__c
            FROM Disclosure_Workflow__c
            WHERE Id = :workflowId
            WITH USER_MODE
            LIMIT 1
        ];

        if (workflows.isEmpty()) {
            throw new AuraHandledException('Disclosure workflow not found.');
        }

        Disclosure_Workflow__c workflow = workflows[0];
        String currentStatus = workflow.Status__c;

        if (!isValidTransition(currentStatus, newStatus)) {
            throw new AuraHandledException(
                'Invalid status transition from ' + currentStatus + ' to ' + newStatus
                    + '. Valid next statuses: ' + String.join(getValidNextStatuses(currentStatus), ', ')
            );
        }

        workflow.Status__c = newStatus;
        workflow.Review_Notes__c = reviewNotes;

        try {
            update as user workflow;
            ElaroLogger.info(
                'DisclosureWorkflowService.advanceWorkflow',
                'Workflow ' + workflowId + ' transitioned from '
                    + currentStatus + ' to ' + newStatus
            );
        } catch (Exception e) {
            ElaroLogger.error(
                'DisclosureWorkflowService.advanceWorkflow',
                e.getMessage(),
                e.getStackTraceString()
            );
            throw new AuraHandledException('Failed to advance workflow. Please try again.');
        }
    }

    /**
     * Records the EDGAR filing details when a disclosure is submitted to the SEC.
     * Sets the filing number, date, filer, and marks the workflow as Filed.
     *
     * @param workflowId The Disclosure_Workflow__c record Id
     * @param edgarNumber The EDGAR filing number assigned by the SEC
     * @throws AuraHandledException if workflow not found or not in Ready_To_File status
     */
    public static void recordFiling(Id workflowId, String edgarNumber) {
        List<Disclosure_Workflow__c> workflows = [
            SELECT Id, Status__c
            FROM Disclosure_Workflow__c
            WHERE Id = :workflowId
            WITH USER_MODE
            LIMIT 1
        ];

        if (workflows.isEmpty()) {
            throw new AuraHandledException('Disclosure workflow not found.');
        }

        Disclosure_Workflow__c workflow = workflows[0];

        if (workflow.Status__c != 'Ready_To_File') {
            throw new AuraHandledException(
                'Workflow must be in Ready_To_File status to record filing. Current status: ' + workflow.Status__c
            );
        }

        workflow.EDGAR_Filing_Number__c = edgarNumber;
        workflow.Filing_Date__c = DateTime.now();
        workflow.Filed_By__c = UserInfo.getUserId();
        workflow.Status__c = 'Filed';

        try {
            update as user workflow;
            ElaroLogger.info(
                'DisclosureWorkflowService.recordFiling',
                'Filing recorded for workflow ' + workflowId
                    + '. EDGAR number: ' + edgarNumber
            );
        } catch (Exception e) {
            ElaroLogger.error(
                'DisclosureWorkflowService.recordFiling',
                e.getMessage(),
                e.getStackTraceString()
            );
            throw new AuraHandledException('Failed to record filing. Please try again.');
        }
    }

    /**
     * Retrieves all disclosure workflows for a given materiality assessment.
     *
     * @param assessmentId The parent Materiality_Assessment__c record Id
     * @return List of disclosure workflows ordered by creation date
     */
    public static List<Disclosure_Workflow__c> getWorkflowsByAssessment(Id assessmentId) {
        return [
            SELECT Id, Materiality_Assessment__c, Form_Type__c, EDGAR_Filing_Number__c,
                Filing_Date__c, Status__c, Review_Notes__c, Filed_By__c,
                Amendment_Reason__c, CreatedDate
            FROM Disclosure_Workflow__c
            WHERE Materiality_Assessment__c = :assessmentId
            WITH USER_MODE
            ORDER BY CreatedDate ASC
        ];
    }

    /**
     * Returns the list of valid next statuses for a given current status.
     *
     * @param currentStatus The current workflow status
     * @return List of valid next status values, empty list if terminal state
     */
    public static List<String> getValidNextStatuses(String currentStatus) {
        return STATUS_TRANSITIONS.get(currentStatus) ?? new List<String>();
    }

    /**
     * Validates whether a status transition is allowed.
     *
     * @param currentStatus The current workflow status
     * @param newStatus The proposed new status
     * @return True if the transition is valid
     */
    private static Boolean isValidTransition(String currentStatus, String newStatus) {
        List<String> validNext = STATUS_TRANSITIONS.get(currentStatus);
        if (validNext == null) {
            return false;
        }
        return new Set<String>(validNext).contains(newStatus);
    }
}
