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
     * Submits a disclosure workflow into the declarative Salesforce Approval Process.
     * The approval chain routes through Legal, CFO, CEO, and Board approvers
     * as configured on the record's approver lookup fields.
     *
     * @param workflowId The Disclosure_Workflow__c record Id
     * @param submitterComments Optional comments from the CISO submitting the disclosure
     * @throws AuraHandledException if workflow not found, not in Drafting status,
     *         approver fields are not populated, or submission fails
     */
    public static void submitForApproval(Id workflowId, String submitterComments) {
        List<Disclosure_Workflow__c> workflows = [
            SELECT Id, Status__c, Legal_Approver__c, CFO_Approver__c,
                CEO_Approver__c, Board_Approver__c
            FROM Disclosure_Workflow__c
            WHERE Id = :workflowId
            WITH USER_MODE
            LIMIT 1
        ];

        if (workflows.isEmpty()) {
            throw new AuraHandledException('Disclosure workflow not found.');
        }

        Disclosure_Workflow__c workflow = workflows[0];

        if (workflow.Status__c != 'Drafting') {
            throw new AuraHandledException(
                'Workflow must be in Drafting status to submit for approval. Current status: '
                    + workflow.Status__c
            );
        }

        if (workflow.Legal_Approver__c == null || workflow.CFO_Approver__c == null
            || workflow.CEO_Approver__c == null || workflow.Board_Approver__c == null) {
            throw new AuraHandledException(
                'All approver fields (Legal, CFO, CEO, Board) must be populated before submitting for approval.'
            );
        }

        workflow.Submitted_Date__c = DateTime.now();
        workflow.Approval_Comments__c = submitterComments;

        try {
            update as user workflow;

            Approval.ProcessSubmitRequest req = new Approval.ProcessSubmitRequest();
            req.setObjectId(workflowId);
            req.setSubmitterId(UserInfo.getUserId());
            req.setComments(submitterComments ?? '');
            req.setProcessDefinitionNameOrId('SEC_Disclosure_Approval');
            req.setSkipEntryCriteria(false);

            Approval.ProcessResult result = Approval.process(req);

            if (!result.isSuccess()) {
                throw new AuraHandledException(
                    'Approval submission failed: '
                        + String.join(getErrorMessages(result.getErrors()), '; ')
                );
            }

            ElaroLogger.info(
                'DisclosureWorkflowService.submitForApproval',
                'Workflow ' + workflowId + ' submitted for approval by '
                    + UserInfo.getUserId()
            );
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            ElaroLogger.error(
                'DisclosureWorkflowService.submitForApproval',
                e.getMessage(),
                e.getStackTraceString()
            );
            throw new AuraHandledException(
                'Failed to submit for approval. Please verify all approver fields are populated and try again.'
            );
        }
    }

    /**
     * Retrieves the current approval status for a disclosure workflow,
     * including the pending approver and process instance details.
     *
     * @param workflowId The Disclosure_Workflow__c record Id
     * @return Map containing workflowStatus, submittedDate, approvalComments,
     *         approvalProcessStatus, currentApproverName, stepStatus, and stepComments
     * @throws AuraHandledException if workflow not found
     */
    public static Map<String, Object> getApprovalStatus(Id workflowId) {
        List<Disclosure_Workflow__c> workflows = [
            SELECT Id, Status__c, Submitted_Date__c, Approval_Comments__c
            FROM Disclosure_Workflow__c
            WHERE Id = :workflowId
            WITH USER_MODE
            LIMIT 1
        ];

        if (workflows.isEmpty()) {
            throw new AuraHandledException('Disclosure workflow not found.');
        }

        Map<String, Object> statusMap = new Map<String, Object>{
            'workflowStatus' => workflows[0].Status__c,
            'submittedDate' => workflows[0].Submitted_Date__c,
            'approvalComments' => workflows[0].Approval_Comments__c
        };

        List<ProcessInstance> instances = [
            SELECT Id, Status, CreatedDate,
                (SELECT Id, ActorId, Actor.Name, StepStatus, Comments
                 FROM StepsAndWorkitems
                 ORDER BY CreatedDate DESC
                 LIMIT 1)
            FROM ProcessInstance
            WHERE TargetObjectId = :workflowId
            WITH USER_MODE
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];

        if (!instances.isEmpty()) {
            ProcessInstance pi = instances[0];
            statusMap.put('approvalProcessStatus', pi.Status);
            if (!pi.StepsAndWorkitems.isEmpty()) {
                ProcessInstanceHistory step = pi.StepsAndWorkitems[0];
                statusMap.put('currentApproverName', step.Actor.Name);
                statusMap.put('stepStatus', step.StepStatus);
                statusMap.put('stepComments', step.Comments);
            }
        }

        return statusMap;
    }

    /**
     * Extracts error messages from a list of Database.Error objects.
     *
     * @param errors The list of Database.Error objects from a failed operation
     * @return List of error message strings
     */
    private static List<String> getErrorMessages(List<Database.Error> errors) {
        List<String> messages = new List<String>();
        for (Database.Error err : errors) {
            messages.add(err.getMessage());
        }
        return messages;
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
