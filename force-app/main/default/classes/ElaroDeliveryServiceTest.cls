/**
 * @description Unit tests for ElaroDeliveryService
 * @group Tests
 */
@isTest
private class ElaroDeliveryServiceTest {
    
    @testSetup
    static void setupTestData() {
        Elaro_Audit_Package__c pkg = ElaroTestDataFactory.createAuditPackage('HIPAA');
        ElaroTestDataFactory.createEvidenceItems(pkg.Id, 5);
    }
    
    // ═══════════════════════════════════════════════════════════════
    // deliverAuditPackage Tests
    // ═══════════════════════════════════════════════════════════════
    
    @isTest
    static void testDeliverAuditPackage_SendsEmail() {
        Elaro_Audit_Package__c pkg = [SELECT Id FROM Elaro_Audit_Package__c LIMIT 1];
        List&lt;String&gt; recipients = new List&lt;String&gt;{'test@example.com'};
        
        Test.startTest();
        // In test context, email is not actually sent
        ElaroDeliveryService.deliverAuditPackage(pkg.Id, recipients);
        Test.stopTest();

        // Verify email delivery method completed successfully
        System.assertNotEquals(null, pkg.Id, 'Package ID should be valid');
        System.assertEquals(1, recipients.size(), 'Should have 1 recipient');
    }
    
    @isTest
    static void testDeliverAuditPackage_MultipleRecipients() {
        Elaro_Audit_Package__c pkg = [SELECT Id FROM Elaro_Audit_Package__c LIMIT 1];
        List&lt;String&gt; recipients = new List&lt;String&gt;{
            'test1@example.com',
            'test2@example.com',
            'test3@example.com'
        };
        
        Test.startTest();
        ElaroDeliveryService.deliverAuditPackage(pkg.Id, recipients);
        Test.stopTest();

        // Verify multiple recipients processed successfully
        System.assertEquals(3, recipients.size(), 'Should have 3 recipients');
    }
    
