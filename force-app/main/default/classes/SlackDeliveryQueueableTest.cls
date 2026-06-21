/**
 * Test class for ElaroDeliveryService.SlackDeliveryQueueable.
 *
 * ElaroDeliveryService.sendToSlack skips enqueuing in test context, so the inner
 * Queueable's callout path is otherwise uncovered. These tests enqueue it
 * directly with a real audit package and a mocked Slack webhook and assert the
 * callout was made plus graceful handling of failures.
 *
 * @author Elaro Team
 * @since v1.0.0 (Spring '26)
 * @group Tests
 * @see ElaroDeliveryService
 * @see ElaroTestDataFactory
 */
@IsTest(testFor=ElaroDeliveryService.class)
private class SlackDeliveryQueueableTest {

    private class SlackMock implements HttpCalloutMock {
        private Integer statusCode;
        public SlackMock(Integer statusCode) {
            this.statusCode = statusCode;
        }
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(this.statusCode);
            res.setStatus(this.statusCode == 200 ? 'OK' : 'Error');
            res.setBody('ok');
            return res;
        }
    }

    @TestSetup
    static void makeData() {
        ElaroTestDataFactory.createAuditPackage('SOC2');
    }

    @IsTest
    static void shouldSendSlackNotificationForPackage() {
        Test.setMock(HttpCalloutMock.class, new SlackMock(200));
        Elaro_Audit_Package__c pkg = [
            SELECT Id FROM Elaro_Audit_Package__c WITH USER_MODE LIMIT 1
        ];

        Test.startTest();
        System.enqueueJob(new ElaroDeliveryService.SlackDeliveryQueueable(pkg.Id, '#compliance'));
        Test.stopTest();

        Assert.areEqual(1, Limits.getCallouts(), 'Delivery queueable should make one Slack callout');
    }

    @IsTest
    static void shouldHandleFailedSlackResponse() {
        Test.setMock(HttpCalloutMock.class, new SlackMock(503));
        Elaro_Audit_Package__c pkg = [
            SELECT Id FROM Elaro_Audit_Package__c WITH USER_MODE LIMIT 1
        ];

        Test.startTest();
        System.enqueueJob(new ElaroDeliveryService.SlackDeliveryQueueable(pkg.Id, '#compliance'));
        Test.stopTest();

        List<AsyncApexJob> jobs = [
            SELECT Id, Status, NumberOfErrors
            FROM AsyncApexJob
            WHERE JobType = 'Queueable'
            AND ApexClass.Name = 'ElaroDeliveryService'
        ];
        Assert.isFalse(jobs.isEmpty(), 'A Queueable AsyncApexJob should have been created');
        Assert.areEqual('Completed', jobs[0].Status, 'Queueable should complete despite a failed Slack response');
        Assert.areEqual(0, jobs[0].NumberOfErrors, 'Failure should be handled internally');
    }

    @IsTest
    static void shouldCompleteForMissingPackage() {
        // Negative path: a non-existent package id makes the SOQL return no rows,
        // which the queueable's try/catch swallows. No callout should be attempted.
        Test.setMock(HttpCalloutMock.class, new SlackMock(200));

        Test.startTest();
        System.enqueueJob(new ElaroDeliveryService.SlackDeliveryQueueable('a0100000000000AAAA', '#compliance'));
        Test.stopTest();

        Assert.areEqual(0, Limits.getCallouts(), 'No callout should be made when the package does not exist');
    }
}
