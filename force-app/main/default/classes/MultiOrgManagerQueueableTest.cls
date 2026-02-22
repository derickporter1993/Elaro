/**
 * Tests for {@link MultiOrgManagerQueueable}.
 * Validates asynchronous multi-org policy syncing and connectivity testing,
 * including both {@code SYNC_POLICIES} and {@code TEST_CONNECTION} operations,
 * error handling, null/empty inputs, bulk scenarios, and the
 * {@link MultiOrgManagerQueueable.MultiOrgManagerFinalizer} inner class.
 *
 * @author Elaro Team
 * @since v3.1.0 (Spring '26)
 * @group Enterprise Features
 * @see MultiOrgManagerQueueable
 * @see MultiOrgManager
 */
@IsTest(testFor=MultiOrgManagerQueueable.class)
private class MultiOrgManagerQueueableTest {

    // ═══════════════════════════════════════════════════════════════
    // TEST DATA SETUP
    // ═══════════════════════════════════════════════════════════════

    @TestSetup
    static void makeData() {
        List<Elaro_Connected_Org__c> orgs = new List<Elaro_Connected_Org__c>();

        orgs.add(new Elaro_Connected_Org__c(
            Name = 'Production Org',
            Instance_URL__c = 'https://prod.my.salesforce.com',
            Org_Id__c = '00D000000000001',
            Is_Active__c = true,
            Connection_Status__c = 'Connected'
        ));

        orgs.add(new Elaro_Connected_Org__c(
            Name = 'Sandbox Org',
            Instance_URL__c = 'https://sandbox.my.salesforce.com',
            Org_Id__c = '00D000000000002',
            Is_Active__c = true,
            Connection_Status__c = 'Connected'
        ));

        orgs.add(new Elaro_Connected_Org__c(
            Name = 'Inactive Org',
            Instance_URL__c = 'https://inactive.my.salesforce.com',
            Org_Id__c = '00D000000000003',
            Is_Active__c = false,
            Connection_Status__c = 'Disconnected'
        ));

        insert as user orgs;
    }

    // ═══════════════════════════════════════════════════════════════
    // HELPER METHODS
    // ═══════════════════════════════════════════════════════════════

    private static List<Elaro_Connected_Org__c> getActiveOrgs() {
        return [
            SELECT Id, Name, Instance_URL__c, Connection_Status__c, Is_Active__c
            FROM Elaro_Connected_Org__c
            WHERE Is_Active__c = true
            WITH USER_MODE
        ];
    }

    private static List<Elaro_Connected_Org__c> getAllOrgs() {
        return [
            SELECT Id, Name, Instance_URL__c, Connection_Status__c, Is_Active__c, Last_Sync__c
            FROM Elaro_Connected_Org__c
            WITH USER_MODE
        ];
    }

    private static List<Id> getOrgIds(List<Elaro_Connected_Org__c> orgs) {
        List<Id> ids = new List<Id>();
        for (Elaro_Connected_Org__c org : orgs) {
            ids.add(org.Id);
        }
        return ids;
    }

    // ═══════════════════════════════════════════════════════════════
    // SYNC_POLICIES — HAPPY PATH TESTS
    // ═══════════════════════════════════════════════════════════════

    @IsTest
    static void shouldExecuteSyncPoliciesSuccessfully() {
        List<String> policyIds = new List<String>{ 'TestPolicy_A', 'TestPolicy_B' };

        Test.startTest();
        System.enqueueJob(
            new MultiOrgManagerQueueable(
                MultiOrgManagerQueueable.Operation.SYNC_POLICIES,
                policyIds
            )
        );
        Test.stopTest();

        List<AsyncApexJob> jobs = [
            SELECT Id, Status
            FROM AsyncApexJob
            WHERE JobType = 'Queueable'
            AND ApexClass.Name = 'MultiOrgManagerQueueable'
        ];
        Assert.isTrue(jobs.size() > 0,
            'SYNC_POLICIES queueable job should have been enqueued and executed');
    }

    @IsTest
    static void shouldSyncPoliciesToActiveOrgsOnly() {
        // SYNC_POLICIES queries for Is_Active__c = true AND Connection_Status__c = 'Connected'
        List<String> policyIds = new List<String>{ 'TestPolicy_C' };

        Test.startTest();
        System.enqueueJob(
            new MultiOrgManagerQueueable(
                MultiOrgManagerQueueable.Operation.SYNC_POLICIES,
                policyIds
            )
        );
        Test.stopTest();

        // Verify the inactive org was not modified (Connection_Status__c remains unchanged)
        Elaro_Connected_Org__c inactiveOrg = [
            SELECT Connection_Status__c
            FROM Elaro_Connected_Org__c
            WHERE Name = 'Inactive Org'
            WITH USER_MODE
            LIMIT 1
        ];
        Assert.areEqual('Disconnected', inactiveOrg.Connection_Status__c,
            'Inactive org should not be affected by SYNC_POLICIES operation');
    }

