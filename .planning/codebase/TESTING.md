# Testing

## Overview

Elaro maintains comprehensive test coverage across both Apex (backend) and LWC (frontend). The project uses Salesforce-native testing frameworks with additional tooling for JavaScript testing.

## Test Statistics

| Metric              | Count           |
| ------------------- | --------------- |
| Total Apex Classes  | 290             |
| Test Classes        | 140             |
| Test Coverage Ratio | 48%             |
| LWC Components      | 43              |
| LWC Test Files      | ~20 (estimated) |

## Apex Testing

### Framework

- **Framework**: Native Salesforce Apex testing
- **Annotation**: `@isTest` (preferred) or `@IsTest`
- **Execution**: Synchronous and asynchronous support

### Test Class Structure

```java
/**
 * @description Test class for ClassName
 * @group Tests
 * @see ClassName
 */
@isTest
private class ClassNameTest {

    @TestSetup
    static void setupTestData() {
        // Create reusable test data
        Account testAccount = new Account(Name = 'Test Account');
        insert testAccount;
    }

    @isTest
    static void testMethodName_SuccessScenario() {
        // Arrange
        // Load test data from @TestSetup

        // Act
        Test.startTest();
        Result result = ClassName.methodName(params);
        Test.stopTest();

        // Assert
        System.assertEquals(expected, actual, 'Message');
    }

    @isTest
    static void testMethodName_ErrorScenario() {
        // Test error handling
    }
}
```

### Test Data Factories

#### 1. ComplianceTestDataFactory

**Purpose**: Create compliance-specific test data
**Location**: `force-app/main/default/classes/ComplianceTestDataFactory.cls`
**Size**: 151 lines

**Features**:

- Framework-aware data creation
- Evidence item generation
- Audit package setup
- Gap creation
- Policy test data

**Usage**:

```java
Elaro_Audit_Package__c pkg = ComplianceTestDataFactory.createAuditPackage('HIPAA');
Elaro_Evidence_Item__c evidence = ComplianceTestDataFactory.createEvidenceItem(pkg.Id);
```

#### 2. ElaroTestDataFactory

**Purpose**: General test data utilities
**Location**: `force-app/main/default/classes/ElaroTestDataFactory.cls`
**Size**: 164 lines

**Features**:

- Mock record IDs (safe for tests)
- User creation
- Permission set assignment
- Account/Contact generation
- Mock Claude API responses

**Mock ID Pattern**:

```java
// Safe mock IDs for testing
Id mockUserId = '005000000000001AAA';
Id mockAccountId = '001000000000001AAA';
```

#### 3. ElaroTestUserFactory

**Purpose**: User and permission testing
**Location**: `force-app/main/default/classes/ElaroTestUserFactory.cls`

### Mock Patterns

#### HTTP Callout Mocks

All external integrations use `HttpCalloutMock`:

```java
private class MockClaudeAPI implements HttpCalloutMock {
    public HttpResponse respond(HttpRequest req) {
        HttpResponse res = new HttpResponse();
        res.setStatusCode(200);
        res.setBody('{"recommendation": "Test", "severity": "MEDIUM"}');
        return res;
    }
}

// In test:
Test.setMock(HttpCalloutMock.class, new MockClaudeAPI());
```

**Mock Classes Present**:

- `SlackIntegrationTest.MockSlackAPI`
- `JiraIntegrationServiceTest.MockJiraAPI`
- `ServiceNowIntegrationTest.MockServiceNowAPI`
- `PagerDutyIntegrationTest.MockPagerDutyAPI`
- `WeeklyScorecardSchedulerTest.MockHttpResponseGenerator`

### Test Method Patterns

#### CRUD Testing

```java
@isTest
static void testCreateGap_Success() {
    Test.startTest();
    Id gapId = service.createGap('POL-001', 'Description', 'HIGH', 'Type', 'Id', 8.5);
    Test.stopTest();

    Compliance_Gap__c gap = [SELECT Id, Severity__c FROM Compliance_Gap__c WHERE Id = :gapId];
    System.assertEquals('HIGH', gap.Severity__c);
}
```

