/**
 * Test class for PrometheionGLBAPrivacyNoticeService
 * Tests GLBA Privacy Rule functionality
 *
 * @author Prometheion
 * @version 1.0
 */
@IsTest
private class PrometheionGLBAPrivacyNoticeServiceTest {

    @TestSetup
    static void setupTestData() {
        // Create test accounts
        List<Account> accounts = new List<Account>();
        for (Integer i = 0; i < 200; i++) {
            accounts.add(new Account(
                Name = 'Financial Account ' + i,
                Industry = 'Financial Services'
            ));
        }
        insert accounts;

        // Create test contacts
        List<Contact> contacts = new List<Contact>();
        for (Integer i = 0; i < 200; i++) {
            contacts.add(new Contact(
                FirstName = 'Customer',
                LastName = 'Contact ' + i,
                Email = 'customer' + i + '@example.com',
                AccountId = accounts[i].Id
            ));
        }
        insert contacts;
    }

    @IsTest
    static void testSendInitialNotice() {
        Contact c = [SELECT Id, AccountId FROM Contact LIMIT 1];

        Test.startTest();
        Privacy_Notice__c notice = PrometheionGLBAPrivacyNoticeService.sendInitialNotice(
            c.Id,
            c.AccountId,
            'Email'
        );
        Test.stopTest();

        System.assertNotEquals(null, notice.Id, 'Notice should be created');
        System.assertEquals('Initial', notice.Notice_Type__c, 'Type should be Initial');
        System.assertEquals('Sent', notice.Delivery_Status__c, 'Status should be Sent');
        System.assertNotEquals(null, notice.Opt_Out_Deadline__c, 'Opt-out deadline should be set');
    }

    @IsTest
    static void testSendInitialNotice_AllDeliveryMethods() {
        List<Contact> contacts = [SELECT Id, AccountId FROM Contact LIMIT 4];
        List<String> methods = new List<String>{'Email', 'Mail', 'In-App Notification', 'Portal'};

        Test.startTest();
        for (Integer i = 0; i < 4; i++) {
            Privacy_Notice__c notice = PrometheionGLBAPrivacyNoticeService.sendInitialNotice(
                contacts[i].Id,
                contacts[i].AccountId,
                methods[i]
            );
            System.assertEquals(methods[i], notice.Delivery_Method__c, 'Delivery method should match');
        }
        Test.stopTest();
    }

    @IsTest
    static void testSendAnnualNotices() {
        // Create existing notices with past due date
        List<Contact> contacts = [SELECT Id, AccountId FROM Contact LIMIT 10];
        List<Privacy_Notice__c> oldNotices = new List<Privacy_Notice__c>();
        for (Contact c : contacts) {
            oldNotices.add(new Privacy_Notice__c(
                Contact__c = c.Id,
                Account__c = c.AccountId,
                Notice_Type__c = 'Initial',
                Sent_Date__c = System.now().addDays(-400),
                Delivery_Method__c = 'Email',
                Delivery_Status__c = 'Delivered',
                Next_Annual_Notice_Due__c = Date.today().addDays(-5)
            ));
        }
        insert oldNotices;

        Test.startTest();
        List<Privacy_Notice__c> annualNotices = PrometheionGLBAPrivacyNoticeService.sendAnnualNotices();
        Test.stopTest();

        System.assert(annualNotices.size() > 0, 'Should create annual notices');
        for (Privacy_Notice__c notice : annualNotices) {
            System.assertEquals('Annual', notice.Notice_Type__c, 'Type should be Annual');
        }
    }

    @IsTest
    static void testSendRevisedNotices() {
        List<Contact> contacts = [SELECT Id FROM Contact LIMIT 50];
        Set<Id> contactIds = new Set<Id>();
        for (Contact c : contacts) {
            contactIds.add(c.Id);
        }

        Test.startTest();
        List<Privacy_Notice__c> notices = PrometheionGLBAPrivacyNoticeService.sendRevisedNotices(
            contactIds,
            'Privacy policy updated to include new data sharing practices'
        );
        Test.stopTest();

        System.assertEquals(50, notices.size(), 'Should create 50 revised notices');
        for (Privacy_Notice__c notice : notices) {
            System.assertEquals('Revised', notice.Notice_Type__c, 'Type should be Revised');
        }
    }

    @IsTest
    static void testProcessOptOut() {
        Contact c = [SELECT Id, AccountId FROM Contact LIMIT 1];
        Privacy_Notice__c notice = new Privacy_Notice__c(
            Contact__c = c.Id,
            Account__c = c.AccountId,
            Notice_Type__c = 'Initial',
            Sent_Date__c = System.now(),
            Delivery_Method__c = 'Email',
            Delivery_Status__c = 'Delivered',
            Opt_Out_Deadline__c = Date.today().addDays(30)
        );
        insert notice;

        Test.startTest();
        PrometheionGLBAPrivacyNoticeService.processOptOut(
            notice.Id,
            new List<String>{'Third-party sharing', 'Marketing'}
        );
        Test.stopTest();

        notice = [SELECT Customer_Opted_Out__c, Opt_Out_Date__c FROM Privacy_Notice__c WHERE Id = :notice.Id];
        System.assertEquals(true, notice.Customer_Opted_Out__c, 'Should be opted out');
        System.assertNotEquals(null, notice.Opt_Out_Date__c, 'Opt-out date should be set');
    }

