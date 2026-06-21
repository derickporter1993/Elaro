/**
 * Test class for PagerDutyIntegration.PagerDutyTriggerQueueable.
 *
 * The queueable resolves a routing key from Elaro_API_Config__mdt before calling
 * the PagerDuty Events API. Custom metadata records cannot be created in tests,
 * so when no active PagerDuty config exists the queueable takes its guarded
 * early-return path (no callout). These tests assert that guard and clean job
 * completion; a callout mock is supplied for safety.
 *
 * @author Elaro Team
 * @since v1.0.0 (Spring '26)
 * @group Tests
 * @see PagerDutyIntegration
 */
@IsTest(testFor=PagerDutyIntegration.class)
private class PagerDutyTriggerQueueableTest {

    private class PagerDutyMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(202);
            res.setStatus('Accepted');
            res.setBody('{"status":"success","dedup_key":"elaro-ALERT-1"}');
            return res;
        }
    }

    private static String buildAlertJson() {
        return JSON.serialize(new Map<String, Object>{
            'alertId' => 'ALERT-1',
            'eventType' => 'High Risk Login',
            'severity' => 'CRITICAL',
            'framework' => 'SOC2',
            'riskScore' => 96,
            'message' => 'Critical compliance event',
            'timestamp' => Datetime.now()
        });
    }

    @IsTest
    static void shouldCompleteWhenRoutingKeyUnconfigured() {
        Test.setMock(HttpCalloutMock.class, new PagerDutyMock());

        Test.startTest();
        System.enqueueJob(new PagerDutyIntegration.PagerDutyTriggerQueueable(buildAlertJson(), 'trigger'));
        Test.stopTest();

        // Without an active PagerDuty Elaro_API_Config__mdt, the guard prevents any callout.
        Assert.areEqual(0, Limits.getCallouts(), 'No callout should occur when the routing key is unconfigured');

        List<AsyncApexJob> jobs = [
            SELECT Id, Status, NumberOfErrors
            FROM AsyncApexJob
            WHERE JobType = 'Queueable'
            AND ApexClass.Name = 'PagerDutyIntegration'
        ];
        Assert.isFalse(jobs.isEmpty(), 'A Queueable AsyncApexJob should have been created');
        Assert.areEqual('Completed', jobs[0].Status, 'Trigger queueable should complete');
        Assert.areEqual(0, jobs[0].NumberOfErrors, 'Trigger queueable should not record errors');
    }

    @IsTest
    static void shouldCompleteOnMalformedAlertPayload() {
        Test.startTest();
        System.enqueueJob(new PagerDutyIntegration.PagerDutyTriggerQueueable('not-json', 'trigger'));
        Test.stopTest();

        List<AsyncApexJob> jobs = [
            SELECT Id, Status
            FROM AsyncApexJob
            WHERE JobType = 'Queueable'
            AND ApexClass.Name = 'PagerDutyIntegration'
        ];
        Assert.areEqual('Completed', jobs[0].Status, 'Trigger queueable should complete on malformed payload');
    }
}
