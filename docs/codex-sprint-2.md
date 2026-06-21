# Codex Fix Plan — Sprint 2 (Test Coverage + Controller Hardening + LWC i18n)

> **Branch:** `codex/sprint-2-coverage-i18n` from current `main`
> **Scope:** the Feb-baseline backlog that lifts grade C → B+ (and toward A-). Three independent tracks; each PR is mechanical once the pattern is set.
> **Tracks:**
> - **Track 1** — Controller try-catch + `as user` hardening (Feb SEC-001..025) — 3 classes, ~8 methods
> - **Track 2** — Real-assertion test rewrites (Feb TEST-002..005) — 3 stub tests + 1 thin test
> - **Track 3** — LWC i18n via Custom Labels — **38 components** (~600+ strings extrapolating from earlier session findings)
> **Estimated effort:** 2-3 weeks single-developer, ~1 week with parallel Codex.

## Track 1 — Controller try-catch + DML hardening

Reference impl: `AIGovernanceController.cls` (every @AuraEnabled method follows the pattern). The fix per method:

```apex
@AuraEnabled
public static <ReturnType> <method>(<params>) {
    try {
        // existing body — change every `insert x` / `update x` / `delete x` to `<op> as user x`
        // change every [SELECT ... FROM ...] to use `WITH USER_MODE`
    } catch (AuraHandledException ahe) {
        throw ahe;  // re-throw — don't double-wrap
    } catch (Exception e) {
        ElaroLogger.error('<ClassName>.<methodName>', e.getMessage(), e.getStackTraceString());
        throw new AuraHandledException(System.Label.<Module>_ErrorGeneric);
    }
}
```

### Track 1, PR 1 — OnCallScheduleController

**File:** `force-app/main/default/classes/OnCallScheduleController.cls`
**Sites (Feb SEC-003..005, SEC-001..002):**
- `:38` `createSchedule` — wrap in try-catch; line 43 `insert ...` → `insert as user ...`
- `:54` `updateSchedule` — wrap; line 59 `update ...` → `update as user ...`
- `:69` `deleteSchedule` — wrap; DML → `delete as user`

**Test additions:** `OnCallScheduleControllerTest` must add a `System.runAs(restrictedUser)` block per method that asserts the `AuraHandledException` fires when the user lacks Schedule write access.

**Acceptance:** `grep -nE "^\s*(insert|update|delete|upsert)\s+(?!as user)" force-app/main/default/classes/OnCallScheduleController.cls` → 0 hits.

### Track 1, PR 2 — MultiOrgManager

**File:** `force-app/main/default/classes/MultiOrgManager.cls`
**Sites (Feb SEC-006..014):**
- `:14` `registerOrg` — wrap in try-catch
- `:29` `insert connectedOrg` → `insert as user`
- `:88`, `:112`, `:123` SOQL — append `WITH USER_MODE`
- `:110` `removeOrg` — wrap
- `:115` `delete org` → `delete as user`
- `:121` `refreshAllConnections` — wrap
- `:207` `testOrgConnection` (a Queueable replacement of the @future, already migrated — verify the migration is in this baseline). If it still uses @future, also do the GOV-008 conversion using `ElaroDailyDigest.SlackDigestQueueable` (line 328) as template.
- `:229` DML in async path → `as user`

### Track 1, PR 3 — HIPAABreachNotificationService

**File:** `force-app/main/default/classes/HIPAABreachNotificationService.cls`
**Sites (Feb SEC-020..025):**
- `:278` `createBreachRecord` — wrap, DML → `as user`
- `:289`, `:348`, `:373` DML → `as user`
- `:333`, `:358` @AuraEnabled methods — wrap

### Track 1, PR 4 — `Module_ErrorGeneric` Custom Labels

