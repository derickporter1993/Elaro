/**
 * Test class for SlackIntegrationQueueable (top-level).
 *
 * This Queueable dispatches Slack callouts by operation and attaches a
 * SlackFinalizer for retry/error logging. These tests enqueue it directly with
 * a mocked Slack webhook, covering the SEND_MESSAGE and SEND_ALERT operations
 * and a non-200 response, asserting callouts and clean completion.
 *
 * @author Elaro Team
 * @since v1.0.0 (Spring '26)
 * @group Tests
 * @see SlackIntegrationQueueable
 */
@IsTest(testFor=SlackIntegrationQueueable.class)
private class SlackIntegrationQueueableTest {

    private class SlackMock implements HttpCalloutMock {
        private Integer statusCode;
        public SlackMock(Integer statusCode) {
            this.statusCode = statusCode;
        }
        public HttpResponse respond(HttpRequest req) {
            Assert.areEqual('POST', req.getMethod(), 'Slack callout should use POST');
            HttpResponse res = new HttpResponse();
            res.setStatusCode(this.statusCode);
            res.setStatus(this.statusCode == 200 ? 'OK' : 'Error');
            res.setBody(this.statusCode == 200 ? 'ok' : 'error');
            return res;
        }
    }

    @IsTest
    static void shouldSendMessageOperation() {
        Test.setMock(HttpCalloutMock.class, new SlackMock(200));
        String payload = JSON.serialize(new Map<String, Object>{
            'channel' => '#compliance',
            'text' => 'Hello from Elaro'
        });

        Test.startTest();
        System.enqueueJob(new SlackIntegrationQueueable(
            SlackIntegrationQueueable.Operation.SEND_MESSAGE, payload, null
        ));
        Test.stopTest();

        Assert.areEqual(1, Limits.getCallouts(), 'SEND_MESSAGE should make one Slack callout');
    }

    @IsTest
    static void shouldSendAlertOperation() {
        Test.setMock(HttpCalloutMock.class, new SlackMock(200));
        String payload = JSON.serialize(new Map<String, Object>{
            'severity' => 'CRITICAL',
            'alertId' => 'ALERT-1',
            'eventType' => 'High Risk Login',
            'riskScore' => 95,
            'message' => 'Critical event',
            'eventId' => '00Q000000000000'
        });

        Test.startTest();
        System.enqueueJob(new SlackIntegrationQueueable(
            SlackIntegrationQueueable.Operation.SEND_ALERT, payload, null, 0
        ));
        Test.stopTest();

        Assert.areEqual(1, Limits.getCallouts(), 'SEND_ALERT should make one Slack callout');
    }

    @IsTest
    static void shouldCompleteOnNon200Response() {
        Test.setMock(HttpCalloutMock.class, new SlackMock(500));
        String payload = JSON.serialize(new Map<String, Object>{ 'text' => 'msg' });

        Test.startTest();
        System.enqueueJob(new SlackIntegrationQueueable(
            SlackIntegrationQueueable.Operation.SEND_MESSAGE, payload, null
        ));
        Test.stopTest();

        // A non-200 is logged inside sendToSlack, not thrown: job completes normally.
        List<AsyncApexJob> jobs = [
            SELECT Id, Status, NumberOfErrors
            FROM AsyncApexJob
            WHERE JobType = 'Queueable'
            AND ApexClass.Name = 'SlackIntegrationQueueable'
        ];
        Assert.isFalse(jobs.isEmpty(), 'A Queueable AsyncApexJob should have been created');
        Assert.areEqual('Completed', jobs[0].Status, 'Queueable should complete despite a 5xx Slack response');
        Assert.areEqual(0, jobs[0].NumberOfErrors, 'Non-200 response should be handled internally');
    }

    @IsTest
    static void finalizerShouldConstructWithRetryContext() {
        SlackIntegrationQueueable.SlackFinalizer finalizer =
            new SlackIntegrationQueueable.SlackFinalizer(
                SlackIntegrationQueueable.Operation.SEND_MESSAGE, '{}', null, 0
            );
        Assert.isNotNull(finalizer, 'Finalizer should be constructable with retry context');
    }
}
