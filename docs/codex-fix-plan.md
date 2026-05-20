# Codex Fix Plan — Elaro Review rev-2026-0520-0328

> **Audience:** Codex (autonomous coding agent) executing remediation tasks from this review.
> **Source of truth:** `.review-state/{security,governor,test,architecture,appexchange}-findings.json` and `.review-state/final-report.md`.
> **Branch convention:** one feature branch per tier (e.g. `codex/fix-tier-1-correctness`). Open one draft PR per tier targeting `claude/review-elaro-architecture-FfI4h`, then re-base to `main` after grade re-runs.
> **Definition of done for every task:** local `npm run precommit` passes; relevant Apex tests run green; the file:line evidence in this plan no longer matches the issue pattern.

This plan is organized by **execution tier**. Tiers are ordered by dependency, not severity — Tier 0 unblocks packaging, Tier 1 contains the runtime-correctness gaps, Tier 2 closes coverage, Tier 3 collapses architectural debt, Tier 4 is AppExchange polish, Tier 5 is housekeeping. Inside each tier, tasks are independent and may be parallelized.

---

## Tier 0 — Release Blockers (DO FIRST)

> Without these, `sf package version create` cannot run. None of the other tiers matter for distribution until Tier 0 closes.

### T0.1 — Register `elaro` namespace in DevHub
- **Finding:** AX-001 (CRITICAL)
- **File:** `sfdx-project.json:9`
- **Action:** Manual step in DevHub (Setup → Packaging → Namespaces → Register). Then remove `_TODO_namespace` and `_TODO_HC_namespace` keys from `sfdx-project.json`.
- **Acceptance:** `sfdx-project.json` has no `_TODO_` markers; `sf org list metadata -m InstalledPackage -o devhub` shows `elaro`.
- **Codex note:** If DevHub access is unavailable, open an issue titled "Register elaro namespace in DevHub" and stop — do not attempt to forge a namespace.

### T0.2 — Add `elaroHC` namespace to Health Check packageDirectory
- **Finding:** AX-002 (CRITICAL)
- **File:** `sfdx-project.json`
- **Action:** Edit the `force-app-healthcheck` packageDirectory entry to include `"namespace": "elaroHC"`. Register `elaroHC` in DevHub.
- **Acceptance:**
  ```json
  {
    "path": "force-app-healthcheck",
    "package": "Elaro Health Check",
    "namespace": "elaroHC",
    "versionName": "Spring 26",
    "versionNumber": "1.0.0.NEXT"
  }
  ```
- **Verify:** `sf package version create -p "Elaro Health Check" --dry-run` succeeds (or fails on a *different* error).

### T0.3 — Replace `packageAliases` placeholder
- **Finding:** AX-007 (HIGH, AppExchange agent)
- **File:** `sfdx-project.json` → `packageAliases`
- **Action:** Replace `"0HoXXXXXXXXXXXX"` with the real Package ID from `sf package list`.
- **Acceptance:** No `XXXXXXXXXX` strings remain in `sfdx-project.json`.

---

## Tier 1 — Runtime Correctness (HIGH-impact, low-blast-radius fixes)

### T1.1 — Make ElaroLogger actually publish Platform Events
- **Finding:** GOV-2026-001 (HIGH), ARCH-008-carry-over
- **File:** `force-app/main/default/classes/ElaroLogger.cls:60`
- **Problem:** Class advertises Platform Event publication (CLAUDE.md, ApexDoc, Finalizer callers all rely on it) but the body is `System.debug(...)` only. `LogEvent__e` exists but is never published.
- **Action:**
  1. Add `LogEvent__e` construction with fields matching its schema (Category__c, Source__c, Message__c, Stack_Trace__c, Severity__c, Correlation_Id__c, Timestamp__c).
  2. Use `EventBus.publish` (Publish Immediately mode — `LogEvent__e` should already be configured for that; verify in object metadata).
  3. Keep `System.debug` as a development convenience but make it conditional on a debug flag or remove it.
  4. Add an in-class @TestVisible static `List<LogEvent__e>` buffer for test assertions.
