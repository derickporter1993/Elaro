# Codex Prompts — All Remaining Tasks (Sprints 1-4)

> Each section is a self-contained Codex task. Copy a single section to hand it to Codex.
> Sequencing notes are in each task's header.

---

## SPRINT 1 — Runtime Correctness Finishing

### T0.3 — Replace `packageAliases` placeholder

**Branch:** `codex/fix-t0.3-package-aliases`
**Dependencies:** T0.1 (DevHub namespace registration must produce real Package ID first — human action)
**Effort:** 1 minute

**File:** `sfdx-project.json`

Replace the placeholder Package IDs with real ones from `sf package list`:

```bash
sf package list --target-dev-hub <devhub-alias>
```

Then in `sfdx-project.json` change:
```json
"packageAliases": {
    "Elaro": "0HoXXXXXXXXXXXX"
}
```
To:
```json
"packageAliases": {
    "Elaro": "0Ho<real-id-from-sf-package-list>",
    "Elaro Health Check": "0Ho<real-id-for-hc-package>"
}
```

**Verify:** `grep -n "XXXXXXXXXX" sfdx-project.json` returns 0 hits.

**PR title:** `chore(packaging): replace packageAliases placeholders with real IDs`

---

### T1.4 — CursorStep AccessLevel.USER_MODE on empty-binds path

**Branch:** `codex/fix-t1.4-cursorstep-usermode`
**Dependencies:** None
**Effort:** 30 minutes

**File:** `force-app/main/default/classes/CursorStep.cls` (lines 148-152)

**Current:**
```apex
if (this.cursorWrapper == null) {
    Map<String, Object> binds = getCursorBinds();
    Database.Cursor realCursor = (binds != null && !binds.isEmpty())
        ? Database.getCursorWithBinds(getCursorQuery(), binds, AccessLevel.USER_MODE)
        : Database.getCursor(getCursorQuery());
    this.cursorWrapper = new CursorWrapper(realCursor);
}
```

**Replace with:**
```apex
if (this.cursorWrapper == null) {
    Map<String, Object> binds = getCursorBinds();
    Database.Cursor realCursor = Database.getCursorWithBinds(
        getCursorQuery(),
        (binds != null) ? binds : new Map<String, Object>(),
        AccessLevel.USER_MODE
    );
    this.cursorWrapper = new CursorWrapper(realCursor);
}
```

**Test addition** — append to `CursorStepTest.cls` (create if missing):

```apex
@IsTest
static void shouldEnforceUserModeWhenBindsEmpty() {
    CursorStep step = new TestCursorStepNoBindsStub();
    StepContext ctx = new StepContext();

    Test.startTest();
    Exception caught;
    try {
        step.execute(ctx);
    } catch (Exception e) {
        caught = e;
    }
    Test.stopTest();

    Assert.isNull(caught, 'Empty-binds path should execute under USER_MODE without exception');
}

private class TestCursorStepNoBindsStub extends CursorStep {
    public override String getCursorQuery() {
        return 'SELECT Id FROM User WHERE IsActive = TRUE LIMIT 1';
    }
    public override Map<String, Object> getCursorBinds() { return null; }
    public override void innerExecute(List<SObject> records, StepContext ctx) {}
    public override void finalize(StepContext ctx) {}
}
```

**Verify:**
```bash
grep -n "Database.getCursor\b" force-app/main/default/classes/CursorStep.cls
# Expected: 0 hits — only Database.getCursorWithBinds remains
```

**PR title:** `fix(cursor-framework): enforce AccessLevel.USER_MODE on empty-binds path`

---

### T1.5 — HIPAA PHI audit gap signal

**Branch:** `codex/fix-t1.5-hipaa-audit-gap`
**Dependencies:** T1.1 (ElaroLogger durable publish) merged first
**Effort:** 2-3 hours

**Step 1 — create `Compliance_Audit_Gap__e` Platform Event**

`force-app/main/default/objects/Compliance_Audit_Gap__e/Compliance_Audit_Gap__e.object-meta.xml`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<CustomObject xmlns="http://soap.sforce.com/2006/04/metadata">
    <deploymentStatus>Deployed</deploymentStatus>
    <eventType>HighVolume</eventType>
    <label>Compliance Audit Gap</label>
    <pluralLabel>Compliance Audit Gaps</pluralLabel>
    <publishBehavior>PublishImmediately</publishBehavior>
</CustomObject>
```

Field files under `.../fields/`:
- `Framework__c` Text(40) required
- `Regulation_Reference__c` Text(80)
- `Source_Class__c` Text(80) required
- `Source_Method__c` Text(80) required
- `Record_Id__c` Text(18)
- `Object_Name__c` Text(80)
- `Error_Detail__c` LongTextArea(32768)
- `Timestamp__c` DateTime required

**Step 2 — modify `HIPAAPrivacyRuleService.auditPHIAccess` (line 216)**

**Current:**
```apex
} catch (Exception e) {
    ElaroLogger.error('Error querying history: ' + e.getMessage(), e);
}

