/**
 * Test class for AccessReviewScheduler.AccessReviewQueueable.
 *
 * The scheduler's inner Queueable delegates to performAccessReview(), which is
 * the same code path the scheduled job runs in production. These tests enqueue
 * the Queueable directly (the path NOT exercised by AccessReviewSchedulerTest,
 * which only runs the scheduler synchronously) and assert the real effect: an
 * audit log entry is written and the job completes without an unhandled exception.
 *
 * @author Elaro Team
 * @since v1.0.0 (Spring '26)
 * @group Tests
 * @see AccessReviewScheduler
 */
@IsTest(testFor=AccessReviewScheduler.class)
private class AccessReviewQueueableTest {

    @TestSetup
    static void makeData() {
        // Recently reviewed records so getUsersRequiringReview has prior data to filter on.
        List<Access_Review__c> reviews = new List<Access_Review__c>();
        for (Integer i = 0; i < 5; i++) {
            reviews.add(new Access_Review__c(
                Review_Type__c = 'Periodic Review',
                Status__c = 'Completed',
                Review_Date__c = Date.today().addDays(-10),
                Due_Date__c = Date.today().addDays(-5),
                Review_Scope__c = 'Full Access Review'
            ));
        }
        insert reviews;
    }

    @IsTest
    static void shouldRunQueueableAndWriteAuditLog() {
        Test.startTest();
        System.enqueueJob(new AccessReviewScheduler.AccessReviewQueueable());
        Test.stopTest();

        // Real effect: performAccessReview() writes an audit log entry regardless of
        // how many users are processed (success path or "no users" path).
        List<Elaro_Audit_Log__c> logs = [
            SELECT Id, Action__c
            FROM Elaro_Audit_Log__c
            WHERE Action__c = 'Access Review Scheduled Job'
            WITH USER_MODE
        ];
        Assert.isFalse(logs.isEmpty(), 'Queueable should create an Access Review audit log entry');
    }

    @IsTest
    static void shouldCompleteJobSuccessfully() {
        Test.startTest();
        System.enqueueJob(new AccessReviewScheduler.AccessReviewQueueable());
        Test.stopTest();

        // The inner Queueable wraps all work in try/catch, so the AsyncApexJob
        // must finish in a Completed state even if internal processing varies.
        List<AsyncApexJob> jobs = [
            SELECT Id, Status, NumberOfErrors
            FROM AsyncApexJob
            WHERE JobType = 'Queueable'
            AND ApexClass.Name = 'AccessReviewScheduler'
        ];
        Assert.isFalse(jobs.isEmpty(), 'A Queueable AsyncApexJob should have been created');
        Assert.areEqual('Completed', jobs[0].Status, 'Queueable job should complete');
        Assert.areEqual(0, jobs[0].NumberOfErrors, 'Queueable should swallow errors internally');
    }
}
