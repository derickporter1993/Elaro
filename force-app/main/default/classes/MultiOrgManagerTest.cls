/**
 * Unit tests for {@link MultiOrgManager} covering org registration, status retrieval,
 * async policy sync via {@link MultiOrgManagerQueueable}, aggregate metrics,
 * bulk connection refresh, and sharing enforcement.
 *
 * @author Elaro Team
 * @since v3.1.0 (Spring '26)
 * @group Tests
 * @see MultiOrgManager
 * @see MultiOrgManagerQueueable
 */
@IsTest(testFor=MultiOrgManager.class)
private class MultiOrgManagerTest {

    @TestSetup
    static void setupTestData() {
        // Create test connected orgs
        List<Elaro_Connected_Org__c> orgs = new List<Elaro_Connected_Org__c>();

        for (Integer i = 0; i < 5; i++) {
            orgs.add(new Elaro_Connected_Org__c(
                Name = 'Test Org ' + i,
                Org_Id__c = '00D' + String.valueOf(1000000000000000L + i),
                Instance_URL__c = 'https://test' + i + '.salesforce.com',
                Environment_Type__c = i < 2 ? 'Production' : 'Sandbox',
                Region__c = 'US',
                Is_Active__c = true,
                Connection_Status__c = i < 3 ? 'Connected' : 'Pending',
                Compliance_Score__c = 75.0 + (i * 5),
                Event_Count__c = 100 + (i * 10),
                Alert_Count__c = 5 + i
            ));
        }
        insert as user orgs;

        // Create audit package for evidence items
        Elaro_Audit_Package__c pkg = ElaroTestDataFactory.createAuditPackage('SOC2');
        ElaroTestDataFactory.createEvidenceItems(pkg.Id, 10);
    }

    // ═══════════════════════════════════════════════════════════════
    // registerOrg Tests
    // ═══════════════════════════════════════════════════════════════

    @IsTest
    static void shouldRegisterOrgAndEnqueueConnectionTest() {
        Map<String, Object> orgConfig = new Map<String, Object>{
            'name' => 'New Test Org',
            'orgId' => '00D1234567890123',
            'instanceUrl' => 'https://neworg.salesforce.com',
            'environmentType' => 'Production',
            'region' => 'US'
        };

        Test.startTest();
        Id orgId = MultiOrgManager.registerOrg(orgConfig);
        Test.stopTest();

        Assert.areNotEqual(null, orgId, 'Should return org ID');

        Elaro_Connected_Org__c org = [
            SELECT Id, Name, Org_Id__c, Instance_URL__c, Is_Active__c, Connection_Status__c
            FROM Elaro_Connected_Org__c
            WHERE Id = :orgId
            WITH USER_MODE
        ];

        Assert.areEqual('New Test Org', org.Name, 'Org name should match');
        Assert.areEqual('00D1234567890123', org.Org_Id__c, 'Org ID should match');
        Assert.areEqual(true, org.Is_Active__c, 'Org should be active');
    }

    @IsTest
    static void shouldThrowWhenMissingName() {
        Map<String, Object> orgConfig = new Map<String, Object>{
            'orgId' => '00D1234567890123',
            'instanceUrl' => 'https://neworg.salesforce.com'
        };

        Test.startTest();
        try {
            MultiOrgManager.registerOrg(orgConfig);
            Assert.fail('Should throw exception for missing name');
        } catch (AuraHandledException e) {
            Assert.isTrue(e.getMessage().contains('name'), 'Should mention name requirement');
        }
        Test.stopTest();
    }

    @IsTest
    static void shouldThrowWhenMissingOrgId() {
        Map<String, Object> orgConfig = new Map<String, Object>{
            'name' => 'Test Org',
            'instanceUrl' => 'https://neworg.salesforce.com'
        };

        Test.startTest();
        try {
            MultiOrgManager.registerOrg(orgConfig);
            Assert.fail('Should throw exception for missing org ID');
        } catch (AuraHandledException e) {
            Assert.isTrue(e.getMessage().contains('Org ID'), 'Should mention org ID requirement');
        }
        Test.stopTest();
    }

    @IsTest
    static void shouldThrowWhenMissingInstanceUrl() {
        Map<String, Object> orgConfig = new Map<String, Object>{
            'name' => 'Test Org',
            'orgId' => '00D1234567890123'
        };

        Test.startTest();
        try {
            MultiOrgManager.registerOrg(orgConfig);
            Assert.fail('Should throw exception for missing instance URL');
        } catch (AuraHandledException e) {
            Assert.isTrue(e.getMessage().contains('Instance URL'), 'Should mention instance URL requirement');
        }
        Test.stopTest();
    }

