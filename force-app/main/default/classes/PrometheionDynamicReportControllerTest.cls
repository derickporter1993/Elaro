/**
 * Test class for PrometheionDynamicReportController
 * @author Derick Porter
 * @date 2026-01-03
 */
@isTest
private class PrometheionDynamicReportControllerTest {

    @testSetup
    static void setupTestData() {
        // Create test accounts
        List<Account> accounts = new List<Account>();
        for (Integer i = 0; i < 10; i++) {
            accounts.add(new Account(Name = 'Test Account ' + i));
        }
        insert accounts;
    }

    @isTest
    static void testGetAvailableObjects() {
        Test.startTest();
        List<PrometheionDynamicReportController.ObjectOption> objects =
            PrometheionDynamicReportController.getAvailableObjects();
        Test.stopTest();

        System.assertNotEquals(0, objects.size(), 'Should return available objects');
    }

    @isTest
    static void testGetFieldMetadata() {
        Test.startTest();
        List<PrometheionDynamicReportController.FieldMetadata> fields =
            PrometheionDynamicReportController.getFieldMetadata('Account');
        Test.stopTest();

        System.assertNotEquals(0, fields.size(), 'Should return field metadata');
    }

    @isTest
    static void testGetFieldMetadataInvalidObject() {
        Test.startTest();
        try {
            PrometheionDynamicReportController.getFieldMetadata('Invalid__c');
            System.assert(false, 'Should have thrown exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('not authorized'),
                'Should throw authorization error');
        }
        Test.stopTest();
    }

    @isTest
    static void testExecuteReport() {
        String configJson = JSON.serialize(new Map<String, Object>{
            'objectApiName' => 'Account',
            'fields' => new List<String>{'Name', 'CreatedDate'},
            'filters' => new List<Object>(),
            'maxRows' => 10,
            'orderBy' => 'Name',
            'orderDirection' => 'ASC'
        });

        Test.startTest();
        PrometheionDynamicReportController.ReportResult result =
            PrometheionDynamicReportController.executeReport(configJson);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertNotEquals(0, result.recordCount, 'Should return records');
    }

    @isTest
    static void testExecuteReportWithFilters() {
        String configJson = JSON.serialize(new Map<String, Object>{
            'objectApiName' => 'Account',
            'fields' => new List<String>{'Name'},
            'filters' => new List<Object>{
                new Map<String, Object>{
                    'field' => 'Name',
                    'operator' => 'LIKE',
                    'value' => 'Test'
                }
            },
            'maxRows' => 10
        });

        Test.startTest();
        PrometheionDynamicReportController.ReportResult result =
            PrometheionDynamicReportController.executeReport(configJson);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
    }

    @isTest
    static void testExecuteReportInvalidObject() {
        String configJson = JSON.serialize(new Map<String, Object>{
            'objectApiName' => 'Invalid__c',
            'fields' => new List<String>{'Name'},
            'filters' => new List<Object>(),
            'maxRows' => 10
        });

        Test.startTest();
        try {
            PrometheionDynamicReportController.executeReport(configJson);
            System.assert(false, 'Should have thrown exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('not authorized'),
                'Should throw authorization error');
        }
        Test.stopTest();
    }
}