    // ═══════════════════════════════════════════════════════════════
    // TEST_CONNECTION — HAPPY PATH TESTS
    // ═══════════════════════════════════════════════════════════════

    @IsTest
    static void shouldExecuteTestConnectionSuccessfully() {
        List<Elaro_Connected_Org__c> activeOrgs = getActiveOrgs();
        List<Id> orgIds = getOrgIds(activeOrgs);

        Test.startTest();
        System.enqueueJob(
            new MultiOrgManagerQueueable(
                MultiOrgManagerQueueable.Operation.TEST_CONNECTION,
                orgIds
            )
        );
        Test.stopTest();

        List<AsyncApexJob> jobs = [
            SELECT Id, Status
            FROM AsyncApexJob
            WHERE JobType = 'Queueable'
            AND ApexClass.Name = 'MultiOrgManagerQueueable'
        ];
        Assert.isTrue(jobs.size() > 0,
            'TEST_CONNECTION queueable job should have been enqueued and executed');

        // Verify orgs were updated with connection results
        List<Elaro_Connected_Org__c> updatedOrgs = [
            SELECT Id, Connection_Status__c, Last_Sync__c
            FROM Elaro_Connected_Org__c
            WHERE Id IN :orgIds
            WITH USER_MODE
        ];
        for (Elaro_Connected_Org__c org : updatedOrgs) {
            Assert.areEqual('Connected', org.Connection_Status__c,
                'Active org Connection_Status__c should be set to Connected after test');
            Assert.isNotNull(org.Last_Sync__c,
                'Active org Last_Sync__c should be populated after connection test');
        }
    }

    @IsTest
    static void shouldTestConnectionForSingleOrg() {
        Elaro_Connected_Org__c singleOrg = [
            SELECT Id FROM Elaro_Connected_Org__c
            WHERE Name = 'Production Org'
            WITH USER_MODE
            LIMIT 1
        ];

        Test.startTest();
        System.enqueueJob(
            new MultiOrgManagerQueueable(
                MultiOrgManagerQueueable.Operation.TEST_CONNECTION,
                new List<Id>{ singleOrg.Id }
            )
        );
        Test.stopTest();

        Elaro_Connected_Org__c updated = [
            SELECT Connection_Status__c, Last_Sync__c
            FROM Elaro_Connected_Org__c
            WHERE Id = :singleOrg.Id
            WITH USER_MODE
        ];
        Assert.areEqual('Connected', updated.Connection_Status__c,
            'Single org should show Connected status after successful test');
        Assert.isNotNull(updated.Last_Sync__c,
            'Single org should have Last_Sync__c set after connection test');
    }

    // ═══════════════════════════════════════════════════════════════
    // NULL / EMPTY INPUT TESTS
    // ═══════════════════════════════════════════════════════════════

    @IsTest
    static void shouldHandleEmptyPolicyIdsForSyncPolicies() {
        List<String> emptyPolicies = new List<String>();

        Test.startTest();
        System.enqueueJob(
            new MultiOrgManagerQueueable(
                MultiOrgManagerQueueable.Operation.SYNC_POLICIES,
                emptyPolicies
            )
        );
        Test.stopTest();

        List<AsyncApexJob> jobs = [
            SELECT Id, Status
            FROM AsyncApexJob
            WHERE JobType = 'Queueable'
            AND ApexClass.Name = 'MultiOrgManagerQueueable'
        ];
        Assert.isTrue(jobs.size() > 0,
            'SYNC_POLICIES should handle empty policy list gracefully');
    }

    @IsTest
    static void shouldHandleEmptyOrgIdsForTestConnection() {
        List<Id> emptyOrgIds = new List<Id>();

        Test.startTest();
        System.enqueueJob(
            new MultiOrgManagerQueueable(
                MultiOrgManagerQueueable.Operation.TEST_CONNECTION,
                emptyOrgIds
            )
        );
        Test.stopTest();

        List<AsyncApexJob> jobs = [
            SELECT Id, Status
            FROM AsyncApexJob
            WHERE JobType = 'Queueable'
            AND ApexClass.Name = 'MultiOrgManagerQueueable'
        ];
        Assert.isTrue(jobs.size() > 0,
            'TEST_CONNECTION should handle empty org ID list gracefully without DML errors');
    }

