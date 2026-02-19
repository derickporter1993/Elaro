/**
 * Manages the lifecycle of SEC materiality assessments including creation,
 * determination, AG delay requests, and status transitions. Materiality
 * assessments are the core record type for SEC cybersecurity incident
 * disclosure under Item 1.05 of Form 8-K.
 *
 * @author Elaro Team
 * @since v3.1.0 (Spring '26)
 * @group SEC Module
 * @see BusinessDayCalculator
 * @see DisclosureWorkflowService
 * @see IncidentTimelineService
 * @see Materiality_Assessment__c
 */
public inherited sharing class MaterialityAssessmentService {

    private static final Integer DEFAULT_FILING_BUSINESS_DAYS = 4;

    /**
     * Valid status transitions for materiality assessments.
     */
    private static final Map<String, Set<String>> VALID_TRANSITIONS = new Map<String, Set<String>>{
        'Draft' => new Set<String>{ 'Under_Review' },
        'Under_Review' => new Set<String>{ 'Determined', 'Draft' },
        'Determined' => new Set<String>{ 'Disclosure_In_Progress', 'AG_Delay_Requested' },
        'AG_Delay_Requested' => new Set<String>{ 'AG_Delay_Granted', 'Disclosure_In_Progress' },
        'AG_Delay_Granted' => new Set<String>{ 'Disclosure_In_Progress' },
        'Disclosure_In_Progress' => new Set<String>{ 'Filed', 'Closed' },
        'Filed' => new Set<String>{ 'Closed' },
        'Closed' => new Set<String>()
    };

    /**
     * Creates a new materiality assessment record with Draft status.
     *
     * @param incidentDescription Description of the cybersecurity incident
     * @param discoveryDate When the incident was discovered
     * @return The newly inserted Materiality_Assessment__c record
     * @throws AuraHandledException if creation fails
     */
    public static Materiality_Assessment__c createAssessment(String incidentDescription, DateTime discoveryDate) {
        Materiality_Assessment__c assessment = new Materiality_Assessment__c(
            Incident_Description__c = incidentDescription,
            Discovery_Date__c = discoveryDate,
            Status__c = 'Draft'
        );

        try {
            insert as user assessment;
            ElaroLogger.info(
                'MaterialityAssessmentService.createAssessment',
                'Created materiality assessment: ' + assessment.Id
            );
        } catch (Exception e) {
            ElaroLogger.error(
                'MaterialityAssessmentService.createAssessment',
                e.getMessage(),
                e.getStackTraceString()
            );
            throw new AuraHandledException('Failed to create materiality assessment. Please verify permissions and try again.');
        }

        return assessment;
    }

    /**
     * Submits a materiality determination, calculates the filing deadline
     * (4 business days per SEC rules), and updates the assessment status.
     *
     * @param assessmentId The materiality assessment record Id
     * @param result The determination result (e.g., Material, Not_Material, Pending_Review)
     * @param determinationDate When the determination was made
     * @throws AuraHandledException if the assessment is not found or update fails
     */
    public static void submitDetermination(Id assessmentId, String result, DateTime determinationDate) {
        List<Materiality_Assessment__c> assessments = [
            SELECT Id, Status__c, Discovery_Date__c
            FROM Materiality_Assessment__c
            WHERE Id = :assessmentId
            WITH USER_MODE
            LIMIT 1
        ];

        if (assessments.isEmpty()) {
            throw new AuraHandledException('Materiality assessment not found.');
        }

        Materiality_Assessment__c assessment = assessments[0];
        DateTime filingDeadline = BusinessDayCalculator.calculateFilingDeadline(
            determinationDate, DEFAULT_FILING_BUSINESS_DAYS
        );

        assessment.Determination_Result__c = result;
        assessment.Determination_Date__c = determinationDate;
        assessment.Filing_Deadline__c = filingDeadline;
        assessment.Status__c = 'Determined';

        try {
            update as user assessment;
            ElaroLogger.info(
                'MaterialityAssessmentService.submitDetermination',
                'Determination submitted for assessment ' + assessmentId
                    + '. Result: ' + result
                    + '. Filing deadline: ' + filingDeadline
            );
        } catch (Exception e) {
            ElaroLogger.error(
                'MaterialityAssessmentService.submitDetermination',
                e.getMessage(),
                e.getStackTraceString()
            );
            throw new AuraHandledException('Failed to submit determination. Please try again.');
        }
    }

    /**
     * Requests an AG (Attorney General) delay for the filing deadline.
     * Recalculates the deadline by adding the delay days to the base deadline.
     *
     * @param assessmentId The materiality assessment record Id
     * @param delayDays Number of additional business days requested
     * @throws AuraHandledException if assessment not found, not determined, or update fails
     */
    public static void requestAGDelay(Id assessmentId, Integer delayDays) {
        List<Materiality_Assessment__c> assessments = [
            SELECT Id, Status__c, Determination_Date__c, Filing_Deadline__c
            FROM Materiality_Assessment__c
            WHERE Id = :assessmentId
            WITH USER_MODE
            LIMIT 1
        ];

        if (assessments.isEmpty()) {
            throw new AuraHandledException('Materiality assessment not found.');
        }

        Materiality_Assessment__c assessment = assessments[0];

        if (assessment.Determination_Date__c == null) {
            throw new AuraHandledException('Cannot request AG delay before materiality determination.');
        }

        DateTime newDeadline = BusinessDayCalculator.calculateWithAGDelay(
            assessment.Determination_Date__c,
            DEFAULT_FILING_BUSINESS_DAYS,
            delayDays
        );

        assessment.AG_Delay_Requested__c = true;
        assessment.AG_Delay_Duration_Days__c = delayDays;
        assessment.Filing_Deadline__c = newDeadline;
        assessment.Status__c = 'AG_Delay_Requested';

        try {
            update as user assessment;
            ElaroLogger.info(
                'MaterialityAssessmentService.requestAGDelay',
                'AG delay of ' + delayDays + ' days requested for assessment ' + assessmentId
                    + '. New deadline: ' + newDeadline
            );
        } catch (Exception e) {
            ElaroLogger.error(
                'MaterialityAssessmentService.requestAGDelay',
                e.getMessage(),
                e.getStackTraceString()
            );
            throw new AuraHandledException('Failed to request AG delay. Please try again.');
        }
    }

    /**
     * Retrieves a materiality assessment with its related incident timeline events.
     *
     * @param assessmentId The materiality assessment record Id
     * @return The assessment with child Incident_Timeline__c records ordered by Event_Date__c
     * @throws AuraHandledException if the assessment is not found
     */
    public static Materiality_Assessment__c getAssessmentWithTimeline(Id assessmentId) {
        List<Materiality_Assessment__c> assessments = [
            SELECT Id, Incident_Description__c, Discovery_Date__c, Determination_Date__c,
                Filing_Deadline__c, AG_Delay_Requested__c, AG_Delay_Granted__c,
                AG_Delay_Duration_Days__c, Financial_Impact__c, Operational_Impact__c,
                Reputational_Impact__c, Data_Impact__c, Determination_Result__c,
                Status__c, Affected_Systems__c, Remediation_Status__c,
                (SELECT Id, Event_Date__c, Event_Type__c, Event_Description__c,
                    Performed_By__c, SLA_Status__c, SLA_Deadline__c
                 FROM Incident_Timelines__r
                 ORDER BY Event_Date__c ASC)
            FROM Materiality_Assessment__c
            WHERE Id = :assessmentId
            WITH USER_MODE
            LIMIT 1
        ];

        if (assessments.isEmpty()) {
            throw new AuraHandledException('Materiality assessment not found.');
        }

        return assessments[0];
    }

    /**
     * Retrieves all open (non-Closed) materiality assessments ordered by discovery date.
     *
     * @return List of open materiality assessments
     */
    public static List<Materiality_Assessment__c> getOpenAssessments() {
        return [
            SELECT Id, Incident_Description__c, Discovery_Date__c, Determination_Date__c,
                Filing_Deadline__c, Determination_Result__c, Status__c,
                Remediation_Status__c, AG_Delay_Requested__c
            FROM Materiality_Assessment__c
            WHERE Status__c != 'Closed'
            WITH USER_MODE
            ORDER BY Discovery_Date__c DESC
        ];
    }

    /**
     * Validates whether a status transition is allowed.
     *
     * @param currentStatus The current status value
     * @param newStatus The proposed new status value
     * @return True if the transition is valid
     */
    public static Boolean isValidTransition(String currentStatus, String newStatus) {
        Set<String> validNext = VALID_TRANSITIONS.get(currentStatus);
        return validNext != null && validNext.contains(newStatus);
    }
}
