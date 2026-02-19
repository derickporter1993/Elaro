# Spec: test-coverage-gaps

**Tier**: Full | **Domain**: SOFTWARE | **Priority**: P1 — High
**Findings**: TEST-002 to TEST-005, TEST-011 to TEST-017 (5 critical + 7 high + 4 medium)
**Scope**: Replace 3 stub tests, add @IsTest(testFor) to key tests, create 4 SEC LWC test files

## Problem
3 test classes are stubs (Assert.isTrue(true)), 147 test classes missing @IsTest(testFor), 4 SEC LWC components have no tests. These block AppExchange readiness and Spring '26 RunRelevantTests.

## Target Files — Stub Replacements
1. `force-app/main/default/classes/ElaroEventProcessorTest.cls` — replace stub
2. `force-app/main/default/classes/ElaroFrameworkEngineTest.cls` — replace stub
3. `force-app/main/default/classes/ElaroEventMonitoringServiceTest.cls` — replace stub

## Target Files — SEC LWC Tests (NEW)
4. `force-app/main/default/lwc/secDisclosureDashboard/__tests__/secDisclosureDashboard.test.js`
5. `force-app/main/default/lwc/secDisclosureForm/__tests__/secDisclosureForm.test.js`
6. `force-app/main/default/lwc/secIncidentTimeline/__tests__/secIncidentTimeline.test.js`
7. `force-app/main/default/lwc/secMaterialityCard/__tests__/secMaterialityCard.test.js`

## Target Files — @IsTest(testFor) Batch Addition
8. ALL test classes in force-app/main/default/classes/*Test.cls missing @IsTest(testFor)

## Acceptance Criteria

- **AC-001**: ElaroEventProcessorTest has 3+ test methods with meaningful assertions (not Assert.isTrue(true))
- **AC-002**: ElaroFrameworkEngineTest has 3+ test methods with meaningful assertions
- **AC-003**: ElaroEventMonitoringServiceTest has 3+ test methods with meaningful assertions
- **AC-004**: All 3 replacement tests use Test.startTest()/stopTest(), @TestSetup where appropriate
- **AC-005**: 4 SEC LWC test files created with loading state, data display, and error handling tests
- **AC-006**: LWC tests use `{ virtual: true }` for Salesforce module mocks per CLAUDE.md
- **AC-007**: @IsTest(testFor=ClassName.class) added to all test classes that have a matching production class
- **AC-008**: `npm run test:unit` passes after all changes

## Scope Fence
- **IN**: 3 stub test classes, 4 SEC LWC test files, @IsTest(testFor) batch addition
- **OUT**: New test classes for untested production classes (separate spec), assertion quality improvements in existing tests

## Checkpoints
1. STOP after reading the 3 production classes (ElaroEventProcessor, ElaroFrameworkEngine, ElaroEventMonitoringService) to understand what to test
2. STOP after reading the 4 SEC LWC components to understand what to test