Some modules don't have an `*_ErrorGeneric` label yet. Pattern: `<MODULE>_ErrorGeneric` (e.g., `OCS_ErrorGeneric`, `MOM_ErrorGeneric`, `HBN_ErrorGeneric`). One label per module. Add to `force-app/main/default/labels/CustomLabels.labels-meta.xml`:
```xml
<labels>
    <fullName>OCS_ErrorGeneric</fullName>
    <language>en_US</language>
    <protected>true</protected>
    <shortDescription>On-Call Schedule generic error message</shortDescription>
    <value>Unable to complete the operation. Please verify your permissions and try again.</value>
</labels>
```

## Track 2 — Real assertions in stub tests

### PR 5-7 — Replace placeholder tests

Three test classes flagged as stubs (Feb TEST-002/003/004) — each currently has `Assert.isTrue(true)` placeholders. Each rewrite must:
1. Use `@IsTest(testFor=<ProductionClass>.class)` annotation
2. Add `@TestSetup` calling `ComplianceTestDataFactory` (canonical test-data source)
3. Cover happy path + at least 1 negative case + 1 bulk-200 case
4. Replace every `Assert.isTrue(true)` with a real assertion on observable behavior

| Stub file | Production class | What to actually test |
|---|---|---|
| `ElaroEventProcessorTest.cls:24` | `ElaroEventProcessor` | Event-deserialization happy path, malformed JSON path, batch processing of 200 events, recursion-guard reset between invocations |
| `ElaroFrameworkEngineTest.cls:24` | `ElaroFrameworkEngine` | Factory dispatch for each supported framework (HIPAA, SOC2, GDPR, CCPA, PCI_DSS), unsupported-framework error, null-input handling |
| `ElaroEventMonitoringServiceTest.cls:24` | `ElaroEventMonitoringService` | Subscription registration, event publish + delivery, error path when EventBus.publish returns failure |

### PR 8 — ElaroAuditPackageGenerator test (Feb TEST-005, "only 1 assertion")

