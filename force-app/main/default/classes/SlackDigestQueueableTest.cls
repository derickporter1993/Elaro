/**
 * Test class for ElaroDailyDigest.SlackDigestQueueable.
 *
 * ElaroDailyDigest.sendDigestToSlack skips enqueuing in test context, so the
 * inner Queueable's callout path is otherwise uncovered. These tests build a
 * DigestData payload, enqueue the Queueable directly with a mocked Slack
 * webhook, and assert the callout was made plus graceful failure handling.
 *
 * @author Elaro Team
 * @since v1.0.0 (Spring '26)
 * @group Tests
 * @see ElaroDailyDigest
 */
@IsTest(testFor=ElaroDailyDigest.class)
private class SlackDigestQueueableTest {

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

    private static ElaroDailyDigest.DigestData buildDigest() {
        ElaroDailyDigest.DigestData digest = new ElaroDailyDigest.DigestData();
        digest.generatedAt = Datetime.now();
        digest.complianceScore = 87.5;
        digest.aiSummary = 'All systems nominal in the last 24 hours.';

        ElaroDailyDigest.EventStatistics stats = new ElaroDailyDigest.EventStatistics();
        stats.totalEvents = 42;
        stats.criticalEvents = 1;
        stats.highRiskEvents = 3;
        stats.resolvedEvents = 38;
        stats.eventsByType = new Map<String, Integer>{ 'Login' => 42 };
        digest.statistics = stats;

        digest.topRisks = new List<ElaroDailyDigest.RiskItem>();
        return digest;
    }

    @IsTest
    static void shouldSendDigestViaCallout() {
        Test.setMock(HttpCalloutMock.class, new SlackMock(200));

        Test.startTest();
        System.enqueueJob(new ElaroDailyDigest.SlackDigestQueueable(buildDigest()));
        Test.stopTest();

        Assert.areEqual(1, Limits.getCallouts(), 'Digest queueable should make one Slack callout');
    }

    @IsTest
    static void shouldHandleFailedDigestResponse() {
        Test.setMock(HttpCalloutMock.class, new SlackMock(500));

        Test.startTest();
        System.enqueueJob(new ElaroDailyDigest.SlackDigestQueueable(buildDigest()));
        Test.stopTest();

        List<AsyncApexJob> jobs = [
            SELECT Id, Status, NumberOfErrors
            FROM AsyncApexJob
            WHERE JobType = 'Queueable'
            AND ApexClass.Name = 'ElaroDailyDigest'
        ];
        Assert.isFalse(jobs.isEmpty(), 'A Queueable AsyncApexJob should have been created');
        Assert.areEqual('Completed', jobs[0].Status, 'Queueable should complete despite a 5xx Slack response');
        Assert.areEqual(0, jobs[0].NumberOfErrors, 'Failure should be handled internally');
    }
}