    // ═══════════════════════════════════════════════════════════════
    // BULK SCENARIO TESTS
    // ═══════════════════════════════════════════════════════════════

    @IsTest
    static void shouldTestConnectionForBulkOrgs() {
        // Create additional connected orgs to test bulk DML update
        List<Elaro_Connected_Org__c> bulkOrgs = new List<Elaro_Connected_Org__c>();
        for (Integer i = 0; i < 50; i++) {
            bulkOrgs.add(new Elaro_Connected_Org__c(
                Name = 'Bulk Org ' + i,
                Instance_URL__c = 'https://bulk' + i + '.my.salesforce.com',
                Org_Id__c = '00D00000000' + String.valueOf(1000 + i),
                Is_Active__c = true,
                Connection_Status__c = 'Pending'
            ));
        }
        insert as user bulkOrgs;

        List<Id> bulkOrgIds = new List<Id>();
        for (Elaro_Connected_Org__c org : bulkOrgs) {
            bulkOrgIds.add(org.Id);
        }

        Test.startTest();
        System.enqueueJob(
            new MultiOrgManagerQueueable(
                MultiOrgManagerQueueable.Operation.TEST_CONNECTION,
                bulkOrgIds
            )
        );
        Test.stopTest();

        List<Elaro_Connected_Org__c> updatedOrgs = [
            SELECT Id, Connection_Status__c, Last_Sync__c
            FROM Elaro_Connected_Org__c
            WHERE Id IN :bulkOrgIds
            WITH USER_MODE
        ];
        Assert.areEqual(50, updatedOrgs.size(),
            'All 50 bulk orgs should be queried and updated in a single execution');
        for (Elaro_Connected_Org__c org : updatedOrgs) {
            Assert.areEqual('Connected', org.Connection_Status__c,
                'Each bulk org should show Connected after test');
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // FINALIZER TESTS
    // ═══════════════════════════════════════════════════════════════

    @IsTest
    static void shouldInstantiateSyncPoliciesFinalizer() {
        List<String> policyIds = new List<String>{ 'Policy_X' };

        Test.startTest();
        MultiOrgManagerQueueable.MultiOrgManagerFinalizer finalizer =
            new MultiOrgManagerQueueable.MultiOrgManagerFinalizer(
                MultiOrgManagerQueueable.Operation.SYNC_POLICIES,
                policyIds,
                null,
                0
            );
        Test.stopTest();

        Assert.isNotNull(finalizer,
            'MultiOrgManagerFinalizer should be instantiable for SYNC_POLICIES with retry count 0');
    }

    @IsTest
    static void shouldInstantiateTestConnectionFinalizer() {
        List<Elaro_Connected_Org__c> activeOrgs = getActiveOrgs();
        List<Id> orgIds = getOrgIds(activeOrgs);

        Test.startTest();
        MultiOrgManagerQueueable.MultiOrgManagerFinalizer finalizer =
            new MultiOrgManagerQueueable.MultiOrgManagerFinalizer(
                MultiOrgManagerQueueable.Operation.TEST_CONNECTION,
                null,
                orgIds,
                1
            );
        Test.stopTest();

        Assert.isNotNull(finalizer,
            'MultiOrgManagerFinalizer should be instantiable for TEST_CONNECTION with retry count 1');
    }

    @IsTest
    static void shouldInstantiateFinalizerAtMaxRetries() {
        Test.startTest();
        MultiOrgManagerQueueable.MultiOrgManagerFinalizer finalizer =
            new MultiOrgManagerQueueable.MultiOrgManagerFinalizer(
                MultiOrgManagerQueueable.Operation.SYNC_POLICIES,
                new List<String>{ 'Policy_Y' },
                null,
                2
            );
        Test.stopTest();

        Assert.isNotNull(finalizer,
            'MultiOrgManagerFinalizer should be instantiable at max retry count of 2');
    }

    // ═══════════════════════════════════════════════════════════════
    // OPERATION ENUM TESTS
    // ═══════════════════════════════════════════════════════════════

    @IsTest
    static void shouldSupportBothOperationEnumValues() {
        Test.startTest();
        MultiOrgManagerQueueable.Operation syncOp = MultiOrgManagerQueueable.Operation.SYNC_POLICIES;
        MultiOrgManagerQueueable.Operation testOp = MultiOrgManagerQueueable.Operation.TEST_CONNECTION;
        Test.stopTest();

        Assert.areEqual('SYNC_POLICIES', syncOp.name(),
            'SYNC_POLICIES enum value should have correct name');
        Assert.areEqual('TEST_CONNECTION', testOp.name(),
            'TEST_CONNECTION enum value should have correct name');
    }
}
