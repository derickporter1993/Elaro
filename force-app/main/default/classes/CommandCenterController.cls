/**
 * Lightning controller for the Compliance Command Center. Provides
 * @AuraEnabled endpoints for the complianceCommandCenter LWC and its
 * child components.
 *
 * @author Elaro Team
 * @since v3.1.0 (Spring '26)
 * @group Compliance Framework
 * @see ComplianceContextEngine
 * @see OrchestrationService
 * @see RemediationOrchestrator
 */
public with sharing class CommandCenterController {

    /**
     * Loads the full compliance context for the Command Center dashboard.
     * Returns framework summaries, prioritized actions, recent gaps,
     * and an overall compliance overview.
     *
     * @return ComplianceContextEngine.ComplianceContext with all dashboard data
     * @throws AuraHandledException if context assembly fails
     */
    @AuraEnabled(cacheable=true)
    public static ComplianceContextEngine.ComplianceContext getComplianceContext() {
        try {
            ElaroLogger.info('CommandCenterController.getComplianceContext', 'Loading compliance context');
            ComplianceContextEngine engine = new ComplianceContextEngine();
            ComplianceContextEngine.ComplianceContext ctx = engine.buildContext();
            ElaroLogger.info('CommandCenterController.getComplianceContext',
                'Context loaded: ' + ctx.frameworkSummaries.size() + ' frameworks, '
                + ctx.prioritizedActions.size() + ' actions');
            return ctx;
        } catch (Exception e) {
            ElaroLogger.error('CommandCenterController.getComplianceContext',
                e.getMessage(), e.getStackTraceString());
            throw new AuraHandledException(
                'Unable to load compliance context. Please verify your permissions and try again.');
        }
    }

    /**
     * Returns compliance actions filtered by framework.
     *
     * @param framework The framework code (e.g., 'SOC2', 'HIPAA')
     * @return List of ComplianceActionItem for the specified framework
     * @throws AuraHandledException if query fails
     */
    @AuraEnabled(cacheable=true)
    public static List<ComplianceContextEngine.ComplianceActionItem> getActionsByFramework(
        String framework
    ) {
        try {
            ComplianceContextEngine engine = new ComplianceContextEngine();
            return engine.getActionsByFramework(framework);
        } catch (Exception e) {
            ElaroLogger.error('CommandCenterController.getActionsByFramework',
                e.getMessage(), e.getStackTraceString());
            throw new AuraHandledException(
                'Unable to load compliance actions. Please try again.');
        }
    }

    /**
     * Updates the status of a compliance gap.
     *
     * @param gapId The Salesforce ID of the Compliance_Gap__c record
     * @param newStatus The new status value (OPEN, IN_PROGRESS, REMEDIATED, VERIFIED, ACCEPTED_RISK)
     * @throws AuraHandledException if update fails
     */
    @AuraEnabled
    public static void updateGapStatus(Id gapId, String newStatus) {
        try {
            ElaroLogger.info('CommandCenterController.updateGapStatus',
                'Updating gap ' + gapId + ' to ' + newStatus);

            Compliance_Gap__c gap = new Compliance_Gap__c(
                Id = gapId,
                Status__c = newStatus
            );

            if (newStatus == 'REMEDIATED' || newStatus == 'VERIFIED') {
                gap.Actual_Remediation_Date__c = Date.today();
            }

            update as user gap;
        } catch (Exception e) {
            ElaroLogger.error('CommandCenterController.updateGapStatus',
                e.getMessage(), e.getStackTraceString());
            throw new AuraHandledException(
                'Unable to update gap status. Please verify you have edit permissions.');
        }
    }

    /**
     * Returns the count of open gaps grouped by severity for the
     * notification feed badge counts.
     *
     * @return Map of severity to count
     * @throws AuraHandledException if query fails
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Integer> getGapCountsBySeverity() {
        try {
            Map<String, Integer> counts = new Map<String, Integer>();
            for (AggregateResult ar : [
                SELECT Severity__c, COUNT(Id) cnt
                FROM Compliance_Gap__c
                WHERE Status__c IN ('OPEN', 'IN_PROGRESS')
                WITH USER_MODE
                GROUP BY Severity__c
            ]) {
                counts.put((String) ar.get('Severity__c'), (Integer) ar.get('cnt'));
            }
            return counts;
        } catch (Exception e) {
            ElaroLogger.error('CommandCenterController.getGapCountsBySeverity',
                e.getMessage(), e.getStackTraceString());
            throw new AuraHandledException('Unable to load gap counts.');
        }
    }

    /**
     * Returns recent compliance gap changes for the notification feed,
     * ordered by last modification time.
     *
     * @param recordLimit Maximum number of activity items to return
     * @return List of ActivityItem ordered by most recent first
     * @throws AuraHandledException if query fails
     */
    @AuraEnabled(cacheable=true)
    public static List<ActivityItem> getRecentActivity(Integer recordLimit) {
        try {
            Integer safeLimit = Math.min(recordLimit ?? 10, 50);
            List<ActivityItem> items = new List<ActivityItem>();

            // Recent gap changes
            for (Compliance_Gap__c gap : [
                SELECT Id, Name, Framework__c, Severity__c, Status__c,
                       Detected_Date__c, LastModifiedDate, LastModifiedBy.Name
                FROM Compliance_Gap__c
                WITH USER_MODE
                ORDER BY LastModifiedDate DESC
                LIMIT :safeLimit
            ]) {
                ActivityItem item = new ActivityItem();
                item.activityId = gap.Id;
                item.activityType = 'GAP_UPDATE';
                item.title = gap.Name + ' — ' + gap.Framework__c;
                item.detail = gap.Severity__c + ' gap is ' + gap.Status__c;
                item.timestamp = gap.LastModifiedDate;
                item.modifiedBy = gap.LastModifiedBy?.Name ?? 'System';
                item.severity = gap.Severity__c;
                items.add(item);
            }

            // Sort by timestamp descending (already sorted from query, but ensure after merge)
            items.sort();
            if (items.size() > safeLimit) {
                List<ActivityItem> trimmed = new List<ActivityItem>();
                for (Integer i = 0; i < safeLimit; i++) {
                    trimmed.add(items[i]);
                }
                return trimmed;
            }
            return items;
        } catch (Exception e) {
            ElaroLogger.error('CommandCenterController.getRecentActivity',
                e.getMessage(), e.getStackTraceString());
            throw new AuraHandledException('Unable to load recent activity.');
        }
    }

    /**
     * Executes a compliance action by delegating to the Remediation Orchestrator.
     * Integrates Command Center with Team 1's Orchestration Engine for automated
     * remediation workflows.
     *
     * @param actionType The remediation action (e.g., 'REVOKE_PERMISSION', 'CREATE_CASE')
     * @param contextRecordId Optional Compliance_Gap__c or Evidence__c Id
     * @param actionParams JSON string with action-specific parameters
     * @return Remediation Case Id for tracking
     * @throws AuraHandledException if Remediation Orchestrator unavailable or execution fails
     * @example
     * String caseId = CommandCenterController.executeComplianceAction(
     *     'CREATE_CASE',
     *     gapId,
     *     '{"priority":"High","description":"Urgent remediation required"}'
     * );
     */
    @AuraEnabled
    public static String executeComplianceAction(
        String actionType,
        String contextRecordId,
        String actionParams
    ) {
        try {
            ElaroLogger.info('CommandCenterController.executeComplianceAction',
                'Executing action: ' + actionType + ' for record: ' + contextRecordId);

            // Validate action type
            if (String.isBlank(actionType)) {
                throw new AuraHandledException('Action type is required.');
            }

            // Delegate to Remediation Orchestrator (Team 1 integration)
            String jobId;
            if (actionType == 'CREATE_CASE') {
                // Parse action parameters
                Map<String, Object> params = String.isNotBlank(actionParams)
                    ? (Map<String, Object>) JSON.deserializeUntyped(actionParams)
                    : new Map<String, Object>();

                String priority = (String) params.get('priority') ?? 'Medium';
                jobId = RemediationOrchestrator.createRemediationCase(contextRecordId, priority);
            } else {
                // For other action types, implement similar delegation patterns
                throw new AuraHandledException(
                    'Action type "' + actionType + '" is not yet implemented. '
                    + 'Supported actions: CREATE_CASE');
            }

            ElaroLogger.info('CommandCenterController.executeComplianceAction',
                'Action queued successfully. Job ID: ' + jobId);

            return jobId;

        } catch (AuraHandledException ae) {
            throw ae;
        } catch (Exception e) {
            ElaroLogger.error('CommandCenterController.executeComplianceAction',
                e.getMessage(), e.getStackTraceString());
            throw new AuraHandledException(
                'Unable to execute compliance action. Please verify your permissions and try again.');
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // ORCHESTRATION INTEGRATION METHODS
    // ═══════════════════════════════════════════════════════════════

    /**
     * Triggers an orchestrated compliance scan across all supported frameworks
     * via the {@link OrchestrationService}. For small framework sets the scan
     * runs synchronously; larger sets are queued asynchronously.
     *
     * @return OrchestrationService.ScanResult with scan ID, status, and per-framework results
     * @throws AuraHandledException if the scan cannot be started or user lacks permissions
     * @example
     * OrchestrationService.ScanResult result = CommandCenterController.triggerOrchestrationScan();
     * System.debug('Scan ID: ' + result.scanId + ', Status: ' + result.status);
     */
    @AuraEnabled
    public static OrchestrationService.ScanResult triggerOrchestrationScan() {
        try {
            ElaroLogger.info('CommandCenterController.triggerOrchestrationScan',
                'Initiating full orchestrated compliance scan');

            OrchestrationService orchestrator = new OrchestrationService();
            OrchestrationService.ScanResult result = orchestrator.triggerFullScan();

            ElaroLogger.info('CommandCenterController.triggerOrchestrationScan',
                'Scan initiated: ' + result.scanId + ' status=' + result.status);

            return result;

        } catch (OrchestrationService.OrchestrationException oe) {
            ElaroLogger.error('CommandCenterController.triggerOrchestrationScan',
                oe.getMessage(), oe.getStackTraceString());
            throw new AuraHandledException(
                'Unable to start compliance scan: ' + oe.getMessage());
        } catch (Exception e) {
            ElaroLogger.error('CommandCenterController.triggerOrchestrationScan',
                e.getMessage(), e.getStackTraceString());
            throw new AuraHandledException(
                'Unable to start compliance scan. Please verify your permissions and try again.');
        }
    }

    /**
     * Triggers an orchestrated compliance scan for specific frameworks.
     * Allows the Command Center UI to request targeted scans when users
     * want to refresh only certain framework postures.
     *
     * @param frameworks JSON array of framework codes (e.g., '["SOC2","HIPAA"]')
     * @return OrchestrationService.ScanResult with scan ID and per-framework results
     * @throws AuraHandledException if frameworks are invalid or scan fails
     */
    @AuraEnabled
    public static OrchestrationService.ScanResult triggerFrameworkScan(List<String> frameworks) {
        try {
            if (frameworks == null || frameworks.isEmpty()) {
                throw new AuraHandledException(
                    'At least one framework must be selected for scanning.');
            }

            ElaroLogger.info('CommandCenterController.triggerFrameworkScan',
                'Initiating scan for frameworks: ' + String.join(frameworks, ', '));

            OrchestrationService orchestrator = new OrchestrationService();
            OrchestrationService.ScanResult result = orchestrator.triggerScan(frameworks);

            ElaroLogger.info('CommandCenterController.triggerFrameworkScan',
                'Scan initiated: ' + result.scanId + ' for ' + frameworks.size() + ' frameworks');

            return result;

        } catch (AuraHandledException ae) {
            throw ae;
        } catch (OrchestrationService.OrchestrationException oe) {
            ElaroLogger.error('CommandCenterController.triggerFrameworkScan',
                oe.getMessage(), oe.getStackTraceString());
            throw new AuraHandledException(
                'Unable to start framework scan: ' + oe.getMessage());
        } catch (Exception e) {
            ElaroLogger.error('CommandCenterController.triggerFrameworkScan',
                e.getMessage(), e.getStackTraceString());
            throw new AuraHandledException(
                'Unable to start framework scan. Please try again.');
        }
    }

    /**
     * Retrieves the current progress of a previously triggered orchestration scan.
     * The Command Center UI polls this endpoint to display scan progress.
     *
     * @param scanId The scan identifier returned by {@code triggerOrchestrationScan}
     * @return OrchestrationService.ScanProgress with completion percentage and status
     * @throws AuraHandledException if progress retrieval fails
     */
    @AuraEnabled
    public static OrchestrationService.ScanProgress getOrchestrationProgress(String scanId) {
        try {
            if (String.isBlank(scanId)) {
                throw new AuraHandledException('Scan ID is required.');
            }

            OrchestrationService orchestrator = new OrchestrationService();
            return orchestrator.getScanProgress(scanId);

        } catch (AuraHandledException ae) {
            throw ae;
        } catch (Exception e) {
            ElaroLogger.error('CommandCenterController.getOrchestrationProgress',
                e.getMessage(), e.getStackTraceString());
            throw new AuraHandledException(
                'Unable to retrieve scan progress. Please try again.');
        }
    }

    /**
     * Returns the list of framework codes registered in the Orchestration Engine.
     * Used by the Command Center UI to populate framework picker components.
     *
     * @return List of supported framework codes (e.g., ['SOC2', 'HIPAA', 'GDPR'])
     * @throws AuraHandledException if retrieval fails
     */
    @AuraEnabled(cacheable=true)
    public static List<String> getRegisteredFrameworks() {
        try {
            return new List<String>(ComplianceServiceFactory.getSupportedFrameworks());
        } catch (Exception e) {
            ElaroLogger.error('CommandCenterController.getRegisteredFrameworks',
                e.getMessage(), e.getStackTraceString());
            throw new AuraHandledException(
                'Unable to retrieve registered frameworks.');
        }
    }

    /**
     * Activity feed item for the notification feed component.
     */
    public class ActivityItem implements Comparable {
        @AuraEnabled public Id activityId;
        @AuraEnabled public String activityType;
        @AuraEnabled public String title;
        @AuraEnabled public String detail;
        @AuraEnabled public Datetime timestamp;
        @AuraEnabled public String modifiedBy;
        @AuraEnabled public String severity;

        /**
         * Sorts by timestamp descending (most recent first).
         *
         * @param compareTo The other ActivityItem
         * @return Negative if this is more recent, positive if older
         */
        public Integer compareTo(Object compareTo) {
            ActivityItem other = (ActivityItem) compareTo;
            Datetime thisTime = this.timestamp ?? Datetime.newInstance(2000, 1, 1);
            Datetime otherTime = other.timestamp ?? Datetime.newInstance(2000, 1, 1);
            // Descending: more recent first
            if (otherTime > thisTime) {
                return 1;
            }
            if (otherTime < thisTime) {
                return -1;
            }
            return 0;
        }
    }
}