**File:** `ElaroAuditPackageGeneratorTest.cls`
**Add:** evidence-package shape assertions (every required field present, framework-specific evidence included, retention-date set), bulk-200 (200 packages don't blow heap), null-input rejection.

### PR 9 — IComplianceModule contract test (Feb TEST-001)

**New file:** `IComplianceModuleTest.cls`
**Purpose:** assert that every implementer (HIPAAModule, SOC2Module, GDPRModule, FINRAModule, AIGovernanceService) satisfies the interface contract — `getFrameworkName()`/`getControls()`/`identifyGaps()` return non-null, `calculateScore(null)` returns 0, etc. Iterate the implementer list so adding a new framework auto-extends the test.

## Track 3 — LWC i18n via Custom Labels (38 components)

**The pattern** (one fully-completed reference shipped in the session that reset; rebuild here):

For each LWC `c-foo`:
1. Inventory hardcoded strings (HTML attrs `title=`/`label=`/`alternative-text=`; HTML text content `>Text<`; JS toast titles/messages `'Success'`/`'Error'`).
2. Add labels to `force-app/main/default/labels/CustomLabels.labels-meta.xml` with `<protected>true</protected>` and a module prefix (e.g. `FOO_CardTitle`, `FOO_Refresh`).
3. Import in `foo.js`:
   ```js
   import CardTitle from "@salesforce/label/c.FOO_CardTitle";
   import Refresh from "@salesforce/label/c.FOO_Refresh";
   // ...
   export default class Foo extends LightningElement {
     label = { CardTitle, Refresh, /* ... */ };
   ```
4. Reference in `foo.html`:
   ```html
   <lightning-card title={label.CardTitle}>
     <lightning-button label={label.Refresh} onclick={handleRefresh}></lightning-button>
   ```
5. **Update the Jest test** (this is the part that catches teams off-guard): any assertion that compared literal display text (`expect(card.title).toBe("Compliance Score")`) breaks because the sfdx-lwc-jest label mock returns `"c.FOO_CardTitle"`. Fix:
   ```js
   import CardTitle from "@salesforce/label/c.FOO_CardTitle";
   ...
   expect(card.title).toBe(CardTitle);   // now resilient to label value
   ```
   For label-irrelevant queries (e.g. finding a button), switch from `.label === "Refresh"` to `.iconName === "utility:refresh"` or a `data-id` selector.

### Track 3 — Per-PR shape (38 PRs, one per component)

Each PR scope: 1 LWC component, 1 commit, runnable independently. Title format: `feat(lwc-i18n): externalize <componentName> strings to Custom Labels`. Acceptance checklist:
- [ ] All `>Text<` text content uses `{label.X}`
- [ ] All attribute strings (`title=`, `label=`, `alternative-text=`, `message=`) use `{label.X}`
- [ ] JS toast titles/messages use `label.X`
- [ ] Component's Jest suite passes (often requires updating 1-3 assertions per component)
- [ ] `grep -nE ">[A-Z][a-z]+[a-z 0-9.,!?:'/-]*<" force-app/main/default/lwc/<name>/<name>.html | grep -vE "\{label\.|\{"` → 0 hits

### Track 3 — Suggested PR order (highest-traffic LWC first)

Inventory the 38 with `find force-app/main/default/lwc -maxdepth 1 -mindepth 1 -type d -exec test ! -f "{}/{}.js" -o ! -execdir grep -lq "@salesforce/label" {} \; -print`. Suggested ordering:
1. `complianceScoreCard` — main dashboard surface
2. `complianceGapList` — primary user workflow
3. `remediationSuggestionCard` — AI-driven UX
4. `complianceGraphViewer` — high string density
5. `riskHeatmap` — small, easy warm-up after #4
6. (continue with the remaining 33 in any order; pick the lower-string-count components for warm-up days)

### Track 3 — Module-prefix mapping (use these for new labels)

| Component family | Prefix |
|---|---|
| `compliance*` | `CGV_`, `CSC_`, `CGL_` (per component) |
| `elaroDashboard`, `elaroCopilot` | `EDB_`, `ECP_` |
| `elaroEvent*` | `EVM_`, `EVX_` |
| `elaroAudit*` | `EAW_`, `EAP_` |
| `jira*` | `JIC_`, `JCM_` |
| `riskHeatmap`, `riskMatrix` | `RHM_`, `RMX_` |
| `secDisclosure*` | `SEC_` |
| `trustCenter*` | `TC_` |

(Use these prefixes consistently with the existing labels in the file — `grep '<fullName>' labels/CustomLabels.labels-meta.xml` to see what's already defined; reuse a label across components when the same text appears in both.)

## Verification (per PR, every track)

```bash
npm run fmt:check && npm run lint && npm run test:unit
bash scripts/standards-gates.sh --report   # gates 3 (System.debug), 8 (target=_blank rel) should not regress
```

For Track 1 PRs, additionally:
- `grep -nE "throw new AuraHandledException\((e|ex)\.getMessage" force-app/main/default/classes/*.cls` → 0 hits (the CI gate added in prior session catches this; if the gate isn't present at HEAD, this PR is a good place to add it)
- `grep -nE "^\s*(insert|update|delete|upsert)\s+(?!as user)" force-app/main/default/classes/*.cls` → ideally 0; non-zero is a known-debt list

## Sequencing & parallelism

- **Tracks 1 and 2** can run in parallel (different files, both Apex)
- **Track 3** runs in parallel with both (LWC only, no Apex overlap)
- **Track 1 PR 4 (labels)** must merge before Track 3 starts to avoid label-namespace conflicts
- Each completed track triggers a `/review` re-run to confirm the grade lift

## Expected grade trajectory

- Track 1 complete → +0.15 weighted (Security 3.5 → 4.1)
- Track 2 complete → +0.075 weighted (Test Quality 3.5 → 4.0)
- Track 3 complete → +0.10 weighted (Maintainability 3.0 → 3.7; AppExchange 2.5 → 3.5 via label coverage)

Sum: +0.325 to weighted total → from 3.325 (Feb baseline) to ~3.65 = solid B-, on the path to A-.