- **Acceptance:**
  - `EventBus.publish(new LogEvent__e(...))` call exists in each of `info`, `warn`, `error`, `critical` methods.
  - `ElaroLoggerTest` asserts the buffer contains the expected event after each level.
  - `grep -rn "EventBus.publish" force-app/main/default/classes/ElaroLogger.cls` returns ≥1 hit.
- **Codex note:** If `LogEvent__e` is in the orphan-PE list (T3.4), confirm it is NOT deleted before doing this task — these two tasks conflict and T1.1 wins.

### T1.2 — Add `with sharing` to Health Check DTOs
- **Findings:** SEC-2026-001, SEC-2026-002, SEC-2026-003 (HIGH)
- **Files:**
  - `force-app-healthcheck/main/default/classes/HealthCheckResult.cls`
  - `force-app-healthcheck/main/default/classes/ScanFinding.cls`
  - `force-app-healthcheck/main/default/classes/ScanRecommendation.cls`
- **Action:** Change top-level class declaration from `public class X` to `public with sharing class X`. These are DTOs with `@AuraEnabled` fields — `with sharing` is correct because LWC binding paths flow through them and the AppExchange security review explicitly requires it on every public class.
- **Acceptance:** `grep -L "with sharing" force-app-healthcheck/main/default/classes/*.cls` excludes these three files (none should remain).

### T1.3 — Add sharing to test-data factories
- **Finding:** Auto-fail-gate caveat (HIGH)
- **Files:**
  - `force-app/main/default/classes/ElaroTestUserFactory.cls`
  - `force-app/main/default/classes/ComplianceTestDataFactory.cls`
  - `force-app/main/default/classes/ElaroTestDataFactory.cls`
- **Action:** Add `inherited sharing` (factories are called from test classes which set their own sharing). Do not add `with sharing` — test data setup must work for restricted-user `runAs` blocks too.
- **Acceptance:** All three start with `@IsTest` followed by `public inherited sharing class …`.

### T1.4 — CursorStep AccessLevel.USER_MODE on empty-binds path
- **Finding:** GOV-2026-002 (HIGH)
- **File:** `force-app/main/default/classes/CursorStep.cls:151`
- **Problem:** When the binds map is empty, code falls through to `Database.getCursor(query)` (no `AccessLevel.USER_MODE` overload), bypassing FLS/CRUD for every subclass without binds.
- **Action:**
  - Replace the no-binds branch with `Database.getCursorWithBinds(query, new Map<String, Object>(), AccessLevel.USER_MODE)`.
  - Or, if the overload doesn't exist on the platform, add an empty bindings sentinel and always go through the binds path.
- **Acceptance:**
  - `grep -n "Database.getCursor" force-app/main/default/classes/CursorStep.cls` shows no call without `AccessLevel`.
  - A new `CursorStepTest.testEmptyBindsHonorsUserMode` runs the empty-binds path under a restricted user and verifies an inaccessible field throws (or is stripped).

### T1.5 — HIPAA PHI audit silent-swallow
- **Finding:** SEC-2026-medium-cluster (MEDIUM but compliance-graded as HIGH-impact)
- **File:** `force-app/main/default/classes/HIPAAPrivacyRuleService.cls` → `auditPHIAccess(...)`
- **Problem:** Catch block silently swallows exceptions. Per 45 CFR 164.312(b), audit trail gaps are reportable.
- **Action:**
  1. Re-raise via `ElaroLogger.critical(...)` (after T1.1 lands, this becomes a durable PE).
  2. Set a `Compliance_Audit_Gap__e` Platform Event so dashboards surface the gap (or create one — check schema first).
  3. Do NOT throw to the caller (audit failures must not break user flows), but DO log and emit telemetry.