return accessLogs;
```

**Replace with:**
```apex
} catch (Exception e) {
    ElaroLogger.error('HIPAAPrivacyRuleService.auditPHIAccess', e.getMessage(), e.getStackTraceString());

    EventBus.publish(new Compliance_Audit_Gap__e(
        Framework__c = 'HIPAA',
        Regulation_Reference__c = '45 CFR 164.312(b)',
        Source_Class__c = 'HIPAAPrivacyRuleService',
        Source_Method__c = 'auditPHIAccess',
        Record_Id__c = recordId,
        Object_Name__c = objectName,
        Error_Detail__c = e.getTypeName() + ': ' + e.getMessage(),
        Timestamp__c = System.now()
    ));

    throw new AuraHandledException(System.Label.HIPAA_AuditQueryFailed);
}
```

**Step 3 — add Custom Label** in `force-app/main/default/labels/CustomLabels.labels-meta.xml`:
```xml
<labels>
    <fullName>HIPAA_AuditQueryFailed</fullName>
    <language>en_US</language>
    <protected>true</protected>
    <shortDescription>HIPAA audit query failure user-facing message</shortDescription>
    <value>Unable to retrieve the PHI access audit log. The failure has been recorded for compliance review.</value>
</labels>
```

**Step 4 — add test** to `HIPAAPrivacyRuleServiceTest.cls`:
```apex
@IsTest
static void shouldPublishAuditGapEventWhenQueryFails() {
    ElaroLogger.publishedEvents.clear();
    Id fakeId = '001000000000001AAA';

    Test.startTest();
    try {
        HIPAAPrivacyRuleService.auditPHIAccess(fakeId, 'Account');
    } catch (AuraHandledException expected) {
        // expected
    }
    Test.stopTest();

    Assert.isFalse(ElaroLogger.publishedEvents.isEmpty(),
        'A LogEvent__e should be published on audit failure');
}
```

**PR title:** `fix(hipaa): publish Compliance_Audit_Gap__e on PHI audit failure`

---

### T1.6 — Verify controller error sanitization (CI gate)

**Branch:** `codex/verify-t1.6-no-getmessage-leakage`
**Dependencies:** None
**Effort:** 30 minutes

The 4 named files already pass — this task locks the gain.

**Verify clean:**
```bash
grep -rn "throw new AuraHandledException(e\.getMessage\|throw new AuraHandledException(ex\.getMessage" \
    force-app/main/default/classes/ --include="*.cls"
# Expected: 0 hits
```

**Add CI gate** to `.github/workflows/elaro-ci.yml` under the `code-quality` job:
```yaml
- name: Block e.getMessage leakage in AuraHandledException
  run: |
    if grep -rn "throw new AuraHandledException(e\.getMessage\|throw new AuraHandledException(ex\.getMessage" \
        force-app/main/default/classes/ --include="*.cls"; then
      echo "::error::AuraHandledException must not leak e.getMessage() to clients"
      exit 1
    fi
```

**PR title:** `chore(security): lock controller error sanitization gain in CI`

---

## SPRINT 2 — Test Coverage (Tier 2)

### T2.1-T2.4 — Queueable + Trigger Test Classes

Each follows the same template. Open one PR per task.

**Template** (substitute `<ProductionClass>` and module-specific args):

```apex
/**
 * Tests for {@link <ProductionClass>}.
 *
 * @author Elaro
 * @since v3.1.0 (Spring '26)
 * @group <Module>
 * @see <ProductionClass>
 */
@IsTest(testFor=<ProductionClass>.class)
private class <ProductionClass>Test {

