/**
 * Manages the compliance gap remediation lifecycle with stage transitions,
 * SLA deadline calculation, and overdue detection. Gaps progress through:
 * Discovery -> Assessment -> Remediation -> Validation -> Monitoring -> Closed.
 *
 * @author Elaro Team
 * @since v3.1.0 (Spring '26)
 * @group Compliance Lifecycle
 * @see Compliance_Gap__c
 * @see ComplianceAlertPublisher
 */
public inherited sharing class RemediationWorkflowService {

    private static final String STAGE_DISCOVERY = 'DISCOVERY';
    private static final String STAGE_ASSESSMENT = 'ASSESSMENT';
    private static final String STAGE_REMEDIATION = 'REMEDIATION';
    private static final String STAGE_VALIDATION = 'VALIDATION';
    private static final String STAGE_MONITORING = 'MONITORING';
    private static final String STAGE_CLOSED = 'CLOSED';

    private static final Map<String, String> NEXT_STAGE = new Map<String, String>{
        STAGE_DISCOVERY => STAGE_ASSESSMENT,
        STAGE_ASSESSMENT => STAGE_REMEDIATION,
        STAGE_REMEDIATION => STAGE_VALIDATION,
        STAGE_VALIDATION => STAGE_MONITORING,
        STAGE_MONITORING => STAGE_CLOSED
    };

    private static final Map<String, Integer> SLA_DAYS_BY_SEVERITY = new Map<String, Integer>{
        'CRITICAL' => 7,
        'HIGH' => 14,
        'MEDIUM' => 30,
        'LOW' => 90
    };

    /**
     * Advances a compliance gap to the next lifecycle stage.
     *
     * @param gapId The ID of the Compliance_Gap__c record
     * @return The updated gap record
     * @throws AuraHandledException if gap not found or already closed
     */
    public static Compliance_Gap__c advanceStage(Id gapId) {
        Compliance_Gap__c gap = getGap(gapId);

        String currentStage = gap.Lifecycle_Stage__c ?? STAGE_DISCOVERY;
        String nextStage = NEXT_STAGE.get(currentStage);

        if (nextStage == null) {
            throw new AuraHandledException('Gap is already at final stage: ' + currentStage);
        }

        gap.Lifecycle_Stage__c = nextStage;

        if (nextStage == STAGE_CLOSED) {
            gap.Status__c = 'VERIFIED';
            gap.Actual_Remediation_Date__c = Date.today();
        } else if (nextStage == STAGE_REMEDIATION) {
            gap.Status__c = 'IN_PROGRESS';
        }

        update as user gap;
        return gap;
    }

    /**
     * Sets a gap to a specific lifecycle stage with validation.
     *
     * @param gapId The ID of the Compliance_Gap__c record
     * @param targetStage The target lifecycle stage
     * @return The updated gap record
     * @throws AuraHandledException if stage transition is invalid
     */
    public static Compliance_Gap__c setStage(Id gapId, String targetStage) {
        Compliance_Gap__c gap = getGap(gapId);
        validateStageTransition(gap.Lifecycle_Stage__c ?? STAGE_DISCOVERY, targetStage);

        gap.Lifecycle_Stage__c = targetStage;

        if (targetStage == STAGE_CLOSED) {
            gap.Status__c = 'VERIFIED';
            gap.Actual_Remediation_Date__c = Date.today();
        } else if (targetStage == STAGE_REMEDIATION) {
            gap.Status__c = 'IN_PROGRESS';
        }

        update as user gap;
        return gap;
    }

    /**
     * Calculates and sets the SLA deadline based on gap severity and detection date.
     * Critical=7d, High=14d, Medium=30d, Low=90d from detection.
     *
     * @param gapId The ID of the Compliance_Gap__c record
     * @return The updated gap record with SLA deadline set
     */
    public static Compliance_Gap__c calculateSLADeadline(Id gapId) {
        Compliance_Gap__c gap = getGap(gapId);

        Integer slaDays = SLA_DAYS_BY_SEVERITY.get(gap.Severity__c) ?? 30;
        Datetime detectedDate = gap.Detected_Date__c ?? Datetime.now();
        gap.SLA_Deadline__c = detectedDate.addDays(slaDays);

        update as user gap;
        return gap;
    }

    /**
     * Calculates and sets SLA deadlines for a batch of gaps.
     *
     * @param gapIds List of Compliance_Gap__c IDs
     * @return List of updated gaps
     */
    public static List<Compliance_Gap__c> calculateSLADeadlines(List<Id> gapIds) {
        List<Compliance_Gap__c> gaps = [
            SELECT Id, Severity__c, Detected_Date__c, SLA_Deadline__c
            FROM Compliance_Gap__c
            WHERE Id IN :gapIds
            WITH USER_MODE
        ];

        for (Compliance_Gap__c gap : gaps) {
            Integer slaDays = SLA_DAYS_BY_SEVERITY.get(gap.Severity__c) ?? 30;
            Datetime detectedDate = gap.Detected_Date__c ?? Datetime.now();
            gap.SLA_Deadline__c = detectedDate.addDays(slaDays);
        }

        update as user gaps;
        return gaps;
    }

    /**
     * Returns all gaps that have exceeded their SLA deadline and are not closed.
     *
     * @return List of overdue gaps ordered by deadline ascending
     */
    public static List<Compliance_Gap__c> getOverdueGaps() {
        return [
            SELECT Id, Name, Framework__c, Severity__c, Status__c, Lifecycle_Stage__c,
                   SLA_Deadline__c, Remediation_Owner__c, Gap_Description__c
            FROM Compliance_Gap__c
            WHERE SLA_Deadline__c < :Datetime.now()
            AND Lifecycle_Stage__c != :STAGE_CLOSED
            AND Status__c != 'VERIFIED'
            AND Status__c != 'ACCEPTED_RISK'
            WITH USER_MODE
            ORDER BY SLA_Deadline__c ASC
        ];
    }

    /**
     * Returns gaps approaching their SLA deadline within the specified number of days.
     *
     * @param daysUntilDeadline Number of days to look ahead
     * @return List of gaps approaching deadline
     */
    public static List<Compliance_Gap__c> getGapsApproachingDeadline(Integer daysUntilDeadline) {
        Datetime threshold = Datetime.now().addDays(daysUntilDeadline);
        return [
            SELECT Id, Name, Framework__c, Severity__c, Status__c, Lifecycle_Stage__c,
                   SLA_Deadline__c, Remediation_Owner__c, Gap_Description__c
            FROM Compliance_Gap__c
            WHERE SLA_Deadline__c <= :threshold
            AND SLA_Deadline__c >= :Datetime.now()
            AND Lifecycle_Stage__c != :STAGE_CLOSED
            AND Status__c != 'VERIFIED'
            AND Status__c != 'ACCEPTED_RISK'
            WITH USER_MODE
            ORDER BY SLA_Deadline__c ASC
        ];
    }

    /**
     * Returns a summary of gaps grouped by lifecycle stage.
     *
     * @return Map of stage name to count
     */
    public static Map<String, Integer> getLifecycleStageSummary() {
        Map<String, Integer> summary = new Map<String, Integer>{
            STAGE_DISCOVERY => 0, STAGE_ASSESSMENT => 0, STAGE_REMEDIATION => 0,
            STAGE_VALIDATION => 0, STAGE_MONITORING => 0, STAGE_CLOSED => 0
        };

        List<AggregateResult> results = [
            SELECT Lifecycle_Stage__c stage, COUNT(Id) cnt
            FROM Compliance_Gap__c
            WHERE Lifecycle_Stage__c != null
            WITH USER_MODE
            GROUP BY Lifecycle_Stage__c
        ];

        for (AggregateResult ar : results) {
            String stage = (String) ar.get('stage');
            Integer cnt = (Integer) ar.get('cnt');
            summary.put(stage, cnt);
        }

        return summary;
    }

    /**
     * Returns the ordered list of valid lifecycle stages.
     *
     * @return List of stage names in order
     */
    public static List<String> getStageOrder() {
        return new List<String>{
            STAGE_DISCOVERY, STAGE_ASSESSMENT, STAGE_REMEDIATION,
            STAGE_VALIDATION, STAGE_MONITORING, STAGE_CLOSED
        };
    }

    /**
     * Returns SLA days configuration by severity.
     *
     * @return Map of severity to SLA days
     */
    public static Map<String, Integer> getSLAConfiguration() {
        return SLA_DAYS_BY_SEVERITY.clone();
    }

    private static Compliance_Gap__c getGap(Id gapId) {
        List<Compliance_Gap__c> gaps = [
            SELECT Id, Name, Framework__c, Severity__c, Status__c, Lifecycle_Stage__c,
                   SLA_Deadline__c, Detected_Date__c, Target_Remediation_Date__c,
                   Actual_Remediation_Date__c, Remediation_Owner__c, Gap_Description__c
            FROM Compliance_Gap__c
            WHERE Id = :gapId
            WITH USER_MODE
            LIMIT 1
        ];

        if (gaps.isEmpty()) {
            throw new AuraHandledException('Compliance gap not found: ' + gapId);
        }
        return gaps[0];
    }

    private static void validateStageTransition(String currentStage, String targetStage) {
        List<String> order = getStageOrder();
        Integer currentIndex = order.indexOf(currentStage);
        Integer targetIndex = order.indexOf(targetStage);

        if (targetIndex < 0) {
            throw new AuraHandledException('Invalid target stage: ' + targetStage);
        }
        if (targetIndex <= currentIndex) {
            throw new AuraHandledException(
                'Cannot move backwards from ' + currentStage + ' to ' + targetStage
            );
        }
    }
}
