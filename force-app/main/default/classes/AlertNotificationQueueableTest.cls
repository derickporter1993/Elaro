/**
 * Test class for ElaroComplianceAlert.AlertNotificationQueueable.
 *
 * This Queueable deserializes an alert payload and dispatches it to a single
 * channel. These tests enqueue it via System.enqueueJob (the real async path)
 * for a callout-free EMAIL channel and a mocked SLACK channel, and assert the
 * dispatch side effects (email invocation / HTTP callout) plus job completion.
 *
 * @author Elaro Team
 * @since v1.0.0 (Spring '26)
 * @group Tests
 * @see ElaroComplianceAlert
 */
@IsTest(testFor=ElaroComplianceAlert.class)
private class AlertNotificationQueueableTest {

    private class SlackCalloutMock implements HttpCalloutMock {
        private Integer statusCode;
        private String body;
        public SlackCalloutMock(Integer statusCode, String body) {
            this.statusCode = statusCode;
            this.body = body;
        }
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(this.statusCode);
            res.setStatus(this.statusCode == 200 ? 'OK' : 'Error');
            res.setBody(this.body);
            res.setHeader('Content-Type', 'application/json');
            return res;
        }
    }

    private static String buildAlertJson(String alertId, String severity) {
        return JSON.serialize(new Map<String, Object>{
            'alertId' => alertId,
            'severity' => severity,
            'riskScore' => 88,
            'eventType' => 'Test Event',
            'message' => 'Test alert message'
        });
    }

    @IsTest
    static void shouldDispatchEmailChannel() {
        Test.startTest();
        System.enqueueJob(
            new ElaroComplianceAlert.AlertNotificationQueueable('EMAIL', buildAlertJson('ALERT-EMAIL', 'HIGH'))
        );
        Test.stopTest();

        // Real effect: an email invocation is recorded by sendEmailAlert().
        Assert.isTrue(
            Limits.getEmailInvocations() > 0,
            'EMAIL channel dispatch should record an email invocation'
        );
    }

    @IsTest
    static void shouldDispatchSlackChannelViaCallout() {
        Test.setMock(HttpCalloutMock.class, new SlackCalloutMock(200, '{"ok":true}'));

        Test.startTest();
        System.enqueueJob(
            new ElaroComplianceAlert.AlertNotificationQueueable('SLACK', buildAlertJson('ALERT-SLACK', 'MEDIUM'))
        );
        Test.stopTest();

        // Real effect: exactly one HTTP callout to the Slack webhook.
        Assert.areEqual(1, Limits.getCallouts(), 'SLACK channel dispatch should make one HTTP callout');
    }

    @IsTest
    static void shouldCompleteJobOnMalformedPayload() {
        // Negative path: invalid JSON is caught inside execute(); the job still completes.
        Test.startTest();
        System.enqueueJob(
            new ElaroComplianceAlert.AlertNotificationQueueable('EMAIL', 'not-valid-json')
        );
        Test.stopTest();

        List<AsyncApexJob> jobs = [
            SELECT Id, Status, NumberOfErrors
            FROM AsyncApexJob
            WHERE JobType = 'Queueable'
            AND ApexClass.Name = 'ElaroComplianceAlert'
        ];
        Assert.isFalse(jobs.isEmpty(), 'A Queueable AsyncApexJob should have been created');
        Assert.areEqual('Completed', jobs[0].Status, 'Queueable should complete despite malformed payload');
        Assert.areEqual(0, jobs[0].NumberOfErrors, 'Deserialization error should be swallowed internally');
    }
}