    private class HappyMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"ok":true,"id":"abc123"}');
            return res;
        }
    }

    private class TransientMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(503);
            res.setBody('Service temporarily unavailable');
            return res;
        }
    }

    private class TerminalMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(400);
            res.setBody('{"error":"invalid payload"}');
            return res;
        }
    }

    @TestSetup
    static void setup() {
        // ComplianceTestDataFactory.createXxx() — DO NOT roll your own
    }

    @IsTest
    static void shouldSucceedOnHappyPath() {
        Test.setMock(HttpCalloutMock.class, new HappyMock());
        ElaroLogger.publishedEvents.clear();

        Test.startTest();
        System.enqueueJob(new <ProductionClass>(/* args */));
        Test.stopTest();

        // Assert side effects (DML, log entries)
    }

    @IsTest
    static void shouldLogAtErrorOnTransientFailure() {
        Test.setMock(HttpCalloutMock.class, new TransientMock());
        ElaroLogger.publishedEvents.clear();

        Test.startTest();
        System.enqueueJob(new <ProductionClass>(/* args */));
        Test.stopTest();

        Assert.isFalse(ElaroLogger.publishedEvents.isEmpty(),
            'transient failure should emit a log event');
    }

    @IsTest
    static void shouldLogAtErrorOnTerminalFailure() {
        Test.setMock(HttpCalloutMock.class, new TerminalMock());
        ElaroLogger.publishedEvents.clear();

        Test.startTest();
        System.enqueueJob(new <ProductionClass>(/* args */));
        Test.stopTest();

        Assert.areEqual('ERROR', ElaroLogger.publishedEvents[0].Level__c,
            'terminal failure should log at ERROR');
    }
}
```

**Per-task specifics:**

| Task | Production class | Constructor signature | Side effect to assert |
|---|---|---|---|
| T2.1 | `ElaroDeliveryQueueable` | _read class to confirm_ | Delivery log row inserted |
| T2.2 | `MultiOrgManagerQueueable` | _read class to confirm_ | Sync log row inserted |
| T2.3 | `SlackIntegrationQueueable` | _read class to confirm_ | Slack webhook called |

**T2.4 differs** — Trigger test for `ElaroEventCaptureTrigger`:

```apex
@IsTest(testFor=ElaroEventCaptureTrigger.class)
private class ElaroEventCaptureTriggerTest {

    @IsTest
    static void shouldHandleEventDelivery() {
        // First read force-app/main/default/triggers/ElaroEventCaptureTrigger.trigger
        // to confirm which Platform Event this trigger fires on
        Test.startTest();
        EventBus.publish(new <CapturedEventApiName>(/* fields */));
        Test.getEventBus().deliver();
        Test.stopTest();

        // Assert trigger side effect — e.g. log row inserted
    }

    @IsTest
    static void shouldResetRecursionGuardBetweenInvocations() {
        Test.startTest();
        for (Integer i = 0; i < 5; i++) {
            EventBus.publish(new <CapturedEventApiName>(/* fields */));
        }
        Test.getEventBus().deliver();
        Test.stopTest();

        // Assert recursion guard reset by verifying 5 side effects, not 1
    }
}
```

**Verify per task:**
```bash
sf apex run test --target-org elaro-dev --tests <ProductionClass>Test \
    --result-format human --wait 10 --code-coverage
# Expected: ≥85% per-class coverage
```

**Stop and ask if:** the production class signature or PE name differs from what's documented. Read the source file first.

**PR title:** `test(<module>): add <ProductionClass>Test with HttpCalloutMock`

---

### T2.6 — SlackNotifier real HttpCalloutMock

**Branch:** `codex/fix-t2.6-slack-notifier-mock`
**Effort:** 1 hour

**File:** `force-app/main/default/classes/SlackNotifierTest.cls`

Replace stub `caughtException == null` assertions with the HappyMock/TerminalMock pattern above. Assert on `req.getBody()` contents, headers, and retry behavior.

**Verify:**
```bash
grep -n "caughtException == null" force-app/main/default/classes/SlackNotifierTest.cls
# Expected: 0 hits

grep -n "HttpCalloutMock" force-app/main/default/classes/SlackNotifierTest.cls
# Expected: ≥1 hit
```

**PR title:** `test(notifications): replace SlackNotifierTest stubs with real HttpCalloutMock`

---

## SPRINT 3 — Architecture & AppExchange Polish

### T3.2 — Wire FeatureFlags into module controllers

**Branch:** `codex/fix-t3.2-featureflags-wiring`
**Effort:** 1 day

**Step 1 — add a `requireEnabled` helper to `FeatureFlags.cls`** (DO NOT redesign the existing methods):

Append to `force-app/main/default/classes/FeatureFlags.cls` inside the class:

```apex
/**
 * Throws AuraHandledException if the named module is disabled.
 *
 * @param moduleName One of: COMMAND_CENTER, EVENT_MONITORING, AI_GOVERNANCE,
 *                   SEC_MODULE, TRUST_CENTER, ASSESSMENT_WIZARD
 * @throws AuraHandledException with stable user-facing message when disabled
 */
public static void requireEnabled(String moduleName) {
    Boolean enabled;
    switch on moduleName {
        when 'COMMAND_CENTER'      { enabled = isCommandCenterEnabled(); }
        when 'EVENT_MONITORING'    { enabled = isEventMonitoringEnabled(); }
        when 'AI_GOVERNANCE'       { enabled = isAIGovernanceEnabled(); }
        when 'SEC_MODULE'          { enabled = isSECModuleEnabled(); }
        when 'TRUST_CENTER'        { enabled = isTrustCenterEnabled(); }
        when 'ASSESSMENT_WIZARD'   { enabled = isAssessmentWizardEnabled(); }
        when else                  { enabled = true; }
    }
    if (!enabled) {
        throw new AuraHandledException(System.Label.Feature_Disabled);
    }
}
```

**Step 2 — add Custom Label:**
```xml
<labels>
    <fullName>Feature_Disabled</fullName>
    <language>en_US</language>
    <protected>true</protected>
    <shortDescription>Generic message when a disabled module is invoked</shortDescription>
    <value>This feature is currently disabled. Contact your administrator if you need access.</value>
