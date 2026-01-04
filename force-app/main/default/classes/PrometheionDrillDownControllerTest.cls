/**
 * Test class for PrometheionDrillDownController
 * @author Derick Porter
 * @date 2026-01-03
 */
@isTest
private class PrometheionDrillDownControllerTest {

    @testSetup
    static void setupTestData() {
        List<Account> accounts = new List<Account>();
        for (Integer i = 0; i < 20; i++) {
            accounts.add(new Account(Name = 'Test Account ' + i));
        }
        insert accounts;
    }

    @isTest
    static void testGetRecords() {
        String contextJson = JSON.serialize(new Map<String, Object>{
            'objectApiName' => 'Account',
            'displayFields' => new List<String>{'Name', 'CreatedDate'},
            'filters' => new List<Object>(),
            'pageSize' => 10,
            'offset' => 0
        });

        Test.startTest();
        PrometheionDrillDownController.DrillDownResult result =
            PrometheionDrillDownController.getRecords(contextJson);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertNotEquals(0, result.totalCount, 'Should return records');
    }

    @isTest
    static void testGetRecordsWithFilters() {
        String contextJson = JSON.serialize(new Map<String, Object>{
            'objectApiName' => 'Account',
            'displayFields' => new List<String>{'Name'},
            'filters' => new List<Object>{
                new Map<String, Object>{
                    'field' => 'Name',
                    'operator' => 'LIKE',
                    'value' => 'Test'
                }
            },
            'pageSize' => 10,
            'offset' => 0
        });

        Test.startTest();
        PrometheionDrillDownController.DrillDownResult result =
            PrometheionDrillDownController.getRecords(contextJson);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
    }

    @isTest
    static void testExportToCSV() {
        String contextJson = JSON.serialize(new Map<String, Object>{
            'objectApiName' => 'Account',
            'displayFields' => new List<String>{'Name'},
            'filters' => new List<Object>(),
            'pageSize' => 10,
            'offset' => 0
        });

        Test.startTest();
        String csv = PrometheionDrillDownController.exportToCSV(contextJson);
        Test.stopTest();

        System.assertNotEquals(null, csv, 'CSV should not be null');
        System.assert(csv.contains('Name'), 'CSV should contain headers');
    }

    @isTest
    static void testGetRecordsInvalidObject() {
        String contextJson = JSON.serialize(new Map<String, Object>{
            'objectApiName' => 'Invalid__c',
            'displayFields' => new List<String>{'Name'},
            'filters' => new List<Object>(),
            'pageSize' => 10,
            'offset' => 0
        });

        Test.startTest();
        try {
            PrometheionDrillDownController.getRecords(contextJson);
            System.assert(false, 'Should have thrown exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('not authorized'),
                'Should throw authorization error');
        }
        Test.stopTest();
    }
}
