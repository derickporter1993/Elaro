# Spec: future-to-queueable

**Tier**: Full | **Domain**: SOFTWARE | **Priority**: P0 — Critical
**Findings**: GOV-005 to GOV-012 (10 critical from Governor Analyst)
**Scope**: 4 files, 8 @future methods → Queueable classes

## Problem
8 @future(callout=true) methods violate Spring '26 standards. CLAUDE.md explicitly states "NEVER @future". Must convert to Queueable + Database.AllowsCallouts pattern.

## Target Files
1. `force-app/main/default/classes/SlackIntegration.cls` — 4 @future methods
2. `force-app/main/default/classes/MultiOrgManager.cls` — 2 @future methods
3. `force-app/main/default/classes/JiraIntegrationService.cls` — 1 @future method
4. `force-app/main/default/classes/ElaroDeliveryService.cls` — 1 @future method

## Reference Implementation
`ElaroDailyDigest.SlackDigestQueueable` (line 297) — correct pattern with Database.AllowsCallouts, try-catch, ElaroLogger.

## Acceptance Criteria

- **AC-001**: All 8 @future methods replaced with inner Queueable classes implementing `Queueable, Database.AllowsCallouts`
- **AC-002**: Each Queueable has try-catch with `ElaroLogger.error()` in execute()
- **AC-003**: SlackIntegration consolidated: 4 @future methods → 1 `SlackNotificationQueueable` with enum for notification type
- **AC-004**: All callers of the old @future methods updated to `System.enqueueJob(new XxxQueueable(params))`
- **AC-005**: No @future annotations remain in any of the 4 files
- **AC-006**: Each Queueable class has proper ApexDoc (@author, @since, @group)
- **AC-007**: Existing test classes updated to cover Queueable execution (Test.startTest/stopTest)

## Scope Fence
- **IN**: SlackIntegration, MultiOrgManager, JiraIntegrationService, ElaroDeliveryService and their test files
- **OUT**: ElaroDailyDigest (already correct), all other files

## Checkpoints
1. STOP after reading all 4 files + reference implementation — confirm conversion plan
2. STOP after SlackIntegration (largest change) — verify pattern before continuing

## Rollback
`git stash` before starting. Each file independently revertable.