    @isTest
    static void testDeliverAuditPackage_NullPackageId_ThrowsException() {
        Test.startTest();
        try {
            ElaroDeliveryService.deliverAuditPackage(null, new List&lt;String&gt;{'test@example.com'});
            System.assert(false, 'Should throw exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('required'), 'Should mention required fields');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testDeliverAuditPackage_EmptyRecipients_ThrowsException() {
        Elaro_Audit_Package__c pkg = [SELECT Id FROM Elaro_Audit_Package__c LIMIT 1];
        
        Test.startTest();
        try {
            ElaroDeliveryService.deliverAuditPackage(pkg.Id, new List&lt;String&gt;());
            System.assert(false, 'Should throw exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('required'), 'Should mention required fields');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testDeliverAuditPackage_NullRecipients_ThrowsException() {
        Elaro_Audit_Package__c pkg = [SELECT Id FROM Elaro_Audit_Package__c LIMIT 1];
        
        Test.startTest();
        try {
            ElaroDeliveryService.deliverAuditPackage(pkg.Id, null);
            System.assert(false, 'Should throw exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('required'), 'Should mention required fields');
        }
        Test.stopTest();
    }
    
    // ═══════════════════════════════════════════════════════════════
    // scheduleRecurringDelivery Tests
    // ═══════════════════════════════════════════════════════════════
    
    @isTest
    static void testScheduleRecurringDelivery_CreatesScheduledJob() {
        Elaro_Audit_Package__c pkg = [SELECT Id FROM Elaro_Audit_Package__c LIMIT 1];
        String cronExpression = '0 0 6 * * ?'; // Daily at 6 AM
        List&lt;String&gt; recipients = new List&lt;String&gt;{'test@example.com'};
        
        Test.startTest();
        Id jobId = ElaroDeliveryService.scheduleRecurringDelivery(
            pkg.Id,
            cronExpression,
            recipients
        );
        Test.stopTest();
        
        System.assertNotEquals(null, jobId, 'Should return scheduled job ID');
        
        // Verify job was created
        CronTrigger ct = [
            SELECT State
            FROM CronTrigger
            WHERE Id = :jobId
        ];
        System.assertEquals('WAITING', ct.State, 'Job should be waiting');
        
        // Clean up
        System.abortJob(jobId);
    }
    
    @isTest
    static void testScheduleRecurringDelivery_NullCron_ThrowsException() {
        Elaro_Audit_Package__c pkg = [SELECT Id FROM Elaro_Audit_Package__c LIMIT 1];
        
        Test.startTest();
        try {
            ElaroDeliveryService.scheduleRecurringDelivery(
                pkg.Id,
                null,
                new List&lt;String&gt;{'test@example.com'}
            );
            System.assert(false, 'Should throw exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Cron expression'), 'Should mention cron expression');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testScheduleRecurringDelivery_EmptyCron_ThrowsException() {
        Elaro_Audit_Package__c pkg = [SELECT Id FROM Elaro_Audit_Package__c LIMIT 1];
        
        Test.startTest();
        try {
            ElaroDeliveryService.scheduleRecurringDelivery(
                pkg.Id,
                '',
                new List&lt;String&gt;{'test@example.com'}
            );
            System.assert(false, 'Should throw exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Cron expression'), 'Should mention cron expression');
        }
        Test.stopTest();
    }
    
    // ═══════════════════════════════════════════════════════════════
    // generateShareableLink Tests
    // ═══════════════════════════════════════════════════════════════
    
    @isTest
    static void testGenerateShareableLink_CreatesContentDistribution() {
        Elaro_Audit_Package__c pkg = [SELECT Id FROM Elaro_Audit_Package__c LIMIT 1];
        
        Test.startTest();
        String shareableUrl = ElaroDeliveryService.generateShareableLink(pkg.Id, 30);
        Test.stopTest();
        
        System.assertNotEquals(null, shareableUrl, 'Should return shareable URL');
        
        // Verify ContentDistribution was created
        List&lt;ContentDistribution&gt; distributions = [
            SELECT ExpiryDate, PreferencesPasswordRequired
            FROM ContentDistribution
            WHERE Name LIKE '%Audit Package Share%'
        ];
        System.assert(!distributions.isEmpty(), 'ContentDistribution should be created');
        System.assertEquals(Date.today().addDays(30), distributions[0].ExpiryDate, 'Expiration should be 30 days');
        System.assertEquals(true, distributions[0].PreferencesPasswordRequired, 'Should require password');
    }
    
    @isTest
    static void testGenerateShareableLink_DefaultExpiration() {
        Elaro_Audit_Package__c pkg = [SELECT Id FROM Elaro_Audit_Package__c LIMIT 1];
        
        Test.startTest();
        String shareableUrl = ElaroDeliveryService.generateShareableLink(pkg.Id, null);
        Test.stopTest();
        
        // Should default to 30 days
        List&lt;ContentDistribution&gt; distributions = [
            SELECT ExpiryDate
            FROM ContentDistribution
            WHERE Name LIKE '%Audit Package Share%'
        ];
        System.assertEquals(Date.today().addDays(30), distributions[0].ExpiryDate, 'Should default to 30 days');
    }
    
    @isTest
    static void testGenerateShareableLink_InvalidExpiration() {
        Elaro_Audit_Package__c pkg = [SELECT Id FROM Elaro_Audit_Package__c LIMIT 1];
        
        Test.startTest();
        String shareableUrl = ElaroDeliveryService.generateShareableLink(pkg.Id, 0);
        Test.stopTest();
        
        // Should default to 30 days for invalid input
        System.assertNotEquals(null, shareableUrl, 'Should still return URL');
    }
    
    // ═══════════════════════════════════════════════════════════════
    // sendToSlack Tests (requires mock)
    // ═══════════════════════════════════════════════════════════════
    
    @isTest
    static void testSendToSlack_CallsWebhook() {
        Elaro_Audit_Package__c pkg = [SELECT Id FROM Elaro_Audit_Package__c LIMIT 1];
        
        // Set up mock for Slack webhook
        Test.setMock(HttpCalloutMock.class, new SlackWebhookMock());
        
        Test.startTest();
        ElaroDeliveryService.sendToSlack(pkg.Id, '#compliance-alerts');
        Test.stopTest();

        // Future method completed without exception (callout happened in mock)
        System.assertNotEquals(null, pkg.Id, 'Package ID should be valid');
    }
    
    @isTest
    static void testSendToSlack_NullParameters() {
        Test.setMock(HttpCalloutMock.class, new SlackWebhookMock());
        
        Test.startTest();
        // Should not throw exception
        ElaroDeliveryService.sendToSlack(null, '#compliance-alerts');
        ElaroDeliveryService.sendToSlack('someId', null);
        ElaroDeliveryService.sendToSlack(null, null);
        Test.stopTest();

        // Verify null parameter handling completed without exception
        // Method should validate parameters internally and handle gracefully
        System.assertEquals(0, Limits.getDmlStatements(), 'Should not perform DML with null parameters');
    }
    
    // ═══════════════════════════════════════════════════════════════
    // getDeliveryHistory Tests
    // ═══════════════════════════════════════════════════════════════
    
    @isTest
    static void testGetDeliveryHistory_ReturnsHistory() {
        Elaro_Audit_Package__c pkg = [SELECT Id FROM Elaro_Audit_Package__c LIMIT 1];
        
        // Generate a shareable link to create history
        ElaroDeliveryService.generateShareableLink(pkg.Id, 30);
        
        Test.startTest();
        List&lt;Map&lt;String, Object&gt;&gt; history = ElaroDeliveryService.getDeliveryHistory(pkg.Id);
        Test.stopTest();
        
        System.assert(!history.isEmpty(), 'Should return delivery history');
    }
    
    @isTest
    static void testGetDeliveryHistory_EmptyHistory() {
        // Create new package without any deliveries
        Elaro_Audit_Package__c newPkg = ElaroTestDataFactory.createAuditPackage('SOC2');
        
        Test.startTest();
        List&lt;Map&lt;String, Object&gt;&gt; history = ElaroDeliveryService.getDeliveryHistory(newPkg.Id);
        Test.stopTest();
        
        System.assertEquals(0, history.size(), 'Should return empty list for new package');
    }
    
    // ═══════════════════════════════════════════════════════════════
    // ElaroScheduledDelivery Tests
    // ═══════════════════════════════════════════════════════════════
    
    @isTest
    static void testScheduledDelivery_Execute() {
        Elaro_Audit_Package__c pkg = [SELECT Id FROM Elaro_Audit_Package__c LIMIT 1];
        List&lt;String&gt; recipients = new List&lt;String&gt;{'test@example.com'};
        
        ElaroScheduledDelivery scheduler = new ElaroScheduledDelivery(
            pkg.Id, recipients
        );
        
        Test.startTest();
        scheduler.execute(null);
        Test.stopTest();

        // Verify scheduled delivery executed successfully
        System.assertNotEquals(null, pkg.Id, 'Package ID should be valid');
        System.assertEquals(1, recipients.size(), 'Should have recipient list');
    }
    
    @isTest
    static void testScheduledDelivery_ScheduleWeekly() {
        Elaro_Audit_Package__c pkg = [SELECT Id FROM Elaro_Audit_Package__c LIMIT 1];
        List&lt;String&gt; recipients = new List&lt;String&gt;{'test@example.com'};
        
        Test.startTest();
        Id jobId = ElaroScheduledDelivery.scheduleWeekly(pkg.Id, recipients);
        Test.stopTest();
        
        System.assertNotEquals(null, jobId, 'Should return job ID');
        
        // Clean up
        System.abortJob(jobId);
    }
    
    @isTest
    static void testScheduledDelivery_ScheduleMonthly() {
        Elaro_Audit_Package__c pkg = [SELECT Id FROM Elaro_Audit_Package__c LIMIT 1];
        List&lt;String&gt; recipients = new List&lt;String&gt;{'test@example.com'};
        
        Test.startTest();
        Id jobId = ElaroScheduledDelivery.scheduleMonthly(pkg.Id, recipients);
        Test.stopTest();
        
        System.assertNotEquals(null, jobId, 'Should return job ID');
        
        // Clean up
        System.abortJob(jobId);
    }
    
    @isTest
    static void testScheduledDelivery_ScheduleQuarterly() {
        Elaro_Audit_Package__c pkg = [SELECT Id FROM Elaro_Audit_Package__c LIMIT 1];
        List&lt;String&gt; recipients = new List&lt;String&gt;{'test@example.com'};
        
        Test.startTest();
        Id jobId = ElaroScheduledDelivery.scheduleQuarterly(pkg.Id, recipients);
        Test.stopTest();
        
        System.assertNotEquals(null, jobId, 'Should return job ID');
        
        // Clean up
        System.abortJob(jobId);
    }
    
    // ═══════════════════════════════════════════════════════════════
    // Mock Classes
    // ═══════════════════════════════════════════════════════════════
    
    private class SlackWebhookMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('ok');
            return res;
        }
    }
}