</labels>
```

**Step 3 — wire into module controllers** — add the guard as the first statement of every `@AuraEnabled` method in:

| Controller file | Module |
|---|---|
| `AIGovernanceController.cls` | `AI_GOVERNANCE` |
| `AssessmentWizardController.cls` | `ASSESSMENT_WIZARD` |
| `SECModuleController.cls` | `SEC_MODULE` |
| `TrustCenterController.cls` | `TRUST_CENTER` |
| `EventMonitoringController.cls` | `EVENT_MONITORING` |
| `CommandCenterController.cls` | `COMMAND_CENTER` |

Pattern:
```apex
@AuraEnabled
public static SomeResult someAction() {
    FeatureFlags.requireEnabled('AI_GOVERNANCE');
    try {
        // existing body
    } catch (Exception e) {
        // existing error handling
    }
}
```

**Step 4 — add `FeatureFlagsTest.shouldBlockEachModuleWhenDisabled`** — iterate the 6 modules, flip each off via `Elaro_Feature_Flags__c` Org Default, call `requireEnabled`, assert exception.

**Verify:**
```bash
# Every module controller should have a requireEnabled guard
for f in AIGovernanceController.cls AssessmentWizardController.cls SECModuleController.cls TrustCenterController.cls EventMonitoringController.cls CommandCenterController.cls; do
    echo "=== $f ==="
    grep -c "FeatureFlags.requireEnabled" force-app/main/default/classes/$f
done
# Expected: each count ≥ number of @AuraEnabled methods in that controller
```

**PR title:** `feat(feature-flags): wire FeatureFlags.requireEnabled into 6 module controllers`

---

### T3.4 — Delete orphan Platform Events

**Branch:** `codex/fix-t3.4-orphan-platform-events`
**Effort:** 30 minutes

**Confirmed orphan:** `GLBA_Compliance_Event__e` — zero callers in `force-app/main/default/classes/`.

**Confirmed live-on-paper-only:** `PCI_Access_Event__e` — 2 references in `PCIAccessControlService.cls:168` and `PCILoggingService.cls:48`, but both are comments saying "would publish to PCI_Access_Event__e" — aspirational, not actual.

**DO NOT TOUCH:** `LogEvent__e` (now actively used by ElaroLogger after T1.1).

**Action:**
```bash
# 1. Confirm GLBA is fully orphan
grep -rn "GLBA_Compliance_Event__e" force-app/ --include="*.cls" --include="*.trigger"
# Expected: 0 hits

# 2. Decide PCI: delete OR wire up
#    Default: delete (the comments are misleading). Wiring up belongs in a separate
#    PCI module enhancement task, not this housekeeping PR.

# 3. Delete the object directories
rm -rf force-app/main/default/objects/GLBA_Compliance_Event__e
rm -rf force-app/main/default/objects/PCI_Access_Event__e

# 4. Remove stale comment references
```

In `PCIAccessControlService.cls:168`, remove or update the comment `// Log access event to PCI_Access_Event__e platform event` to remove the dead PE reference.

In `PCILoggingService.cls:48`, remove or update `// In production, would also publish to PCI_Access_Event__e platform event`.

**Verify:**
```bash
ls force-app/main/default/objects/ | grep -E "GLBA_Compliance_Event__e|PCI_Access_Event__e"
# Expected: no output

grep -rn "GLBA_Compliance_Event__e\|PCI_Access_Event__e" force-app/
# Expected: no output
```

**PR title:** `chore(cleanup): delete orphan GLBA and PCI Platform Events`

---

### T4.1 — LWC hardcoded English → Custom Labels

**Branch:** `codex/fix-t4.1-lwc-custom-labels`
**Effort:** 1-2 days (19 files, ~50+ strings)

**Files (confirmed by grep):**

| File | String count |
|---|---:|
| `complianceGraphViewer/complianceGraphViewer.html` | 9 |
| `jiraIssueCard/jiraIssueCard.html` | 7 |
| `jiraCreateModal/jiraCreateModal.html` | 4 |
| `elaroTrendAnalyzer/elaroTrendAnalyzer.html` | 3 |
| `wizardStep/wizardStep.html` | 3 |
| `remediationSuggestionCard/remediationSuggestionCard.html` | 3 |
| `onCallScheduleManager/onCallScheduleManager.html` | 3 |
| `escalationPathConfig/escalationPathConfig.html` | 3 |
| `elaroCopilot/elaroCopilot.html` | 2 |
| `elaroDashboard/elaroDashboard.html` | 2 |
| `elaroEventMonitor/elaroEventMonitor.html` | 2 |
| `elaroROICalculator/elaroROICalculator.html` | 2 |
| `controlMappingMatrix/controlMappingMatrix.html` | 2 |
| `apiUsageDashboard/apiUsageDashboard.html` | 1 |
| `elaroDynamicReportBuilder/elaroDynamicReportBuilder.html` | 1 |
| `elaroEventExplorer/elaroEventExplorer.html` | 1 |
| `riskHeatmap/riskHeatmap.html` | 1 |
| `elaroAuditWizard/elaroAuditWizard.html` | 1 |
| `elaroComparativeAnalytics/elaroComparativeAnalytics.html` | 1 |

