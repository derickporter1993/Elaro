# Code Conventions

## Naming Conventions

### Apex

#### Classes

- **Format**: PascalCase with `Elaro` prefix
- **Pattern**: `Elaro[Feature][Type]`
- **Examples**:
  ```java
  public with sharing class ElaroSecurityUtils { }
  public with sharing class ElaroComplianceCopilot { }
  public abstract with sharing class ComplianceServiceBase { }
  ```

#### Methods

- **Format**: camelCase
- **Pattern**: Descriptive verb phrases
- **Controller Methods**: `@AuraEnabled` with cacheable where appropriate
- **Examples**:
  ```java
  public static ComplianceRecommendation analyzeEventPattern(List<String> eventIds)
  private static ScoreFactor calculatePermissionSprawlScore()
  @AuraEnabled(cacheable=true)
  public static ScoreResult calculateReadinessScore()
  ```

#### Variables

- **Format**: camelCase
- **Private Variables**: Start with lowercase
- **Constants**: UPPER_SNAKE_CASE
- **Examples**:
  ```java
  private static final String NAMED_CREDENTIAL = 'callout:Elaro_Claude_API';
  private static final Integer MAX_TOKENS = 4096;
  private List<Elaro_Evidence_Item__c> evidenceItems;
  ```

#### Custom Objects

- **Format**: Pascal_Snake_Case\_\_c
- **Pattern**: `Elaro_Object_Name__c`
- **Examples**:
  - `Elaro_Evidence_Item__c`
  - `Elaro_Audit_Package__c`
  - `Compliance_Gap__c`

#### Custom Fields

- **Format**: Snake_Case\_\_c
- **Examples**:
  - `Evidence_Type__c`
  - `Risk_Score__c`
  - `Framework__c`

### LWC (JavaScript)

#### Components

- **Format**: camelCase with `elaro` prefix
- **Pattern**: `elaro[ComponentName]`
- **Examples**:
  - `elaroCopilot`
  - `elaroDashboard`
  - `elaroSetupWizard`

#### Properties

- **Format**: camelCase
- **Reactive**: `@track` for mutable, `@wire` for immutable
- **Examples**:
  ```javascript
  @track query = "";
  @track messages = [];
  @wire(calculateReadinessScore) wiredScore;
  ```

#### Methods

- **Format**: camelCase with verb prefix
- **Event Handlers**: `handle[Event]`
- **Getters**: Standard naming
- **Examples**:
  ```javascript
  handleQueryChange(event) { }
  handleSubmit() { }
  get hasMessages() { }
  extractErrorMessage(error) { }
  ```

#### Constants

- **Format**: UPPER_SNAKE_CASE
- **Examples**:
  ```javascript
  const DEBOUNCE_DELAY = 300;
  const FRAMEWORKS = [...];
  ```

## Code Style

### Apex

#### Class Structure

```java
/**
 * @description Brief description
 * @group Category
 * @author Elaro
 */
public with sharing class ClassName {

    // ═══════════════════════════════════════════════════════════════
    // CONSTANTS
    // ═══════════════════════════════════════════════════════════════

    // ═══════════════════════════════════════════════════════════════
    // INSTANCE VARIABLES
    // ═══════════════════════════════════════════════════════════════

    // ═══════════════════════════════════════════════════════════════
    // PUBLIC METHODS
    // ═══════════════════════════════════════════════════════════════

    // ═══════════════════════════════════════════════════════════════
    // PRIVATE METHODS
    // ═══════════════════════════════════════════════════════════════

    // ═══════════════════════════════════════════════════════════════
    // INNER CLASSES
    // ═══════════════════════════════════════════════════════════════
}
```

#### Method Structure

```java
/**
 * @description What the method does
 * @param paramName Description
 * @return Description
 * @throws ExceptionType When thrown
 */
public ReturnType methodName(ParamType paramName) {
    // Guard clauses first
    if (invalidCondition) {
        return defaultValue;
    }

    try {
        // Main logic
    } catch (SpecificException e) {
        // Specific handling
    } catch (Exception e) {
        // General handling
    }
}
```

