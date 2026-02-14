# Elaro Remediation Plan v3 — Autonomous Execution

**Date:** February 14, 2026
**Current Score:** 69/100 (F — auto-fail on CRUD/FLS)
**Target Score:** 93+ (A)
**Execution Mode:** Fully autonomous. No human checkpoints. Self-verifying.
**Branch:** `claude/review-codebase-2b8T8`

---

## Execution Principle: Ratchet First

The original codebase had perfect standards in CLAUDE.md and zero enforcement. That's how 123 DML violations accumulated across 39 files while the docs said "ALWAYS use `as user`."

This plan does not repeat that mistake. Every wave follows the same order:

1. **Build the ratchet** — Write the script that detects the violation
2. **Run the ratchet** — Confirm it catches all known violations (validates the script works)
3. **Fix the violations** — Mechanical execution
4. **Run the ratchet again** — Confirm zero violations remain (validates the fixes work)
5. **Wire the ratchet into CI** — Prevent regression permanently
6. **Commit and push**

The ratchet is built BEFORE the fixes. If the ratchet can't detect the problem, the fixes can't be verified. If the fixes don't bring the count to zero, the wave isn't done.

---

## What I Will Do (and How I Will Verify It)

### Wave 1 — Security: 135 violations → 0

**What gets fixed:**
- 123 DML statements missing `as user` (39 files)
- 10 SOQL queries missing `WITH USER_MODE` (7 files)
- 1 SOQL injection surface — ElaroMatrixController `Database.query()` → `Database.queryWithBinds()` (2 methods)
- 1 @AuraEnabled without try-catch — ElaroAIRiskPredictor.predictRisk()
- Pre-commit hook not running tests

**Step 1 — Build `scripts/check-apex-security.sh`:**

The script checks for:
- `insert `, `update `, `delete `, `upsert ` without `as user` in non-test .cls files
- `Database.insert(`, `Database.update(`, `Database.delete(` without `AccessLevel.USER_MODE`
- `SELECT ... FROM` without `WITH USER_MODE` in non-test .cls files
- `Database.query(` in non-test production code (must use `queryWithBinds`)
- `@future` annotation
- Exits non-zero if any violations found

**Step 2 — Run the script, confirm it finds all 135 violations.**
If the count doesn't match, the script has a bug. Fix the script before touching any production code.

**Step 3 — Fix violations with parallel agents:**

| Agent | Files | Pattern |
|-------|-------|---------|
| Agent 1 (DML batch A-E) | AccessReviewScheduler thru ElaroInstallHandler (15 files) | `insert X;` → `insert as user X;` / `update X;` → `update as user X;` / `delete X;` → `delete as user X;` / `upsert X F;` → `upsert as user X F;` |
| Agent 2 (DML batch E-Z) | ElaroLegalDocumentGenerator thru SlackNotifier (24 files) | Same mechanical pattern. `Database.insert(X, false)` → `Database.insert(X, false, AccessLevel.USER_MODE)` |
| Agent 3 (SOQL + injection + try-catch) | BenchmarkingService, ComplianceGraphService, ElaroComplianceCopilotService, DataResidencyService, MultiOrgManager, ElaroConsentWithdrawalHandler, ElaroRealtimeMonitor, RemediationOrchestrator, ElaroMatrixController, ElaroAIRiskPredictor (10 files) | Add `WITH USER_MODE` to 10 queries. Refactor ElaroMatrixController.queryDirect() and querySummary() to `Database.queryWithBinds()`. Wrap ElaroAIRiskPredictor.predictRisk() in try-catch with ElaroLogger.error + AuraHandledException. |

Each agent reads the file, makes the change, re-reads to verify. No agent guesses — every edit is verified against the file.

**Step 4 — Run the script again. Must return 0 violations.**
If any remain, fix them. Do not proceed until count = 0.

**Step 5 — Fix pre-commit hook.**
Change `.husky/pre-commit` from `npx lint-staged` to `npm run precommit`. This makes every future commit run: preflight + format check + lint + Jest tests.

**Step 6 — Wire script into CI.**
Add `check-apex-security.sh` as a hard-fail step in `.github/workflows/elaro-ci.yml` under the `code-quality` job. No `|| true`. No `|| echo`. Hard fail.