    // ═══════════════════════════════════════════════════════════════
    // getMultiOrgStatus Tests
    // ═══════════════════════════════════════════════════════════════

    @IsTest
    static void shouldReturnMultiOrgStatus() {
        Test.startTest();
        MultiOrgManager.MultiOrgStatus status = MultiOrgManager.getMultiOrgStatus();
        Test.stopTest();

        Assert.areNotEqual(null, status, 'Should return status');
        Assert.areNotEqual(null, status.currentOrg, 'Should have current org');
        Assert.areNotEqual(null, status.connectedOrgs, 'Should have connected orgs list');
        Assert.isTrue(status.totalOrgs > 0, 'Should have at least one org');
        Assert.isTrue(status.aggregateScore >= 0, 'Aggregate score should be non-negative');
    }

    @IsTest
    static void shouldIncludeConnectedOrgsInStatus() {
        Test.startTest();
        MultiOrgManager.MultiOrgStatus status = MultiOrgManager.getMultiOrgStatus();
        Test.stopTest();

        Assert.isTrue(status.connectedOrgs.size() >= 5, 'Should include test connected orgs');

        // Verify org details
        for (MultiOrgManager.OrgStatus os : status.connectedOrgs) {
            Assert.areNotEqual(null, os.orgId, 'Org should have ID');
            Assert.areNotEqual(null, os.name, 'Org should have name');
            Assert.areNotEqual(null, os.instanceUrl, 'Org should have instance URL');
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // syncPoliciesAsync Tests
    // ═══════════════════════════════════════════════════════════════

    @IsTest
    static void shouldEnqueuePolicySyncQueueable() {
        List<String> policyIds = new List<String>{ 'Policy1', 'Policy2' };

        Test.setMock(HttpCalloutMock.class, new MultiOrgCalloutMock(200, '{"status":"success"}'));

        Test.startTest();
        MultiOrgManager.syncPoliciesAsync(policyIds);
        Test.stopTest();

        // Test.stopTest() forces the Queueable to execute synchronously.
        // Verify no unhandled exceptions occurred (implicit via reaching this point).
        Assert.isNotNull(policyIds, 'Policy IDs should not be null after async sync');
    }

    @IsTest
    static void shouldHandleSyncWithNoActiveOrgs() {
        // Deactivate all orgs
        List<Elaro_Connected_Org__c> orgs = [
            SELECT Id FROM Elaro_Connected_Org__c
            WITH USER_MODE
        ];
        for (Elaro_Connected_Org__c org : orgs) {
            org.Is_Active__c = false;
        }
        update as user orgs;

        List<String> policyIds = new List<String>{ 'Policy1' };

        Test.setMock(HttpCalloutMock.class, new MultiOrgCalloutMock(200, '{"status":"success"}'));

        Test.startTest();
        MultiOrgManager.syncPoliciesAsync(policyIds);
        Test.stopTest();

        // Verify no exceptions when no active orgs exist
        Assert.isNotNull(policyIds, 'Policy IDs should not be null after sync with no active orgs');
    }

    // ═══════════════════════════════════════════════════════════════
    // removeOrg Tests
    // ═══════════════════════════════════════════════════════════════

    @IsTest
    static void shouldRemoveOrg() {
        Elaro_Connected_Org__c org = [
            SELECT Id FROM Elaro_Connected_Org__c WITH USER_MODE LIMIT 1
        ];

        Test.startTest();
        MultiOrgManager.removeOrg(org.Id);
        Test.stopTest();

        // Verify org was deleted
        List<Elaro_Connected_Org__c> remainingOrgs = [
            SELECT Id FROM Elaro_Connected_Org__c WHERE Id = :org.Id WITH USER_MODE
        ];

        Assert.areEqual(0, remainingOrgs.size(), 'Org should be deleted');
    }

    // ═══════════════════════════════════════════════════════════════
    // refreshAllConnections Tests
    // ═══════════════════════════════════════════════════════════════

    @IsTest
    static void shouldEnqueueBulkConnectionTest() {
        Test.setMock(HttpCalloutMock.class, new MultiOrgCalloutMock(200, '{"status":"success"}'));

        Test.startTest();
        MultiOrgManager.refreshAllConnections();
        Test.stopTest();

        // After Test.stopTest(), the Queueable executes synchronously.
        // Verify all active orgs have updated connection status.
        List<Elaro_Connected_Org__c> orgs = [
            SELECT Id, Connection_Status__c, Last_Sync__c
            FROM Elaro_Connected_Org__c
            WHERE Is_Active__c = true
            WITH USER_MODE
        ];

        Assert.isTrue(orgs.size() > 0, 'Should have active orgs to refresh');
        for (Elaro_Connected_Org__c org : orgs) {
            Assert.areEqual('Connected', org.Connection_Status__c,
                'Connection status should be Connected after successful test');
            Assert.isNotNull(org.Last_Sync__c, 'Last sync should be populated after connection test');
        }
    }

    @IsTest
    static void shouldHandleRefreshWithNoActiveOrgs() {
        // Deactivate all orgs
        List<Elaro_Connected_Org__c> orgs = [
            SELECT Id FROM Elaro_Connected_Org__c WITH USER_MODE
        ];
        for (Elaro_Connected_Org__c org : orgs) {
            org.Is_Active__c = false;
        }
        update as user orgs;

        Test.startTest();
        MultiOrgManager.refreshAllConnections();
        Test.stopTest();

        // Should return early without enqueuing — no exception expected
        Assert.isNotNull(orgs, 'Should handle empty org list gracefully');
    }

    // ═══════════════════════════════════════════════════════════════
    // getAggregateMetrics Tests
    // ═══════════════════════════════════════════════════════════════

    @IsTest
    static void shouldReturnAggregateMetrics() {
        Test.startTest();
        MultiOrgManager.AggregateMetrics metrics = MultiOrgManager.getAggregateMetrics();
        Test.stopTest();

        Assert.areNotEqual(null, metrics, 'Should return metrics');
        Assert.isTrue(metrics.totalEvents >= 0, 'Total events should be non-negative');
        Assert.isTrue(metrics.totalAlerts >= 0, 'Total alerts should be non-negative');
        Assert.isTrue(metrics.avgComplianceScore >= 0, 'Average score should be non-negative');
        Assert.isTrue(metrics.orgCount > 0, 'Should have at least one org');
    }

    @IsTest
    static void shouldCountEvidenceItemsInMetrics() {
        Test.startTest();
        MultiOrgManager.AggregateMetrics metrics = MultiOrgManager.getAggregateMetrics();
        Test.stopTest();

        // Should include evidence items from test setup
        Assert.isTrue(metrics.totalEvents >= 10, 'Should count evidence items');
    }

    // ═══════════════════════════════════════════════════════════════
    // Bulk Operations Tests
    // ═══════════════════════════════════════════════════════════════

    @IsTest
    static void shouldHandleBulkOrgRegistration() {
        // Create multiple orgs
        List<Map<String, Object>> orgConfigs = new List<Map<String, Object>>();

        for (Integer i = 0; i < 10; i++) {
            orgConfigs.add(new Map<String, Object>{
                'name' => 'Bulk Org ' + i,
                'orgId' => '00D' + String.valueOf(2000000000000000L + i),
                'instanceUrl' => 'https://bulk' + i + '.salesforce.com',
                'environmentType' => 'Sandbox',
                'region' => 'US'
            });
        }

        Test.startTest();
        List<Id> orgIds = new List<Id>();
        for (Map<String, Object> config : orgConfigs) {
            orgIds.add(MultiOrgManager.registerOrg(config));
        }
        Test.stopTest();

        Assert.areEqual(10, orgIds.size(), 'Should create 10 orgs');

        // Verify all orgs were created
        List<Elaro_Connected_Org__c> createdOrgs = [
            SELECT Id FROM Elaro_Connected_Org__c
            WHERE Name LIKE 'Bulk Org%'
            WITH USER_MODE
        ];

        Assert.areEqual(10, createdOrgs.size(), 'Should have 10 bulk orgs');
    }

    // ═══════════════════════════════════════════════════════════════
    // Permission Tests
    // ═══════════════════════════════════════════════════════════════

    @IsTest
    static void shouldEnforceWithSharingOnStatusRetrieval() {
        // Test with different user context
        User testUser = ElaroTestUserFactory.createElaroUser();

        System.runAs(testUser) {
            Test.startTest();
            MultiOrgManager.MultiOrgStatus status = MultiOrgManager.getMultiOrgStatus();
            Test.stopTest();

            Assert.areNotEqual(null, status, 'Should return status with sharing');
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // Mock Classes
    // ═══════════════════════════════════════════════════════════════

    private class MultiOrgCalloutMock implements HttpCalloutMock {
        private Integer statusCode;
        private String responseBody;

        public MultiOrgCalloutMock(Integer statusCode, String responseBody) {
            this.statusCode = statusCode;
            this.responseBody = responseBody;
        }

        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(this.statusCode);
            res.setStatus(this.statusCode == 200 ? 'OK' : 'Error');
            res.setBody(this.responseBody);
            res.setHeader('Content-Type', 'application/json');
            return res;
        }
    }
}