- **Acceptance:** Catch block contains both a logger call and a Platform Event publish; no bare `catch (Exception e) { }` remains.

### T1.6 — Sanitize controller error-message leakage
- **Files (Codex must verify each):**
  - `force-app/main/default/classes/BlockchainVerification.cls` (may be deleted in T3.3 — check first)
  - `force-app/main/default/classes/ServiceNowIntegration.cls` → `getIncidentStatus`
  - `force-app/main/default/classes/ComplianceReportGenerator.cls`
  - `force-app/main/default/classes/RootCauseAnalysisEngine.cls`
  - `force-app/main/default/classes/NaturalLanguageQueryService.cls`
- **Pattern to find:**
  ```apex
  } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());  // ❌ leaks stack/details
  }
  ```
- **Pattern to replace with:**
  ```apex
  } catch (Exception e) {
      ElaroLogger.error('ClassName.methodName', e.getMessage(), e.getStackTraceString());
      throw new AuraHandledException(System.Label.Error_Generic);  // ✓ stable user-facing label
  }
  ```
- **Acceptance:** `grep -rn "AuraHandledException(e\.getMessage" force-app/main/default/classes/` returns 0 hits.

---

## Tier 2 — Test Coverage

### T2.1–T2.3 — Create test classes for 3 uncovered queueable callout classes
- **Findings:** TEST-2026-002 / 003 / 004 (HIGH)
- **Files to create:**
  - `force-app/main/default/classes/ElaroDeliveryQueueableTest.cls` + meta.xml
  - `force-app/main/default/classes/MultiOrgManagerQueueableTest.cls` + meta.xml
  - `force-app/main/default/classes/SlackIntegrationQueueableTest.cls` + meta.xml
- **Template every test must follow:**
  ```apex
  @IsTest(testFor=ElaroDeliveryQueueable.class)
  private class ElaroDeliveryQueueableTest {
      private class DeliveryMock implements HttpCalloutMock {
          public HttpResponse respond(HttpRequest req) {
              HttpResponse res = new HttpResponse();
              res.setStatusCode(200);
              res.setBody('{"ok":true}');
              return res;
          }
      }

      @TestSetup
      static void setup() {
          // Use ComplianceTestDataFactory
      }

      @IsTest
      static void shouldDeliverPayloadSuccessfully() {
          Test.setMock(HttpCalloutMock.class, new DeliveryMock());
          Test.startTest();
          System.enqueueJob(new ElaroDeliveryQueueable(...));
          Test.stopTest();
          Assert.areEqual(1, [SELECT COUNT() FROM Delivery_Log__c], 'one log row expected');
      }

      @IsTest
      static void shouldRetryOnTransientFailure() { /* … */ }

      @IsTest
      static void shouldLogOnTerminalFailure() { /* … */ }
  }
  ```
- **Acceptance:** Each new test class has ≥3 methods (happy path, transient failure, terminal failure), uses `HttpCalloutMock`, asserts via `Assert` class, and lifts code coverage of the production class to ≥85%.

### T2.4 — Test for `ElaroEventCaptureTrigger`
- **Finding:** TEST-2026-005 (HIGH)
- **File to create:** `force-app/main/default/triggers/ElaroEventCaptureTriggerTest.cls` (Note: trigger tests live under `classes/`)
- **Coverage:** Publishing the underlying Platform Event, verifying the trigger handler runs once per event, recursion-guard reset between invocations.
- **Acceptance:** Test class with `EventBus.publish` setup; `Test.getEventBus().deliver()` to flush; assertions on handler side effects.

### T2.5 — Add `System.runAs()` to 21 controller tests
- **Finding:** TEST-2026-001 (HIGH)
- **Scope:** All 22 controller test classes except `ElaroAISettingsControllerTest`.
- **Pattern to add:**
  ```apex
  @IsTest
  static void shouldRespectSharingForReadOnlyUser() {
      User readOnlyUser = ElaroTestUserFactory.createReadOnlyUser();
      System.runAs(readOnlyUser) {
          Test.startTest();
          // call AuraEnabled methods that should be denied
          Assert.... ;
          Test.stopTest();
      }
  }
  ```
