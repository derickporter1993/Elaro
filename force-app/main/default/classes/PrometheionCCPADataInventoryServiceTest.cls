/**
 * Test class for PrometheionCCPADataInventoryService
 * Tests CCPA Section 1798.100 Right to Know functionality
 *
 * @author Prometheion
 * @version 1.0
 */
@IsTest
private class PrometheionCCPADataInventoryServiceTest {

    @TestSetup
    static void setupTestData() {
        // Create test accounts
        List<Account> accounts = new List<Account>();
        for (Integer i = 0; i < 200; i++) {
            accounts.add(new Account(
                Name = 'Test Account ' + i,
                Industry = 'Technology',
                BillingState = 'California'
            ));
        }
        insert accounts;

        // Create test contacts (California residents)
        List<Contact> contacts = new List<Contact>();
        for (Integer i = 0; i < 200; i++) {
            contacts.add(new Contact(
                FirstName = 'Test',
                LastName = 'Contact ' + i,
                Email = 'test' + i + '@example.com',
                MailingState = 'CA',
                AccountId = accounts[i].Id
            ));
        }
        insert contacts;
    }

    @IsTest
    static void testCreateCCPARequest() {
        Contact c = [SELECT Id FROM Contact LIMIT 1];

        Test.startTest();
        CCPA_Request__c request = PrometheionCCPADataInventoryService.createCCPARequest(
            c.Id,
            'Right to Know'
        );
        Test.stopTest();

        System.assertNotEquals(null, request.Id, 'Request should be created');
        System.assertEquals('Pending', request.Status__c, 'Status should be Pending');
        System.assertEquals('Right to Know', request.Request_Type__c, 'Type should match');
    }

    @IsTest
    static void testCreateBulkCCPARequests() {
        List<Contact> contacts = [SELECT Id FROM Contact LIMIT 200];
        Set<Id> contactIds = new Set<Id>();
        for (Contact c : contacts) {
            contactIds.add(c.Id);
        }

        Test.startTest();
        List<CCPA_Request__c> requests = PrometheionCCPADataInventoryService.createBulkCCPARequests(
            contactIds,
            'Right to Delete'
        );
        Test.stopTest();

        System.assertEquals(200, requests.size(), 'Should create 200 requests');
    }

    @IsTest
    static void testGetDataInventory() {
        Contact c = [SELECT Id FROM Contact LIMIT 1];

        Test.startTest();
        Map<String, Object> inventory = PrometheionCCPADataInventoryService.getDataInventory(c.Id);
        Test.stopTest();

        System.assertNotEquals(null, inventory, 'Should return inventory');
        System.assert(inventory.containsKey('categories'), 'Should have categories');
    }

    @IsTest
    static void testProcessDoNotSellRequest() {
        Contact c = [SELECT Id, CCPA_Do_Not_Sell__c FROM Contact LIMIT 1];
        System.assertEquals(false, c.CCPA_Do_Not_Sell__c, 'Should initially be false');

        Test.startTest();
        PrometheionCCPADataInventoryService.processDoNotSellRequest(c.Id);
        Test.stopTest();

        c = [SELECT CCPA_Do_Not_Sell__c, CCPA_OptOut_Date__c FROM Contact WHERE Id = :c.Id];
        System.assertEquals(true, c.CCPA_Do_Not_Sell__c, 'Should be opted out');
        System.assertNotEquals(null, c.CCPA_OptOut_Date__c, 'Opt-out date should be set');
    }

    @IsTest
    static void testProcessBulkDoNotSell() {
        List<Contact> contacts = [SELECT Id FROM Contact LIMIT 200];
        Set<Id> contactIds = new Set<Id>();
        for (Contact c : contacts) {
            contactIds.add(c.Id);
        }

        Test.startTest();
        PrometheionCCPADataInventoryService.processBulkDoNotSellRequests(contactIds);
        Test.stopTest();

        List<Contact> updatedContacts = [
            SELECT CCPA_Do_Not_Sell__c
            FROM Contact
            WHERE Id IN :contactIds
        ];
        for (Contact c : updatedContacts) {
            System.assertEquals(true, c.CCPA_Do_Not_Sell__c, 'All should be opted out');
        }
    }

