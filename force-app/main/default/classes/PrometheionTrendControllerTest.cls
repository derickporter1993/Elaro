/**
 * Test class for PrometheionTrendController
 * @author Derick Porter
 * @date 2026-01-03
 */
@isTest
private class PrometheionTrendControllerTest {

    @testSetup
    static void setupTestData() {
        List<Account> accounts = new List<Account>();
        for (Integer i = 0; i < 10; i++) {
            accounts.add(new Account(Name = 'Test Account ' + i));
        }
        insert accounts;
    }

    @isTest
    static void testGetDateFields() {
        Test.startTest();
        List<PrometheionTrendController.DateFieldOption> fields =
            PrometheionTrendController.getDateFields('Account');
        Test.stopTest();

        System.assertNotEquals(null, fields, 'Should return date fields');
    }

    @isTest
    static void testGetMetricFields() {
        Test.startTest();
        List<PrometheionTrendController.MetricFieldOption> fields =
            PrometheionTrendController.getMetricFields('Account');
        Test.stopTest();

        System.assertNotEquals(null, fields, 'Should return metric fields');
    }

    @isTest
    static void testGetTimeSeries() {
        Test.startTest();
        PrometheionTrendController.TrendResult result =
            PrometheionTrendController.getTimeSeries(
                'Account',
                'CreatedDate',
                'Id',
                'month',
                12,
                ''
            );
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
    }

    @isTest
    static void testGetTimeSeriesInvalidObject() {
        Test.startTest();
        try {
            PrometheionTrendController.getTimeSeries(
                'Invalid__c',
                'CreatedDate',
                'Id',
                'month',
                12,
                ''
            );
            System.assert(false, 'Should have thrown exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('not authorized'),
                'Should throw authorization error');
        }
        Test.stopTest();
    }
}