- **Acceptance:** Each controller test class has ≥1 `System.runAs` block exercising a non-System user; `grep -l "System.runAs" force-app/main/default/classes/*ControllerTest.cls | wc -l` ≥ 22.
- **Codex note:** This is the most repetitive task in the plan. May be parallelized 4-wide across controllers.

### T2.6 — Wire `HttpCalloutMock` into SlackNotifierTest
- **Finding:** TEST-2026-007 (re-raise of prior TEST-019)
- **File:** existing `SlackNotifierTest.cls`
- **Action:** Add a real `HttpCalloutMock` implementation; assertions on request body, headers, retry behavior. Stop asserting `caughtException == null`.

---

## Tier 3 — Architecture Consolidation (HIGH-impact, multi-file changes)

### T3.1 — Unify framework registries
- **Finding:** ARCH-2026-001 (HIGH)
- **Problem:** `IComplianceModule` and `IRiskScoringService` are two parallel abstractions with no shared lookup. `ComplianceServiceFactory.getSupportedFrameworks()` is hardcoded; `ComplianceFrameworkService.getSupportedFrameworks()` is metadata-driven; the two can disagree.
- **Action:**
  1. Define `ComplianceFramework__mdt` as the single source of truth (it likely already exists — verify).
  2. Add a `Module_Implementation__c` (Apex class name) field if missing.
  3. Refactor `ComplianceServiceFactory.create(...)` to look up the class via metadata and instantiate via `Type.forName(...).newInstance()`.
  4. Delete the hardcoded switch list in the factory.
  5. Either retire `IRiskScoringService` (fold into `IComplianceModule`) or make `IComplianceModule.getRiskScoringService()` the canonical accessor.
- **Acceptance:**
  - `grep -n "switch on framework" force-app/main/default/classes/ComplianceServiceFactory.cls` returns 0.
  - All 14 frameworks have a `ComplianceFramework__mdt` record with `Module_Implementation__c` set.
  - A new `ComplianceServiceFactoryTest.shouldInstantiateAllAdvertisedFrameworks` iterates the metadata, calls `create()` on each, and asserts no `null` return / no thrown exception.
- **Scope warning:** This is the largest task in the plan. If Codex isn't confident, **stop and ask** — wrong design here propagates.

### T3.2 — Wire `FeatureFlags` into entry points
- **Finding:** ARCH-2026-003 (HIGH)
- **Problem:** `FeatureFlags.cls` exposes 6 module switches; zero production callers.
- **Action:** Add a `FeatureFlags.requireEnabled('moduleName')` guard at the top of every `@AuraEnabled` method in each module's primary controller (HealthCheck, AssessmentWizard, SECModule, AIGovernance, TrustCenter, EventMonitoring). Pattern:
  ```apex
  @AuraEnabled
  public static SomeResult someAction() {
      FeatureFlags.requireEnabled(FeatureFlags.MODULE_HEALTH_CHECK);
      // existing body
  }
  ```
  - `requireEnabled` should throw `AuraHandledException(System.Label.Feature_Disabled)` when the flag is off.
- **Acceptance:** Every `@AuraEnabled` method in the 6 module controllers calls `FeatureFlags.requireEnabled(...)` as its first non-try statement. A new `FeatureFlagsTest.shouldBlockWhenDisabled` flips each flag off and asserts the exception.