    @IsTest
    static void testGetPendingCCPARequests() {
        List<Contact> contacts = [SELECT Id FROM Contact LIMIT 5];
        List<CCPA_Request__c> requests = new List<CCPA_Request__c>();
        for (Contact c : contacts) {
            requests.add(new CCPA_Request__c(
                Contact__c = c.Id,
                Request_Type__c = 'Right to Know',
                Status__c = 'Pending',
                Request_Date__c = System.now(),
                Response_Deadline__c = Date.today().addDays(45)
            ));
        }
        insert requests;

        Test.startTest();
        List<CCPA_Request__c> pending = PrometheionCCPADataInventoryService.getPendingCCPARequests();
        Test.stopTest();

        System.assert(pending.size() >= 5, 'Should return pending requests');
    }

    @IsTest
    static void testCompleteRequest() {
        Contact c = [SELECT Id FROM Contact LIMIT 1];
        CCPA_Request__c request = new CCPA_Request__c(
            Contact__c = c.Id,
            Request_Type__c = 'Right to Know',
            Status__c = 'In Progress',
            Request_Date__c = System.now(),
            Response_Deadline__c = Date.today().addDays(45)
        );
        insert request;

        Test.startTest();
        PrometheionCCPADataInventoryService.completeRequest(request.Id, 'Data provided to consumer');
        Test.stopTest();

        request = [SELECT Status__c, Completed_Date__c FROM CCPA_Request__c WHERE Id = :request.Id];
        System.assertEquals('Completed', request.Status__c, 'Status should be Completed');
    }

    @IsTest
    static void testGetOverdueRequests() {
        Contact c = [SELECT Id FROM Contact LIMIT 1];
        CCPA_Request__c request = new CCPA_Request__c(
            Contact__c = c.Id,
            Request_Type__c = 'Right to Know',
            Status__c = 'Pending',
            Request_Date__c = System.now().addDays(-50),
            Response_Deadline__c = Date.today().addDays(-5)
        );
        insert request;

        Test.startTest();
        List<CCPA_Request__c> overdue = PrometheionCCPADataInventoryService.getOverdueRequests();
        Test.stopTest();

        System.assert(overdue.size() >= 1, 'Should return overdue request');
    }

    @IsTest
    static void testGetComplianceMetrics() {
        Test.startTest();
        Map<String, Object> metrics = PrometheionCCPADataInventoryService.getComplianceMetrics();
        Test.stopTest();

        System.assert(metrics.containsKey('totalRequests'), 'Should have totalRequests');
        System.assert(metrics.containsKey('optOutCount'), 'Should have optOutCount');
        System.assert(metrics.containsKey('averageResponseTime'), 'Should have averageResponseTime');
    }

    @IsTest
    static void testVerifyCaliforniaResidency() {
        Contact c = [SELECT Id, MailingState FROM Contact WHERE MailingState = 'CA' LIMIT 1];

        Test.startTest();
        Boolean isResident = PrometheionCCPADataInventoryService.verifyCaliforniaResidency(c.Id);
        Test.stopTest();

        System.assertEquals(true, isResident, 'Should be California resident');
    }

    @IsTest
    static void testSLAEnforcement() {
        Contact c = [SELECT Id FROM Contact LIMIT 1];

        Test.startTest();
        CCPA_Request__c request = PrometheionCCPADataInventoryService.createCCPARequest(c.Id, 'Right to Know');
        Test.stopTest();

        System.assertEquals(
            Date.today().addDays(45),
            request.Response_Deadline__c,
            'Deadline should be 45 days from request'
        );
    }
}
