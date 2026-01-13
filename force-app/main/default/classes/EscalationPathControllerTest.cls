/**
 * @description Test class for EscalationPathController
 * @author Prometheion Development Team
 * @since 2026-01
 */
@isTest
private class EscalationPathControllerTest {

    @TestSetup
    static void setupTestData() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User testUser = new User(
            Alias = 'escpath',
            Email = 'escpathuser@prometheion.test',
            EmailEncodingKey = 'UTF-8',
            LastName = 'EscPath',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/New_York',
            UserName = 'escpathuser' + Datetime.now().getTime() + '@prometheion.test'
        );
        insert testUser;

        Prometheion_Escalation_Path__c path = new Prometheion_Escalation_Path__c(
            User__c = testUser.Id,
            Level__c = 1,
            Active__c = true,
            Role__c = 'Team Lead',
            Notification_Method__c = 'Both',
            Escalation_Delay_Minutes__c = 15
        );
        insert path;
    }

    @isTest
    static void testGetPaths() {
        Test.startTest();
        List<Prometheion_Escalation_Path__c> paths = EscalationPathController.getPaths();
        Test.stopTest();

        System.assertEquals(1, paths.size(), 'Should return one path');
        System.assertEquals(1, paths[0].Level__c, 'Level should match');
    }

    @isTest
    static void testCreatePath() {
        User testUser = [SELECT Id FROM User WHERE LastName = 'EscPath' LIMIT 1];

        Prometheion_Escalation_Path__c newPath = new Prometheion_Escalation_Path__c(
            User__c = testUser.Id,
            Level__c = 2,
            Active__c = true,
            Role__c = 'Manager',
            Notification_Method__c = 'Email',
            Escalation_Delay_Minutes__c = 30
        );

        Test.startTest();
        Id pathId = EscalationPathController.createPath(newPath);
        Test.stopTest();

        System.assertNotEquals(null, pathId, 'Path ID should be returned');

        List<Prometheion_Escalation_Path__c> paths = [SELECT Level__c FROM Prometheion_Escalation_Path__c WHERE Id = :pathId];
        System.assertEquals(1, paths.size(), 'Path should exist');
        System.assertEquals(2, paths[0].Level__c, 'Level should match');
    }

    @isTest
    static void testUpdatePath() {
        Prometheion_Escalation_Path__c path = [SELECT Id, Role__c FROM Prometheion_Escalation_Path__c LIMIT 1];
        path.Role__c = 'Senior Team Lead';

        Test.startTest();
        EscalationPathController.updatePath(path);
        Test.stopTest();

        Prometheion_Escalation_Path__c updated = [SELECT Role__c FROM Prometheion_Escalation_Path__c WHERE Id = :path.Id];
        System.assertEquals('Senior Team Lead', updated.Role__c, 'Role should be updated');
    }

    @isTest
    static void testDeletePath() {
        Prometheion_Escalation_Path__c path = [SELECT Id FROM Prometheion_Escalation_Path__c LIMIT 1];

        Test.startTest();
        EscalationPathController.deletePath(path.Id);
        Test.stopTest();

        List<Prometheion_Escalation_Path__c> paths = [SELECT Id FROM Prometheion_Escalation_Path__c WHERE Id = :path.Id];
        System.assertEquals(0, paths.size(), 'Path should be deleted');
    }

    @isTest
    static void testCreatePath_MissingUser() {
        Prometheion_Escalation_Path__c path = new Prometheion_Escalation_Path__c(
            User__c = null,
            Level__c = 1,
            Active__c = true,
            Role__c = 'Team Lead',
            Escalation_Delay_Minutes__c = 15
        );

        Test.startTest();
        try {
            EscalationPathController.createPath(path);
            System.assert(false, 'Expected exception for missing user');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('User'), 'Error message should mention user');
        }
        Test.stopTest();
    }

    @isTest
    static void testCreatePath_InvalidLevel_Zero() {
        User testUser = [SELECT Id FROM User WHERE LastName = 'EscPath' LIMIT 1];

        Prometheion_Escalation_Path__c path = new Prometheion_Escalation_Path__c(
            User__c = testUser.Id,
            Level__c = 0,
            Active__c = true,
            Role__c = 'Team Lead',
            Escalation_Delay_Minutes__c = 15
        );

        Test.startTest();
        try {
            EscalationPathController.createPath(path);
            System.assert(false, 'Expected exception for invalid level');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Level'), 'Error message should mention level');
        }
        Test.stopTest();
    }

    @isTest
    static void testCreatePath_InvalidLevel_TooHigh() {
        User testUser = [SELECT Id FROM User WHERE LastName = 'EscPath' LIMIT 1];

        Prometheion_Escalation_Path__c path = new Prometheion_Escalation_Path__c(
            User__c = testUser.Id,
            Level__c = 5,
            Active__c = true,
            Role__c = 'Team Lead',
            Escalation_Delay_Minutes__c = 15
        );

        Test.startTest();
        try {
            EscalationPathController.createPath(path);
            System.assert(false, 'Expected exception for invalid level');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Level'), 'Error message should mention level');
        }
        Test.stopTest();
    }

    @isTest
    static void testCreatePath_InvalidDelay() {
        User testUser = [SELECT Id FROM User WHERE LastName = 'EscPath' LIMIT 1];

        Prometheion_Escalation_Path__c path = new Prometheion_Escalation_Path__c(
            User__c = testUser.Id,
            Level__c = 1,
            Active__c = true,
            Role__c = 'Team Lead',
            Escalation_Delay_Minutes__c = 0
        );

        Test.startTest();
        try {
            EscalationPathController.createPath(path);
            System.assert(false, 'Expected exception for invalid delay');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('delay'), 'Error message should mention delay');
        }
        Test.stopTest();
    }

    @isTest
    static void testCreatePath_NullDelay() {
        User testUser = [SELECT Id FROM User WHERE LastName = 'EscPath' LIMIT 1];

        Prometheion_Escalation_Path__c path = new Prometheion_Escalation_Path__c(
            User__c = testUser.Id,
            Level__c = 1,
            Active__c = true,
            Role__c = 'Team Lead',
            Escalation_Delay_Minutes__c = null
        );

        Test.startTest();
        try {
            EscalationPathController.createPath(path);
            System.assert(false, 'Expected exception for null delay');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('delay'), 'Error message should mention delay');
        }
        Test.stopTest();
    }

    @isTest
    static void testCreateMultipleLevels() {
        User testUser = [SELECT Id FROM User WHERE LastName = 'EscPath' LIMIT 1];

        Prometheion_Escalation_Path__c path2 = new Prometheion_Escalation_Path__c(
            User__c = testUser.Id,
            Level__c = 2,
            Active__c = true,
            Role__c = 'Manager',
            Notification_Method__c = 'Both',
            Escalation_Delay_Minutes__c = 30
        );

        Prometheion_Escalation_Path__c path3 = new Prometheion_Escalation_Path__c(
            User__c = testUser.Id,
            Level__c = 3,
            Active__c = true,
            Role__c = 'CISO',
            Notification_Method__c = 'All',
            Escalation_Delay_Minutes__c = 60
        );

        Test.startTest();
        EscalationPathController.createPath(path2);
        EscalationPathController.createPath(path3);
        Test.stopTest();

        List<Prometheion_Escalation_Path__c> paths = EscalationPathController.getPaths();
        System.assertEquals(3, paths.size(), 'Should have 3 paths');
    }
}