**Step 7 — Run `npm run precommit` to verify nothing is broken.**

**Step 8 — Commit and push.**

**Self-verification before moving to Wave 2:**
```bash
bash scripts/check-apex-security.sh    # Must exit 0
npm run precommit                      # Must pass
```
Both must pass. If either fails, debug and fix before proceeding.

---

### Wave 2 — Architecture + Maintainability: 7 violations → 0

**What gets fixed:**
- 2 triggers with inline business logic (PerformanceAlertEventTrigger, ElaroAlertTrigger)
- 1 stale constant (ElaroConstants.SALESFORCE_API_VERSION = '64.0')
- 1 constant duplication (ComplianceServiceFactory duplicates ElaroConstants)
- 2 copy-paste controllers (EscalationPathController, OnCallScheduleController) — both lack try-catch

**Step 1 — No new ratchet script needed.** Wave 1's `check-apex-security.sh` already covers @AuraEnabled try-catch. Trigger delegation is verified by inspection (triggers must be <20 lines of logic — delegation + guard only).

**Step 2 — Fix with parallel agents:**

| Agent | Scope | Deliverable |
|-------|-------|-------------|
| Agent 1 | PerformanceAlertEventTrigger | Create `PerformanceAlertHandler.cls` (`with sharing`, `insert as user`, full ApexDoc). Move Performance_Alert_History__c creation from trigger to handler. Trigger becomes: guard check → `PerformanceAlertHandler.handleAlerts(Trigger.new)` → guard reset. Create `PerformanceAlertHandlerTest.cls` with `@IsTest(testFor=PerformanceAlertHandler.class)`. |
| Agent 2 | ElaroAlertTrigger | Create `ElaroAlertPublisher.cls` (`inherited sharing`, full ApexDoc). Move EventBus.publish() from trigger to publisher. Trigger becomes: guard check → `ElaroAlertPublisher.publishAlerts(Trigger.new)` → guard reset. Create `ElaroAlertPublisherTest.cls`. |
| Agent 3 | ElaroConstants + ComplianceServiceFactory | Fix `SALESFORCE_API_VERSION` to `'66.0'`. In ComplianceServiceFactory, replace all duplicated framework string literals with references to ElaroConstants. |
| Agent 4 | EscalationPathController + OnCallScheduleController | Add try-catch with ElaroLogger.error + AuraHandledException to every @AuraEnabled method in both controllers. Extract shared CRUD logic to reduce duplication. Ensure all DML uses `as user` (should already be fixed in Wave 1 — verify). |

**Step 3 — Verify:**
- Read each trigger file — must be <20 lines, no DML, no EventBus.publish, only delegation
- Read ElaroConstants — version must be '66.0'
- Read ComplianceServiceFactory — zero duplicated framework strings
- `bash scripts/check-apex-security.sh` — must still exit 0
- `npm run precommit` — must pass

**Step 4 — Commit and push.**

---

### Wave 3 — Governor Limits + Async: 4 violations → 0

**What gets fixed:**
- 1 `@future(callout=true)` in JiraIntegrationService
- 0 Transaction Finalizers → add 3
- 0 AsyncOptions with DuplicateSignature → add 2
- 1 synchronous Schedulable (ComplianceReportScheduler)

**Step 1 — Add `@future` check to `check-apex-security.sh`.** Grep for `@future` in non-test .cls files. Run it — must find exactly 1 violation (JiraIntegrationService).

**Step 2 — Fix with parallel agents:**

| Agent | Scope | Deliverable |
|-------|-------|-------------|
| Agent 1 | JiraIntegrationService @future → Queueable | Create `JiraCalloutQueueable.cls` (`inherited sharing`, implements `Queueable, Database.AllowsCallouts`). Move callout logic from @future method. Remove @future method. Update all callers (JiraIntegrationService.cls, any class that calls the old method). Add `JiraCalloutQueueableTest.cls`. |
| Agent 2 | Transaction Finalizers | Create `BreachDeadlineMonitorFinalizer.cls`, `ComplianceSnapshotFinalizer.cls`, `AccessReviewFinalizer.cls` — each implements `Finalizer`. Pattern: check `ParentJobResult.UNHANDLED_EXCEPTION` → `ElaroLogger.error()` → optionally re-enqueue with backoff. Register finalizers in corresponding Queueable execute() methods via `System.attachFinalizer()`. |
| Agent 3 | AsyncOptions + ComplianceReportScheduler | Add `AsyncOptions` with `QueueableDuplicateSignature` (using record IDs) and `setMaximumQueueableStackDepth(5)` to BreachDeadlineMonitor and AccessReviewScheduler enqueue calls. Refactor ComplianceReportScheduler.execute() to enqueue a new `ComplianceReportQueueable.cls` instead of running synchronously. |