### T3.3 — Execute platform redesign Phase 1 or mark Deferred
- **Finding:** ARCH-2026-004 (HIGH)
- **File:** `docs/elaro-platform-redesign-core-plus-packs.md` (or wherever e22c374 added it)
- **Decision required from human, not Codex.** Two paths:
  - **Path A — Execute:** Codex creates `force-app-hipaa-pack/`, moves HIPAA classes (start with `HIPAAPrivacyRuleService`, `HIPAABreachNotificationService`, related controllers/LWC), updates `sfdx-project.json` with a third packageDirectory, deletes the dead code (`BlockchainVerification.cls`, `BenchmarkingService.cls`, `SelfHealingDeployer.cls`, `Elaro_Evidence_Item__c`, `Elaro_Evidence_Anchor__c`). **High blast radius — open a dedicated branch and PR; do not bundle with other tiers.**
  - **Path B — Defer:** Add `**Status:** Deferred to Q3 2026` header to the redesign doc and delete it from the active spec list.
- **Codex note:** Default to **Path B** until a human OKs Path A. Document the decision in the PR description.

### T3.4 — Delete orphan Platform Events (or wire them up)
- **Files:**
  - `force-app/main/default/objects/LogEvent__e/` — **DO NOT DELETE** until T1.1 lands; this becomes the ElaroLogger sink.
  - `force-app/main/default/objects/GLBA_Compliance_Event__e/`
  - `force-app/main/default/objects/PCI_Access_Event__e/`
- **Action:** For the two non-Log events, check `grep -rn "GLBA_Compliance_Event__e\|PCI_Access_Event__e" force-app/`. If zero callers, delete the object directory. If callers exist, this finding is wrong — flag for re-review.
- **Acceptance:** No PE objects remain unreferenced.

### T3.5 — Resolve Step/StepProcessor framework adoption
- **Finding:** ARCH-medium-cluster
- **Problem:** `Step`, `StepProcessor`, `CursorStep` framework exists but has only 1 production consumer (`StepProcessor` itself, which means the framework is theoretical).
- **Decision required:** Either (a) migrate the 3-5 remaining Batchables to CursorStep, or (b) delete the framework. **Codex must ask first.**

### T3.6 — PCI trigger inline logic → handler
- **Finding:** ARCH-2026-006 (HIGH)
- **File:** `force-app/main/default/triggers/PCIComplianceTrigger.trigger`
- **Action:** Extract inline rule logic into `PCIComplianceTriggerHandler.cls`. Trigger body becomes a single dispatch call. Match the pattern in the other 4 triggers.

### T3.7 — Move controller DML calls to services
- **Finding:** ARCH-2026-005 (HIGH)
- **Files to audit:** Any controller (`*Controller.cls`) that calls `insert`, `update`, `delete`, `upsert` directly.
- **Pattern:** Controllers should call service methods; services own DML. Search command:
  ```bash
  grep -lE "^\s*(insert|update|delete|upsert)\s+as\s+user" force-app/main/default/classes/*Controller.cls
  ```
- **Acceptance:** No `*Controller.cls` directly executes DML. (DML stays in `*Service.cls` / `*Handler.cls`.)

---

## Tier 4 — AppExchange Polish

### T4.1 — Replace hardcoded English in 16 LWC HTML templates
- **Finding:** AX-003 / ARCH-2026-007 (HIGH)
- **Files (Codex must `grep` for the latest list):**
  - `force-app/main/default/lwc/elaroCopilot/elaroCopilot.html`
  - `force-app/main/default/lwc/elaroDashboard/elaroDashboard.html`
  - `force-app/main/default/lwc/elaroEventMonitor/elaroEventMonitor.html`
  - `force-app/main/default/lwc/elaroROICalculator/elaroROICalculator.html`
  - `force-app/main/default/lwc/elaroComparativeAnalytics/elaroComparativeAnalytics.html`
  - `force-app/main/default/lwc/jiraCreateModal/jiraCreateModal.html`
  - …plus 10 more identified by `grep -lE ">[A-Z][a-z]+ [A-Z][a-z]+<" force-app/main/default/lwc/**/*.html`
