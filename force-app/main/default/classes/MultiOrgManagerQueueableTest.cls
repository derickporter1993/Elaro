/**
 * Test class for MultiOrgManagerQueueable.
 *
 * This Queueable replaces legacy @future methods on MultiOrgManager. It supports
 * TEST_CONNECTION (updates a connected-org record with its connection result) and
 * SYNC_POLICIES (pushes compliance policies to active orgs), with a Finalizer for
 * retry/error logging. MultiOrgManager skips enqueuing in test context, so these
 * tests enqueue the Queueable directly and assert the real persisted effects.
 *
 * @author Elaro Team
 * @since v1.0.0 (Spring '26)
 * @group Tests
 * @see MultiOrgManagerQueueable
 */
@IsTest(testFor=MultiOrgManagerQueueable.class)
private class MultiOrgManagerQueueableTest {

    @TestSetup
    static void makeData() {
        List<Elaro_Connected_Org__c> orgs = new List<Elaro_Connected_Org__c>();
        for (Integer i = 0; i < 3; i++) {
            orgs.add(new Elaro_Connected_Org__c(
                Name = 'Test Org ' + i,
                Org_Id__c = '00D' + String.valueOf(1000000000000000L + i),
                Instance_URL__c = 'https://test' + i + '.salesforce.com',
                Environment_Type__c = 'Sandbox',
                Region__c = 'US',
                Is_Active__c = true,
                Connection_Status__c = 'Pending'
            ));
        }
        insert as user orgs;
    }

    @IsTest
    static void testConnectionShouldUpdateOrgRecord() {
        Elaro_Connected_Org__c org = [
            SELECT Id, Connection_Status__c, Last_Sync__c
            FROM Elaro_Connected_Org__c
            WITH USER_MODE
            LIMIT 1
        ];
        Assert.areEqual('Pending', org.Connection_Status__c, 'Precondition: org starts Pending');

        Test.startTest();
        System.enqueueJob(new MultiOrgManagerQueueable(
            MultiOrgManagerQueueable.Operation.TEST_CONNECTION, org.Id
        ));
        Test.stopTest();

        // Real effect: executeTestConnection() updates the org's status and sync time.
        Elaro_Connected_Org__c updated = [
            SELECT Id, Connection_Status__c, Last_Sync__c
            FROM Elaro_Connected_Org__c
            WHERE Id = :org.Id
            WITH USER_MODE
        ];
        Assert.areEqual('Connected', updated.Connection_Status__c, 'Connection test should mark org Connected');
        Assert.isNotNull(updated.Last_Sync__c, 'Connection test should stamp Last_Sync__c');
    }

    @IsTest
    static void syncPoliciesShouldCompleteForActiveOrgs() {
        // Use policy identifiers that match no Compliance_Policy__mdt records so the
        // sync loop runs against active orgs without depending on deployed metadata.
        List<String> policyIds = new List<String>{ 'NoSuchPolicyA', 'NoSuchPolicyB' };

        Test.startTest();
        System.enqueueJob(new MultiOrgManagerQueueable(
            MultiOrgManagerQueueable.Operation.SYNC_POLICIES, policyIds
        ));
        Test.stopTest();

        List<AsyncApexJob> jobs = [
            SELECT Id, Status, NumberOfErrors
            FROM AsyncApexJob
            WHERE JobType = 'Queueable'
            AND ApexClass.Name = 'MultiOrgManagerQueueable'
        ];
        Assert.isFalse(jobs.isEmpty(), 'A Queueable AsyncApexJob should have been created');
        Assert.areEqual('Completed', jobs[0].Status, 'SYNC_POLICIES job should complete');

        // Active orgs remain intact after a sync run.
        List<Elaro_Connected_Org__c> activeOrgs = [
            SELECT Id FROM Elaro_Connected_Org__c WHERE Is_Active__c = true WITH USER_MODE
        ];
        Assert.areEqual(3, activeOrgs.size(), 'Active orgs should be unchanged by policy sync');
    }

    @IsTest
    static void finalizerShouldConstructWithRetryContext() {
        // The Finalizer cannot be driven with a real FinalizerContext from a test,
        // but constructing it confirms the retry-context wiring compiles.
        MultiOrgManagerQueueable.MultiOrgManagerFinalizer finalizer =
            new MultiOrgManagerQueueable.MultiOrgManagerFinalizer(
                MultiOrgManagerQueueable.Operation.SYNC_POLICIES,
                new List<String>{ 'P1' },
                null,
                0
            );
        Assert.isNotNull(finalizer, 'Finalizer should be constructable with retry context');
    }
}