    @IsTest
    static void testProcessOptOut_DeadlinePassed() {
        Contact c = [SELECT Id, AccountId FROM Contact LIMIT 1];
        Privacy_Notice__c notice = new Privacy_Notice__c(
            Contact__c = c.Id,
            Account__c = c.AccountId,
            Notice_Type__c = 'Initial',
            Sent_Date__c = System.now().addDays(-60),
            Delivery_Method__c = 'Email',
            Delivery_Status__c = 'Delivered',
            Opt_Out_Deadline__c = Date.today().addDays(-30)
        );
        insert notice;

        Test.startTest();
        try {
            PrometheionGLBAPrivacyNoticeService.processOptOut(notice.Id, new List<String>{'Marketing'});
            System.assert(false, 'Should throw exception');
        } catch (PrometheionGLBAPrivacyNoticeService.GLBAComplianceException e) {
            System.assert(e.getMessage().contains('deadline'), 'Should mention deadline');
        }
        Test.stopTest();
    }

    @IsTest
    static void testGetContactsMissingNotices() {
        // Contacts from setup don't have notices yet
        Test.startTest();
        List<Id> missingIds = PrometheionGLBAPrivacyNoticeService.getContactsMissingNotices();
        Test.stopTest();

        // May return contacts if they're old enough (30+ days)
        System.assertNotEquals(null, missingIds, 'Should return list');
    }

    @IsTest
    static void testGetOverdueNoticeCount() {
        // Create overdue notices
        List<Contact> contacts = [SELECT Id, AccountId FROM Contact LIMIT 5];
        List<Privacy_Notice__c> overdueNotices = new List<Privacy_Notice__c>();
        for (Contact c : contacts) {
            overdueNotices.add(new Privacy_Notice__c(
                Contact__c = c.Id,
                Account__c = c.AccountId,
                Notice_Type__c = 'Annual',
                Sent_Date__c = System.now().addDays(-400),
                Delivery_Method__c = 'Email',
                Delivery_Status__c = 'Delivered',
                Next_Annual_Notice_Due__c = Date.today().addDays(-10)
            ));
        }
        insert overdueNotices;

        Test.startTest();
        Integer count = PrometheionGLBAPrivacyNoticeService.getOverdueNoticeCount();
        Test.stopTest();

        System.assert(count >= 5, 'Should find overdue notices');
    }

    @IsTest
    static void testUpdateDeliveryStatus() {
        Contact c = [SELECT Id, AccountId FROM Contact LIMIT 1];
        Privacy_Notice__c notice = new Privacy_Notice__c(
            Contact__c = c.Id,
            Account__c = c.AccountId,
            Notice_Type__c = 'Initial',
            Sent_Date__c = System.now(),
            Delivery_Method__c = 'Email',
            Delivery_Status__c = 'Pending'
        );
        insert notice;

        Test.startTest();
        PrometheionGLBAPrivacyNoticeService.updateDeliveryStatus(notice.Id, 'Delivered');
        Test.stopTest();

        notice = [SELECT Delivery_Status__c FROM Privacy_Notice__c WHERE Id = :notice.Id];
        System.assertEquals('Delivered', notice.Delivery_Status__c, 'Status should be updated');
    }

    @IsTest
    static void testGetComplianceMetrics() {
        // Create some test data
        List<Contact> contacts = [SELECT Id, AccountId FROM Contact LIMIT 5];
        List<Privacy_Notice__c> notices = new List<Privacy_Notice__c>();
        for (Contact c : contacts) {
            notices.add(new Privacy_Notice__c(
                Contact__c = c.Id,
                Account__c = c.AccountId,
                Notice_Type__c = 'Initial',
                Sent_Date__c = System.now(),
                Delivery_Method__c = 'Email',
                Delivery_Status__c = 'Delivered',
                Opt_Out_Deadline__c = Date.today().addDays(30)
            ));
        }
        insert notices;

        Test.startTest();
        Map<String, Object> metrics = PrometheionGLBAPrivacyNoticeService.getComplianceMetrics();
        Test.stopTest();

        System.assert(metrics.containsKey('totalNoticesThisYear'), 'Should have totalNoticesThisYear');
        System.assert(metrics.containsKey('optOutRate'), 'Should have optOutRate');
        System.assert(metrics.containsKey('overdueCount'), 'Should have overdueCount');
        System.assert(metrics.containsKey('pendingDeliveries'), 'Should have pendingDeliveries');
    }

    @IsTest
    static void testBulkNoticeCreation() {
        List<Contact> contacts = [SELECT Id, AccountId FROM Contact LIMIT 200];
        Set<Id> contactIds = new Set<Id>();
        for (Contact c : contacts) {
            contactIds.add(c.Id);
        }

        Test.startTest();
        Integer startQueries = Limits.getQueries();

        List<Privacy_Notice__c> notices = PrometheionGLBAPrivacyNoticeService.sendRevisedNotices(
            contactIds,
            'Bulk test'
        );

        Integer endQueries = Limits.getQueries();
        Test.stopTest();

        System.assertEquals(200, notices.size(), 'Should create 200 notices');
        System.assert(endQueries - startQueries < 10, 'Should be bulkified');
    }
}
