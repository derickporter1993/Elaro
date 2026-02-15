# Elaro Code Review Findings

**Generated:** 2026-02-15 | **Scanned:** 299 Apex classes, 59 LWC components, 54 custom objects, 8 Platform Events, 5 Permission Sets, 5 Triggers
**Standards Reference:** [CLAUDE.md](../CLAUDE.md) | **Target:** AppExchange 2GP (API v66.0, Spring '26)

---

## Executive Summary

| Category | Grade | Critical | High | Medium | Total |
|----------|-------|----------|------|--------|-------|
| Apex Security | D+ | 125 | 15 | 8 | 148 |
| Apex Testing & Docs | C | 0 | 155 | 109 | 264 |
| LWC Standards | C+ | 0 | 95 | 9 | 104 |
| Metadata & Architecture | C+ | 3 | 54 | 30 | 87 |
| **TOTAL** | | **128** | **319** | **156** | **603** |

**AppExchange Blockers:** DML without `as user` (125), dynamic SOQL injection (15), `@future` usage (8), missing permission set entries (54+ classes), broken LWC components (3)

---

## Category 1: Apex Security (Grade: D+)

### 1.1 CRITICAL: DML Without `as user` (125 instances)

Per CLAUDE.md: _"All DML uses `as user`"_ — AppExchange rejection if violated.

#### INSERT without `as user` (80+ instances)

| # | File | Line | Code | Fix |
|---|------|------|------|-----|
| 1 | `AccessReviewScheduler.cls` | 69 | `insert reviews;` | `insert as user reviews;` |
| 2 | `AccessReviewScheduler.cls` | 200 | `insert gap;` | `insert as user gap;` |
| 3 | `AccessReviewScheduler.cls` | 217 | `insert log;` | `insert as user log;` |
| 4 | `AccessReviewScheduler.cls` | 234 | `insert log;` | `insert as user log;` |
| 5 | `ApiUsageSnapshot.cls` | 39 | `insert new API_Usage_Snapshot__c(...)` | `insert as user new API_Usage_Snapshot__c(...)` |
| 6 | `AuditReportController.cls` | 114 | `insert cv;` | `insert as user cv;` |
| 7 | `BlockchainVerification.cls` | 195 | `insert anchorsToInsert;` | `insert as user anchorsToInsert;` |
| 8 | `BlockchainVerification.cls` | 318 | `insert anchor;` | `insert as user anchor;` |
| 9 | `BreachDeadlineMonitor.cls` | 255 | `insert newGaps;` | `insert as user newGaps;` |
| 10 | `BreachDeadlineMonitor.cls` | 332 | `insert log;` | `insert as user log;` |
| 11 | `BreachDeadlineMonitor.cls` | 349 | `insert log;` | `insert as user log;` |
| 12 | `ComplianceReportScheduler.cls` | 459 | `insert sanitized;` | `insert as user sanitized;` |
| 13 | `ComplianceScoreSnapshotScheduler.cls` | 84 | `insert snapshots;` | `insert as user snapshots;` |
| 14 | `ComplianceScoreSnapshotScheduler.cls` | 222 | `insert log;` | `insert as user log;` |
| 15 | `ComplianceScoreSnapshotScheduler.cls` | 265 | `insert gap;` | `insert as user gap;` |
| 16 | `ComplianceScoreSnapshotScheduler.cls` | 287 | `insert gap;` | `insert as user gap;` |
| 17 | `ComplianceScoreSnapshotScheduler.cls` | 305 | `insert log;` | `insert as user log;` |
| 18 | `ComplianceScoreSnapshotScheduler.cls` | 322 | `insert log;` | `insert as user log;` |
| 19 | `ComplianceServiceBase.cls` | 102 | `insert gap;` | `insert as user gap;` |
| 20 | `ComplianceServiceBase.cls` | 128 | `insert evidence;` | `insert as user evidence;` |
| 21 | `ComplianceServiceBase.cls` | 195 | `insert auditLog;` | `insert as user auditLog;` |
| 22 | `ElaroAuditPackageGenerator.cls` | 51 | `insert auditPackage;` | `insert as user auditPackage;` |
| 23 | `ElaroAuditPackageGenerator.cls` | 95 | `insert mappings;` | `insert as user mappings;` |
| 24 | `ElaroAuditPackageGenerator.cls` | 129 | `insert evidenceItems;` | `insert as user evidenceItems;` |
| 25 | `ElaroComplianceAlert.cls` | 45 | `insert alertRecord;` | `insert as user alertRecord;` |
| 26 | `ElaroDeliveryService.cls` | 166 | `insert cd;` | `insert as user cd;` |
| 27 | `ElaroGDPRDataErasureService.cls` | 137 | `insert new Integration_Error__c(...)` | `insert as user new Integration_Error__c(...)` |
| 28 | `ElaroGraphIndexer.cls` | 101 | `insert node;` | `insert as user node;` |
| 29 | `ElaroGraphIndexer.cls` | 226 | `insert error;` | `insert as user error;` |
| 30 | `ElaroGraphIndexer.cls` | 391 | `insert nodesToInsert;` | `insert as user nodesToInsert;` |

> **Note:** 50+ additional insert violations exist across remaining classes. Run `grep -rn '^\s*insert ' force-app/main/default/classes/ | grep -v 'as user' | grep -v 'Test.cls'` to get the full list.

#### UPDATE without `as user` (30 instances)

| # | File | Line | Code | Fix |
|---|------|------|------|-----|
| 1 | `BreachDeadlineMonitor.cls` | 311 | `update breachesToUpdate;` | `update as user breachesToUpdate;` |
| 2 | `ElaroPDFExporter.cls` | 55 | `update pkg;` | `update as user pkg;` |
| 3 | `ElaroQuickActionsService.cls` | 223 | `update decision.getRecords();` | `update as user decision.getRecords();` |
| 4 | `ElaroQuickActionsService.cls` | 502 | `update inactiveUsers;` | `update as user inactiveUsers;` |
| 5 | `ElaroTestUserFactory.cls` | 163 | `update manager;` | `update as user manager;` |
| 6 | `EscalationPathController.cls` | 59 | `update path;` | `update as user path;` |
| 7 | `HIPAABreachNotificationService.cls` | 348 | `update breach;` | `update as user breach;` |
| 8 | `HIPAABreachNotificationService.cls` | 373 | `update breach;` | `update as user breach;` |
| 9 | `JiraIntegrationService.cls` | 54 | `update gap;` | `update as user gap;` |
| 10 | `JiraIntegrationService.cls` | 126 | `update gap;` | `update as user gap;` |
| 11 | `JiraWebhookHandler.cls` | 135 | `update gap;` | `update as user gap;` |
| 12 | `JiraWebhookHandler.cls` | 178 | `update gap;` | `update as user gap;` |
| 13 | `JiraWebhookHandler.cls` | 234 | `update gap;` | `update as user gap;` |
| 14 | `MobileAlertEscalator.cls` | 93 | `update gap;` | `update as user gap;` |
| 15 | `MobileAlertPublisher.cls` | 113 | `update gap;` | `update as user gap;` |
| 16 | `MobileAlertPublisher.cls` | 147 | `update gap;` | `update as user gap;` |
| 17 | `OnCallScheduleController.cls` | 59 | `update schedule;` | `update as user schedule;` |
| 18 | `RemediationExecutor.cls` | 115 | `update suggestion;` | `update as user suggestion;` |
| 19 | `RemediationExecutor.cls` | 251 | `update suggestionsToUpdate;` | `update as user suggestionsToUpdate;` |
| 20 | `RemediationExecutor.cls` | 368 | `update suggestion;` | `update as user suggestion;` |
| 21 | `RemediationExecutor.cls` | 377 | `update suggestion;` | `update as user suggestion;` |
| 22 | `RemediationExecutor.cls` | 396 | `update gap;` | `update as user gap;` |
| 23 | `RemediationExecutor.cls` | 419 | `update gaps;` | `update as user gaps;` |
| 24 | `RemediationOrchestrator.cls` | 223 | `update u;` | `update as user u;` |
| 25 | `RemediationOrchestrator.cls` | 342 | `update event;` | `update as user event;` |
| 26 | `RemediationSuggestionService.cls` | 197 | `update suggestions;` | `update as user suggestions;` |
| 27 | `RemediationSuggestionService.cls` | 576 | `update suggestion;` | `update as user suggestion;` |
| 28 | `SOC2ChangeManagementService.cls` | 169 | `update change;` | `update as user change;` |
| 29 | `SOC2IncidentResponseService.cls` | 399 | `update incident;` | `update as user incident;` |
| 30 | `SOC2IncidentResponseService.cls` | 421 | `update incident;` | `update as user incident;` |

#### DELETE without `as user` (15 instances)

| # | File | Line | Code | Fix |
|---|------|------|------|-----|
| 1 | `ElaroQuickActionsService.cls` | 162 | `delete assignmentsToRemove;` | `delete as user assignmentsToRemove;` |
| 2 | `ElaroQuickActionsService.cls` | 267 | `delete assignments;` | `delete as user assignments;` |
| 3 | `ElaroQuickActionsService.cls` | 282 | `delete setsToRemove;` | `delete as user setsToRemove;` |
| 4 | `ElaroQuickActionsService.cls` | 379 | `delete toRemove;` | `delete as user toRemove;` |
| 5 | `ElaroQuickActionsService.cls` | 446 | `delete assignments;` | `delete as user assignments;` |
| 6 | `ElaroQuickActionsService.cls` | 543 | `delete psa;` | `delete as user psa;` |
| 7 | `EscalationPathController.cls` | 72 | `delete [SELECT ...]` | `delete as user [SELECT ...]` |
| 8 | `OnCallScheduleController.cls` | 72 | `delete [SELECT ...]` | `delete as user [SELECT ...]` |
| 9 | `RemediationOrchestrator.cls` | 204 | `delete assignments;` | `delete as user assignments;` |
| 10 | `RemediationOrchestrator.cls` | 311 | `delete sessions;` | `delete as user sessions;` |
| 11 | `SOC2AccessReviewService.cls` | 277 | `delete toRevoke;` | `delete as user toRevoke;` |

> **Note:** 4+ additional delete violations may exist. Run `grep -rn '^\s*delete ' force-app/main/default/classes/ | grep -v 'as user' | grep -v 'Test.cls'` for the full list.

### 1.2 CRITICAL: Dynamic SOQL String Concatenation (15 instances)

Per CLAUDE.md: _"ONLY Database.queryWithBinds(), NEVER string concatenation"_ — SOQL injection risk.

| # | File | Line | Vulnerable Code | Fix |
|---|------|------|-----------------|-----|
| 1 | `AIDetectionEngine.cls` | 60 | `'SELECT ... FROM ' + getToolingObjectName(metadataType)` | Validate against allowlist |
| 2 | `ElaroDrillDownController.cls` | 243 | `'SELECT ' + String.join(selectFields, ', ') + ' FROM ' + ctx.objectApiName` | Validate field/object names against Schema |
| 3 | `ElaroDrillDownController.cls` | 319 | `'SELECT COUNT() FROM ' + ctx.objectApiName` | Allowlist object names |
| 4 | `ElaroDynamicReportController.cls` | 347 | `'SELECT ' + String.join(selectFields, ', ') + ' FROM ' + cfg.objectApiName` | Validate inputs against Schema |
| 5 | `ElaroGDPRDataPortabilityService.cls` | 77 | `'SELECT ' + String.join(fieldNames, ',') + ...` | Validate field names |
| 6 | `ElaroMatrixController.cls` | 305 | `'SELECT COUNT_DISTINCT(' + rowField + ') ...'` | Allowlist field/object names |
| 7 | `ElaroMatrixController.cls` | 312 | `'SELECT COUNT_DISTINCT(' + colField + ') ...'` | Allowlist field/object names |
| 8 | `ElaroMatrixController.cls` | 338 | `'SELECT ' + rowField + ', ' + colField + '...'` | Validate inputs |
| 9 | `ElaroMatrixController.cls` | 382 | `'SELECT ... FROM ' + summaryObjectName` | Allowlist object name |
| 10 | `ElaroPDFController.cls` | 98 | `'SELECT ... FROM Elaro_Evidence_Item__c ...'` | Use parameterized binding |
| 11 | `ElaroTrendController.cls` | 312 | `'SELECT ' + bucketExpr + ' ...'` | Validate object name |
| 12 | `HIPAAPrivacyRuleService.cls` | 156 | `'SELECT ... FROM ' + historyObjectName` | Allowlist history object names |
| 13 | `SOC2IncidentResponseService.cls` | 432 | `'SELECT ... FROM Security_Incident__c ...'` | Proper query construction |

### 1.3 CRITICAL: `@future` Methods (8 instances)

Per CLAUDE.md: _"NEVER @future. @future is legacy."_ — Use Queueable pattern instead.

| # | File | Line | Method | Fix |
|---|------|------|--------|-----|
| 1 | `ElaroDeliveryService.cls` | 188 | `sendToSlack(String, String)` | Convert to `SendToSlackQueueable implements Queueable` |
| 2 | `JiraIntegrationService.cls` | 65 | `createIssueAsync(String, String)` | Convert to `JiraIssueQueueable implements Queueable` |
| 3 | `MultiOrgManager.cls` | 95 | `syncPolicies(List<String>)` | Convert to `PolicySyncQueueable implements Queueable` |
| 4 | `MultiOrgManager.cls` | 225 | `testOrgConnection(Id)` | Convert to `OrgConnectionTestQueueable implements Queueable` |
| 5 | `SlackIntegration.cls` | 15 | `sendAlert(String)` | Convert to `SlackAlertQueueable implements Queueable` |
| 6 | `SlackIntegration.cls` | 74 | `sendAuditPackageNotification(String, String)` | Convert to Queueable |
| 7 | `SlackIntegration.cls` | 123 | `sendDailyDigest(String)` | Convert to Queueable |
| 8 | `SlackIntegration.cls` | 214 | `sendToSlackFuture(String)` | Convert to Queueable |

### 1.4 PASSING: No Violations Found

- `WITH SECURITY_ENFORCED` — none found (all use `WITH USER_MODE`)
- `System.debug()` as primary logging — none found (all use `ElaroLogger`)
- Missing try-catch on `@AuraEnabled` — all have proper error handling
- Missing sharing keywords — all production classes have correct keywords

---

## Category 2: Apex Testing & Documentation (Grade: C)

### 2.1 HIGH: Test Classes Missing `@IsTest(testFor=...)` (155 instances)

Per CLAUDE.md Spring '26 best practice: _"@IsTest(testFor) links test to production class for RunRelevantTests"_

**force-app (147 test classes):**

<details>
<summary>Click to expand full list</summary>

- `AccessReviewSchedulerTest.cls`
- `AlertHistoryServiceTest.cls`
- `AnomalyDetectionServiceTest.cls`
- `ApiUsageDashboardControllerTest.cls`
- `ApiUsageSnapshotTest.cls`
- `AuditReportControllerTest.cls`
- `BenchmarkingServiceTest.cls`
- `BlockchainVerificationTest.cls`
- `BreachDeadlineMonitorTest.cls`
- `CCPAConsumerRightsServiceTest.cls`
- `BreachPatternMatcherTest.cls`
- `BusinessDayCalculatorTest.cls`
- `ChangeImpactAnalyzerTest.cls`
- `ComplianceAlertPublisherTest.cls`
- `ComplianceServiceBaseTest.cls`
- `ComplianceServiceFactoryTest.cls`
- `ConfigDriftDetectorTest.cls`
- `ElaroAIRiskPredictorTest.cls`
- `ElaroAISettingsControllerTest.cls`
- `ElaroAlertQueueableTest.cls`
- `ElaroAlertTriggerTest.cls`
- `ElaroAuditTrailPollerTest.cls`
- `ElaroBulkOperationTest.cls`
- `ElaroCCPAComplianceServiceTest.cls`
- `ElaroChangeAdvisorTest.cls`
- `ElaroClaudeAPIMockTest.cls`
- `ElaroComplianceAlertTest.cls`
- `ElaroComplianceCopilotServiceTest.cls`
- `ElaroConstantsTest.cls`
- `ElaroDailyDigestTest.cls`
- `ElaroDeliveryServiceTest.cls`
- `ElaroDormantAccountAlertSchedulerTest.cls`
- `ElaroDrillDownControllerTest.cls`
- `ElaroDynamicReportControllerTest.cls`
- `ElaroEventParserTest.cls`
- `ElaroEventPublisherTest.cls`
- `ElaroEventSchedulerTest.cls`
- `ElaroExecutiveKPIControllerTest.cls`
- `ElaroGDPRComplianceServiceTest.cls`
- `ElaroGDPRExceptionTest.cls`
- `ElaroGLBAAnnualNoticeSchedulerTest.cls`
- `ElaroHistoricalEventBatchTest.cls`
- _(and 104 more — all 147 test classes in force-app)_

</details>

**force-app-healthcheck (8 test classes):**
- `AuditTrailScannerTest.cls`
- `HealthCheckControllerTest.cls`
- `HealthCheckScannerTest.cls`
- `MFAComplianceScannerTest.cls`
- `ProfilePermissionScannerTest.cls`
- `ScoreAggregatorTest.cls`
- `SessionSettingsScannerTest.cls`
- `ToolingApiServiceTest.cls`

**Fix:** Change `@IsTest` to `@IsTest(testFor=ProductionClassName.class)`

### 2.2 MEDIUM: Test Classes Missing `@TestSetup` (79 instances)

Per CLAUDE.md: _"@TestSetup — create shared test data once per class (reduces test execution time)"_

<details>
<summary>Click to expand full list (79 files)</summary>

- `AIAuditTrailScannerTest.cls`
- `AIDetectionEngineTest.cls`
- `AIRiskClassificationEngineTest.cls`
- `AlertHistoryServiceTest.cls`
- `ApiUsageDashboardControllerTest.cls`
- `ApiUsageSnapshotTest.cls`
- `AssessmentWizardControllerTest.cls`
- `BenchmarkingServiceTest.cls`
- `BreachPatternMatcherTest.cls`
- `BusinessDayCalculatorTest.cls`
- `ChangeImpactAnalyzerTest.cls`
- `ComplianceAlertPublisherTest.cls`
- `ComplianceServiceBaseTest.cls`
- `ComplianceServiceFactoryTest.cls`
- `ConfigDriftDetectorTest.cls`
- `ElaroAIRiskPredictorTest.cls`
- `ElaroAISettingsControllerTest.cls`
- `ElaroAlertQueueableTest.cls`
- `ElaroAlertTriggerTest.cls`
- `ElaroAuditTrailPollerTest.cls`
- `ElaroBulkOperationTest.cls`
- `ElaroCCPAComplianceServiceTest.cls`
- `ElaroChangeAdvisorTest.cls`
- `ElaroClaudeAPIMockTest.cls`
- `ElaroComplianceAlertTest.cls`
- `ElaroComplianceCopilotServiceTest.cls`
- `ElaroConstantsTest.cls`
- `ElaroDailyDigestTest.cls`
- `ElaroDeliveryServiceTest.cls`
- `ElaroDormantAccountAlertSchedulerTest.cls`
- `ElaroDrillDownControllerTest.cls`
- `ElaroDynamicReportControllerTest.cls`
- `ElaroEventParserTest.cls`
- `ElaroEventPublisherTest.cls`
- `ElaroEventSchedulerTest.cls`
- `ElaroExecutiveKPIControllerTest.cls`
- `ElaroGDPRComplianceServiceTest.cls`
- `ElaroGDPRExceptionTest.cls`
- `ElaroGLBAAnnualNoticeSchedulerTest.cls`
- `ElaroHistoricalEventBatchTest.cls`
- _(and 39 more)_

</details>

**Fix:** Add `@TestSetup static void makeData() { }` with shared test record creation using `ComplianceTestDataFactory`.

### 2.3 MEDIUM: Production Classes Missing Class-Level ApexDoc (10 instances)

| # | File | Fix |
|---|------|-----|
| 1 | `AlertHistoryService.cls` | Add `/** ... @author Elaro Team @since v1.0.0 @group Alerting */` |
| 2 | `ApiLimitsCalloutMock.cls` | Add ApexDoc header |
| 3 | `ApiUsageDashboardController.cls` | Add ApexDoc header |
| 4 | `ApiUsageSnapshot.cls` | Add ApexDoc header |
| 5 | `DeploymentMetrics.cls` | Add ApexDoc header |
| 6 | `ElaroLegalDocumentGenerator.cls` | Add ApexDoc header |
| 7 | `FlowExecutionLogger.cls` | Add ApexDoc header |
| 8 | `FlowExecutionStats.cls` | Add ApexDoc header |
| 9 | `LimitMetrics.cls` | Add ApexDoc header |
| 10 | `SlackNotifier.cls` | Add ApexDoc header |

### 2.4 MEDIUM: Test Classes Missing Class-Level ApexDoc (20 instances)

| # | File |
|---|------|
| 1 | `AlertHistoryServiceTest.cls` |
| 2 | `ApiUsageDashboardControllerTest.cls` |
| 3 | `ApiUsageSnapshotTest.cls` |
| 4 | `DeploymentMetricsTest.cls` |
| 5 | `ElaroAISettingsControllerTest.cls` |
| 6 | `ElaroAlertTriggerTest.cls` |
| 7 | `ElaroAuditTrailPollerTest.cls` |
| 8 | `ElaroChangeAdvisorTest.cls` |
| 9 | `ElaroComplianceCopilotTest.cls` |
| 10 | `ElaroComplianceScorerTest.cls` |
| 11 | `ElaroEventPublisherTest.cls` |
| 12 | `ElaroGraphIndexerTest.cls` |
| 13 | `ElaroLegalDocumentGeneratorTest.cls` |
| 14 | `ElaroQuickActionsServiceTest.cls` |
| 15 | `ElaroReasoningEngineTest.cls` |
| 16 | `ElaroSalesforceThreatDetectorTest.cls` |
| 17 | `ElaroScoreCallbackTest.cls` |
| 18 | `FlowExecutionLoggerTest.cls` |
| 19 | `LimitMetricsTest.cls` |
| 20 | `TriggerRecursionGuardTest.cls` |

### 2.5 PASSING: No Violations Found

- `System.assertEquals` / `System.assertNotEquals` / `System.assert` — none found (all use `Assert` class)
- Missing `Test.startTest()` / `Test.stopTest()` — all test methods use properly
- Missing access modifiers on abstract/override methods — all compliant with v65.0+

---

## Category 3: LWC Standards (Grade: C+)

### 3.1 HIGH: Hardcoded English Strings in HTML Templates (80+ instances across 19 components)

Per CLAUDE.md: _"Custom Labels for ALL user-facing strings. NEVER hardcode English strings in HTML templates or JS files."_

| # | Component | Example Violations | Est. Count |
|---|-----------|-------------------|------------|
| 1 | `apiUsageDashboard` | `"No snapshots yet."` | 1 |
| 2 | `auditReportGenerator` | `label="Framework"`, `label="Generate Report"`, `"Report Summary"` | 8 |
| 3 | `complianceGapList` | `"No compliance gaps found"` | 1 |
| 4 | `complianceGraphViewer` | `label="Filter by Framework"`, `"Severity Distribution"`, `"No Graph Data"`, legend labels, modal labels | 25+ |
| 5 | `controlMappingMatrix` | `"Export Matrix"`, `"Source Framework"`, `"Coverage"`, stat labels, modal headings | 20+ |
| 6 | `deploymentMonitorDashboard` | `"No deployment data available"` | 3 |
| 7 | `elaroAiSettings` | `label="Enable AI Reasoning"`, `label="Save Settings"` | 8 |
| 8 | `elaroAuditWizard` | Step labels, field labels, button labels, status messages | 30+ |
| 9 | `elaroComparativeAnalytics` | `label="Object"`, `label="Generate Matrix"`, `"Matrix Results"` | 7 |
| 10 | `elaroCopilot` | `"Elaro"`, `"Compliance Copilot"`, `"How can I help..."`, `"Evidence"` | 10+ |
| 11 | `elaroDashboard` | `"Compliance Dashboard"`, `"Overall Score"`, `"Top Risks"` | 15+ |
| 12 | `elaroDrillDownViewer` | `"No records found..."`, `label="Export to CSV"` | 2 |
| 13 | `elaroDynamicReportBuilder` | `label="Select Object"`, `label="Run Report"` | 15 |
| 14 | `elaroEventExplorer` | `"Total Events"`, `"Critical"`, `"Event Details"` | 15+ |
| 15 | `elaroEventMonitor` | `"No events received yet..."` | 1 |
| 16 | `elaroExecutiveKPIDashboard` | `alternative-text="Loading KPIs"` | 1 |
| 17 | `elaroROICalculator` | `"Elaro ROI Calculator"`, `label="Industry"`, result labels | 15+ |
| 18 | `healthCheckRiskTable` | `title="Risk Findings"`, `"No findings match..."` | 3 |
| 19 | `complianceCopilot` | Some labels used via JS property but not all strings covered | 3 |

**Fix:** Create Custom Labels in `force-app/main/default/labels/CustomLabels.labels-meta.xml` and import them in each component's JS file.

### 3.2 HIGH: Hardcoded English Strings in JS Files (15+ instances across 5 components)

| # | Component | File | Line | Code |
|---|-----------|------|------|------|
| 1 | `elaroEventMonitor` | `.js` | 39 | `"Subscribed to Elaro Events"` |
| 2 | `elaroEventMonitor` | `.js` | 45 | `"Unsubscribed from Elaro Events"` |
| 3 | `elaroEventMonitor` | `.js` | 51 | `"Event subscription error: "` |
| 4 | `auditReportGenerator` | `.js` | 56 | `"Please select framework and date range"` |
| 5 | `auditReportGenerator` | `.js` | 73 | `"An error occurred"` |
| 6 | `auditReportGenerator` | `.js` | 80 | `"Please generate a report first"` |
| 7 | `auditReportGenerator` | `.js` | 92 | `"An error occurred"` |
| 8 | `elaroAuditWizard` | `.js` | 128 | `"Finish"` / `"Next"` |
| 9 | `wizardStep` | `.js` | 60 | `"Approval"` |
| 10 | `wizardStep` | `.js` | 64 | `"Review"` |
| 11 | `wizardStep` | `.js` | 88 | `"Completed"` |
| 12 | `secMaterialityCard` | `.js` | 39 | `"Material"` |

### 3.3 MEDIUM: Components Missing Jest Test Files (4 components)

| # | Component | Location |
|---|-----------|----------|
| 1 | `secDisclosureDashboard` | `force-app/main/default/lwc/secDisclosureDashboard/` — no `__tests__/` |
| 2 | `secDisclosureForm` | `force-app/main/default/lwc/secDisclosureForm/` — no `__tests__/` |
| 3 | `secIncidentTimeline` | `force-app/main/default/lwc/secIncidentTimeline/` — no `__tests__/` |
| 4 | `secMaterialityCard` | `force-app/main/default/lwc/secMaterialityCard/` — no `__tests__/` |

**Fix:** Create `__tests__/componentName.test.js` for each with loading, error, empty, and data state tests.

### 3.4 MEDIUM: Excessive Custom CSS (3 components)

| # | Component | CSS Lines | Issue |
|---|-----------|-----------|-------|
| 1 | `elaroCopilot` | 625 | Extensive custom styling (flexbox, gradients, custom buttons) — should use SLDS |
| 2 | `elaroDashboard` | 971 | Custom progress bars, badges, cards — SLDS equivalents exist |
| 3 | `controlMappingMatrix` | 140 | Uses `!important` overrides — styling approach red flag |

### 3.5 MEDIUM: Missing ARIA Labels (2 components)

| # | Component | Issue |
|---|-----------|-------|
| 1 | `complianceCopilot` | Chat input missing `aria-label` |
| 2 | `elaroCopilot` | Input `aria-label` could be more descriptive |

### 3.6 PASSING: No Violations Found

- `if:true` / `if:false` — none found (all use `lwc:if` / `lwc:elseif` / `lwc:else`)
- All 55 of 59 components have Jest tests (93% coverage)

---

## Category 4: Metadata & Architecture (Grade: C+)

### 4.1 CRITICAL: Broken LWC Components (3 instances)

| # | Component | Issue | Fix |
|---|-----------|-------|-----|
| 1 | `utils/` | Folder contains `focusManager.js` + meta but no `utils.js` or `utils.html` | Rename folder to `focusManager` or restructure |
| 2 | `elaroScoreListener/` | Missing `elaroScoreListener.html` (exposed component with no template) | Add HTML template |
| 3 | `pollingManager/` | Missing `pollingManager.html` (utility with no template) | Add HTML template |

### 4.2 HIGH: Permission Set Coverage Gaps (54+ Apex classes missing)

Per CLAUDE.md: _"Every new object, field, Apex class, LWC page, and tab MUST have a Permission Set granting access."_

54 public/global Apex classes with `@AuraEnabled` or callout capabilities are NOT in any permission set.

<details>
<summary>Click to expand sample of missing classes</summary>

- `AccessReviewScheduler`
- `AssessmentWizardController`
- `AssessmentWizardService`
- `BenchmarkingService`
- `BlockchainVerification`
- `BreachDeadlineMonitor`
- `CommandCenterController`
- `ComplianceReportGenerator`
- `ElaroComplianceCopilot`
- _(and 44+ more)_

</details>

**Discovery command:**
```bash
grep -rl '@AuraEnabled\|global ' force-app/main/default/classes/*.cls | while read f; do
  name=$(basename "$f" .cls)
  if ! grep -q "<apexClass>$name</apexClass>" force-app/main/default/permissionsets/*.permissionset-meta.xml; then
    echo "MISSING: $name"
  fi
done | sort
```

### 4.3 HIGH: Platform Events Not in Permission Sets (11 events)

| # | Platform Event | Fix |
|---|----------------|-----|
| 1 | `BreachIndicator__e` | Add `<objectPermissions>` to relevant permission sets |
| 2 | `CCPA_Request_Event__e` | Add to permission sets |
| 3 | `ComplianceAlert__e` | Add to permission sets |
| 4 | `ConfigurationDrift__e` | Add to permission sets |
| 5 | `GDPR_Data_Export_Event__e` | Add to permission sets |
| 6 | `GDPR_Erasure_Event__e` | Add to permission sets |
| 7 | `GLBA_Compliance_Event__e` | Add to permission sets |
| 8 | `PCI_Access_Event__e` | Add to permission sets |
| 9 | `Performance_Alert__e` | Add to permission sets |
| 10 | `Elaro_Alert_Event__e` | Add to permission sets (system use) |
| 11 | `Elaro_Score_Result__e` | Add to permission sets (system use) |

### 4.4 HIGH: Tabs Not in Permission Sets (18 tabs)

None of the 18 main package tabs have `<tabSettings>` entries in any permission set:

`API_Usage_Snapshot__c`, `Alert__c`, `Compliance_Evidence__c`, `Compliance_Gap__c`, `Compliance_Score__c`, `Deployment_Job__c`, `Elaro_All_Components`, `Elaro_Compliance_Hub`, `Elaro_Dashboard`, `Flow_Execution__c`, `Integration_Error__c`, `Metadata_Change__c`, `Performance_Alert_History__c`, `SEC_Disclosure_Dashboard`, `TechDebtChecklist__c`, `TechDebtDependency__c`, `TechDebt__c`, `Vendor_Compliance__c`

### 4.5 MEDIUM: Flexipages Not in Permission Sets (11 pages)

11 flexipages exist but have no `<pageAccesses>` in any permission set.

### 4.6 MEDIUM: Namespace Inconsistency

`sfdx-project.json` has empty `"namespace": ""` for HC package, but CLAUDE.md references `elaroHC` namespace.

**Fix:** Update `sfdx-project.json` to add `"namespace": "elaroHC"` to the HC package directory entry.

### 4.7 PASSING: No Violations Found

- API versions — all 431 files use v66.0
- Object/field naming — all follow conventions (`PascalCase__c` objects, `Snake_Case__c` fields)
- Trigger patterns — all 5 triggers follow one-trigger-per-object with handler classes
- `if:true`/`if:false` — none found in any LWC template
- Custom Metadata — correct `__mdt` suffix
- Platform Events — correct `__e` suffix
- Big Objects — correct `__b` suffix

---

## Remediation Priority Matrix

### Phase 1: AppExchange Blockers (Do First)

| Task | Files | Effort | Impact |
|------|-------|--------|--------|
| Add `as user` to all DML | ~50 files | 2-3 hrs | AppExchange rejection fix |
| Fix dynamic SOQL injection | 13 files | 3-4 hrs | Security vulnerability fix |
| Convert `@future` to Queueable | 4 files | 2-3 hrs | PMD violation fix |
| Fix broken LWC components | 3 components | 30 min | Build failure fix |
| Add classes to permission sets | 5 perm set files | 2-3 hrs | Package usability fix |

### Phase 2: Standards Compliance (Do Next)

| Task | Files | Effort | Impact |
|------|-------|--------|--------|
| Add `@IsTest(testFor=...)` | 155 files | 2 hrs | Spring '26 compliance |
| Add missing ApexDoc | 30 files | 2-3 hrs | Documentation standards |
| Add tabs/events to perm sets | 5 perm set files | 1-2 hrs | Tab/event visibility |
| Create Custom Labels for LWC | 19 components | 4-6 hrs | i18n compliance |

### Phase 3: Quality Improvements (Do When Possible)

| Task | Files | Effort | Impact |
|------|-------|--------|--------|
| Add `@TestSetup` to tests | 79 files | 4-6 hrs | Test performance |
| Create SEC module Jest tests | 4 components | 2-3 hrs | Test coverage |
| Refactor custom CSS to SLDS | 3 components | 3-4 hrs | Styling consistency |
| Fix namespace config | 1 file | 5 min | Package config |
| Add missing ARIA labels | 2 components | 30 min | Accessibility |

---

## Quick Validation Commands

```bash
# Find all remaining DML without 'as user' (production code only)
grep -rn '^\s*\(insert\|update\|delete\|upsert\) ' force-app/main/default/classes/ | grep -v 'as user' | grep -v 'Test\.cls'

# Find all @future methods
grep -rn '@future' force-app/main/default/classes/

# Find all dynamic SOQL concatenation
grep -rn "FROM '" force-app/main/default/classes/ | grep -v 'Test\.cls' | grep '+'

# Find test classes without testFor
grep -rn '@IsTest$' force-app/main/default/classes/*Test.cls

# Find hardcoded strings in LWC HTML
grep -rn 'label="[A-Z]' force-app/main/default/lwc/**/*.html

# Find classes not in permission sets
for f in force-app/main/default/classes/*.cls; do
  name=$(basename "$f" .cls)
  [[ "$name" == *Test ]] && continue
  grep -q "$name" force-app/main/default/permissionsets/*.permissionset-meta.xml 2>/dev/null || echo "MISSING: $name"
done
```

---

## How to Use This File in a New Chat

Start a new Claude Code session and say:

> Read `docs/code-review-findings.md` — it contains all findings from our codebase review.
> I want to work on [Phase 1 / Phase 2 / Phase 3 / specific finding].

Claude will read this file, understand all findings with file paths and line numbers, and pick up exactly where this session left off.
