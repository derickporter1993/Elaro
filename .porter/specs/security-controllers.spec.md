# Spec: security-controllers

**Tier**: Full | **Domain**: SOFTWARE | **Priority**: P0 — Critical
**Findings**: SEC-001 to SEC-025 (21 critical+high from Security Reviewer)
**Scope**: 3 files, ~15 method modifications

## Problem
Three controller classes have @AuraEnabled methods missing try-catch error handling, DML without `as user`, and SOQL without `WITH USER_MODE`. These are AppExchange rejection criteria.

## Target Files
1. `force-app/main/default/classes/OnCallScheduleController.cls`
2. `force-app/main/default/classes/MultiOrgManager.cls`
3. `force-app/main/default/classes/HIPAABreachNotificationService.cls`

## Acceptance Criteria

- **AC-001**: Every @AuraEnabled method in all 3 files wrapped in try-catch with `ElaroLogger.error(className.methodName, e.getMessage(), e.getStackTraceString())` and `throw new AuraHandledException(userFriendlyMessage)`
- **AC-002**: Every DML statement uses `as user` syntax (`insert as user`, `update as user`, `delete as user`)
- **AC-003**: Every SOQL query includes `WITH USER_MODE`
- **AC-004**: No `Schema.sObjectType.*.isCreateable()` / `isUpdateable()` / `isDeletable()` checks remain (redundant with `as user`)
- **AC-005**: Reference pattern matches `AIGovernanceController.cls` (the exemplary implementation)
- **AC-006**: All existing test classes still pass after modifications

## Scope Fence
- **IN**: OnCallScheduleController, MultiOrgManager, HIPAABreachNotificationService
- **OUT**: All other classes. Do NOT touch any files not listed above.

## Checkpoints
1. STOP after reading all 3 files — confirm understanding
2. STOP after modifying each file — verify no compilation errors introduced

## Rollback
`git stash` before starting. Revert individual files with `git checkout -- <file>`.
