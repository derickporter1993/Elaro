/**
 * Test class for ServiceNowIntegration.ServiceNowPushEvidenceQueueable.
 *
 * ServiceNowIntegration.pushEvidence skips enqueuing in test context, so the
 * inner Queueable's callout path is otherwise uncovered. These tests enqueue it
 * directly with a real evidence item and a mocked ServiceNow API and assert the
 * callout was made plus graceful failure handling.
 *
 * @author Elaro Team
 * @since v1.0.0 (Spring '26)
 * @group Tests
 * @see ServiceNowIntegration
 * @see ElaroTestDataFactory
 */
@IsTest(testFor=ServiceNowIntegration.class)
private class ServiceNowPushEvidenceQueueableTest {

    private class ServiceNowMock implements HttpCalloutMock {
        private Integer statusCode;
        public ServiceNowMock(Integer statusCode) {
            this.statusCode = statusCode;
        }
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(this.statusCode);
            res.setStatus(this.statusCode == 201 ? 'Created' : 'Error');
            res.setBody('{"result":{"sys_id":"abc123"}}');
            return res;
        }
    }

    @TestSetup
    static void makeData() {
        Elaro_Audit_Package__c pkg = ElaroTestDataFactory.createAuditPackage('SOC2');
        ElaroTestDataFactory.createEvidenceItem(pkg.Id);
    }

    @IsTest
    static void shouldPushEvidenceViaCallout() {
        Test.setMock(HttpCalloutMock.class, new ServiceNowMock(201));
        Elaro_Evidence_Item__c evidence = [
            SELECT Id FROM Elaro_Evidence_Item__c WITH USER_MODE LIMIT 1
        ];

        Test.startTest();
        System.enqueueJob(new ServiceNowIntegration.ServiceNowPushEvidenceQueueable(evidence.Id));
        Test.stopTest();

        Assert.areEqual(1, Limits.getCallouts(), 'Queueable should push evidence with one ServiceNow callout');
    }

    @IsTest
    static void shouldHandleFailedPush() {
        Test.setMock(HttpCalloutMock.class, new ServiceNowMock(500));
        Elaro_Evidence_Item__c evidence = [
            SELECT Id FROM Elaro_Evidence_Item__c WITH USER_MODE LIMIT 1
        ];

        Test.startTest();
        System.enqueueJob(new ServiceNowIntegration.ServiceNowPushEvidenceQueueable(evidence.Id));
        Test.stopTest();

        List<AsyncApexJob> jobs = [
            SELECT Id, Status, NumberOfErrors
            FROM AsyncApexJob
            WHERE JobType = 'Queueable'
            AND ApexClass.Name = 'ServiceNowIntegration'
        ];
        Assert.isFalse(jobs.isEmpty(), 'A Queueable AsyncApexJob should have been created');
        Assert.areEqual('Completed', jobs[0].Status, 'Queueable should complete despite a failed push');
        Assert.areEqual(0, jobs[0].NumberOfErrors, 'Failure should be handled internally');
    }

    @IsTest
    static void shouldCompleteForMissingEvidence() {
        Test.setMock(HttpCalloutMock.class, new ServiceNowMock(201));

        Test.startTest();
        System.enqueueJob(new ServiceNowIntegration.ServiceNowPushEvidenceQueueable('a0100000000000AAAA'));
        Test.stopTest();

        // Missing evidence -> QueryException caught, no callout attempted.
        Assert.areEqual(0, Limits.getCallouts(), 'No callout should be made when evidence does not exist');
    }
}
