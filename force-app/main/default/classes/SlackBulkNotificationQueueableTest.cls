/**
 * Test class for SlackNotifier.SlackBulkNotificationQueueable.
 *
 * SlackNotifier.notifyBulkAsync skips enqueuing in test context, so the inner
 * Queueable's bulk-callout path is otherwise uncovered. These tests enqueue it
 * directly with a serialized payload list and a mocked Slack webhook, asserting
 * one callout per payload (success) and graceful handling of HTTP errors.
 *
 * @author Elaro Team
 * @since v1.0.0 (Spring '26)
 * @group Tests
 * @see SlackNotifier
 */
@IsTest(testFor=SlackNotifier.class)
private class SlackBulkNotificationQueueableTest {

    private class SlackMock implements HttpCalloutMock {
        private Integer statusCode;
        public SlackMock(Integer statusCode) {
            this.statusCode = statusCode;
        }
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(this.statusCode);
            res.setStatus(this.statusCode == 200 ? 'OK' : 'Bad Request');
            res.setBody('{}');
            return res;
        }
    }

    private static String buildPayloads(Integer count) {
        List<String> payloads = new List<String>();
        for (Integer i = 0; i < count; i++) {
            payloads.add(JSON.serialize(new Map<String, Object>{ 'text' => 'Bulk msg ' + i }));
        }
        return JSON.serialize(payloads);
    }

    @IsTest
    static void shouldSendOneCalloutPerPayload() {
        Test.setMock(HttpCalloutMock.class, new SlackMock(200));

        Test.startTest();
        System.enqueueJob(new SlackNotifier.SlackBulkNotificationQueueable(buildPayloads(3)));
        Test.stopTest();

        Assert.areEqual(3, Limits.getCallouts(), 'Bulk queueable should make one callout per payload');
    }

    @IsTest
    static void shouldHandleHttpFailureForEachPayload() {
        Test.setMock(HttpCalloutMock.class, new SlackMock(400));

        Test.startTest();
        System.enqueueJob(new SlackNotifier.SlackBulkNotificationQueueable(buildPayloads(2)));
        Test.stopTest();

        // Every payload is still attempted (one callout each); the 4xx responses are
        // handled internally via the error-logging path without aborting the loop.
        Assert.areEqual(2, Limits.getCallouts(), 'Each payload should be attempted even on HTTP failure');

        List<AsyncApexJob> jobs = [
            SELECT Id, Status, NumberOfErrors
            FROM AsyncApexJob
            WHERE JobType = 'Queueable'
            AND ApexClass.Name = 'SlackNotifier'
        ];
        Assert.areEqual('Completed', jobs[0].Status, 'Queueable should complete despite HTTP failures');
        Assert.areEqual(0, jobs[0].NumberOfErrors, 'HTTP failures should be handled internally');
    }

    @IsTest
    static void shouldCompleteOnMalformedPayloadList() {
        // Negative path: invalid JSON is caught in execute() and logged once.
        Test.startTest();
        System.enqueueJob(new SlackNotifier.SlackBulkNotificationQueueable('not-a-json-array'));
        Test.stopTest();

        List<AsyncApexJob> jobs = [
            SELECT Id, Status, NumberOfErrors
            FROM AsyncApexJob
            WHERE JobType = 'Queueable'
            AND ApexClass.Name = 'SlackNotifier'
        ];
        Assert.isFalse(jobs.isEmpty(), 'A Queueable AsyncApexJob should have been created');
        Assert.areEqual('Completed', jobs[0].Status, 'Queueable should complete on malformed payload');
    }
}
