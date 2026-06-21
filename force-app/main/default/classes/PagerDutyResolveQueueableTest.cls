/**
 * Test class for PagerDutyIntegration.PagerDutyResolveQueueable.
 *
 * Like the trigger queueable, this resolves a routing key from
 * Elaro_API_Config__mdt before calling the PagerDuty Events API. With no active
 * PagerDuty config available in tests, the queueable takes its guarded
 * early-return path. These tests cover both the resolve and acknowledge actions
 * and assert clean job completion.
 *
 * @author Elaro Team
 * @since v1.0.0 (Spring '26)
 * @group Tests
 * @see PagerDutyIntegration
 */
@IsTest(testFor=PagerDutyIntegration.class)
private class PagerDutyResolveQueueableTest {

    private class PagerDutyMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(202);
            res.setStatus('Accepted');
            res.setBody('{"status":"success"}');
            return res;
        }
    }

    @IsTest
    static void shouldCompleteResolveAction() {
        Test.setMock(HttpCalloutMock.class, new PagerDutyMock());

        Test.startTest();
        System.enqueueJob(new PagerDutyIntegration.PagerDutyResolveQueueable('elaro-ALERT-1', 'resolve'));
        Test.stopTest();

        // No active PagerDuty config -> guarded early return, no callout.
        Assert.areEqual(0, Limits.getCallouts(), 'No callout should occur when the routing key is unconfigured');

        List<AsyncApexJob> jobs = [
            SELECT Id, Status, NumberOfErrors
            FROM AsyncApexJob
            WHERE JobType = 'Queueable'
            AND ApexClass.Name = 'PagerDutyIntegration'
        ];
        Assert.isFalse(jobs.isEmpty(), 'A Queueable AsyncApexJob should have been created');
        Assert.areEqual('Completed', jobs[0].Status, 'Resolve queueable should complete');
        Assert.areEqual(0, jobs[0].NumberOfErrors, 'Resolve queueable should not record errors');
    }

    @IsTest
    static void shouldCompleteAcknowledgeAction() {
        Test.setMock(HttpCalloutMock.class, new PagerDutyMock());

        Test.startTest();
        System.enqueueJob(new PagerDutyIntegration.PagerDutyResolveQueueable('elaro-ALERT-2', 'acknowledge'));
        Test.stopTest();

        List<AsyncApexJob> jobs = [
            SELECT Id, Status
            FROM AsyncApexJob
            WHERE JobType = 'Queueable'
            AND ApexClass.Name = 'PagerDutyIntegration'
        ];
        Assert.isFalse(jobs.isEmpty(), 'A Queueable AsyncApexJob should have been created');
        Assert.areEqual('Completed', jobs[0].Status, 'Acknowledge queueable should complete');
    }
}