- **Action:** For each hardcoded string:
  1. Add a Custom Label to `force-app/main/default/labels/CustomLabels.labels-meta.xml` with `<protected>true</protected>`.
  2. Import the label in the LWC JS file: `import LabelName from "@salesforce/label/c.LabelName";`
  3. Replace the inline text with `{label.LabelName}`.
- **Acceptance:** `grep -rE ">[A-Z][a-z]+ [A-Z][a-z]+<" force-app/main/default/lwc/**/*.html` returns 0 results that aren't `{label.X}` expressions or pure punctuation.

### T4.2 — Differentiate Admin vs User Permission Sets
- **Finding:** AX-006 (MEDIUM, AppExchange agent)
- **Problem:** Admin and User PS variants currently grant identical scope (51 objects / 18 tabs / 94 classes each).
- **Action:** For each `Elaro_*_User.permissionset-meta.xml`, remove:
  - Object access on configuration/setup objects (`*_Setting__c`, `*_Config__c`)
  - Tab visibility for admin-only tabs (Setup, Configuration, Diagnostics)
  - Apex class access to setup/install/admin controllers
- **Acceptance:** Diff between `Elaro_X_Admin` and `Elaro_X_User` is non-empty for every module pair. Verify with `diff <(xmllint --xpath ...) <(xmllint --xpath ...)`.

### T4.3 — Migrate CI from sfdx-scanner to Code Analyzer v5
- **Finding:** ARCH-modernization (MEDIUM)
- **File:** `.github/workflows/elaro-ci.yml` (security-scan job)
- **Action:** Replace `sf plugins install @salesforce/sfdx-scanner` with `sf plugins install @salesforce/plugin-code-analyzer`. Update `sf scanner run` invocations to `sf code-analyzer run` per v5 syntax.
- **Acceptance:** `grep -n "sfdx-scanner" .github/workflows/elaro-ci.yml` returns 0; security-scan job passes a successful run on this branch.

### T4.4 — Add Apex tests to CI
- **Finding:** ARCH-modernization (MEDIUM)
- **File:** `.github/workflows/elaro-ci.yml`
- **Action:** Add a new job `apex-tests` that authenticates a scratch org and runs `sf apex run test --test-level RunLocalTests --wait 30 --code-coverage --result-format json`. Gate on 85% coverage.
- **Acceptance:** A successful CI run on the next commit includes an `apex-tests` job with green status.

### T4.5 — Grant `Elaro_Async_Framework_Flags__c` in Permission Set
- **Finding:** AX-medium-cluster
- **File:** Whichever `Elaro_*_Admin.permissionset-meta.xml` owns async framework config.
- **Action:** Add a `<customSettingAccesses>` (or appropriate) entry granting read/edit. Confirm via `sf project deploy validate`.

---

## Tier 5 — Housekeeping

### T5.1 — Add `Finalizer` + `AsyncOptions` to OrchestrationScanQueueable
- **Finding:** GOV-2026-medium (MEDIUM but customer-visible)
- **File:** `force-app/main/default/classes/OrchestrationService.cls:303`
- **Action:** Set `AsyncOptions` with `QueueableDuplicateSignature` keyed on the scan ID; attach a `Finalizer` that re-enqueues on `UNHANDLED_EXCEPTION` with backoff.

### T5.2 — Add LIMIT to 3 unbounded queries
- **Finding:** GOV-2026-medium cluster
- **Codex must `grep`:** Any `[SELECT ... FROM ...]` without a `LIMIT` in production paths (excluding aggregate queries and cursor sources).
- **Action:** Add `LIMIT 10000` (or smaller per business semantics) to bounded report queries.

### T5.3 — Replace non-selective LIKE
- **Finding:** GOV-2026-medium
- **Codex must locate** the LIKE query the agent identified. Replace with an indexed selective filter (e.g., on a `Status__c` boolean) or a precomputed search-index field.

