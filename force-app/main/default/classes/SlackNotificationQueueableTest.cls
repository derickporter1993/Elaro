/**
 * Test class for SlackIntegration.SlackNotificationQueueable.
 *
 * SlackIntegration.enqueueNotification skips enqueuing in test context, so the
 * inner Queueable's callout path is otherwise uncovered. These tests construct
 * and enqueue it directly with a mocked Slack webhook and assert the callout was
 * made (success path) and that the job completes on a non-2xx response.
 *
 * @author Elaro Team
 * @since v1.0.0 (Spring '26)
 * @group Tests
 * @see SlackIntegration
 */
@IsTest(testFor=SlackIntegration.class)
private class SlackNotificationQueueableTest {

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

    private static Map<String, Object> sampleMessage() {
        return new Map<String, Object>{
            'channel' => '#compliance',
            'text' => 'Test notification'
        };
    }

    @IsTest
    static void shouldSendNotificationViaCallout() {
        Test.setMock(HttpCalloutMock.class, new SlackMock(200));

        Test.startTest();
        System.enqueueJob(new SlackIntegration.SlackNotificationQueueable(
            SlackIntegration.NotificationType.CUSTOM_MESSAGE, sampleMessage()
        ));
        Test.stopTest();

        Assert.areEqual(1, Limits.getCallouts(), 'Queueable should make exactly one Slack callout');
    }

    @IsTest
    static void shouldHandleNon2xxResponse() {
        Test.setMock(HttpCalloutMock.class, new SlackMock(500));

        Test.startTest();
        System.enqueueJob(new SlackIntegration.SlackNotificationQueueable(
            SlackIntegration.NotificationType.ALERT, sampleMessage()
        ));
        Test.stopTest();

        // A 5xx is logged, not thrown: the job must still complete cleanly.
        List<AsyncApexJob> jobs = [
            SELECT Id, Status, NumberOfErrors
            FROM AsyncApexJob
            WHERE JobType = 'Queueable'
            AND ApexClass.Name = 'SlackIntegration'
        ];
        Assert.isFalse(jobs.isEmpty(), 'A Queueable AsyncApexJob should have been created');
        Assert.areEqual('Completed', jobs[0].Status, 'Queueable should complete despite a 5xx Slack response');
        Assert.areEqual(0, jobs[0].NumberOfErrors, 'Non-2xx response should be handled internally');
    }
}
