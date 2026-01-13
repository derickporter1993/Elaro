/**
 * @description Test class for OnCallScheduleController
 * @author Prometheion Development Team
 * @since 2026-01
 */
@isTest
private class OnCallScheduleControllerTest {

    @TestSetup
    static void setupTestData() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User testUser = new User(
            Alias = 'schuser',
            Email = 'scheduleuser@prometheion.test',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Schedule',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/New_York',
            UserName = 'scheduleuser' + Datetime.now().getTime() + '@prometheion.test'
        );
        insert testUser;

        Prometheion_On_Call_Schedule__c schedule = new Prometheion_On_Call_Schedule__c(
            Name = 'Primary On-Call',
            User__c = testUser.Id,
            Start_Time__c = Datetime.now().addHours(-1),
            End_Time__c = Datetime.now().addHours(8),
            Active__c = true,
            Rotation_Name__c = 'Primary',
            Timezone__c = 'America/New_York',
            Notification_Methods__c = 'Mobile;Email'
        );
        insert schedule;
    }

    @isTest
    static void testGetSchedules() {
        Test.startTest();
        List<Prometheion_On_Call_Schedule__c> schedules = OnCallScheduleController.getSchedules();
        Test.stopTest();

        System.assertEquals(1, schedules.size(), 'Should return one schedule');
        System.assertEquals('Primary On-Call', schedules[0].Name, 'Name should match');
    }

    @isTest
    static void testCreateSchedule() {
        User testUser = [SELECT Id FROM User WHERE LastName = 'Schedule' LIMIT 1];

        Prometheion_On_Call_Schedule__c newSchedule = new Prometheion_On_Call_Schedule__c(
            Name = 'Secondary On-Call',
            User__c = testUser.Id,
            Start_Time__c = Datetime.now().addDays(1),
            End_Time__c = Datetime.now().addDays(1).addHours(8),
            Active__c = true,
            Rotation_Name__c = 'Secondary',
            Timezone__c = 'America/Chicago',
            Notification_Methods__c = 'Mobile'
        );

        Test.startTest();
        Id scheduleId = OnCallScheduleController.createSchedule(newSchedule);
        Test.stopTest();

        System.assertNotEquals(null, scheduleId, 'Schedule ID should be returned');

        List<Prometheion_On_Call_Schedule__c> schedules = [SELECT Name FROM Prometheion_On_Call_Schedule__c WHERE Id = :scheduleId];
        System.assertEquals(1, schedules.size(), 'Schedule should exist');
        System.assertEquals('Secondary On-Call', schedules[0].Name, 'Name should match');
    }

    @isTest
    static void testUpdateSchedule() {
        Prometheion_On_Call_Schedule__c schedule = [SELECT Id, Name FROM Prometheion_On_Call_Schedule__c LIMIT 1];
        schedule.Name = 'Updated Schedule Name';

        Test.startTest();
        OnCallScheduleController.updateSchedule(schedule);
        Test.stopTest();

        Prometheion_On_Call_Schedule__c updated = [SELECT Name FROM Prometheion_On_Call_Schedule__c WHERE Id = :schedule.Id];
        System.assertEquals('Updated Schedule Name', updated.Name, 'Name should be updated');
    }

    @isTest
    static void testDeleteSchedule() {
        Prometheion_On_Call_Schedule__c schedule = [SELECT Id FROM Prometheion_On_Call_Schedule__c LIMIT 1];

        Test.startTest();
        OnCallScheduleController.deleteSchedule(schedule.Id);
        Test.stopTest();

        List<Prometheion_On_Call_Schedule__c> schedules = [SELECT Id FROM Prometheion_On_Call_Schedule__c WHERE Id = :schedule.Id];
        System.assertEquals(0, schedules.size(), 'Schedule should be deleted');
    }

    @isTest
    static void testCreateSchedule_MissingStartTime() {
        User testUser = [SELECT Id FROM User WHERE LastName = 'Schedule' LIMIT 1];

        Prometheion_On_Call_Schedule__c schedule = new Prometheion_On_Call_Schedule__c(
            Name = 'Invalid Schedule',
            User__c = testUser.Id,
            Start_Time__c = null,
            End_Time__c = Datetime.now().addHours(8),
            Active__c = true
        );

        Test.startTest();
        try {
            OnCallScheduleController.createSchedule(schedule);
            System.assert(false, 'Expected exception for missing start time');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Start time'), 'Error message should mention start time');
        }
        Test.stopTest();
    }

    @isTest
    static void testCreateSchedule_MissingEndTime() {
        User testUser = [SELECT Id FROM User WHERE LastName = 'Schedule' LIMIT 1];

        Prometheion_On_Call_Schedule__c schedule = new Prometheion_On_Call_Schedule__c(
            Name = 'Invalid Schedule',
            User__c = testUser.Id,
            Start_Time__c = Datetime.now(),
            End_Time__c = null,
            Active__c = true
        );

        Test.startTest();
        try {
            OnCallScheduleController.createSchedule(schedule);
            System.assert(false, 'Expected exception for missing end time');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('End time'), 'Error message should mention end time');
        }
        Test.stopTest();
    }

    @isTest
    static void testCreateSchedule_InvalidTimeRange() {
        User testUser = [SELECT Id FROM User WHERE LastName = 'Schedule' LIMIT 1];

        Prometheion_On_Call_Schedule__c schedule = new Prometheion_On_Call_Schedule__c(
            Name = 'Invalid Schedule',
            User__c = testUser.Id,
            Start_Time__c = Datetime.now().addHours(8),
            End_Time__c = Datetime.now(),
            Active__c = true
        );

        Test.startTest();
        try {
            OnCallScheduleController.createSchedule(schedule);
            System.assert(false, 'Expected exception for invalid time range');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('after start'), 'Error message should mention time order');
        }
        Test.stopTest();
    }

    @isTest
    static void testCreateSchedule_MissingUser() {
        Prometheion_On_Call_Schedule__c schedule = new Prometheion_On_Call_Schedule__c(
            Name = 'Invalid Schedule',
            User__c = null,
            Start_Time__c = Datetime.now(),
            End_Time__c = Datetime.now().addHours(8),
            Active__c = true
        );

        Test.startTest();
        try {
            OnCallScheduleController.createSchedule(schedule);
            System.assert(false, 'Expected exception for missing user');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('User'), 'Error message should mention user');
        }
        Test.stopTest();
    }
}