### T5.4 — Migrate remaining Batchables to CursorStep
- **Finding:** GOV-2026-info
- **Decision required:** see T3.5 — do not do this in isolation.

### T5.5 — Fix ApexDoc `@version` → `@since` in ElaroLogger and 1 other
- **Finding:** ARCH-low
- **Action:** Replace `@version` with `@since` in any class still using the legacy tag.

### T5.6 — Rename `TechDebt_Manager.permissionset`
- **Finding:** ARCH-low
- **File:** `force-app/main/default/permissionsets/TechDebt_Manager.permissionset-meta.xml`
- **Action:** Rename to `Elaro_TechDebtManager_Admin.permissionset-meta.xml` (matches `Elaro_*_Admin` convention). Update any `<tabSettings>` or app references.

### T5.7 — Resolve remaining 7 low-severity npm vulns
- **Finding:** Discovered in CI fix (this PR)
- **File:** `package.json` / `package-lock.json`
- **Source:** `@salesforce/sfdx-lwc-jest` → `jest-environment-jsdom` → `jsdom` → `whatwg-url` chain.
- **Action:** Check whether `@salesforce/sfdx-lwc-jest` has a newer version that updates jsdom. If yes, bump. If no, suppress the advisories via `package.json` `overrides` only after confirming exploitability is N/A in test scope.

### T5.8 — Final scanner clean run
- **Action:** After all above tiers land, run `sf code-analyzer run --target force-app --severity-threshold 1 --format html --outfile scanner-reports/final.html`. Zero HIGH severity findings is the AppExchange gate.

---

## Execution Order & Estimated Effort

| Tier | Tasks | Effort (rough) | Can parallelize? |
|---|---|---|---|
| Tier 0 | 3 | 1 day (DevHub admin step blocks) | No (sequential gates) |
| Tier 1 | 6 | 3-4 days | Mostly yes; T1.6 should follow T1.1 (logger) |
| Tier 2 | 6 | 4-5 days | Yes, 3-way parallelism trivial |
| Tier 3 | 7 | 7-10 days | T3.1 alone is 3 days; T3.3 needs human OK |
| Tier 4 | 5 | 3 days | Yes |
| Tier 5 | 8 | 2-3 days | Yes |
| **Total** | **35** | **3-4 weeks single-developer; 2 weeks with parallel Codex agents** | |

**Grade trajectory:** Tier 0 alone re-bases the grade from C+ to B (clears both criticals). Tiers 1-2 close the runtime concerns and push to B+/A-. Tier 3 is what turns the codebase into a clean A.

---

## Codex Operating Notes

1. **One PR per tier.** Don't mix tiers — review reviewers can't reason about a 35-task megamerge.
2. **Always run `npm run precommit` before pushing.** It runs preflight + fmt:check + lint + test:unit. The CI job that gates `code-quality` requires the same.
3. **Apex tests:** Run `sf apex run test -o <scratchOrg> -c -r human -w 10 --test-level RunLocalTests`. 85% per-class is the gate.
4. **If a task is ambiguous, stop and open an issue rather than guessing.** Examples flagged above: T3.1 (registry design), T3.3 (redesign path A vs B), T3.5 (Step framework keep vs delete).
5. **Don't touch the `archive-2026-02-19/` directory.** It's the prior-review baseline for the next review run.
6. **After each tier merges,** re-run the Solentra review (`/review --resume` or fresh `/review`) to confirm score progression and catch regressions.

---

## Cross-References

- Source findings: `.review-state/security-findings.json`, `.review-state/governor-findings.json`, `.review-state/test-findings.json`, `.review-state/architecture-findings.json`, `.review-state/appexchange-findings.json`
- Score breakdown: `.review-state/state.json` (`scoring` block)
- Narrative report: `.review-state/final-report.md`
- Prior baseline: `.review-state/archive-2026-02-19/`
- Project standards: `CLAUDE.md` (the standards this plan enforces)
