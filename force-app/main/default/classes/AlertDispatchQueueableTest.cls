/**
 * Test class for ElaroComplianceAlert.AlertDispatchQueueable.
 *
 * This Queueable processes a batch of AlertQueueItem records and dispatches each
 * to its channel within a single async job (avoiding the 50-enqueueJob limit).
 * These tests enqueue it via System.enqueueJob and assert the dispatch side
 * effects (email invocations / HTTP callouts) plus job completion.
 *
 * @author Elaro Team
 * @since v1.0.0 (Spring '26)
 * @group Tests
 * @see ElaroComplianceAlert
 */
@IsTest(testFor=ElaroComplianceAlert.class)
private class AlertDispatchQueueableTest {

    private class SlackCalloutMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setStatus('OK');
            res.setBody('{"ok":true}');
            res.setHeader('Content-Type', 'application/json');
            return res;
        }
    }

    private static ElaroComplianceAlert.AlertQueueItem buildItem(String channel, String severity) {
        ElaroComplianceAlert.AlertQueueItem item = new ElaroComplianceAlert.AlertQueueItem();
        item.alertId = 'ALERT-DISPATCH';
        item.channel = channel;
        item.severity = severity;
        item.eventData = new Map<String, Object>{
            'eventType' => 'Test Event',
            'riskScore' => 85
        };
        return item;
    }

    @IsTest
    static void shouldDispatchMultipleEmailItems() {
        List<ElaroComplianceAlert.AlertQueueItem> items =
            new List<ElaroComplianceAlert.AlertQueueItem>{
                buildItem('EMAIL', 'HIGH'),
                buildItem('EMAIL', 'CRITICAL')
            };

        Test.startTest();
        System.enqueueJob(new ElaroComplianceAlert.AlertDispatchQueueable(items));
        Test.stopTest();

        // Real effect: email invocations are recorded for the EMAIL items.
        Assert.isTrue(
            Limits.getEmailInvocations() > 0,
            'EMAIL items should record email invocations'
        );
    }

    @IsTest
    static void shouldDispatchSlackItemViaCallout() {
        Test.setMock(HttpCalloutMock.class, new SlackCalloutMock());

        List<ElaroComplianceAlert.AlertQueueItem> items =
            new List<ElaroComplianceAlert.AlertQueueItem>{ buildItem('SLACK', 'HIGH') };

        Test.startTest();
        System.enqueueJob(new ElaroComplianceAlert.AlertDispatchQueueable(items));
        Test.stopTest();

        Assert.areEqual(1, Limits.getCallouts(), 'SLACK item should make one HTTP callout');
    }

    @IsTest
    static void shouldCompleteJobAndSwallowPerItemErrors() {
        // BELL items query a CustomNotificationType that may not exist in the test
        // org; the per-item try/catch must keep the job in a Completed state.
        List<ElaroComplianceAlert.AlertQueueItem> items =
            new List<ElaroComplianceAlert.AlertQueueItem>{
                buildItem('EMAIL', 'HIGH'),
                buildItem('BELL', 'HIGH')
            };

        Test.startTest();
        System.enqueueJob(new ElaroComplianceAlert.AlertDispatchQueueable(items));
        Test.stopTest();

        List<AsyncApexJob> jobs = [
            SELECT Id, Status, NumberOfErrors
            FROM AsyncApexJob
            WHERE JobType = 'Queueable'
            AND ApexClass.Name = 'ElaroComplianceAlert'
        ];
        Assert.isFalse(jobs.isEmpty(), 'A Queueable AsyncApexJob should have been created');
        Assert.areEqual('Completed', jobs[0].Status, 'Dispatch job should complete');
        Assert.areEqual(0, jobs[0].NumberOfErrors, 'Per-item errors should be swallowed internally');
    }
}
