/**
 * Multi-org management service for enterprise deployments.
 * Manages connected orgs, policy sync, and cross-org compliance status.
 *
 * Async operations (policy sync, connection testing) are delegated to
 * {@link MultiOrgManagerQueueable} with {@link AsyncOptions} and
 * {@link QueueableDuplicateSignature} for duplicate prevention.
 *
 * @author Elaro Team
 * @since v3.1.0 (Spring '26)
 * @group Enterprise Features
 * @see MultiOrgManagerQueueable
 * @see ElaroComplianceScorer
 */
public with sharing class MultiOrgManager {

    /**
     * Registers a connected org with the provided configuration and enqueues
     * an asynchronous connection test via {@link MultiOrgManagerQueueable}.
     *
     * @param orgConfig Configuration map containing name, orgId, instanceUrl, environmentType, region
     * @return Id of the created Elaro_Connected_Org__c record
     * @throws AuraHandledException if required config fields are missing
     */
    @AuraEnabled
    public static Id registerOrg(Map<String, Object> orgConfig) {
        validateOrgConfig(orgConfig);

        Elaro_Connected_Org__c connectedOrg = new Elaro_Connected_Org__c(
            Name = (String)orgConfig.get('name'),
            Org_Id__c = (String)orgConfig.get('orgId'),
            Instance_URL__c = (String)orgConfig.get('instanceUrl'),
            Environment_Type__c = (String)orgConfig.get('environmentType'),
            Region__c = (String)orgConfig.get('region'),
            Is_Active__c = true,
            Last_Sync__c = null,
            Connection_Status__c = 'Pending'
        );

        insert as user connectedOrg;

        // Enqueue async connection test (single org)
        enqueueConnectionTest(new List<Id>{ connectedOrg.Id });

        return connectedOrg.Id;
    }

    /**
     * Retrieves the multi-org compliance status including current org
     * and all active connected orgs with aggregate scoring.
     *
     * @return MultiOrgStatus containing current and connected org statuses
     */
    @AuraEnabled(cacheable=true)
    public static MultiOrgStatus getMultiOrgStatus() {
        MultiOrgStatus status = new MultiOrgStatus();
        status.currentOrg = getCurrentOrgStatus();
        status.connectedOrgs = new List<OrgStatus>();
        status.aggregateScore = 0;

        List<Elaro_Connected_Org__c> orgs = [
            SELECT Id, Name, Org_Id__c, Instance_URL__c, Environment_Type__c,
                   Region__c, Is_Active__c, Last_Sync__c, Connection_Status__c,
                   Compliance_Score__c
            FROM Elaro_Connected_Org__c
            WHERE Is_Active__c = true
            WITH USER_MODE
            ORDER BY Name
        ];

        Decimal totalScore = status.currentOrg.complianceScore;
        Integer orgCount = 1;

        for (Elaro_Connected_Org__c org : orgs) {
            OrgStatus os = new OrgStatus();
            os.orgId = org.Id;
            os.name = org.Name;
            os.instanceUrl = org.Instance_URL__c;
            os.environmentType = org.Environment_Type__c;
            os.region = org.Region__c;
            os.connectionStatus = org.Connection_Status__c;
            os.lastSync = org.Last_Sync__c;
            os.complianceScore = org.Compliance_Score__c != null ? org.Compliance_Score__c : 0;

            status.connectedOrgs.add(os);
            totalScore += os.complianceScore;
            orgCount++;
        }

        status.aggregateScore = totalScore / orgCount;
        status.totalOrgs = orgCount;

        return status;
    }

    /**
     * Enqueues an asynchronous job to sync compliance policies to all active
     * connected orgs. Replaces the legacy {@code @future} syncPolicies method
     * with a {@link MultiOrgManagerQueueable} that supports callouts, retry
     * via Transaction Finalizers, and duplicate prevention via AsyncOptions.
     *
     * @param policyIds List of policy record IDs or DeveloperNames to sync
     * @throws AuraHandledException if the Queueable cannot be enqueued
     */
    @AuraEnabled
    public static void syncPoliciesAsync(List<String> policyIds) {
        try {
            MultiOrgManagerQueueable job = new MultiOrgManagerQueueable(
                MultiOrgManagerQueueable.Operation.SYNC_POLICIES,
                policyIds
            );

            AsyncOptions options = new AsyncOptions();
            options.setMaximumQueueableStackDepth(5);
            options.setDuplicateSignature(
                new QueueableDuplicateSignature.Builder()
                    .addString('MultiOrgManager_SyncPolicies')
                    .build()
            );

            System.enqueueJob(job, options);
        } catch (Exception e) {
            ElaroLogger.error('MultiOrgManager.syncPoliciesAsync', e.getMessage(), e.getStackTraceString());
            throw new AuraHandledException('Unable to start policy sync. Please try again.');
        }
    }

    /**
     * Removes a connected org by deactivating and deleting its record.
     *
     * @param orgId The connected org record ID to remove
     * @throws AuraHandledException if the record cannot be found or deleted
     */
    @AuraEnabled
    public static void removeOrg(String orgId) {
        Elaro_Connected_Org__c org = [
            SELECT Id FROM Elaro_Connected_Org__c
            WHERE Id = :orgId
            WITH USER_MODE
            LIMIT 1
        ];
        delete as user org;
    }

    /**
     * Refreshes the connection status for all active connected orgs by
     * enqueuing a single {@link MultiOrgManagerQueueable} that tests all
     * connections in bulk with a single DML update. This replaces the legacy
     * pattern of calling an {@code @future} method per org in a loop, which
     * risked hitting async job limits (async job storm).
     *
     * @throws AuraHandledException if the Queueable cannot be enqueued
     */
    @AuraEnabled
    public static void refreshAllConnections() {
        List<Elaro_Connected_Org__c> orgs = [
            SELECT Id FROM Elaro_Connected_Org__c
            WHERE Is_Active__c = true
            WITH USER_MODE
        ];

        if (orgs.isEmpty()) {
            return;
        }

        List<Id> orgIds = new List<Id>();
        for (Elaro_Connected_Org__c org : orgs) {
            orgIds.add(org.Id);
        }

        enqueueConnectionTest(orgIds);
    }

    /**
     * Aggregates compliance metrics from the current org and all connected orgs.
     *
     * @return AggregateMetrics containing combined events, alerts, and average compliance score
     */
    @AuraEnabled(cacheable=true)
    public static AggregateMetrics getAggregateMetrics() {
        AggregateMetrics metrics = new AggregateMetrics();

        // Get current org metrics
        Map<String, Object> currentScore = ElaroComplianceScorer.calculateComplianceScore();
        metrics.totalEvents = 0;
        metrics.totalAlerts = 0;
        metrics.avgComplianceScore = (Decimal)currentScore.get('overallScore');

        // Count events
        metrics.totalEvents = [SELECT COUNT() FROM Elaro_Evidence_Item__c WHERE CreatedDate >= LAST_N_DAYS:30 WITH USER_MODE];

        // Get connected org metrics
        List<Elaro_Connected_Org__c> orgs = [
            SELECT Compliance_Score__c, Event_Count__c, Alert_Count__c
            FROM Elaro_Connected_Org__c
            WHERE Is_Active__c = true
            WITH USER_MODE
        ];

        Decimal scoreSum = metrics.avgComplianceScore;
        Integer count = 1;

        for (Elaro_Connected_Org__c org : orgs) {
            if (org.Compliance_Score__c != null) {
                scoreSum += org.Compliance_Score__c;
                count++;
            }
            metrics.totalEvents += org.Event_Count__c != null ? (Integer)org.Event_Count__c : 0;
            metrics.totalAlerts += org.Alert_Count__c != null ? (Integer)org.Alert_Count__c : 0;
        }

        metrics.avgComplianceScore = scoreSum / count;
        metrics.orgCount = count;

        return metrics;
    }

    // ═══════════════════════════════════════════════════════════════
    // PRIVATE METHODS
    // ═══════════════════════════════════════════════════════════════

    /**
     * Enqueues a {@link MultiOrgManagerQueueable} to test connectivity for the
     * provided org record IDs. Uses {@link AsyncOptions} with a
     * {@link QueueableDuplicateSignature} to prevent duplicate connection test
     * jobs from being enqueued concurrently.
     *
     * @param orgIds List of Elaro_Connected_Org__c record IDs to test
     */
    private static void enqueueConnectionTest(List<Id> orgIds) {
        MultiOrgManagerQueueable job = new MultiOrgManagerQueueable(
            MultiOrgManagerQueueable.Operation.TEST_CONNECTION,
            orgIds
        );

        AsyncOptions options = new AsyncOptions();
        options.setMaximumQueueableStackDepth(5);
        options.setDuplicateSignature(
            new QueueableDuplicateSignature.Builder()
                .addString('MultiOrgManager_TestConnection')
                .build()
        );

        System.enqueueJob(job, options);
    }

    private static void validateOrgConfig(Map<String, Object> config) {
        if (String.isBlank((String)config.get('name'))) {
            throw new AuraHandledException('Org name is required');
        }
        if (String.isBlank((String)config.get('orgId'))) {
            throw new AuraHandledException('Org ID is required');
        }
        if (String.isBlank((String)config.get('instanceUrl'))) {
            throw new AuraHandledException('Instance URL is required');
        }
    }

    private static OrgStatus getCurrentOrgStatus() {
        OrgStatus status = new OrgStatus();
        status.orgId = UserInfo.getOrganizationId();
        status.name = UserInfo.getOrganizationName();
        status.instanceUrl = URL.getOrgDomainUrl().toExternalForm();
        status.environmentType = [SELECT IsSandbox FROM Organization WITH USER_MODE LIMIT 1].IsSandbox ? 'Sandbox' : 'Production';
        status.region = 'Current';
        status.connectionStatus = 'Connected';
        status.lastSync = Datetime.now();

        Map<String, Object> scoreData = ElaroComplianceScorer.calculateComplianceScore();
        status.complianceScore = (Decimal)scoreData.get('overallScore');

        return status;
    }

    /**
     * Syncs a set of compliance policies to a single connected org via callout.
     * Retained as a package-private utility for direct invocation in synchronous
     * test contexts.
     *
     * @param org The target connected org
     * @param policies The compliance policies to sync
     */
    @TestVisible
    private static void syncPoliciesToOrg(Elaro_Connected_Org__c org, List<Compliance_Policy__mdt> policies) {
        // In production, this would call the connected org's API
        // to create/update policy records
        ElaroLogger.info('MultiOrgManager.syncPoliciesToOrg', 'Syncing ' + policies.size() + ' policies to org ' + org.Id);
    }

    // ═══════════════════════════════════════════════════════════════
    // INNER CLASSES
    // ═══════════════════════════════════════════════════════════════

    /**
     * Wrapper containing the full multi-org compliance status overview.
     */
    public class MultiOrgStatus {
        @AuraEnabled public OrgStatus currentOrg;
        @AuraEnabled public List<OrgStatus> connectedOrgs;
        @AuraEnabled public Decimal aggregateScore;
        @AuraEnabled public Integer totalOrgs;
    }

    /**
     * Status snapshot for a single org (current or connected).
     */
    public class OrgStatus {
        @AuraEnabled public String orgId;
        @AuraEnabled public String name;
        @AuraEnabled public String instanceUrl;
        @AuraEnabled public String environmentType;
        @AuraEnabled public String region;
        @AuraEnabled public String connectionStatus;
        @AuraEnabled public Datetime lastSync;
        @AuraEnabled public Decimal complianceScore;
    }

    /**
     * Aggregate compliance metrics across all orgs.
     */
    public class AggregateMetrics {
        @AuraEnabled public Integer totalEvents;
        @AuraEnabled public Integer totalAlerts;
        @AuraEnabled public Decimal avgComplianceScore;
        @AuraEnabled public Integer orgCount;
    }
}