#### Security Testing

```java
@isTest
static void testHasReadAccess_ValidObject() {
    Test.startTest();
    Boolean hasAccess = ElaroSecurityUtils.hasReadAccess('Account');
    Test.stopTest();

    System.assertEquals(true, hasAccess, 'Should have read access');
}

@isTest
static void testHasReadAccess_InvalidObject() {
    Test.startTest();
    Boolean hasAccess = ElaroSecurityUtils.hasReadAccess('InvalidObject__c');
    Test.stopTest();

    System.assertEquals(false, hasAccess, 'Should not have access to invalid object');
}
```

#### Queueable Testing

```java
@isTest
static void testQueueableExecution() {
    AlertQueueItem item = new AlertQueueItem();
    item.alertId = 'ALERT-001';
    item.severity = 'HIGH';

    Test.startTest();
    System.enqueueJob(new ElaroAlertQueueable(item));
    Test.stopTest();

    // Assert: Queueable should execute without errors
    System.assert(true);
}
```

#### Negative Testing

```java
@isTest
static void testMethod_InvalidInput() {
    Test.startTest();
    try {
        ClassName.method(null);
        System.assert(false, 'Should have thrown exception');
    } catch (Exception e) {
        System.assert(e.getMessage().contains('Expected error message'));
    }
    Test.stopTest();
}
```

### Test Coverage Areas

#### Comprehensive Coverage

- **ElaroSecurityUtilsTest**: 416 lines
  - CRUD access tests (read, create, update, delete)
  - FLS access tests (field read, field write)
  - Invalid object/field tests
  - `stripInaccessibleFields` tests
  - `buildSecureQuery` tests
  - SecurityException tests

#### Integration Tests

- **SlackIntegrationTest**: HTTP callout mocking
- **JiraIntegrationServiceTest**: Jira API mocking
- **ServiceNowIntegrationTest**: ServiceNow mocking
- **PagerDutyIntegrationTest**: PagerDuty mocking

#### Service Tests

- **ElaroComplianceCopilotTest**: Copilot functionality
- **ElaroComplianceScorerTest**: Scoring engine
- **ElaroGraphIndexerTest**: Graph indexing
- **ElaroISO27001AccessReviewServiceTest**: ISO 27001 features

### Running Apex Tests

```bash
# Run all tests
sf apex run test -o elaro-dev

# Run with coverage
sf apex run test -o elaro-dev -c -r human -w 10

# Run specific test class
sf apex run test -n ElaroSecurityUtilsTest -o elaro-dev
```

## LWC Testing

### Framework

- **Test Runner**: Jest
- **Framework**: `@salesforce/sfdx-lwc-jest`
- **Version**: 7.1.2
- **DOM Testing**: `@testing-library/jest-dom`

### Test File Location

```
lwc/componentName/
├── __tests__/
│   └── componentName.test.js
├── componentName.js
├── componentName.html
└── componentName.js-meta.xml
```

### Test Structure

```javascript
import { createElement } from "lwc";
import ComponentName from "c/componentName";

describe("c-component-name", () => {
  afterEach(() => {
    // Clean up DOM
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
  });

  it("renders correctly", () => {
    // Arrange
    const element = createElement("c-component-name", {
      is: ComponentName,
    });

    // Act
    document.body.appendChild(element);

    // Assert
    const div = element.shadowRoot.querySelector("div");
    expect(div).not.toBeNull();
  });

  it("handles user input", () => {
    // Test event handling
  });
});
```

### Mocking LWC Services

#### Wire Adapters

```javascript
import { registerApexTestWireAdapter } from "@salesforce/sfdx-lwc-jest";
import getData from "@salesforce/apex/Controller.getData";

const getDataAdapter = registerApexTestWireAdapter(getData);

it("displays data from wire", async () => {
  const element = createElement("c-component", { is: Component });
  document.body.appendChild(element);

  // Emit data
  getDataAdapter.emit({ data: "test" });

  // Wait for re-render
  await Promise.resolve();

  // Assert
});
```