**Per-file procedure:**

1. Open the `.html`. For each hardcoded string like `<lightning-card title="Compliance Score">`:
   - Add a label entry to `force-app/main/default/labels/CustomLabels.labels-meta.xml`:
     ```xml
     <labels>
         <fullName>CGV_ComplianceScore</fullName>
         <language>en_US</language>
         <protected>true</protected>
         <shortDescription>Compliance Score card title</shortDescription>
         <value>Compliance Score</value>
     </labels>
     ```
   - Label naming: `<ModulePrefix>_<DescriptiveName>` (e.g. `CGV_` for complianceGraphViewer, `JIC_` for jiraIssueCard).
2. Import the label in the LWC JS file:
   ```javascript
   import ComplianceScore from "@salesforce/label/c.CGV_ComplianceScore";
   ```
3. Expose via the `label` object:
   ```javascript
   label = { ComplianceScore, /* others */ };
   ```
4. Reference in the HTML:
   ```html
   <lightning-card title={label.ComplianceScore}>
   ```

**Batch one PR per LWC** (don't mega-PR 19 files — review reviewers can't reason about it). Prefix per-file: `feat(lwc-labels):` not `fix:`.

**Verify per file:**
```bash
grep -cE ">[A-Z][a-z]+[a-z 0-9.,!?']*<" force-app/main/default/lwc/<componentName>/<componentName>.html
# Expected: 0 (or only matches that are label.X expressions in punctuation)
```

**Final aggregate verify after all 19 PRs:**
```bash
for f in $(find force-app/main/default/lwc -name "*.html"); do
    HITS=$(grep -cE ">[A-Z][a-z]+[a-z 0-9.,!?']*<" "$f")
    if [ "$HITS" -gt 0 ]; then echo "$f: $HITS"; fi
done
# Expected: no output
```

**PR title:** `feat(lwc-labels): replace hardcoded strings in <componentName> with Custom Labels`

---

### T4.2 — Admin vs User Permission Set differentiation

**Branch:** `codex/fix-t4.2-permission-set-leastprivilege`
**Effort:** 1 day

**Pairs to differentiate** (the User variant must be a strict subset of Admin):

| Admin | User |
|---|---|
| `Elaro_AI_Governance_Admin.permissionset-meta.xml` | `Elaro_AI_Governance_User.permissionset-meta.xml` |
| `Elaro_Async_Admin.permissionset-meta.xml` | `Elaro_Async_User.permissionset-meta.xml` |
| `Elaro_Rule_Engine_Admin.permissionset-meta.xml` | `Elaro_Rule_Engine_User.permissionset-meta.xml` |
| `Elaro_SEC_Admin.permissionset-meta.xml` | `Elaro_SEC_User.permissionset-meta.xml` |
| `Elaro_Admin.permissionset-meta.xml` | `Elaro_User.permissionset-meta.xml` |

**For each User variant, REMOVE:**

1. **Setup/config object access** — any object whose API name ends in `_Setting__c`, `_Config__c`, `_Configuration__c`, `_Rule_Config__c`, `_Flags__c`:
   ```xml
   <!-- REMOVE entries like: -->
   <objectPermissions>
       <object>Elaro_Async_Framework_Flags__c</object>
       <allowEdit>true</allowEdit>
       <allowCreate>true</allowCreate>
       ...
   </objectPermissions>
   ```

2. **Setup/config tabs** — any tab labeled with "Setup", "Configuration", "Settings", "Admin", "Diagnostics":
   ```xml
   <tabSettings>
       <tab>AI_Governance_Settings</tab>
       <visibility>Hidden</visibility>  <!-- User should NOT see -->
   </tabSettings>
   ```

3. **Setup/install controllers** — any Apex class whose name ends in `InstallHandler`, `MigrationManager`, `ConfigService`:
   ```xml
   <classAccesses>
       <apexClass>ElaroInstallHandler</apexClass>
       <enabled>false</enabled>  <!-- Or remove the block entirely -->
   </classAccesses>
   ```

**Verify per pair:**
```bash
# The User variant must have FEWER components than the Admin variant
diff <(grep -c "<object>" force-app/main/default/permissionsets/Elaro_AI_Governance_Admin.permissionset-meta.xml) \
     <(grep -c "<object>" force-app/main/default/permissionsets/Elaro_AI_Governance_User.permissionset-meta.xml)
# Expected: Admin count > User count
```