#### Comments

- **JavaDoc**: All public methods
- **Section Headers**: Use ═══ blocks for major sections
- **Inline**: Only for complex logic
- **TODO**: Mark with `// TODO:` and context

#### Line Length

- **Soft Limit**: 120 characters
- **Hard Limit**: 150 characters
- **Break Strategy**: Break at logical points

#### Indentation

- **Style**: 4 spaces (no tabs)
- **Braces**: Same line (K&R style)

### LWC (JavaScript)

#### Component Structure

```javascript
// Imports
import { LightningElement, track, wire } from "lwc";
import methodName from "@salesforce/apex/Controller.methodName";
import { ShowToastEvent } from "lightning/platformShowToastEvent";

// Constants
const DEBOUNCE_DELAY = 300;

// Component Class
export default class ComponentName extends LightningElement {
  // Reactive properties
  @track state = {};

  // Wire adapters
  @wire(wiredMethod) wiredData;

  // Getters
  get computedProperty() {}

  // Event handlers
  handleEvent(event) {}

  // Private methods
  privateMethod() {}

  // Lifecycle hooks
  disconnectedCallback() {}
}
```

#### Comments

- **JSDoc**: For complex methods
- **Inline**: Explain "why" not "what"

## Security Patterns

### Sharing Enforcement

**REQUIRED**: All classes must use `with sharing`

```java
// ✅ CORRECT
public with sharing class ElaroSecurityUtils { }

// ❌ WRONG
public class ElaroAlertQueueable { }  // Missing with sharing - SECURITY ISSUE
```

### CRUD/FLS Enforcement

#### Method 1: WITH SECURITY_ENFORCED (Preferred for new code)

```java
List<Elaro_Evidence_Item__c> items = [
    SELECT Id, Name FROM Elaro_Evidence_Item__c
    WITH SECURITY_ENFORCED
];
```

#### Method 2: WITH USER_MODE (Newer approach)

```java
List<Elaro_Evidence_Item__c> items = [
    SELECT Id, Name FROM Elaro_Evidence_Item__c
    WITH USER_MODE
];
```

#### Method 3: Schema Describe (For programmatic checks)

```java
if (Schema.sObjectType.Compliance_Gap__c.isCreateable()) {
    insert gap;
}
```

#### Method 4: stripInaccessible (Modern approach)

```java
items = ElaroSecurityUtils.stripInaccessibleFields(AccessType.READABLE, items);
```

### Input Validation

```java
@AuraEnabled
public static Result methodName(String input) {
    if (String.isBlank(input)) {
        throw new AuraHandledException('Input is required');
    }
    // Process
}
```

### Error Handling

#### Apex

```java
try {
    // Operation
} catch (DmlException e) {
    // Handle DML errors
    System.debug(LoggingLevel.ERROR, 'DML Error: ' + e.getDmlMessage(0));
} catch (Exception e) {
    // Handle general errors
    System.debug(LoggingLevel.ERROR, 'Error: ' + e.getMessage());
}
```

#### LWC

```javascript
try {
  // Operation
} catch (error) {
  const message = error?.body?.message || error?.message || "Unknown error";
  this.showToast("Error", message, "error");
}
```

## Error Handling Patterns

### Structured Logging

All classes use consistent logging format:

```java
System.debug(LoggingLevel.ERROR,
    '[ClassName] MethodName: message - ' +
    'CorrelationId: ' + correlationId + ', ' +
    'Error: ' + e.getMessage());
```

### Exception Classes

- `ElaroException` - Base exception
- `ComplianceServiceException` - Service layer
- `SecurityException` - Security violations (nested in ElaroSecurityUtils)

### Error Tracking

Persistent error logging via `Integration_Error__c`:

```java
Integration_Error__c error = new Integration_Error__c(
    Error_Type__c = 'INTEGRATION',
    Error_Message__c = e.getMessage(),
    Correlation_Id__c = correlationId,
    Status__c = 'NEW',
    Timestamp__c = System.now()
);
insert error;
```

## Async Patterns

### Queueable (Preferred)

```java
public with sharing class QueueableClass
    implements Queueable, Database.AllowsCallouts {

    public void execute(QueueableContext context) {
        // Implementation with retry logic
    }
}

// Usage
System.enqueueJob(new QueueableClass(params));
```

### @future (Legacy)

```java
@future(callout=true)
public static void asyncMethod(String param) {
    // No return value, no retry
}
```

### Schedulable

```java
public with sharing class SchedulerClass implements Schedulable {
    public void execute(SchedulableContext sc) {
        // Scheduled execution
    }
}
```

## Caching Patterns

### Static Cache

```java
private static ScoreFactor cache;

private static ScoreFactor getCachedData() {
    if (cache != null) {
        return cache;
    }
    cache = expensiveOperation();
    return cache;
}
```

### Platform Cache

```java
Cache.OrgPartition partition = Cache.Org.getPartition('local.ElaroCache');
partition.put(key, value, 3600); // TTL 1 hour
```

## Testing Conventions

### Test Class Naming

- **Pattern**: `[ClassName]Test`
- **Example**: `ElaroSecurityUtilsTest`

### Test Method Naming

- **Pattern**: `test[Scenario]_[ExpectedResult]`
- **Examples**:
  - `testHasReadAccess_ValidObject_ReturnsTrue`
  - `testValidateCRUDAccess_InvalidObject_ThrowsException`

### Test Structure

```java
@isTest
private class ClassNameTest {
    @TestSetup
    static void setupTestData() {
        // Create test data
    }

    @isTest
    static void testMethodName() {
        // Arrange
        // Act
        Test.startTest();
        // Operation
        Test.stopTest();
        // Assert
    }
}
```

## Documentation Standards

### Class Documentation

```java
/**
 * ClassName - Brief description
 *
 * Detailed description of what this class does,
 * its responsibilities, and key features.
 *
 * @author Elaro
 * @version 1.0
 */
```

### Method Documentation

```java
/**
 * @description Brief description
 * @param paramName Description of parameter
 * @return Description of return value
 * @throws ExceptionType When this exception is thrown
 */
```

### Section Headers

```java
// ═══════════════════════════════════════════════════════════════
// SECTION NAME
// ═══════════════════════════════════════════════════════════════
```

## Git Conventions

### Commit Messages

- **Format**: `type(scope): message`
- **Types**: `feat`, `fix`, `docs`, `test`, `refactor`
- **Examples**:
  - `feat(security): add FLS validation to EvidenceService`
  - `fix(copilot): resolve rate limiting issue`
  - `docs(readme): update installation instructions`

### Branching

- Feature branches for development
- Main branch for production
- GSD creates atomic commits per task

## File Organization

### Apex Classes

1. Constants (private static final)
2. Instance variables
3. Public methods (including @AuraEnabled)
4. Private methods (grouped by functionality)
5. Inner classes (at bottom)

### LWC Components

1. Imports
2. Constants
3. Component class
4. Reactive properties (@track, @wire)
5. Getters
6. Event handlers
7. Private methods
8. Lifecycle hooks

## Best Practices

### Do's ✅

- Use `with sharing` on all classes
- Validate all inputs
- Use Named Credentials for external APIs
- Cache expensive operations
- Handle all exceptions
- Write test classes
- Document public methods
- Use constants for magic values
- Use bulkified patterns
- Include correlation IDs for tracing

### Don'ts ❌

- Hardcode secrets or credentials
- Use `@future` when `Queueable` is available
- Put SOQL/DML in loops
- Swallow exceptions silently
- Skip CRUD/FLS checks
- Exceed 150 character lines
- Mix concerns in single class
- Skip documentation
