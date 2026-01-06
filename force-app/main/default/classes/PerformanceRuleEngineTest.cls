@IsTest
private class PerformanceRuleEngineTest {
    @IsTest 
    static void testEvaluate_CriticalThresholds() {
        LimitMetrics.GovernorStats s = new LimitMetrics.GovernorStats();
        s.cpuMs = 9500; s.heapKb = 6000; s.soql = 100; s.dml = 155;
        Test.startTest();
        PerformanceRuleEngine.EvalResult r = PerformanceRuleEngine.evaluateAndPublish(s, null);
        Test.stopTest();
        System.assertEquals(true, r.critical, 'Should mark critical');
        System.assertNotEquals(null, r.message, 'Should have a message');
    }
    
    @IsTest
    static void testEvaluate_WarningThresholds() {
        LimitMetrics.GovernorStats s = new LimitMetrics.GovernorStats();
        s.cpuMs = 8500; s.heapKb = 4800; s.soql = 85; s.dml = 145;
        Test.startTest();
        PerformanceRuleEngine.EvalResult r = PerformanceRuleEngine.evaluateAndPublish(s, null);
        Test.stopTest();
        System.assertEquals(true, r.warning, 'Should mark warning');
        System.assertEquals(false, r.critical, 'Should not be critical');
    }
    
    @IsTest
    static void testEvaluate_NoAlerts() {
        LimitMetrics.GovernorStats s = new LimitMetrics.GovernorStats();
        s.cpuMs = 1000; s.heapKb = 2000; s.soql = 10; s.dml = 5;
        Test.startTest();
        PerformanceRuleEngine.EvalResult r = PerformanceRuleEngine.evaluateAndPublish(s, null);
        Test.stopTest();
        System.assertEquals(false, r.warning, 'Should not mark warning');
        System.assertEquals(false, r.critical, 'Should not mark critical');
        System.assert(r.message.contains('No alerts'), 'Message should indicate no alerts');
    }
    
    @IsTest
    static void testEvaluate_NullInput() {
        Test.startTest();
        try {
            PerformanceRuleEngine.EvalResult r = PerformanceRuleEngine.evaluateAndPublish(null, null);
            System.assert(false, 'Should have thrown exception');
        } catch (IllegalArgumentException e) {
            System.assert(e.getMessage().contains('GovernorStats cannot be null'), 'Error message should mention null');
        }
        Test.stopTest();
    }
    
    @IsTest
    static void testEvaluate_WithContextRecordId() {
        LimitMetrics.GovernorStats s = new LimitMetrics.GovernorStats();
        s.cpuMs = 9500; s.heapKb = 6000; s.soql = 100; s.dml = 155;
        String contextId = 'a000000000000001';
        
        Test.startTest();
        PerformanceRuleEngine.EvalResult r = PerformanceRuleEngine.evaluateAndPublish(s, contextId);
        Test.stopTest();
        
        System.assertEquals(true, r.critical, 'Should mark critical');
        System.assertNotEquals(null, r.eventsPublished, 'Should track events published');
    }
    
    @IsTest
    static void testEvaluate_PlatformEventPublishing() {
        LimitMetrics.GovernorStats s = new LimitMetrics.GovernorStats();
        s.cpuMs = 9500; s.heapKb = 6000; s.soql = 100; s.dml = 155;
        
        Test.startTest();
        PerformanceRuleEngine.EvalResult r = PerformanceRuleEngine.evaluateAndPublish(s, null);
        Test.stopTest();
        
        // Verify events were published (count should be > 0 for critical thresholds)
        System.assert(r.eventsPublished > 0, 'Should have published events');
        System.assertEquals(0, r.eventsFailed, 'Should not have failed events');
    }
}
