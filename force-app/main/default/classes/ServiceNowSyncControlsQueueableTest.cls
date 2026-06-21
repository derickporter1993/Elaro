/**
 * Test class for ServiceNowIntegration.ServiceNowSyncControlsQueueable.
 *
 * ServiceNowIntegration.syncControls skips enqueuing in test context, so the
 * inner Queueable's callout path is otherwise uncovered. These tests enqueue it
 * directly with a mocked ServiceNow API and assert one callout per framework
 * control plus graceful handling of unknown frameworks.
 *
 * @author Elaro Team
 * @since v1.0.0 (Spring '26)
 * @group Tests
 * @see ServiceNowIntegration
 */
@IsTest(testFor=ServiceNowIntegration.class)
private class ServiceNowSyncControlsQueueableTest {

    private class ServiceNowMock implements HttpCalloutMock {
        public Integer callCount = 0;
        public HttpResponse respond(HttpRequest req) {
            callCount++;
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(201);
            res.setStatus('Created');
            res.setBody('{"result":{"sys_id":"ctrl' + callCount + '"}}');
            return res;
        }
    }

    @IsTest
    static void shouldSyncControlsForKnownFramework() {
        ServiceNowMock mock = new ServiceNowMock();
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        // FINRA module exposes a bounded control set (well under the callout limit).
        System.enqueueJob(new ServiceNowIntegration.ServiceNowSyncControlsQueueable('FINRA'));
        Test.stopTest();

        Assert.isTrue(Limits.getCallouts() > 0, 'Known framework should produce at least one control callout');
        Assert.areEqual(Limits.getCallouts(), mock.callCount, 'Mock should observe every control callout');
    }

    @IsTest
    static void shouldCompleteForUnknownFramework() {
        ServiceNowMock mock = new ServiceNowMock();
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        // An unrecognized framework resolves to no module -> empty control set.
        System.enqueueJob(new ServiceNowIntegration.ServiceNowSyncControlsQueueable('UNKNOWN_FW'));
        Test.stopTest();

        Assert.areEqual(0, Limits.getCallouts(), 'Unknown framework should produce no control callouts');

        List<AsyncApexJob> jobs = [
            SELECT Id, Status
            FROM AsyncApexJob
            WHERE JobType = 'Queueable'
            AND ApexClass.Name = 'ServiceNowIntegration'
        ];
        Assert.isFalse(jobs.isEmpty(), 'A Queueable AsyncApexJob should have been created');
        Assert.areEqual('Completed', jobs[0].Status, 'Queueable should complete for an unknown framework');
    }
}