**Stop and ask if:** any pair currently has identical scope by design (e.g. there genuinely are no admin-only components). Some user-facing modules may be flat. Document the decision in the PR body.

**PR title:** `fix(permissions): differentiate Admin and User Permission Sets for least privilege`

---

### T4.3 — CI migration to Code Analyzer v5

**Branch:** `codex/fix-t4.3-code-analyzer-v5`
**Effort:** 2-3 hours

**File:** `.github/workflows/elaro-ci.yml`

The current `security-scan` job uses retired `@salesforce/sfdx-scanner` (v4) and `sf scanner run`. Migrate to `@salesforce/plugin-code-analyzer` (v5) and `sf code-analyzer run`.

**Changes:**

1. **Install command:**
   ```yaml
   # Before
   - name: Install scanner
     run: sf plugins install @salesforce/sfdx-scanner

   # After
   - name: Install Code Analyzer v5
     run: sf plugins install code-analyzer
   ```

2. **Invocations** — replace every `sf scanner run` with `sf code-analyzer run`. Note CLI flag changes:

   | v4 flag | v5 equivalent |
   |---|---|
   | `--target` | `--workspace` |
   | `--engine` | (auto-detected, or use `--rule-selector` per engine) |
   | `--format html` | `--view detail --output-file <file>.html` |
   | `--format json` | `--output-file <file>.json` |
   | `--severity-threshold` | `--severity-threshold` (unchanged but values are now 1-5) |
   | `--category` | `--rule-selector` |

3. **AppExchange profile invocation:**
   ```yaml
   # Before
   sf scanner run \
       --target "force-app" \
       --category "Security,AppExchange" \
       --format html \
       --outfile "scanner-reports/code-analyzer-appexchange.html"

   # After
   sf code-analyzer run \
       --workspace "force-app" \
       --rule-selector "Security,AppExchange" \
       --output-file "scanner-reports/code-analyzer-appexchange.html" \
       --output-file "scanner-reports/code-analyzer-appexchange.json"
   ```

4. **SARIF output for CodeQL upload:**
   ```yaml
   sf code-analyzer run \
       --workspace force-app \
       --output-file scanner-results.sarif
   ```

**Verify:**
```bash
grep -n "sfdx-scanner\|sf scanner run" .github/workflows/elaro-ci.yml
# Expected: 0 hits

grep -n "code-analyzer\|sf code-analyzer run" .github/workflows/elaro-ci.yml
# Expected: ≥3 hits
```

Push the branch; the CI workflow runs. Confirm `security-scan` job green.

**Stop and ask if:** v5 finds new violations that v4 didn't. The v5 ruleset is broader. Triage before suppressing.

**PR title:** `chore(ci): migrate security-scan to @salesforce/plugin-code-analyzer v5`

---

### T4.4 — Add Apex tests job to CI

**Branch:** `codex/fix-t4.4-ci-apex-tests`
**Effort:** 3-4 hours (auth setup is the time sink)

**File:** `.github/workflows/elaro-ci.yml`

Add a new job after `unit-tests`:

```yaml
  apex-tests:
    name: Apex Tests
    needs: code-quality
    runs-on: ubuntu-latest
    timeout-minutes: 30
    steps:
      - uses: actions/checkout@v4

      - name: Setup Salesforce CLI
        run: |
          npm install -g @salesforce/cli
          sf --version

      - name: Authenticate DevHub
        env:
          DEVHUB_AUTH_URL: ${{ secrets.DEVHUB_AUTH_URL }}
        run: |
          echo "$DEVHUB_AUTH_URL" > devhub-auth.txt
          sf org login sfdx-url --sfdx-url-file devhub-auth.txt --alias devhub --set-default-dev-hub

      - name: Create scratch org
        run: |
          sf org create scratch \
              --definition-file config/project-scratch-def.json \
              --duration-days 1 \
              --alias ci-scratch \
              --set-default \
              --wait 15

      - name: Deploy source
        run: sf project deploy start --target-org ci-scratch --wait 30

      - name: Run Apex tests
        run: |
          sf apex run test \
              --target-org ci-scratch \
              --test-level RunLocalTests \
              --code-coverage \
              --result-format json \
              --output-dir apex-test-results \
              --wait 30

      - name: Enforce coverage threshold
        run: |
          COVERAGE=$(jq '.result.summary.testRunCoverage | rtrimstr("%") | tonumber' apex-test-results/test-result-*.json)
          echo "Coverage: $COVERAGE%"
          if (( $(echo "$COVERAGE < 85" | bc -l) )); then
            echo "::error::Apex coverage $COVERAGE% is below 85% threshold"
            exit 1
          fi

      - name: Delete scratch org
        if: always()
        run: sf org delete scratch --target-org ci-scratch --no-prompt
```

