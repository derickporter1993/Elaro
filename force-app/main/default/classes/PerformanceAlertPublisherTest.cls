/**
 * Test class for PerformanceAlertPublisher
 */
@isTest
private class PerformanceAlertPublisherTest {
    
    @isTest
    static void testPublishSuccess() {
        Test.startTest();
        PerformanceAlertPublisher.publish('CPU', 8500, 10000, null, 'Test stack trace');
        Test.stopTest();
        
        // Verify alert was saved to history
        List<Performance_Alert_History__c> alerts = [
            SELECT Metric__c, Value__c, Threshold__c, Stack__c
            FROM Performance_Alert_History__c
            WHERE Metric__c = 'CPU'
        ];
        System.assertEquals(1, alerts.size(), 'Expected one alert to be saved');
        System.assertEquals(8500, alerts[0].Value__c, 'Value should match');
        System.assertEquals(10000, alerts[0].Threshold__c, 'Threshold should match');
    }
    
    @isTest
    static void testPublishWithNullMetric() {
        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            PerformanceAlertPublisher.publish(null, 8500, 10000, null, null);
        } catch (AuraHandledException e) {
            exceptionThrown = true;
            System.assert(e.getMessage().contains('Metric cannot be blank'), 'Expected validation error');
        }
        Test.stopTest();
        System.assert(exceptionThrown, 'Expected AuraHandledException to be thrown');
    }
    
    @isTest
    static void testPublishWithNullValue() {
        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            PerformanceAlertPublisher.publish('CPU', null, 10000, null, null);
        } catch (AuraHandledException e) {
            exceptionThrown = true;
            System.assert(e.getMessage().contains('Value cannot be null'), 'Expected validation error');
        }
        Test.stopTest();
        System.assert(exceptionThrown, 'Expected AuraHandledException to be thrown');
    }
    
    @isTest
    static void testPublishWithLongStackTrace() {
        String longStack = '';
        for (Integer i = 0; i < 4000; i++) {
            longStack += 'x';
        }
        
        Test.startTest();
        PerformanceAlertPublisher.publish('HEAP', 5000, 6000, 'someRecordId', longStack);
        Test.stopTest();
        
        List<Performance_Alert_History__c> alerts = [
            SELECT Stack__c
            FROM Performance_Alert_History__c
            WHERE Metric__c = 'HEAP'
        ];
        System.assertEquals(1, alerts.size(), 'Expected one alert to be saved');
        System.assert(alerts[0].Stack__c.length() <= 32768, 'Stack should be truncated');
    }
    
    @isTest
    static void testPublishBulk_MultipleMetrics() {
        // Test publishing 200+ alerts to verify governor limit handling
        List<String> metrics = new List<String>{'CPU', 'HEAP', 'SOQL', 'DML'};
        
        Test.startTest();
        for (Integer i = 0; i < 200; i++) {
            String metric = metrics[Math.mod(i, metrics.size())] + '_BULK';
            PerformanceAlertPublisher.publish(
                metric, 
                Math.mod(i, 100) * 100, 
                10000, 
                null, 
                'Bulk test ' + i
            );
        }
        Test.stopTest();
        
        // Verify alerts were saved
        List<Performance_Alert_History__c> alerts = [
            SELECT Metric__c FROM Performance_Alert_History__c
            WHERE Metric__c LIKE '%_BULK'
        ];
        System.assertEquals(200, alerts.size(), 'Should save all 200 alerts');
    }
    
    @isTest
    static void testPublishWithXSSCharacters() {
        // Test XSS prevention in stack trace
        String xssStack = '<script>alert("xss")</script><img src=x onerror=alert(1)>';
        
        Test.startTest();
        PerformanceAlertPublisher.publish('XSS_TEST', 1000, 2000, null, xssStack);
        Test.stopTest();
        
        List<Performance_Alert_History__c> alerts = [
            SELECT Stack__c FROM Performance_Alert_History__c
            WHERE Metric__c = 'XSS_TEST'
        ];
        System.assertEquals(1, alerts.size(), 'Alert should be saved');
        System.assert(!alerts[0].Stack__c.contains('<script>'), 'XSS should be escaped');
        System.assert(alerts[0].Stack__c.contains('&lt;script&gt;'), 'HTML should be escaped');
    }
}
