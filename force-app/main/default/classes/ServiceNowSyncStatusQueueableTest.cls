/**
 * Test class for ServiceNowIntegration.ServiceNowSyncStatusQueueable.
 *
 * ServiceNowIntegration.syncComplianceStatus skips enqueuing in test context, so
 * the inner Queueable's callout path is otherwise uncovered. These tests enqueue
 * it directly with a real audit package and a mocked ServiceNow API and assert
 * the callout was made plus graceful failure handling.
 *
 * @author Elaro Team
 * @since v1.0.0 (Spring '26)
 * @group Tests
 * @see ServiceNowIntegration
 * @see ElaroTestDataFactory
 */
@IsTest(testFor=ServiceNowIntegration.class)
private class ServiceNowSyncStatusQueueableTest {

    private class ServiceNowMock implements HttpCalloutMock {
        private Integer statusCode;
        public ServiceNowMock(Integer statusCode) {
            this.statusCode = statusCode;
        }
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(this.statusCode);
            res.setStatus(this.statusCode < 300 ? 'OK' : 'Error');
            res.setBody('{"result":{"sys_id":"def456"}}');
            return res;
        }
    }

    @TestSetup
    static void makeData() {
        ElaroTestDataFactory.createAuditPackage('HIPAA');
    }

    @IsTest
    static void shouldSyncStatusViaCallout() {
        Test.setMock(HttpCalloutMock.class, new ServiceNowMock(200));
        Elaro_Audit_Package__c pkg = [
            SELECT Id FROM Elaro_Audit_Package__c WITH USER_MODE LIMIT 1
        ];

        Test.startTest();
        System.enqueueJob(new ServiceNowIntegration.ServiceNowSyncStatusQueueable(pkg.Id));
        Test.stopTest();

        Assert.areEqual(1, Limits.getCallouts(), 'Queueable should sync status with one ServiceNow callout');
    }

    @IsTest
    static void shouldHandleFailedSync() {
        Test.setMock(HttpCalloutMock.class, new ServiceNowMock(503));
        Elaro_Audit_Package__c pkg = [
            SELECT Id FROM Elaro_Audit_Package__c WITH USER_MODE LIMIT 1
        ];

        Test.startTest();
        System.enqueueJob(new ServiceNowIntegration.ServiceNowSyncStatusQueueable(pkg.Id));
        Test.stopTest();

        List<AsyncApexJob> jobs = [
            SELECT Id, Status, NumberOfErrors
            FROM AsyncApexJob
            WHERE JobType = 'Queueable'
            AND ApexClass.Name = 'ServiceNowIntegration'
        ];
        Assert.isFalse(jobs.isEmpty(), 'A Queueable AsyncApexJob should have been created');
        Assert.areEqual('Completed', jobs[0].Status, 'Queueable should complete despite a failed sync');
        Assert.areEqual(0, jobs[0].NumberOfErrors, 'Failure should be handled internally');
    }
}
