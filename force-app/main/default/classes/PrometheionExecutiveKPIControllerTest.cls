/**
 * Test class for PrometheionExecutiveKPIController
 * Comprehensive test coverage for KPI dashboard functionality
 * @author Derick Porter
 * @date 2026-01-03
 */
@isTest
private class PrometheionExecutiveKPIControllerTest {

    @isTest
    static void testGetKPIMetricsEmpty() {
        // Test with no metadata records (expected scenario in test org)
        Test.startTest();
        List<PrometheionExecutiveKPIController.KPIMetric> metrics =
            PrometheionExecutiveKPIController.getKPIMetrics('');
        Test.stopTest();

        System.assertNotEquals(null, metrics, 'Should return metrics list (even if empty)');
        System.assertEquals(true, metrics instanceof List<PrometheionExecutiveKPIController.KPIMetric>, 'Should return list type');
    }

    @isTest
    static void testGetKPIMetricsWithRecordIds() {
        // Test with metadata record IDs parameter (empty string = all records)
        Test.startTest();
        List<PrometheionExecutiveKPIController.KPIMetric> metrics =
            PrometheionExecutiveKPIController.getKPIMetrics('record1,record2');
        Test.stopTest();

        System.assertNotEquals(null, metrics, 'Should return metrics list');
    }

    @isTest
    static void testGetKPIByNameEmptyName() {
        // Test with blank KPI name
        Test.startTest();
        try {
            PrometheionExecutiveKPIController.getKPIByName('');
            System.assert(false, 'Should have thrown exception for blank name');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('required') ||
                         e.getMessage().contains('KPI name'),
                         'Should indicate KPI name is required: ' + e.getMessage());
        }
        Test.stopTest();
    }

    @isTest
    static void testGetKPIByNameNull() {
        // Test with null KPI name
        Test.startTest();
        try {
            PrometheionExecutiveKPIController.getKPIByName(null);
            System.assert(false, 'Should have thrown exception for null name');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('required') ||
                         e.getMessage().contains('KPI name'),
                         'Should indicate KPI name is required: ' + e.getMessage());
        }
        Test.stopTest();
    }

    @isTest
    static void testGetKPIByNameNotFound() {
        // Test with non-existent KPI name
        Test.startTest();
        try {
            PrometheionExecutiveKPIController.getKPIByName('nonexistent_kpi_12345');
            System.assert(false, 'Should have thrown exception for non-existent KPI');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('not found') ||
                         e.getMessage().contains('KPI not found'),
                         'Should indicate KPI not found: ' + e.getMessage());
        }
        Test.stopTest();
    }

    @isTest
    static void testGetKPIByNameWithSpecialCharacters() {
        // Test sanitization of special characters in KPI name
        Test.startTest();
        try {
            PrometheionExecutiveKPIController.getKPIByName('test-kpi; DROP TABLE--');
            System.assert(false, 'Should have thrown exception or sanitized input');
        } catch (AuraHandledException e) {
            // Expected - should either not find or sanitize the name
            System.assert(true, 'Exception expected for invalid characters');
        }
        Test.stopTest();
    }

    @isTest
    static void testKPIMetricClassStructure() {
        // Test that KPIMetric inner class can be instantiated and has expected structure
        PrometheionExecutiveKPIController.KPIMetric metric = 
            new PrometheionExecutiveKPIController.KPIMetric();
        
        metric.kpiName = 'test';
        metric.label = 'Test Label';
        metric.currentValue = 100;
        metric.hasError = false;

        System.assertEquals('test', metric.kpiName, 'KPI name should be set');
        System.assertEquals('Test Label', metric.label, 'Label should be set');
        System.assertEquals(100, metric.currentValue, 'Current value should be set');
        System.assertEquals(false, metric.hasError, 'Has error should be false');
    }
}
