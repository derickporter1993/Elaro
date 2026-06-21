/**
 * Test class for ComplianceScoreSnapshotScheduler.ComplianceSnapshotQueueable.
 *
 * The inner Queueable delegates to captureSnapshots(), which evaluates every
 * framework, inserts Compliance_Score__c snapshot rows, and writes a daily
 * summary audit log. These tests enqueue the Queueable directly and assert the
 * real persisted effects.
 *
 * @author Elaro Team
 * @since v1.0.0 (Spring '26)
 * @group Tests
 * @see ComplianceScoreSnapshotScheduler
 */
@IsTest(testFor=ComplianceScoreSnapshotScheduler.class)
private class ComplianceSnapshotQueueableTest {

    @IsTest
    static void shouldCaptureSnapshotsAndWriteSummary() {
        Test.startTest();
        System.enqueueJob(new ComplianceScoreSnapshotScheduler.ComplianceSnapshotQueueable());
        Test.stopTest();

        // Real effect 1: a daily summary audit log is created by createDailySummary().
        List<Elaro_Audit_Log__c> summaryLogs = [
            SELECT Id, Action__c
            FROM Elaro_Audit_Log__c
            WHERE Action__c = 'Daily Compliance Summary'
            WITH USER_MODE
        ];
        Assert.isFalse(summaryLogs.isEmpty(), 'Queueable should create a Daily Compliance Summary audit log');

        // Real effect 2: an execution audit log is also written.
        List<Elaro_Audit_Log__c> executionLogs = [
            SELECT Id
            FROM Elaro_Audit_Log__c
            WHERE Action__c = 'Compliance Score Snapshot'
            WITH USER_MODE
        ];
        Assert.isFalse(executionLogs.isEmpty(), 'Queueable should create a Compliance Score Snapshot audit log');
    }

    @IsTest
    static void shouldPersistComplianceScoreSnapshots() {
        Test.startTest();
        System.enqueueJob(new ComplianceScoreSnapshotScheduler.ComplianceSnapshotQueueable());
        Test.stopTest();

        // Real effect: one Compliance_Score__c snapshot per evaluated framework.
        List<Compliance_Score__c> snapshots = [
            SELECT Id, Framework__c, Score__c
            FROM Compliance_Score__c
            WITH USER_MODE
        ];
        Assert.isFalse(snapshots.isEmpty(), 'Queueable should persist Compliance_Score__c snapshots');
    }

    @IsTest
    static void shouldCompleteJobSuccessfully() {
        Test.startTest();
        System.enqueueJob(new ComplianceScoreSnapshotScheduler.ComplianceSnapshotQueueable());
        Test.stopTest();

        List<AsyncApexJob> jobs = [
            SELECT Id, Status, NumberOfErrors
            FROM AsyncApexJob
            WHERE JobType = 'Queueable'
            AND ApexClass.Name = 'ComplianceScoreSnapshotScheduler'
        ];
        Assert.isFalse(jobs.isEmpty(), 'A Queueable AsyncApexJob should have been created');
        Assert.areEqual('Completed', jobs[0].Status, 'Queueable job should complete');
        Assert.areEqual(0, jobs[0].NumberOfErrors, 'Queueable should swallow errors internally');
    }
}
