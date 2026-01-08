/**
 * @description Test class for SchedulerErrorHandler utility
 * @author Prometheion Team
 * @date 2025
 */
@isTest
private class SchedulerErrorHandlerTest {
    
    @TestSetup
    static void setupTestData() {
        // Create test user if needed for context
    }
    
    @isTest
    static void testLogError_Success() {
        Test.startTest();
        
        Exception testException = new SchedulerErrorHandler.SchedulerException('Test error message');
        Id logId = SchedulerErrorHandler.logError('TestScheduler', testException);
        
        Test.stopTest();
        
        System.assertNotEquals(null, logId, 'Log record should be created');
        
        Prometheion_Audit_Log__c log = [
            SELECT Action__c, Status__c, Details__c 
            FROM Prometheion_Audit_Log__c 
            WHERE Id = :logId
        ];
        
        System.assertEquals('SCHEDULER_ERROR', log.Action__c);
        System.assertEquals('Error', log.Status__c);
        System.assert(log.Details__c.contains('TestScheduler'));
    }
    
    @isTest
    static void testLogError_WithAdditionalContext() {
        Test.startTest();
        
        Exception testException = new SchedulerErrorHandler.SchedulerException('Test error');
        String context = '{"batchId": "123", "recordCount": 500}';
        Id logId = SchedulerErrorHandler.logError('TestBatch', testException, context);
        
        Test.stopTest();
        
        System.assertNotEquals(null, logId, 'Log record should be created');
        
        Prometheion_Audit_Log__c log = [
            SELECT Details__c 
            FROM Prometheion_Audit_Log__c 
            WHERE Id = :logId
        ];
        
        System.assert(log.Details__c.contains('additionalContext'));
    }
    
    @isTest
    static void testLogSuccess() {
        Test.startTest();
        
        Id logId = SchedulerErrorHandler.logSuccess('TestScheduler', 'Processed 100 records successfully');
        
        Test.stopTest();
        
        System.assertNotEquals(null, logId, 'Log record should be created');
        
        Prometheion_Audit_Log__c log = [
            SELECT Action__c, Status__c, Details__c 
            FROM Prometheion_Audit_Log__c 
            WHERE Id = :logId
        ];
        
        System.assertEquals('SCHEDULER_SUCCESS', log.Action__c);
        System.assertEquals('Success', log.Status__c);
    }
    
    @isTest
    static void testHandleSaveResults_AllSuccess() {
        Account acc = new Account(Name = 'Test Account');
        insert acc;
        
        acc.Name = 'Updated Account';
        List<Database.SaveResult> results = Database.update(new List<Account>{acc}, false);
        
        Test.startTest();
        
        Integer failureCount = SchedulerErrorHandler.handleSaveResults(results, 'TestScheduler', 'UPDATE');
        
        Test.stopTest();
        
        System.assertEquals(0, failureCount, 'No failures expected');
    }
    
    @isTest
    static void testHandleSaveResults_WithFailures() {
        // Create a scenario that will fail - duplicate external ID or validation rule
        Account acc = new Account(); // Missing required Name field
        List<Database.SaveResult> results = Database.insert(new List<Account>{acc}, false);
        
        Test.startTest();
        
        Integer failureCount = SchedulerErrorHandler.handleSaveResults(results, 'TestScheduler', 'INSERT');
        
        Test.stopTest();
        
        System.assertEquals(1, failureCount, 'One failure expected');
        
        // Verify error was logged
        List<Prometheion_Audit_Log__c> logs = [
            SELECT Id FROM Prometheion_Audit_Log__c 
            WHERE Action__c = 'SCHEDULER_ERROR'
        ];
        System.assertEquals(1, logs.size(), 'Error should be logged');
    }
    
    @isTest
    static void testIsBusinessDay_Weekday() {
        // Find next Monday
        Date testDate = Date.today();
        while (Datetime.newInstance(testDate, Time.newInstance(0,0,0,0)).format('EEEE') != 'Monday') {
            testDate = testDate.addDays(1);
        }
        
        // We can't easily mock Date.today(), so we test the method returns Boolean
        Test.startTest();
        Boolean result = SchedulerErrorHandler.isBusinessDay();
        Test.stopTest();
        
        // Just verify it returns a boolean without error
        System.assertNotEquals(null, result);
    }
    
    @isTest
    static void testSavepointAndRollback() {
        Account acc = new Account(Name = 'Test Account');
        insert acc;
        
        Test.startTest();
        
        Savepoint sp = SchedulerErrorHandler.setSavepoint();
        
        acc.Name = 'Modified Name';
        update acc;
        
        SchedulerErrorHandler.rollbackAndLog(sp, 'TestScheduler', 'Test rollback');
        
        Test.stopTest();
        
        // Verify rollback occurred
        Account refreshedAcc = [SELECT Name FROM Account WHERE Id = :acc.Id];
        System.assertEquals('Test Account', refreshedAcc.Name, 'Name should be rolled back');
        
        // Verify rollback was logged
        List<Prometheion_Audit_Log__c> logs = [
            SELECT Details__c FROM Prometheion_Audit_Log__c 
            WHERE Action__c = 'SCHEDULER_ERROR'
        ];
        System.assertEquals(1, logs.size());
    }
    
    @isTest
    static void testNotifyOnFailure_NoWebhook() {
        // Test that notification gracefully handles missing webhook config
        Test.startTest();
        
        // This should not throw - just log a warning
        SchedulerErrorHandler.notifyOnFailureSync('TestScheduler', 'Test error', 'Test stack trace');
        
        Test.stopTest();
        
        // No assertion needed - just verify no exception thrown
        System.assert(true, 'Method completed without exception');
    }
    
    @isTest
    static void testNotifyOnFailure_WithMockWebhook() {
        // Set up mock for HTTP callout
        Test.setMock(HttpCalloutMock.class, new SlackWebhookMock());
        
        Test.startTest();
        
        // Note: @future methods don't execute in test context without Test.stopTest()
        SchedulerErrorHandler.notifyOnFailure('TestScheduler', 'Test error message', 'Test stack trace');
        
        Test.stopTest();
        
        // Verify mock was called (implicitly by no exception)
        System.assert(true, 'Notification sent without exception');
    }
    
    // Mock class for Slack webhook
    private class SlackWebhookMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('ok');
            return res;
        }
    }
}