**Step 3 — Verify:**
```bash
bash scripts/check-apex-security.sh    # Must exit 0 (includes @future check)
npm run precommit                      # Must pass
```
- Grep `@future` — must return 0 results
- Read each Finalizer class — must implement Finalizer interface, use ElaroLogger
- Read BreachDeadlineMonitor + AccessReviewScheduler — must use AsyncOptions

**Step 4 — Commit and push.**

---

### Wave 4 — LWC Compliance: ~240 violations → 0

This is the largest wave. ~200 hardcoded strings across 34 components, 13 components missing states, 8 WCAG violations, 18 missing tab grants.

**What gets fixed:**
- ~200 hardcoded English strings across 34 LWC components → Custom Labels
- 13 components missing loading/error/empty states
- 8 components with WCAG accessibility violations
- 18 tabs missing from Elaro_Admin and Elaro_User permission sets
- ~55 Apex classes missing from permission sets (audit and add where needed)

**Step 1 — Build `scripts/check-lwc-compliance.sh`:**
- Detect non-expression text content in LWC HTML files (text outside `{...}` that isn't whitespace or SLDS class names)
- Detect `if:true` / `if:false` patterns
- Report violations with file:line

Run it — must find violations in all 34 known components.

**Step 2 — Build `scripts/check-permissionsets.sh`:**
- Count tabs in `force-app/main/default/tabs/`
- Count tabSettings in Elaro_Admin and Elaro_User permission sets
- Fail if any tab is missing from either permission set

Run it — must fail (18 tabs missing).

**Step 3 — Fix with parallel agents:**

| Agent | Scope | Components |
|-------|-------|------------|
| Agent 1 | Labels batch 1 | auditReportGenerator, complianceDashboard, complianceGapList, complianceScoreCard, complianceTrendChart, complianceTimeline, controlMappingMatrix, deploymentMonitorDashboard. For each: create Custom Labels in CustomLabels.labels-meta.xml (naming: `[MODULE]_[Description]`, `<protected>true</protected>`), import in JS, replace HTML text with `{label.X}`. Update Jest mocks for new label imports. |
| Agent 2 | Labels batch 2 | elaroAiSettings, elaroAuditPackageBuilder, elaroAuditWizard, elaroComparativeAnalytics, elaroDashboard, elaroDrillDownViewer, elaroDynamicReportBuilder. Same pattern. |
| Agent 3 | Labels batch 3 | elaroEventExplorer, elaroEventMonitor, elaroExecutiveKPIDashboard, elaroROICalculator, elaroReadinessScore, elaroTrendAnalyzer, escalationPathConfig, executiveKpiDashboard. Same pattern. |
| Agent 4 | Labels batch 4 | flowExecutionMonitor, frameworkSelector, jiraCreateModal, jiraIssueCard, onCallScheduleManager, performanceAlertPanel, remediationSuggestionCard, reportSchedulerConfig, riskHeatmap, secDisclosureForm, systemMonitorDashboard. Same pattern. |
| Agent 5 | State handling + WCAG | Add loading (lightning-spinner), error (role="alert" div with {errorMessage}), empty (slds-illustration) states to: apiUsageDashboard, assessmentProgressTracker, crossFrameworkPrefill, elaroExecutiveKPIDashboard, elaroROICalculator, riskHeatmap, secDisclosureForm, secIncidentTimeline. Add aria-labels to icon-only buttons in: complianceCopilot, elaroCopilot, elaroDashboard, elaroROICalculator, complianceGraphViewer, healthCheckDashboard. Skip sub-components that receive data via @api (healthCheckCtaBanner, healthCheckMfaIndicator, healthCheckScoreGauge, secMaterialityCard — these are presentational). |
| Agent 6 | Permission sets | Add all 18 tabSettings (visibility: Visible) to both Elaro_Admin.permissionset-meta.xml and Elaro_User.permissionset-meta.xml. Audit 55 missing Apex classes — for each, check if it's called from an @AuraEnabled controller. If yes, add to permission set. If it's an internal utility only called by other granted classes, skip (Salesforce doesn't require permission set grants for classes called server-side only). |

**Important for label agents:** All 4 label agents write to the same `CustomLabels.labels-meta.xml` file. Run them sequentially OR have each agent write to a separate temp file, then merge. Merging is safer — prevents edit conflicts.

**Step 4 — Verify:**
```bash
bash scripts/check-lwc-compliance.sh   # Must exit 0
bash scripts/check-permissionsets.sh   # Must exit 0
bash scripts/check-apex-security.sh    # Must still exit 0
npm run precommit                      # Must pass (Jest tests pass with new label mocks)
```

**Step 5 — Wire both scripts into CI as hard-fail steps. Commit and push.**

---

### Wave 5 — Test Quality + Documentation + CI Hardening: final push to 93+

**What gets fixed:**
- 0 → all test classes get `@IsTest(testFor=...)`
- 0 → 8+ test classes get `System.runAs()`
- 0 → all test classes adopt ComplianceTestDataFactory
- ~15 shallow test classes get additional test methods
- All production classes get `@author`, `@since`, `@group` ApexDoc tags
- All public controller methods get `@example` tag
- 7 CI soft-fail points → 0
- jest-axe wired into CI

**Step 1 — Build `scripts/check-apexdoc.sh`:**
- For every non-test .cls file, verify the class-level ApexDoc block contains `@author`, `@since`, `@group`
- Report missing tags with file:line

Run it — will find violations on most classes.

**Step 2 — Fix with parallel agents:**

| Agent | Scope | Deliverable |
|-------|-------|-------------|
| Agent 1 | @IsTest(testFor) annotations | Read every *Test.cls file. Identify the production class it tests (by name convention or by reading the test). Add `@IsTest(testFor=ProductionClass.class)` to the class declaration. Mechanical — do not change test logic. |
| Agent 2 | System.runAs() permission tests | For 8 controller test classes (CommandCenterControllerTest, HealthCheckControllerTest, ElaroQuickActionsServiceTest, RemediationOrchestratorTest, EscalationPathControllerTest, OnCallScheduleControllerTest, AuditReportControllerTest, ElaroMatrixControllerTest): add 1 positive test (create user, assign Elaro_Admin permission set, runAs, call @AuraEnabled method, assert success) and 1 negative test (create user, no permission set, runAs, call method, assert AuraHandledException). |
| Agent 3 | ComplianceTestDataFactory + @TestSetup | Audit ComplianceTestDataFactory — add factory methods for any test data patterns used inline across test classes. Update test classes to use factory instead of inline creation. Add @TestSetup to classes that don't have it. |
| Agent 4 | Negative + bulk tests | For each controller test class: add at least 1 negative test (null input, invalid ID, missing required field → assert AuraHandledException). For each trigger handler test class: add 1 bulk test inserting 200 records, verify handler processes all without governor limit exception. |
| Agent 5 | ApexDoc completion | Add to every production class: `@author Elaro Team`, `@since v3.1.0 (Spring '26)`, `@group [Module]`. Module mapping: Core Infrastructure (ElaroLogger, ElaroSecurityUtils, ElaroConstants, ComplianceServiceFactory, ComplianceServiceBase, TriggerRecursionGuard), Command Center (CommandCenter*), Event Monitoring (Elaro*Event*, ElaroRealtimeMonitor), Assessment (Assessment*, Wizard*), SEC (SEC*), AI Governance (ElaroAI*, ElaroReasoning*), Integration (Jira*, Slack*, MultiOrg*), Health Check (HealthCheck*, Scanner*, HCLogger). Add `@example` to all public @AuraEnabled methods. Add SECURITY justification comment to all `without sharing` classes that lack one. |
| Agent 6 | CI pipeline hardening | In `.github/workflows/elaro-ci.yml`: (1) Remove `\|\| echo` from format check and lint check steps. (2) Remove `\|\| true` from all Code Analyzer steps. (3) Remove `continue-on-error: true` from SARIF upload. (4) Change Code Analyzer to `--severity-threshold 1`. (5) Add `check-apexdoc.sh` step to code-quality job. (6) Add `npm run test:a11y` step to unit-tests job. (7) Verify all Wave 1-4 ratchet scripts are present as hard-fail steps. |

**Step 3 — Verify:**
```bash
bash scripts/check-apexdoc.sh          # Must exit 0
bash scripts/check-apex-security.sh    # Must exit 0
bash scripts/check-lwc-compliance.sh   # Must exit 0
bash scripts/check-permissionsets.sh   # Must exit 0
npm run precommit                      # Must pass
```

Read CI workflow — confirm zero `|| true`, zero `|| echo`, zero `continue-on-error: true` on quality gate steps.

**Step 4 — Commit and push. This is the final commit.**

---

## Self-Enforcement Rules

These rules govern my execution. They exist because the original codebase proved that unenforced rules are ignored.

**Rule 1: Never skip verification.** Every wave ends with running all ratchet scripts. If any script fails, the wave is not done. Debug and fix before proceeding. Do not batch-skip verification across waves.

**Rule 2: Ratchet before fix.** Build the detection script first. Run it to confirm it catches known violations. If the script doesn't catch the violation, the script is wrong — fix the script. Only then fix the code.

**Rule 3: Never soft-fail.** No `|| true`. No `|| echo`. No `continue-on-error`. If a check runs, it blocks on failure. If it shouldn't block, it shouldn't run.

**Rule 4: Every new file gets full treatment.** Any new .cls file (handlers, publishers, Queueables, Finalizers, tests) must have: sharing keyword, API v66.0, ApexDoc with @author/@since/@group, `as user` on all DML, `WITH USER_MODE` on all SOQL. Verify against `check-apex-security.sh` and `check-apexdoc.sh` before committing.

**Rule 5: Every agent prompt is self-contained.** When spawning sub-agents, include: the exact files to modify, the exact pattern to apply, the verification command to run after. Do not assume agents know the project standards — embed the rules in the prompt.

**Rule 6: Commit per wave, not per file.** Each wave is one atomic commit. All fixes in the wave pass all ratchets before the commit is created. This keeps git history clean and makes rollback simple.

**Rule 7: Read before edit.** Every file is read completely before any edit is made. No blind find-replace across the codebase. Each edit is verified by re-reading the file after the change.

---

## Post-Execution Verification

After all 5 waves are complete, run the full suite:

```bash
# All ratchets
bash scripts/check-apex-security.sh
bash scripts/check-lwc-compliance.sh
bash scripts/check-permissionsets.sh
bash scripts/check-apexdoc.sh

# Pre-commit (fmt + lint + jest)
npm run precommit

# Accessibility
npm run test:a11y

# Final grep checks
grep -rn '@future' force-app/ --include='*.cls'                    # 0 results
grep -rn 'WITH SECURITY_ENFORCED' force-app/ --include='*.cls'    # 0 results
grep -rn 'System\.assertEquals' force-app/ --include='*.cls'      # 0 results
grep -rn 'if:true\|if:false' force-app/ --include='*.html'        # 0 results
```

Every command must return 0 violations. If any fail, the plan is not complete.

---

## Score Progression

| Metric | Now | W1 | W2 | W3 | W4 | W5 |
|--------|-----|-----|-----|-----|-----|-----|
| DML violations | 123 | 0 | 0 | 0 | 0 | 0 |
| SOQL violations | 10 | 0 | 0 | 0 | 0 | 0 |
| Injection surfaces | 1 | 0 | 0 | 0 | 0 | 0 |
| @future methods | 1 | 1 | 1 | 0 | 0 | 0 |
| Hardcoded LWC strings | ~200 | ~200 | ~200 | ~200 | 0 | 0 |
| Missing tab grants | 18 | 18 | 18 | 18 | 0 | 0 |
| WCAG violations | 8 | 8 | 8 | 8 | 0 | 0 |
| CI soft-fails | 7 | 6 | 6 | 5 | 4 | 0 |
| Ratchets | 0 | 2 | 2 | 3 | 5 | 10 |
| **Score** | **69** | **80** | **84** | **86** | **91** | **95** |
| **Grade** | **F** | **B-** | **B** | **B** | **A-** | **A** |