**Required GitHub Secret:** `DEVHUB_AUTH_URL`. Generate locally with:
```bash
sf org display --target-org <devhub-alias> --verbose --json | jq -r '.result.sfdxAuthUrl'
```

Add as a repository secret in Settings → Secrets → Actions.

**Verify:** push branch; new `Apex Tests` job appears in the CI matrix and runs green. The build-success job at the bottom of the file should already gate on this via the `needs:` chain — verify or add `apex-tests` to its `needs:` list.

**Stop and ask if:** DevHub credentials are not available — this requires the human's access. Open an issue requesting the secret.

**PR title:** `chore(ci): add Apex tests job with scratch org and 85% coverage gate`

---

## SPRINT 4 — Governor & Final Scan

### T5.1 — OrchestrationScanQueueable Finalizer + AsyncOptions

**Branch:** `codex/fix-t5.1-orchestration-finalizer`
**Effort:** 2-3 hours

**File:** `force-app/main/default/classes/OrchestrationService.cls` (around line 303)

**Add a Finalizer inner class:**
```apex
public class OrchestrationScanFinalizer implements Finalizer {
    private String scanId;
    private List<String> frameworks;
    private Integer attemptNumber;

    public OrchestrationScanFinalizer(String scanId, List<String> frameworks, Integer attemptNumber) {
        this.scanId = scanId;
        this.frameworks = frameworks;
        this.attemptNumber = attemptNumber;
    }

    public void execute(FinalizerContext ctx) {
        if (ctx.getResult() == ParentJobResult.UNHANDLED_EXCEPTION) {
            ElaroLogger.error(
                'OrchestrationScanQueueable',
                'Scan ' + scanId + ' attempt ' + attemptNumber + ' failed with UNHANDLED_EXCEPTION',
                ctx.getException()?.getStackTraceString()
            );

            // Retry once with exponential backoff via depth-limited enqueue
            if (attemptNumber < 2) {
                AsyncOptions retryOptions = new AsyncOptions();
                retryOptions.setMaximumQueueableStackDepth(5);
                System.enqueueJob(
                    new OrchestrationScanQueueable(scanId, frameworks, attemptNumber + 1),
                    retryOptions
                );
            }
        }
    }
}
```

**Modify `OrchestrationScanQueueable`:**

1. Add `attemptNumber` field with default `1` for backwards compat:
   ```apex
   private Integer attemptNumber;

   public OrchestrationScanQueueable(String scanId, List<String> frameworks) {
       this(scanId, frameworks, 1);
   }

   public OrchestrationScanQueueable(String scanId, List<String> frameworks, Integer attemptNumber) {
       this.scanId = scanId;
       this.frameworks = frameworks;
       this.attemptNumber = attemptNumber;
   }
   ```

2. Attach Finalizer in `execute()`:
   ```apex
   public void execute(QueueableContext context) {
       System.attachFinalizer(new OrchestrationScanFinalizer(scanId, frameworks, attemptNumber));

       try {
           // existing body
       } catch (Exception e) {
           // existing handling — Finalizer also fires on uncaught, so let it propagate if you want retry
           ElaroLogger.error('OrchestrationScanQueueable',
               'Scan ' + scanId + ' failed: ' + e.getMessage(),
               e.getStackTraceString());
           throw e;  // CHANGED: was silently swallowed; throw to trigger Finalizer retry
       }
   }
   ```

3. Add a `enqueueWithDuplicatePrevention` static helper:
   ```apex
   public static Id enqueueWithDuplicatePrevention(String scanId, List<String> frameworks) {
       AsyncOptions options = new AsyncOptions();
       options.setMaximumQueueableStackDepth(5);
       options.DuplicateSignature = QueueableDuplicateSignature.Builder()
           .addString(scanId)
           .build();
       return System.enqueueJob(new OrchestrationScanQueueable(scanId, frameworks), options);
   }
   ```

**Update callers** — anywhere `new OrchestrationScanQueueable(...)` is constructed and enqueued, replace with `OrchestrationScanQueueable.enqueueWithDuplicatePrevention(scanId, frameworks)`.

**Verify:**
```bash
grep -n "OrchestrationScanFinalizer\|attachFinalizer\|DuplicateSignature" force-app/main/default/classes/OrchestrationService.cls
# Expected: ≥3 hits (finalizer class, attachFinalizer call, duplicate signature builder)
```

**PR title:** `feat(orchestration): add Finalizer retry and duplicate prevention to OrchestrationScanQueueable`

---

### T5.2 — LIMIT clauses on bounded queries

**Branch:** `codex/fix-t5.2-query-limits`
**Effort:** 1-2 hours

The agent flagged "3 unbounded queries". My re-grep shows most flagged hits are bounded-by-Id-IN-collection or single-record lookups by Id. The genuinely unbounded ones need LIMIT.