#### Platform Events

```javascript
import { registerTestWireAdapter } from "@salesforce/sfdx-lwc-jest";
import { ShowToastEvent } from "lightning/platformShowToastEvent";

const showToastAdapter = registerTestWireAdapter(ShowToastEvent);
```

### Running LWC Tests

```bash
# Run all LWC tests
npm run test:unit

# Run with coverage
npm run test:unit:coverage

# Run in watch mode
npm run test:unit:watch

# Run specific test
npx jest componentName.test.js
```

## Accessibility Testing

### Framework

- **Engine**: axe-core 4.11.1
- **Integration**: jest-axe
- **Runner**: Custom script `scripts/accessibility-audit.js`

### Running Accessibility Tests

```bash
npm run test:a11y
```

### Accessibility Patterns in Code

All LWC components include ARIA labels:

```javascript
get overallScoreAriaLabel() {
    return `Overall compliance score: ${this.displayScore} out of 100`;
}
```

## Code Quality Tests

### Linting

```bash
npm run lint          # Check for issues
npm run lint:fix      # Auto-fix issues
```

### Formatting

```bash
npm run fmt:check     # Check formatting
npm run fmt           # Fix formatting
```

### Pre-commit Validation

```bash
npm run precommit     # Runs fmt:check + lint + test:unit
npm run validate      # Alias for precommit
```

## Test Coverage Standards

### Apex Coverage

- **Target**: 75% minimum (Salesforce requirement)
- **Current**: Estimated 70-80% (based on test class count)
- **Critical Classes**: 90%+ coverage
  - Security utilities
  - Compliance services
  - Integration classes

### LWC Coverage

- **Target**: 80% minimum
- **Focus Areas**:
  - User interactions
  - Error handling
  - Data loading states
  - Event handling

## Testing Best Practices

### Do's ✅

- Use `@TestSetup` for shared test data
- Mock all HTTP callouts
- Test both success and error scenarios
- Use descriptive test method names
- Include negative test cases
- Test CRUD/FLS enforcement
- Use test data factories
- Verify governor limits not exceeded

### Don'ts ❌

- Don't use `@isTest(SeeAllData=true)` unless necessary
- Don't hardcode IDs (use TestDataFactory)
- Don't skip error scenario testing
- Don't write tests without assertions
- Don't ignore test failures

## Continuous Integration

### Pre-commit Hooks

```json
"lint-staged": {
    "*.{js,ts,html,md,json,yml,yaml,xml}": ["prettier --write"],
    "force-app/**/*.js": ["eslint --fix"]
}
```

### CI/CD Pipeline (Inferred)

1. Checkout code
2. Install dependencies: `npm install`
3. Validate formatting: `npm run fmt:check`
4. Lint: `npm run lint`
5. Run LWC tests: `npm run test:unit`
6. Deploy to scratch org: `sf project deploy start`
7. Run Apex tests: `sf apex run test -c`
8. Validate coverage meets threshold

## Test Organization

### By Type

- Unit tests (isolated component testing)
- Integration tests (component interactions)
- Security tests (CRUD/FLS validation)
- Mock tests (external API testing)

### By Layer

- LWC tests (frontend)
- Apex controller tests
- Service layer tests
- Integration tests

### By Feature

- Copilot tests
- Dashboard tests
- Compliance framework tests
- Integration tests (Slack, Jira, etc.)

## Known Testing Gaps

1. **Einstein Platform**: Mock exists but actual integration not tested
2. **Platform Events**: Excluded from deployment, limited testing
3. **Complex Async Flows**: Some Queueable chain testing may be incomplete
4. **Bulk Data Testing**: Limited testing with >200 records

## Future Improvements

1. Add mutation testing for critical paths
2. Implement contract testing for external APIs
3. Add visual regression testing for LWC
4. Increase coverage to 85%+ across all modules
5. Add performance testing for scoring algorithms
