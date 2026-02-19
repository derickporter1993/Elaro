# Spec: appexchange-packaging

**Tier**: Full | **Domain**: SOFTWARE | **Priority**: P0 — Blocker
**Findings**: AX-001 to AX-004, AX-007, AX-011 (1 critical + 4 high + 1 medium)
**Scope**: Permission set XML files, sfdx-project.json, feature flag custom setting

## Problem
AppExchange submission blocked: empty namespace, ~30 custom objects missing from permission sets, 18/19 tabs missing, ~260 Apex classes missing from permission sets, no feature flag kill switches for main package.

## Target Files
1. `sfdx-project.json` — namespace configuration
2. `force-app/main/default/permissionsets/Elaro_Admin.permissionset-meta.xml` — add missing objects, tabs, classes
3. `force-app/main/default/permissionsets/Elaro_User.permissionset-meta.xml` — add read access
4. NEW: `force-app/main/default/objects/Elaro_Feature_Flags__c/` — create Hierarchy Custom Setting
5. NEW: `force-app/main/default/classes/FeatureFlags.cls` — feature flag utility class

## Acceptance Criteria

- **AC-001**: `sfdx-project.json` has `"namespace": "elaro"` for main package (note: actual namespace registration requires DevHub — add TODO comment)
- **AC-002**: `Elaro_Admin` permission set grants CRUD on ALL custom objects in force-app/main/default/objects/
- **AC-003**: `Elaro_Admin` permission set grants Visible on ALL custom tabs in force-app/main/default/tabs/
- **AC-004**: `Elaro_Admin` permission set grants access to ALL Apex classes with @AuraEnabled methods
- **AC-005**: `Elaro_User` permission set grants Read access on all objects and Visible on all tabs
- **AC-006**: `Elaro_Feature_Flags__c` Hierarchy Custom Setting created with boolean fields for each major module (Command_Center_Enabled__c, Event_Monitoring_Enabled__c, AI_Governance_Enabled__c, SEC_Module_Enabled__c, Trust_Center_Enabled__c, Assessment_Wizard_Enabled__c) all defaulting TRUE
- **AC-007**: `FeatureFlags.cls` utility class with static methods checking each flag, following `inherited sharing` pattern
- **AC-008**: FeatureFlags test class created

## Scope Fence
- **IN**: Permission sets, sfdx-project.json, feature flag custom setting + utility class
- **OUT**: Health Check package (separate namespace — requires separate DevHub action), Elaro_Admin_Extended, TechDebt_Manager

## Checkpoints
1. STOP after inventorying all objects/tabs/classes to add — present count for approval
2. STOP after permission set updates — verify XML validity
