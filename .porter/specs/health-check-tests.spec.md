# Spec: health-check-tests

**Tier**: Full | **Domain**: SOFTWARE | **Priority**: P1 — High
**Findings**: TEST-006 to TEST-010 (5 high from Test Auditor)
**Scope**: 5 new test classes in force-app-healthcheck/

## Problem
5 Health Check production classes have zero test coverage: HCLogger, HealthCheckFeatureFlags, HealthCheckResult, ScanFinding, ScanRecommendation. AppExchange requires 85%+ coverage per class.

## Target Files (ALL NEW)
1. `force-app-healthcheck/main/default/classes/HCLoggerTest.cls`
2. `force-app-healthcheck/main/default/classes/HealthCheckFeatureFlagsTest.cls`
3. `force-app-healthcheck/main/default/classes/HealthCheckResultTest.cls`
4. `force-app-healthcheck/main/default/classes/ScanFindingTest.cls`
5. `force-app-healthcheck/main/default/classes/ScanRecommendationTest.cls`

## Acceptance Criteria

- **AC-001**: HCLoggerTest covers info(), error(), warn() methods with assertions on log behavior
- **AC-002**: HealthCheckFeatureFlagsTest covers default-on behavior, custom setting override, null handling
- **AC-003**: HealthCheckResultTest covers constructor, JSON serialization, field access
- **AC-004**: ScanFindingTest covers construction, severity enum, field mapping
- **AC-005**: ScanRecommendationTest covers construction, priority ordering, field access
- **AC-006**: All 5 test classes use `@IsTest(testFor=ClassName.class)` annotation
- **AC-007**: All 5 test classes use `Assert` class only (not System.assertEquals)
- **AC-008**: Each test class has 3+ test methods with meaningful assertions
- **AC-009**: Each test class includes corresponding .cls-meta.xml with apiVersion 66.0

## Scope Fence
- **IN**: 5 new test classes in force-app-healthcheck/main/default/classes/
- **OUT**: Existing Health Check tests (already passing), main package tests

## Checkpoints
1. STOP after reading all 5 production classes to understand API surface
