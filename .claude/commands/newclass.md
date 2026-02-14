# Create New Apex Class

Generate a new Apex class following Elaro coding standards (CLAUDE.md) and AppExchange security requirements.

## Usage

When creating a new Apex class, gather these details:

1. **Class Name** - PascalCase (e.g., MyFeatureService, MyFeatureController)
2. **Purpose** - Brief description of functionality
3. **Type** - Choose one:
   - Controller (LWC backend logic) — `with sharing`
   - Service (Business logic layer) — `inherited sharing`
   - Utility (Helper/common functions) — `inherited sharing`
   - Batch (Async batch processing) — `inherited sharing`
   - Scheduler (Scheduled jobs) — `inherited sharing`
   - Trigger Handler (Trigger logic) — `inherited sharing`
   - Test (Test class) — `@IsTest private class`

## Template Structure

Every new Apex class should include:

### 1. ApexDoc Header (NOT JSDoc — no @description tag)
```apex
/**
 * Handles business logic for [feature description].
 *
 * @author Elaro Team
 * @since v3.1.0 (Spring '26)
 * @group [Feature Group]
 * @see [RelatedClass]
 */
```

### 2. Class Declaration with Sharing
```apex
// Controllers — enforces sharing
public with sharing class MyController { }

// Services, utilities, handlers — inherits caller context
public inherited sharing class MyService { }

// System operations ONLY — MUST document why
/**
 * SECURITY: without sharing required because [specific justification].
 */
public without sharing class MyEventPublisher { }
```

### 3. SOQL — ALWAYS WITH USER_MODE
```apex
/**
 * Retrieves records with CRUD/FLS enforcement.
 *
 * @param recordIds List of record IDs to query
 * @return List of matching records
 * @throws AuraHandledException if query fails or user lacks permission
 */
public static List<MyObject__c> getRecords(List<Id> recordIds) {
    return [
        SELECT Id, Name, Status__c
        FROM MyObject__c
        WHERE Id IN :recordIds
        WITH USER_MODE
    ];
}
```

### 4. DML — ALWAYS 'as user'
```apex
public static void processData(List<MyObject__c> records) {
    try {
        // Business logic here
        update as user records;
    } catch (Exception e) {
        ElaroLogger.error('MyService.processData', e.getMessage(), e.getStackTraceString());
        throw new AuraHandledException('Unable to process records. Please verify permissions and try again.');
    }
}
```

### 5. ApexDoc for Public Methods
```apex
/**
 * Executes the compliance scan for the given framework.
 *
 * @param frameworkName The compliance framework identifier
 * @return ScanResult containing findings and score
 * @throws AuraHandledException if scan fails or user lacks permission
 * @example
 * ScanResult result = MyService.runScan('HIPAA');
 */
```

## File Locations

Place the new class in:
```
force-app/main/default/classes/MyClass.cls
force-app/main/default/classes/MyClass.cls-meta.xml
```

Health Check components go in `force-app-healthcheck/main/default/classes/`.

## Metadata File — API v66.0
```xml
<?xml version="1.0" encoding="UTF-8"?>
<ApexClass xmlns="http://soap.sforce.com/2006/04/metadata">
    <apiVersion>66.0</apiVersion>
    <status>Active</status>
</ApexClass>
```

## Required Test Class

For every new class, create a test class:
```
force-app/main/default/classes/MyClassTest.cls
```

Test class requirements:
- 85%+ coverage (75% absolute minimum)
- Test positive scenarios
- Test negative scenarios (exceptions)
- Test bulk operations (200+ records)
- Test security violations (without user permissions)
- Use `Test.startTest()`/`Test.stopTest()` for async
- Use `System.runAs()` for permission tests
- Use `Assert` class (NEVER `System.assertEquals`)

## Example Test Structure
```apex
@IsTest(testFor=MyClass.class)
private class MyClassTest {

    @TestSetup
    static void makeData() {
        // Create test data using ComplianceTestDataFactory
    }

    @IsTest
    static void shouldProcessRecordsSuccessfully() {
        Test.startTest();
        // Test normal operation
        Test.stopTest();

        Assert.isNotNull(result, 'Result should not be null');
        Assert.areEqual(expected, actual, 'Should match expected value');
    }

    @IsTest
    static void shouldThrowWhenUserLacksPermission() {
        User testUser = ElaroTestUserFactory.createMinimalAccessUser();
        System.runAs(testUser) {
            Test.startTest();
            try {
                MyClass.myMethod();
                Assert.fail('Expected AuraHandledException');
            } catch (AuraHandledException e) {
                Assert.isTrue(e.getMessage().contains('permission'),
                    'Error should mention permissions');
            }
            Test.stopTest();
        }
    }

    @IsTest
    static void shouldHandleBulkOperation() {
        List<MyObject__c> records = new List<MyObject__c>();
        for (Integer i = 0; i < 200; i++) {
            records.add(new MyObject__c(Name = 'Test ' + i));
        }
        insert as user records;

        Test.startTest();
        MyClass.processBulk(records);
        Test.stopTest();

        Assert.areEqual(200, [SELECT COUNT() FROM MyObject__c WITH USER_MODE],
            'All 200 records should be processed');
    }
}
```

## Common Patterns

### LWC Controller Pattern
```apex
public with sharing class MyComponentController {

    @AuraEnabled(cacheable=true)
    public static List<MyObject__c> getRecords() {
        try {
            return [SELECT Id, Name FROM MyObject__c WITH USER_MODE LIMIT 50];
        } catch (Exception e) {
            ElaroLogger.error('MyComponentController.getRecords', e.getMessage(), e.getStackTraceString());
            throw new AuraHandledException('Unable to load records. Please verify permissions.');
        }
    }

    @AuraEnabled
    public static void updateRecord(Id recordId, String newValue) {
        try {
            MyObject__c record = [SELECT Id FROM MyObject__c WHERE Id = :recordId WITH USER_MODE];
            record.Name = newValue;
            update as user record;
        } catch (Exception e) {
            ElaroLogger.error('MyComponentController.updateRecord', e.getMessage(), e.getStackTraceString());
            throw new AuraHandledException('Unable to update record. Please verify permissions.');
        }
    }
}
```

### Queueable Pattern (NOT @future)
```apex
public inherited sharing class MyProcessor implements Queueable {
    private Database.Cursor cursor;
    private Integer position;

    public MyProcessor(Database.Cursor cursor, Integer position) {
        this.cursor = cursor;
        this.position = position;
    }

    public void execute(QueueableContext ctx) {
        List<SObject> records = cursor.fetch(position, 200);
        // Process records...
        if (position + 200 < cursor.getNumRecords()) {
            System.enqueueJob(new MyProcessor(cursor, position + 200));
        }
    }
}
```

## Checklist

Before considering the class complete:
- [ ] Explicit sharing declaration (`with sharing`, `inherited sharing`, or documented `without sharing`)
- [ ] All SOQL uses `WITH USER_MODE`
- [ ] All DML uses `as user` or `AccessLevel.USER_MODE`
- [ ] All `Database.*` calls include `AccessLevel.USER_MODE`
- [ ] ApexDoc on class and all public methods (no `@description` tag)
- [ ] ElaroLogger for error logging (no `System.debug()`)
- [ ] `@AuraEnabled` methods have try-catch with user-friendly messages
- [ ] API version 66.0 in meta.xml
- [ ] Test class created with 85%+ coverage
- [ ] Tests use `Assert` class (not `System.assert*`)
- [ ] Tests include positive, negative, and bulk scenarios
