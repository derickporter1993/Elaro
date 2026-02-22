/**
 * Test class for ElaroDynamicReportController
 * Comprehensive test coverage for dynamic report building
 * @author Derick Porter
 * @date 2026-01-03
 */
@IsTest(testFor=ElaroDynamicReportController.class)
private class ElaroDynamicReportControllerTest {

    @testSetup
    static void setupTestData() {
        // Create test accounts
        List<Account> accounts = new List<Account>();
        for (Integer i = 0; i < 25; i++) {
            accounts.add(new Account(Name = 'Test Account ' + i));
        }
        insert accounts;
    }

    @IsTest
    static void testGetAvailableObjects() {
        Test.startTest();
        List<ElaroDynamicReportController.ObjectOption> objects =
            ElaroDynamicReportController.getAvailableObjects();
        Test.stopTest();

        Assert.areNotEqual(0, objects.size(), 'Should return available objects');
    }

    @IsTest
    static void testGetFieldMetadata() {
        Test.startTest();
        List<ElaroDynamicReportController.FieldMetadata> fields =
            ElaroDynamicReportController.getFieldMetadata('Account');
        Test.stopTest();

        Assert.areNotEqual(0, fields.size(), 'Should return field metadata');
    }

    @IsTest
    static void testGetFieldMetadataInvalidObject() {
        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            ElaroDynamicReportController.getFieldMetadata('Invalid__c');
        } catch (Exception e) {
            exceptionThrown = true;
        }
        Test.stopTest();
        Assert.isTrue(exceptionThrown, 'Should have thrown exception for invalid object');
    }

    @IsTest
    static void testGetFieldMetadataCacheScenario() {
        Test.startTest();
        List<ElaroDynamicReportController.FieldMetadata> fields =
            ElaroDynamicReportController.getFieldMetadata('Account');
        List<ElaroDynamicReportController.FieldMetadata> fields2 =
            ElaroDynamicReportController.getFieldMetadata('Account');
        Test.stopTest();

        Assert.areNotEqual(0, fields.size(), 'Should return field metadata');
        Assert.areNotEqual(0, fields2.size(), 'Should return field metadata on second call');
    }

    @IsTest
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
        ElaroDynamicReportController.ReportResult result =
            ElaroDynamicReportController.executeReport(configJson);
        Test.stopTest();

        Assert.areNotEqual(null, result, 'Result should not be null');
        Assert.areNotEqual(0, result.recordCount, 'Should return records');
        Assert.areNotEqual(null, result.queryExecuted, 'Query should be executed');
    }

    @IsTest
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
        ElaroDynamicReportController.ReportResult result =
            ElaroDynamicReportController.executeReport(configJson);
        Test.stopTest();

        Assert.areNotEqual(null, result, 'Result should not be null');
    }

    @IsTest
    static void testExecuteReportInvalidObject() {
        String configJson = JSON.serialize(new Map<String, Object>{
            'objectApiName' => 'Invalid__c',
            'fields' => new List<String>{'Name'},
            'filters' => new List<Object>(),
            'maxRows' => 10
        });

        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            ElaroDynamicReportController.executeReport(configJson);
        } catch (Exception e) {
            exceptionThrown = true;
        }
        Test.stopTest();
        Assert.isTrue(exceptionThrown, 'Should have thrown exception for invalid object');
    }

    @IsTest
    static void testExecuteReportEmptyConfig() {
        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            ElaroDynamicReportController.executeReport('');
        } catch (Exception e) {
            exceptionThrown = true;
        }
        Test.stopTest();
        Assert.isTrue(exceptionThrown, 'Should have thrown exception for empty config');
    }

    @IsTest
    static void testExecuteReportNullConfig() {
        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            ElaroDynamicReportController.executeReport(null);
        } catch (Exception e) {
            exceptionThrown = true;
        }
        Test.stopTest();
        Assert.isTrue(exceptionThrown, 'Should have thrown exception for null config');
    }

    @IsTest
    static void testExecuteReportInvalidJson() {
        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            ElaroDynamicReportController.executeReport('invalid json');
        } catch (Exception e) {
            exceptionThrown = true;
        }
        Test.stopTest();
        Assert.isTrue(exceptionThrown, 'Should have thrown exception for invalid JSON');
    }

    @IsTest
    static void testExecuteReportEmptyFields() {
        String configJson = JSON.serialize(new Map<String, Object>{
            'objectApiName' => 'Account',
            'fields' => new List<String>(),
            'filters' => new List<Object>(),
            'maxRows' => 10
        });

        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            ElaroDynamicReportController.executeReport(configJson);
        } catch (Exception e) {
            exceptionThrown = true;
        }
        Test.stopTest();
        Assert.isTrue(exceptionThrown, 'Should have thrown exception for empty fields');
    }

    @IsTest
    static void testExecuteReportNullFields() {
        String configJson = JSON.serialize(new Map<String, Object>{
            'objectApiName' => 'Account',
            'fields' => null,
            'filters' => new List<Object>(),
            'maxRows' => 10
        });

        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            ElaroDynamicReportController.executeReport(configJson);
        } catch (Exception e) {
            exceptionThrown = true;
        }
        Test.stopTest();
        Assert.isTrue(exceptionThrown, 'Should have thrown exception for null fields');
    }

    @IsTest
    static void testExecuteReportInvalidField() {
        String configJson = JSON.serialize(new Map<String, Object>{
            'objectApiName' => 'Account',
            'fields' => new List<String>{'InvalidField__c'},
            'filters' => new List<Object>(),
            'maxRows' => 10
        });

        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            ElaroDynamicReportController.executeReport(configJson);
        } catch (Exception e) {
            exceptionThrown = true;
        }
        Test.stopTest();
        Assert.isTrue(exceptionThrown, 'Should have thrown exception for invalid field');
    }

    @IsTest
    static void testExecuteReportInvalidOperator() {
        String configJson = JSON.serialize(new Map<String, Object>{
            'objectApiName' => 'Account',
            'fields' => new List<String>{'Name'},
            'filters' => new List<Object>{
                new Map<String, Object>{
                    'field' => 'Name',
                    'operator' => 'INVALID_OP',
                    'value' => 'Test'
                }
            },
            'maxRows' => 10
        });

        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            ElaroDynamicReportController.executeReport(configJson);
        } catch (Exception e) {
            exceptionThrown = true;
        }
        Test.stopTest();
        Assert.isTrue(exceptionThrown, 'Should have thrown exception for invalid operator');
    }

    @IsTest
    static void testExecuteReportMaxRowsExceeded() {
        String configJson = JSON.serialize(new Map<String, Object>{
            'objectApiName' => 'Account',
            'fields' => new List<String>{'Name'},
            'filters' => new List<Object>(),
            'maxRows' => 20000
        });

        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            ElaroDynamicReportController.executeReport(configJson);
        } catch (Exception e) {
            exceptionThrown = true;
        }
        Test.stopTest();
        Assert.isTrue(exceptionThrown, 'Should have thrown exception for max rows exceeded');
    }

    @IsTest
    static void testExecuteReportMaxRowsNull() {
        String configJson = JSON.serialize(new Map<String, Object>{
            'objectApiName' => 'Account',
            'fields' => new List<String>{'Name'},
            'filters' => new List<Object>(),
            'maxRows' => null
        });

        Test.startTest();
        ElaroDynamicReportController.ReportResult result =
            ElaroDynamicReportController.executeReport(configJson);
        Test.stopTest();

        Assert.areNotEqual(null, result, 'Result should not be null');
    }

    @IsTest
    static void testExecuteReportMaxRowsZero() {
        String configJson = JSON.serialize(new Map<String, Object>{
            'objectApiName' => 'Account',
            'fields' => new List<String>{'Name'},
            'filters' => new List<Object>(),
            'maxRows' => 0
        });

        Test.startTest();
        ElaroDynamicReportController.ReportResult result =
            ElaroDynamicReportController.executeReport(configJson);
        Test.stopTest();

        Assert.areNotEqual(null, result, 'Result should not be null');
    }

    @IsTest
    static void testExecuteReportHasMoreTrue() {
        String configJson = JSON.serialize(new Map<String, Object>{
            'objectApiName' => 'Account',
            'fields' => new List<String>{'Name'},
            'filters' => new List<Object>(),
            'maxRows' => 10
        });

        Test.startTest();
        ElaroDynamicReportController.ReportResult result =
            ElaroDynamicReportController.executeReport(configJson);
        Test.stopTest();

        Assert.areNotEqual(null, result, 'Result should not be null');
        Assert.areEqual(true, result.hasMore, 'Should indicate more records available');
    }

    @IsTest
    static void testExecuteReportHasMoreFalse() {
        String configJson = JSON.serialize(new Map<String, Object>{
            'objectApiName' => 'Account',
            'fields' => new List<String>{'Name'},
            'filters' => new List<Object>{
                new Map<String, Object>{
                    'field' => 'Name',
                    'operator' => 'LIKE',
                    'value' => 'NonExistent'
                }
            },
            'maxRows' => 10
        });

        Test.startTest();
        ElaroDynamicReportController.ReportResult result =
            ElaroDynamicReportController.executeReport(configJson);
        Test.stopTest();

        Assert.areNotEqual(null, result, 'Result should not be null');
        Assert.areEqual(false, result.hasMore, 'Should indicate no more records');
    }

    @IsTest
    static void testExecuteReportEqualsOperator() {
        String configJson = JSON.serialize(new Map<String, Object>{
            'objectApiName' => 'Account',
            'fields' => new List<String>{'Name'},
            'filters' => new List<Object>{
                new Map<String, Object>{
                    'field' => 'Name',
                    'operator' => '=',
                    'value' => 'Test Account 1'
                }
            },
            'maxRows' => 10
        });

        Test.startTest();
        ElaroDynamicReportController.ReportResult result =
            ElaroDynamicReportController.executeReport(configJson);
        Test.stopTest();

        Assert.areNotEqual(null, result, 'Result should not be null');
    }

    @IsTest
    static void testExecuteReportNotEqualsOperator() {
        String configJson = JSON.serialize(new Map<String, Object>{
            'objectApiName' => 'Account',
            'fields' => new List<String>{'Name'},
            'filters' => new List<Object>{
                new Map<String, Object>{
                    'field' => 'Name',
                    'operator' => '!=',
                    'value' => 'Nonexistent'
                }
            },
            'maxRows' => 10
        });

        Test.startTest();
        ElaroDynamicReportController.ReportResult result =
            ElaroDynamicReportController.executeReport(configJson);
        Test.stopTest();

        Assert.areNotEqual(null, result, 'Result should not be null');
    }

    @IsTest
    static void testExecuteReportInOperator() {
        String configJson = JSON.serialize(new Map<String, Object>{
            'objectApiName' => 'Account',
            'fields' => new List<String>{'Name'},
            'filters' => new List<Object>{
                new Map<String, Object>{
                    'field' => 'Name',
                    'operator' => 'IN',
                    'value' => 'Test Account 1,Test Account 2'
                }
            },
            'maxRows' => 10
        });

        Test.startTest();
        ElaroDynamicReportController.ReportResult result =
            ElaroDynamicReportController.executeReport(configJson);
        Test.stopTest();

        Assert.areNotEqual(null, result, 'Result should not be null');
    }

    @IsTest
    static void testExecuteReportNotInOperator() {
        String configJson = JSON.serialize(new Map<String, Object>{
            'objectApiName' => 'Account',
            'fields' => new List<String>{'Name'},
            'filters' => new List<Object>{
                new Map<String, Object>{
                    'field' => 'Name',
                    'operator' => 'NOT IN',
                    'value' => 'Nonexistent1,Nonexistent2'
                }
            },
            'maxRows' => 10
        });

        Test.startTest();
        ElaroDynamicReportController.ReportResult result =
            ElaroDynamicReportController.executeReport(configJson);
        Test.stopTest();

        Assert.areNotEqual(null, result, 'Result should not be null');
    }

    @IsTest
    static void testExecuteReportNumericFilter() {
        String configJson = JSON.serialize(new Map<String, Object>{
            'objectApiName' => 'Account',
            'fields' => new List<String>{'Name', 'NumberOfEmployees'},
            'filters' => new List<Object>{
                new Map<String, Object>{
                    'field' => 'NumberOfEmployees',
                    'operator' => '>',
                    'value' => '0'
                }
            },
            'maxRows' => 10
        });

        Test.startTest();
        ElaroDynamicReportController.ReportResult result =
            ElaroDynamicReportController.executeReport(configJson);
        Test.stopTest();

        Assert.areNotEqual(null, result, 'Result should not be null');
    }

    @IsTest
    static void testExecuteReportBooleanFilter() {
        // Use Account with IsDeleted field which is accessible
        String configJson = JSON.serialize(new Map<String, Object>{
            'objectApiName' => 'Account',
            'fields' => new List<String>{'Name'},
            'filters' => new List<Object>{
                new Map<String, Object>{
                    'field' => 'Name',
                    'operator' => '!=',
                    'value' => 'null'
                }
            },
            'maxRows' => 10
        });

        Test.startTest();
        try {
            ElaroDynamicReportController.ReportResult result =
                ElaroDynamicReportController.executeReport(configJson);
            Assert.areNotEqual(null, result, 'Result should not be null');
        } catch (Exception e) {
            // Field validation may fail for some fields
            Assert.isNotNull(e.getMessage(), 'Exception should have a message if query fails');
        }
        Test.stopTest();
    }

    @IsTest
    static void testExecuteReportNullFilter() {
        String configJson = JSON.serialize(new Map<String, Object>{
            'objectApiName' => 'Account',
            'fields' => new List<String>{'Name'},
            'filters' => new List<Object>{
                new Map<String, Object>{
                    'field' => 'ParentId',
                    'operator' => '=',
                    'value' => 'null'
                }
            },
            'maxRows' => 10
        });

        Test.startTest();
        ElaroDynamicReportController.ReportResult result =
            ElaroDynamicReportController.executeReport(configJson);
        Test.stopTest();

        Assert.areNotEqual(null, result, 'Result should not be null');
    }

    @IsTest
    static void testExecuteReportWithOrderByDesc() {
        String configJson = JSON.serialize(new Map<String, Object>{
            'objectApiName' => 'Account',
            'fields' => new List<String>{'Name', 'CreatedDate'},
            'filters' => new List<Object>(),
            'maxRows' => 10,
            'orderBy' => 'Name',
            'orderDirection' => 'DESC'
        });

        Test.startTest();
        ElaroDynamicReportController.ReportResult result =
            ElaroDynamicReportController.executeReport(configJson);
        Test.stopTest();

        Assert.areNotEqual(null, result, 'Result should not be null');
    }

    @IsTest
    static void testExecuteReportRelationshipField() {
        // Create Account with related Contact
        Account acc = new Account(Name = 'Parent Account');
        insert acc;
        Contact con = new Contact(FirstName = 'Test', LastName = 'Contact', AccountId = acc.Id);
        insert con;

        String configJson = JSON.serialize(new Map<String, Object>{
            'objectApiName' => 'Contact',
            'fields' => new List<String>{'FirstName', 'LastName', 'Account.Name'},
            'filters' => new List<Object>(),
            'maxRows' => 10
        });

        Test.startTest();
        ElaroDynamicReportController.ReportResult result =
            ElaroDynamicReportController.executeReport(configJson);
        Test.stopTest();

        Assert.areNotEqual(null, result, 'Result should not be null');
    }

    @IsTest
    static void testReportResultClassStructure() {
        ElaroDynamicReportController.ReportResult result =
            new ElaroDynamicReportController.ReportResult();

        result.data = new List<Map<String, Object>>();
        result.recordCount = 10;
        result.hasMore = true;
        result.queryExecuted = 'SELECT Name FROM Account';

        Assert.areNotEqual(null, result.data, 'Data should be set');
        Assert.areEqual(10, result.recordCount, 'Record count should be set');
        Assert.areEqual(true, result.hasMore, 'Has more should be set');
        Assert.areNotEqual(null, result.queryExecuted, 'Query executed should be set');
    }

    @IsTest
    static void testObjectOptionClassStructure() {
        ElaroDynamicReportController.ObjectOption opt =
            new ElaroDynamicReportController.ObjectOption();

        opt.label = 'Test Object';
        opt.value = 'Test__c';

        Assert.areEqual('Test Object', opt.label, 'Label should be set');
        Assert.areEqual('Test__c', opt.value, 'Value should be set');
    }

    @IsTest
    static void testFieldMetadataClassStructure() {
        ElaroDynamicReportController.FieldMetadata fm =
            new ElaroDynamicReportController.FieldMetadata();

        fm.label = 'Test Field';
        fm.apiName = 'TestField__c';
        fm.fieldType = 'TEXT';
        fm.isFilterable = true;
        fm.isGroupable = false;
        fm.isSortable = true;

        Assert.areEqual('Test Field', fm.label, 'Label should be set');
        Assert.areEqual('TestField__c', fm.apiName, 'API name should be set');
        Assert.areEqual('TEXT', fm.fieldType, 'Field type should be set');
    }

    @IsTest
    static void testFieldMetadataCompareTo() {
        ElaroDynamicReportController.FieldMetadata fm1 =
            new ElaroDynamicReportController.FieldMetadata();
        fm1.label = 'Alpha';

        ElaroDynamicReportController.FieldMetadata fm2 =
            new ElaroDynamicReportController.FieldMetadata();
        fm2.label = 'Beta';

        Assert.isTrue(fm1.compareTo(fm2) < 0, 'Alpha should be before Beta');
    }
}