**Identify candidates:**
```bash
# Find SOQL queries in production classes that have WHERE clauses but no LIMIT
# (excludes test cleanup, aggregate queries, getRecordById patterns)
grep -rEn "\[SELECT [^]]+ FROM [A-Za-z_]+(__c)? WHERE [^]]+\]" force-app/main/default/classes/*.cls \
    | grep -v "LIMIT\|Test\.cls\|WHERE Id = :\|WHERE Id IN :" \
    | head -10
```

For each genuinely-unbounded match:
- If the business intent is "all matching records", add `LIMIT 10000` (or smaller for known-bounded use cases).
- If the intent is "first match", add `LIMIT 1`.
- If iterating, replace with cursor pattern.

Example:
```apex
// Before
List<Compliance_Score__c> scores = [SELECT Id, Score__c FROM Compliance_Score__c WHERE Framework__c = :fw WITH USER_MODE];

// After
List<Compliance_Score__c> scores = [SELECT Id, Score__c FROM Compliance_Score__c WHERE Framework__c = :fw WITH USER_MODE LIMIT 10000];
```

**Verify:**
```bash
grep -rEn "\[SELECT [^]]+ FROM [A-Za-z_]+(__c)? WHERE [^]]+\]" force-app/main/default/classes/*.cls \
    | grep -v "LIMIT\|Test\.cls\|WHERE Id = :\|WHERE Id IN :\|getQueryLocator" \
    | wc -l
# Expected: 0 or only genuinely-bounded patterns
```

**PR title:** `perf(soql): add LIMIT to unbounded queries`

---

### T5.3 — Replace non-selective LIKE query

**Branch:** `codex/fix-t5.3-selective-like`
**Effort:** 2-3 hours (depending on data model)

**Locate the offender:**
```bash
grep -rn "LIKE\s*'%" force-app/main/default/classes/*.cls | grep -v "Test\.cls"
```

For each `LIKE '%foo%'` pattern (leading wildcard = non-selective):
- Add an indexed boolean/picklist field to support a selective filter, OR
- Pre-compute a normalized search-index field via trigger, OR
- Route the search through SOSL `FIND :term IN ALL FIELDS RETURNING Object__c(...)` if full-text search is the intent.

**Stop and ask if:** the LIKE is on small lookup tables (< 1000 rows) — the query may be fine in practice; document the rationale in code comments and skip.

**PR title:** `perf(soql): replace non-selective LIKE with indexed selective filter`

---

### T5.8 — Final scanner clean run

**Branch:** `codex/fix-t5.8-scanner-clean`
**Effort:** Variable (depends on what's found)

After all other tiers land:

```bash
sf code-analyzer run \
    --workspace force-app \
    --severity-threshold 2 \
    --output-file scanner-reports/final-pre-appexchange.html \
    --view detail
```

Zero severity-1 (HIGH) findings is the AppExchange gate. If anything HIGH remains:
- Triage: real issue vs false positive
- Fix real issues
- Suppress false positives via `.code-analyzer.yaml` with documented reason

**Verify:**
```bash
sf code-analyzer run --workspace force-app --severity-threshold 1 --view summary
# Expected: 0 violations at severity 1
```

**PR title:** `chore(scanner): final Code Analyzer pre-AppExchange clean run`

---

## Sequencing Cheat-sheet

```
T0.1 (human, DevHub) ────┐
                         ├──> T0.3 (1 line edit)
                         │
T1.1 (Logger) ────┬────> T1.5 (HIPAA, needs durable logger)
                  ├────> T1.6 verify (CI gate)
                  ├────> T2.4 trigger test (uses publishedEvents)
                  └────> Sprint 2 T2.1/T2.2/T2.3 (parallel)
                  
T1.4 (CursorStep) — independent, ship anytime
                  
T3.2 (FeatureFlags) ────> T3.4 (orphan PE cleanup, only after T1.1 secures LogEvent__e)

T4.1 (LWC labels) ──── 19 independent PRs, parallel
T4.2 (PS diff) ──── independent
T4.3 (CI v5) ────> T4.4 (Apex CI) ────> T5.8 (final scanner)

T5.1 (Orchestration) — independent
T5.2/T5.3 (queries) — independent
```

## Per-PR universal checklist

- [ ] One task, one PR
- [ ] PR description references the finding ID from `.review-state/*-findings.json`
- [ ] Acceptance grep commands from this prompt run cleanly
- [ ] `npm run precommit` passes locally
- [ ] Apex tests (when scratch available): `sf apex run test --test-level RunLocalTests --code-coverage` shows touched classes at ≥85%
- [ ] No regression in 900-test Jest suite
- [ ] No new dependencies added unless task explicitly requires them
- [ ] Commit message follows existing repo style (see `git log --oneline -10`)
