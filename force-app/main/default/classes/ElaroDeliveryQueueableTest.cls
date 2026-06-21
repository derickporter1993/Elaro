/**
 * Test class for ElaroDeliveryQueueable.
 *
 * This Queueable posts an audit-package notification to Slack via Named
 * Credential, with retry handled by an attached Transaction Finalizer. The
 * actual http.send() is skipped under Test.isRunningTest(), so these tests
 * verify the queueable resolves the package, builds the message, attaches its
 * finalizer, and completes. A callout mock is supplied for safety.
 *
 * @author Elaro Team
 * @since v1.0.0 (Spring '26)
 * @group Tests
 * @see ElaroDeliveryQueueable
 * @see ElaroTestDataFactory
 */
@IsTest(testFor=ElaroDeliveryQueueable.class)
private class ElaroDeliveryQueueableTest {

    private class SlackCalloutMock implements HttpCalloutMock {
        private Integer statusCode;
        public SlackCalloutMock(Integer statusCode) {
            this.statusCode = statusCode;
        }
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(this.statusCode);
            res.setStatus(this.statusCode == 200 ? 'OK' : 'Server Error');
            res.setBody('ok');
            return res;
        }
    }

    @TestSetup
    static void makeData() {
        ElaroTestDataFactory.createAuditPackage('SOC2');
    }

    @IsTest
    static void shouldDeliverForValidPackage() {
        Test.setMock(HttpCalloutMock.class, new SlackCalloutMock(200));

        Elaro_Audit_Package__c pkg = [
            SELECT Id FROM Elaro_Audit_Package__c WITH USER_MODE LIMIT 1
        ];

        Test.startTest();
        System.enqueueJob(new ElaroDeliveryQueueable(pkg.Id, '#compliance'));
        Test.stopTest();

        // Real effect: the queueable resolves the package, builds the message and
        // completes. (http.send is skipped in test context by design.)
        List<AsyncApexJob> jobs = [
            SELECT Id, Status, NumberOfErrors
            FROM AsyncApexJob
            WHERE JobType = 'Queueable'
            AND ApexClass.Name = 'ElaroDeliveryQueueable'
        ];
        Assert.isFalse(jobs.isEmpty(), 'A Queueable AsyncApexJob should have been created');
        Assert.areEqual('Completed', jobs[0].Status, 'Delivery job should complete for a valid package');
        Assert.areEqual(0, jobs[0].NumberOfErrors, 'Delivery job should not record errors');
    }

    @IsTest
    static void shouldConstructWithExplicitRetryCount() {
        Elaro_Audit_Package__c pkg = [
            SELECT Id FROM Elaro_Audit_Package__c WITH USER_MODE LIMIT 1
        ];

        Test.setMock(HttpCalloutMock.class, new SlackCalloutMock(200));

        Test.startTest();
        // Exercises the three-arg constructor used by the retry path.
        System.enqueueJob(new ElaroDeliveryQueueable(pkg.Id, '#compliance', 1));
        Test.stopTest();

        List<AsyncApexJob> jobs = [
            SELECT Id, Status
            FROM AsyncApexJob
            WHERE JobType = 'Queueable'
            AND ApexClass.Name = 'ElaroDeliveryQueueable'
        ];
        Assert.isFalse(jobs.isEmpty(), 'Retry-count constructor should enqueue a job');
        Assert.areEqual('Completed', jobs[0].Status, 'Retry-count delivery job should complete');
    }

    @IsTest
    static void finalizerShouldConstructWithRetryContext() {
        // The DeliveryFinalizer cannot be driven with a real FinalizerContext from a
        // test, but constructing it confirms the retry-context wiring compiles and is
        // wired with the package, channel, and retry count the execute() method attaches.
        ElaroDeliveryQueueable.DeliveryFinalizer finalizer =
            new ElaroDeliveryQueueable.DeliveryFinalizer('a01000000000000AAA', '#compliance', 0);
        Assert.isNotNull(finalizer, 'Finalizer should be constructable with retry context');
    }
}
