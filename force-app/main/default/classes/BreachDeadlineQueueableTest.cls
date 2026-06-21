/**
 * Test class for BreachDeadlineMonitor.BreachDeadlineQueueable.
 *
 * The inner Queueable delegates to monitorDeadlines(), which scans
 * HIPAA_Breach__c records, publishes alert platform events, updates breach
 * statuses, and writes an audit log. These tests seed breaches in the relevant
 * deadline windows, enqueue the Queueable directly, and assert the real effects
 * (status transition + audit log).
 *
 * @author Elaro Team
 * @since v1.0.0 (Spring '26)
 * @group Tests
 * @see BreachDeadlineMonitor
 */
@IsTest(testFor=BreachDeadlineMonitor.class)
private class BreachDeadlineQueueableTest {

    @TestSetup
    static void makeData() {
        List<HIPAA_Breach__c> breaches = new List<HIPAA_Breach__c>();

        // Overdue breach: deadline in the past, notifications incomplete.
        breaches.add(new HIPAA_Breach__c(
            Description__c = 'Overdue test breach',
            Discovery_Date__c = Date.today().addDays(-90),
            Notification_Deadline__c = Date.today().addDays(-5),
            Notification_Required__c = true,
            Individuals_Notified__c = false,
            HHS_Notified__c = false,
            Records_Affected__c = 120,
            Status__c = 'Open',
            Risk_Level__c = 'High'
        ));

        // Critical breach: deadline within 7 days.
        breaches.add(new HIPAA_Breach__c(
            Description__c = 'Critical-window test breach',
            Discovery_Date__c = Date.today().addDays(-40),
            Notification_Deadline__c = Date.today().addDays(3),
            Notification_Required__c = true,
            Individuals_Notified__c = false,
            HHS_Notified__c = false,
            Records_Affected__c = 50,
            Status__c = 'Open',
            Risk_Level__c = 'Medium'
        ));

        // Large breach requiring HHS notification (500+ records).
        breaches.add(new HIPAA_Breach__c(
            Description__c = 'Large HHS-reportable test breach',
            Discovery_Date__c = Date.today().addDays(-10),
            Notification_Deadline__c = Date.today().addDays(20),
            Notification_Required__c = true,
            Individuals_Notified__c = false,
            HHS_Notified__c = false,
            Records_Affected__c = 750,
            Status__c = 'Open',
            Risk_Level__c = 'High'
        ));

        insert breaches;
    }

    @IsTest
    static void shouldTransitionOverdueBreachStatus() {
        Test.startTest();
        System.enqueueJob(new BreachDeadlineMonitor.BreachDeadlineQueueable());
        Test.stopTest();

        // Real effect: overdue breach is moved to 'Notification In Progress'.
        List<HIPAA_Breach__c> overdue = [
            SELECT Id, Status__c
            FROM HIPAA_Breach__c
            WHERE Notification_Deadline__c < TODAY
            WITH USER_MODE
        ];
        Assert.isFalse(overdue.isEmpty(), 'Overdue breach should still exist');
        Assert.areEqual(
            'Notification In Progress',
            overdue[0].Status__c,
            'Overdue breach should be advanced to Notification In Progress'
        );
    }

    @IsTest
    static void shouldWriteMonitoringAuditLog() {
        Test.startTest();
        System.enqueueJob(new BreachDeadlineMonitor.BreachDeadlineQueueable());
        Test.stopTest();

        List<Elaro_Audit_Log__c> logs = [
            SELECT Id, Action__c
            FROM Elaro_Audit_Log__c
            WHERE Action__c = 'Breach Deadline Monitor'
            WITH USER_MODE
        ];
        Assert.isFalse(logs.isEmpty(), 'Queueable should write a Breach Deadline Monitor audit log');
    }

    @IsTest
    static void shouldCompleteJobSuccessfully() {
        Test.startTest();
        System.enqueueJob(new BreachDeadlineMonitor.BreachDeadlineQueueable());
        Test.stopTest();

        List<AsyncApexJob> jobs = [
            SELECT Id, Status, NumberOfErrors
            FROM AsyncApexJob
            WHERE JobType = 'Queueable'
            AND ApexClass.Name = 'BreachDeadlineMonitor'
        ];
        Assert.isFalse(jobs.isEmpty(), 'A Queueable AsyncApexJob should have been created');
        Assert.areEqual('Completed', jobs[0].Status, 'Queueable job should complete');
        Assert.areEqual(0, jobs[0].NumberOfErrors, 'Queueable should swallow errors internally');
    }
}
