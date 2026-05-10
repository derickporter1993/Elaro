# AGENT 8: INTEGRATION, QA & LAUNCH

**Timeline**: Q4, Weeks 47-52 (6 weeks)
**Package**: Both Elaro 2GP + Health Check 2GP
**Directory**: force-app/ + force-app-healthcheck/
**Priority**: CRITICAL PATH — AppExchange launch blocker

---

## Mission

Integrate all Team 1 and Team 2 modules, execute comprehensive QA (security, performance, accessibility),
and prepare both packages for AppExchange security review and public launch.

---

## Build Order (Sequential Execution Required)

### Week 47: API Version Upgrade + Integration Wiring

#### Task 1: Upgrade All v65.0 Classes to v66.0

**Objective**: Ensure all Apex classes use Spring '26 API version

```bash
# Find all v65.0 classes
find force-app -name "*.cls-meta.xml" -exec grep -l "65.0" {} \;
find force-app-healthcheck -name "*.cls-meta.xml" -exec grep -l "65.0" {} \;

# Update to v66.0
find force-app -name "*.cls-meta.xml" -exec sed -i '' 's/<apiVersion>65.0/<apiVersion>66.0/g' {} \;
find force-app-healthcheck -name "*.cls-meta.xml" -exec sed -i '' 's/<apiVersion>65.0/<apiVersion>66.0/g' {} \;
```

**Validation**: Run Code Analyzer after upgrade to catch breaking changes

```bash
sf scanner run --target force-app --format table --severity-threshold 1
sf scanner run --target force-app-healthcheck --format table --severity-threshold 1
```

#### Task 2: Wire Command Center to Team 1 Orchestration Engine

**File**: `force-app/main/default/classes/CommandCenterController.cls`

**Integration Points**:
1. **Compliance Context Engine** → **Team 1 Rule Engine** (read rule execution results)
2. **Action Execution** → **Team 1 Orchestration Engine** (enqueue compliance actions)

```apex
// INTEGRATION EXAMPLE (add to CommandCenterController.cls)

/**
 * Executes a compliance action by delegating to the Orchestration Engine.
 *
 * @param actionId Compliance_Action__mdt DeveloperName
 * @param contextRecordId Optional Compliance_Finding__c or Control__c Id
 * @return Orchestration Job Id for tracking
 * @throws AuraHandledException if Orchestration Engine unavailable
 */
@AuraEnabled
public static String executeComplianceAction(String actionId, String contextRecordId) {
    try {
        // Verify Orchestration Engine is available (Team 1 dependency)
        if (!FeatureFlags.isOrchestrationEngineEnabled()) {
            throw new AuraHandledException('Orchestration Engine not available. Please contact your administrator.');
        }

        // Retrieve action metadata
        Compliance_Action__mdt action = [
            SELECT DeveloperName, Action_Type__c, Target_Object__c, Automation_Class__c
            FROM Compliance_Action__mdt
            WHERE DeveloperName = :actionId
            WITH USER_MODE
            LIMIT 1
        ];

        // Delegate to Orchestration Engine (Team 1)
        // ASSUMPTION: Team 1 provides ComplianceOrchestrationService.cls
        String jobId = ComplianceOrchestrationService.enqueueAction(
            action.Automation_Class__c,
            new Map<String, Object>{
                'actionId' => actionId,
                'contextRecordId' => contextRecordId,
                'triggeredBy' => UserInfo.getUserId()
            }
        );

        ElaroLogger.info('CommandCenterController.executeComplianceAction',
            'Action queued: ' + actionId + ', JobId: ' + jobId);

        return jobId;

    } catch (Exception e) {
        ElaroLogger.error('CommandCenterController.executeComplianceAction',
            e.getMessage(), e.getStackTraceString());
        throw new AuraHandledException('Unable to execute action: ' + e.getMessage());
    }
}
```

**Test Coverage**: `CommandCenterControllerTest.cls` (mock ComplianceOrchestrationService response)

#### Task 3: Wire Assessment Wizard Auto-Scan to Team 1 Rule Engine

**File**: `force-app/main/default/classes/AssessmentWizardService.cls`

**Integration Points**:
1. **Auto-Scan Step** → **Team 1 Rule Engine** (execute control validation rules)
2. **Session State** → **Team 1 Cursor Framework** (bulk control processing)

```apex
// INTEGRATION EXAMPLE (add to AssessmentWizardService.cls)

/**
 * Executes automated control validation for the current wizard step.
 * Delegates to Rule Engine for bulk control evaluation.
 *
 * @param sessionId Compliance_Assessment_Session__c Id
 * @return List of auto-scan results (pass/fail/not-applicable)
 * @throws AuraHandledException if Rule Engine unavailable
 */
public static List<ControlScanResult> executeAutoScan(Id sessionId) {
    try {
        // Retrieve session state
        Compliance_Assessment_Session__c session = [
            SELECT Id, Current_Step__c, Framework__c, Session_State__c
            FROM Compliance_Assessment_Session__c
            WHERE Id = :sessionId
            WITH USER_MODE
            LIMIT 1
        ];

        // Parse session state to get control references for current step
        Map<String, Object> state = (Map<String, Object>) JSON.deserializeUntyped(session.Session_State__c);
        List<String> controlRefs = (List<String>) state.get('currentStepControlReferences');

        // Verify Rule Engine is available (Team 1 dependency)
        if (!FeatureFlags.isRuleEngineEnabled()) {
            throw new AuraHandledException('Rule Engine not available. Manual assessment required.');
        }

        // Delegate to Rule Engine (Team 1)
        // ASSUMPTION: Team 1 provides ComplianceRuleService.cls
        List<ControlScanResult> results = ComplianceRuleService.evaluateControls(
            controlRefs,
            session.Framework__c,
            new Map<String, Object>{
                'sessionId' => sessionId,
                'scanType' => 'WIZARD_AUTO_SCAN'
            }
        );

        // Update session state with scan results
        state.put('autoScanResults', results);
        session.Session_State__c = JSON.serialize(state);
        update as user session;

        ElaroLogger.info('AssessmentWizardService.executeAutoScan',
            'Scanned ' + controlRefs.size() + ' controls for session: ' + sessionId);

        return results;

    } catch (Exception e) {
        ElaroLogger.error('AssessmentWizardService.executeAutoScan',
            e.getMessage(), e.getStackTraceString());
        throw new AuraHandledException('Auto-scan failed: ' + e.getMessage());
    }
}
```

**Test Coverage**: `AssessmentWizardServiceTest.cls` (mock ComplianceRuleService response)

#### Task 4: Wire Event Monitoring to Team 1 Rule Engine Results

**File**: `force-app/main/default/classes/EventCorrelationEngine.cls`

**Integration Points**:
1. **Platform Event Subscriber** → **Team 1 Rule Engine Results** (ComplianceAlert__e triggered by rule violations)
2. **Correlation Rules** → **Big Object Storage** (EventWindowService writes to Compliance_Event_Window__b)

```apex
// INTEGRATION EXAMPLE (add to EventCorrelationEngine.cls)

/**
 * Subscribes to Compliance_Alert__e events and correlates them against
 * Correlation_Rule__mdt patterns. Triggered by Team 1 Rule Engine violations.
 *
 * Runs in system context (without sharing) to ensure event processing succeeds
 * regardless of the triggering user's record access.
 */
public without sharing class EventCorrelationEngine {

    /**
     * Processes incoming compliance alerts and checks for breach patterns.
     * Called by Platform Event trigger: ComplianceAlertTrigger.trigger
     *
     * @param alerts List of ComplianceAlert__e events
     */
    public static void processAlerts(List<ComplianceAlert__e> alerts) {
        try {
            // Store alerts in Big Object for time-window correlation
            List<Compliance_Event_Window__b> eventRecords = new List<Compliance_Event_Window__b>();

            for (ComplianceAlert__e alert : alerts) {
                Compliance_Event_Window__b eventRecord = new Compliance_Event_Window__b();
                eventRecord.Event_Type__c = alert.Alert_Type__c;
                eventRecord.Framework__c = alert.Framework__c;
                eventRecord.Severity__c = alert.Severity__c;
                eventRecord.Timestamp__c = Datetime.now();
                eventRecord.Source_Record_Id__c = alert.Source_Record_Id__c;
                eventRecord.Event_Data__c = JSON.serialize(alert); // Full event as JSON
                eventRecords.add(eventRecord);
            }

            // Immediate insert (Big Objects don't support DML options)
            Database.insertImmediate(eventRecords);

            // Correlate against active Correlation_Rule__mdt patterns
            List<Correlation_Rule__mdt> activeRules = [
                SELECT Id, Rule_Name__c, Event_Sequence__c, Time_Window_Minutes__c, Severity__c
                FROM Correlation_Rule__mdt
                WHERE Is_Active__c = true
                WITH USER_MODE
            ];

            for (Correlation_Rule__mdt rule : activeRules) {
                checkPatternMatch(rule, alerts);
            }

        } catch (Exception e) {
            ElaroLogger.error('EventCorrelationEngine.processAlerts',
                e.getMessage(), e.getStackTraceString());
            // Do NOT throw — event processing must be resilient
        }
    }

    private static void checkPatternMatch(Correlation_Rule__mdt rule, List<ComplianceAlert__e> newAlerts) {
        // Parse Event_Sequence__c (JSON array of event types)
        List<String> requiredSequence = (List<String>) JSON.deserialize(
            rule.Event_Sequence__c, List<String>.class
        );

        // Query Big Object for events within time window
        Datetime windowStart = Datetime.now().addMinutes(-1 * Integer.valueOf(rule.Time_Window_Minutes__c));

        List<Compliance_Event_Window__b> recentEvents = [
            SELECT Event_Type__c, Timestamp__c, Event_Data__c
            FROM Compliance_Event_Window__b
            WHERE Timestamp__c >= :windowStart
            ORDER BY Timestamp__c DESC
        ];

        // Pattern matching logic (sequence detection)
        if (matchesSequence(recentEvents, requiredSequence)) {
            publishBreachIndicator(rule, recentEvents);
        }
    }

    private static Boolean matchesSequence(List<Compliance_Event_Window__b> events, List<String> sequence) {
        // Simplified pattern matching (real implementation: sliding window algorithm)
        Integer matchCount = 0;
        for (Compliance_Event_Window__b event : events) {
            if (matchCount < sequence.size() && event.Event_Type__c == sequence[matchCount]) {
                matchCount++;
            }
        }
        return matchCount == sequence.size();
    }

    private static void publishBreachIndicator(Correlation_Rule__mdt rule, List<Compliance_Event_Window__b> matchedEvents) {
        BreachIndicator__e indicator = new BreachIndicator__e();
        indicator.Pattern_Name__c = rule.Rule_Name__c;
        indicator.Severity__c = rule.Severity__c;
        indicator.Event_Sequence__c = JSON.serialize(matchedEvents);
        indicator.Time_Window_Minutes__c = Integer.valueOf(rule.Time_Window_Minutes__c);

        EventBus.publish(indicator);

        ElaroLogger.info('EventCorrelationEngine.publishBreachIndicator',
            'Breach pattern detected: ' + rule.Rule_Name__c);
    }
}
```

**Test Coverage**: `EventCorrelationEngineTest.cls` (mock Platform Event publish, verify Big Object insert)

---

### Week 48: Checkmarx Security Scan + Remediation

#### Task 5: Joint Checkmarx Scan (CRITICAL)

**Objective**: Zero HIGH/CRITICAL findings before AppExchange submission

**Checklist**:
- [ ] Run Checkmarx SAST scan on entire force-app/ directory
- [ ] Run Checkmarx SAST scan on force-app-healthcheck/ directory
- [ ] Export findings report (PDF + CSV)
- [ ] Triage findings with security team
- [ ] Fix ALL CRITICAL and HIGH severity findings
- [ ] Suppress false positives with documented justification
- [ ] Re-scan to verify fixes
- [ ] Archive final clean scan report for AppExchange submission

**Common Vulnerabilities to Watch**:
1. **SOQL Injection**: Dynamic SOQL without `Database.queryWithBinds()`
2. **XSS in LWC**: Unsanitized user input in HTML templates
3. **Hardcoded Secrets**: API keys, tokens in code
4. **Missing FLS/CRUD**: Queries without `WITH USER_MODE` or `as user`
5. **Insecure HTTP**: HTTP callouts without certificate validation
6. **Sensitive Data Exposure**: Debug logs containing PII
7. **Trust Center Guest User**: Over-privileged Sites guest profile

**Remediation SLA**: 2 weeks maximum (Checkmarx findings block launch)

---

### Week 49: End-to-End Testing

#### Task 6: CMMC Workflow Testing

**Test Scenario**: Complete CMMC Level 2 assessment for a fictitious defense contractor

**Steps**:
1. Create scratch org with both packages installed
2. Assign Permission Sets: Elaro_Admin, Elaro_Health_Check_User
3. Load CMMC test data (171 controls)
4. Execute Assessment Wizard: CMMC Level 2
5. Trigger auto-scan (Rule Engine integration)
6. Upload evidence files
7. Route for approval workflow
8. Generate compliance report
9. Verify Command Center shows action items
10. Execute 5 compliance actions (Orchestration Engine)
11. Verify Event Monitoring captures configuration drift

**Success Criteria**: Zero errors, all 171 controls assessed, score calculated, PDF report generated

#### Task 7: SEC Cybersecurity Workflow Testing

**Test Scenario**: Materiality assessment + 8-K filing workflow

**Steps**:
1. Create Materiality_Assessment__c record (ransomware incident)
2. Trigger 4-business-day deadline calculation (validate Holiday__c exclusion)
3. Route through approval process (CISO → Legal → CFO → CEO → Board)
4. Generate disclosure draft
5. Create Disclosure_Workflow__c (Form 8-K)
6. Verify SEC_Control_Mapping__c junctions created
7. Export filing package (PDF + XBRL stub)

**Success Criteria**: Correct deadline, all approvals tracked, filing package complete

#### Task 8: AI Governance Workflow Testing

**Test Scenario**: Einstein Discovery model registration + EU AI Act classification

**Steps**:
1. Deploy Einstein Prediction to scratch org
2. Run AIDetectionEngine.cls (Metadata API scan)
3. Verify AI_System_Registry__c record auto-created
4. Execute AIRiskClassificationEngine.cls (EU AI Act Annex III)
5. Verify Risk_Level__c = "High" (if credit scoring use case)
6. Create AI_Human_Oversight_Record__c (override AI output)
7. Generate AI Governance Report
8. Verify Trust Center shows AI compliance badge

**Success Criteria**: Auto-discovery works, classification accurate, NIST AI RMF mapped

---

### Week 50: Performance + Accessibility Testing

#### Task 9: Performance Testing (500+ Rules, 1000+ Controls)

**Objective**: Ensure platform scales to enterprise customer data volumes

**Test Scenarios**:
1. **Rule Engine Bulk Execution**: 500 active rules, 1000 controls, single scan
2. **Cursor Framework**: Process 10,000 Compliance_Finding__c records
3. **Event Correlation**: 1000 ComplianceAlert__e events in 5 minutes
4. **Trust Center Data Aggregation**: 50 frameworks, 200K control records

**Performance SLAs**:
| Operation | Max Time | Governor Limits |
|-----------|----------|-----------------|
| Rule Engine Scan (500 rules) | 60 seconds | <10K SOQL rows, <200 SOQL queries |
| Cursor Processing (10K records) | 5 minutes | <50 CPU time (cumulative across jobs) |
| Event Correlation (1K events) | 30 seconds | <10 Platform Event publishes/sec |
| Trust Center Aggregation | 10 minutes | <50M Big Object rows queried |

**Tools**:
- Salesforce Event Monitoring (track ApexExecution events)
- Developer Console Debug Logs (LIMITS statements)
- Load testing: `sf apex run --file scripts/performance-test.apex`

**Optimization Techniques** (if SLAs violated):
1. **Reduce SOQL queries**: Bulkify loops, use Maps
2. **Cursor batch size**: Tune from 200 to 1000 rows/fetch
3. **Platform Cache**: Cache Compliance_Rule__mdt for 60 minutes
4. **Asynchronous Processing**: Move heavy queries to Queueable
5. **Big Object Indexes**: Verify Compliance_Event_Window__b indexed on Timestamp__c

#### Task 10: WCAG 2.1 AA Accessibility Audit

**Objective**: Ensure all LWC components meet WCAG 2.1 Level AA standards

**Tools**:
- **axe DevTools** Chrome extension
- **NVDA** screen reader (Windows) / **VoiceOver** (macOS)
- **Keyboard Navigation**: Tab, Shift+Tab, Enter, Esc, Arrow keys

**Test Components**:
1. Health Check Dashboard
2. Compliance Command Center
3. Assessment Wizard
4. SEC Disclosure Dashboard
5. AI Governance Dashboard
6. Trust Center Public View

**WCAG 2.1 AA Checklist** (per component):
- [ ] **1.1.1 Non-text Content**: All images have `alt` text
- [ ] **1.3.1 Info and Relationships**: Semantic HTML (headings, lists, tables)
- [ ] **1.4.3 Contrast (Minimum)**: 4.5:1 for normal text, 3:1 for large text
- [ ] **1.4.11 Non-text Contrast**: 3:1 for UI components (buttons, inputs)
- [ ] **2.1.1 Keyboard**: All functionality accessible via keyboard
- [ ] **2.4.3 Focus Order**: Logical tab order
- [ ] **2.4.7 Focus Visible**: Clear focus indicators
- [ ] **3.2.1 On Focus**: No unexpected context changes
- [ ] **4.1.2 Name, Role, Value**: ARIA labels on custom components

**Common Fixes**:
```html
<!-- BAD: No ARIA label on icon button -->
<lightning-button-icon icon-name="utility:close" onclick={handleClose}></lightning-button-icon>

<!-- GOOD: Descriptive ARIA label -->
<lightning-button-icon icon-name="utility:close" alternative-text="Close dialog" onclick={handleClose}></lightning-button-icon>

<!-- BAD: Color-only severity indicator -->
<div class="severity-high">High Risk</div>

<!-- GOOD: Icon + text + color -->
<lightning-icon icon-name="utility:warning" variant="error" size="x-small"></lightning-icon>
<span class="severity-high">High Risk</span>

<!-- BAD: Custom datatable without ARIA -->
<div class="custom-table">...</div>

<!-- GOOD: Use lightning-datatable (ARIA built-in) -->
<lightning-datatable
    key-field="id"
    data={findings}
    columns={columns}
    aria-label="Compliance findings table">
</lightning-datatable>
```

**Remediation**: Fix all Level A and AA violations before launch

---

### Week 51: Documentation + AppExchange Listing Prep

#### Task 11: AppExchange Security Review Submission

**Required Artifacts** (checklist):
- [ ] **Security Review Application** (Salesforce Partner Portal)
- [ ] **Checkmarx SAST Report** (clean scan, zero HIGH findings)
- [ ] **Code Analyzer Report** (`sf scanner run` output, zero violations)
- [ ] **Test Coverage Report** (85%+ per class, 90%+ overall)
- [ ] **Apex Test Execution Logs** (all tests passing)
- [ ] **Package Installation Guide** (PDF, includes Permission Set assignment)
- [ ] **Data Security Matrix** (documents object-level security, FLS enforcement)
- [ ] **Third-Party Integrations** (if any external APIs used)
- [ ] **GDPR/Privacy Compliance Statement** (data retention, deletion policies)
- [ ] **Accessibility Conformance Report** (WCAG 2.1 AA, VPAT format)

**Security Review SLA**: 10-15 business days (Salesforce team review)

**Common Rejection Reasons** (AVOID):
1. SOQL injection vulnerabilities (use `Database.queryWithBinds()`)
2. Missing FLS checks (use `WITH USER_MODE`, `as user`)
3. Overly permissive Permission Sets (grant minimal access)
4. Hardcoded credentials (use Named Credentials)
5. Sensitive data in debug logs (sanitize `System.debug()`)
6. Guest user over-privileged (Trust Center Sites profile)

#### Task 12: AppExchange Listing Content

**Listing Components** (Salesforce Partner Portal):
1. **App Name**: Elaro Compliance Platform
2. **Tagline**: "Automate compliance across 15+ frameworks with AI-powered risk management"
3. **Description** (500 words):
   - What: Managed package for compliance automation
   - Who: GRC teams, CISOs, Compliance Officers, Auditors
   - Why: Reduce manual compliance work by 80%, pass audits faster
   - How: Rule engine, automated scanning, evidence collection, reporting
   - Frameworks: HIPAA, SOC2, PCI-DSS, GDPR, CMMC, SEC, EU AI Act, ISO 27001, FedRAMP, FINRA, NIS2, DORA
4. **Features List** (12 bullets):
   - Free Security Health Check (lead generation)
   - Compliance Command Center (contextual actions)
   - Event-Driven Monitoring (real-time alerts)
   - Guided Assessment Wizards (reduce assessment time 70%)
   - SEC Cybersecurity Disclosure (4-day deadline automation)
   - AI Governance (EU AI Act + NIST AI RMF)
   - Trust Center (shareable compliance status)
   - Rule Engine (500+ pre-built rules)
   - Evidence Repository (audit-ready documentation)
   - Cross-Framework Mapping (reduce duplicate work)
   - Executive Dashboards (board-ready reports)
   - AppExchange Certified
5. **Screenshots** (10 images, 1280x800):
   - Health Check Dashboard (score gauge)
   - Command Center (action cards)
   - Assessment Wizard (progress tracker)
   - SEC Filing Workflow (materiality assessment)
   - AI System Registry (auto-discovery results)
   - Trust Center Public View (compliance badges)
   - Event Monitoring (alert feed)
   - Rule Engine Configuration
   - Evidence Upload (drag-drop)
   - Executive Dashboard (compliance score trends)
6. **Demo Video** (2 minutes, YouTube):
   - 0:00-0:15 — Problem: Manual compliance is slow, error-prone
   - 0:15-0:45 — Solution: Elaro automates scanning, alerting, reporting
   - 0:45-1:15 — Demo: Health Check → Command Center → Assessment Wizard
   - 1:15-1:45 — Results: 80% time savings, audit-ready in days
   - 1:45-2:00 — CTA: Install free Health Check, upgrade to full platform
7. **Pricing** (per-org subscription):
   - Free: Health Check only
   - Starter: $499/month (HIPAA, SOC2, GDPR)
   - Professional: $999/month (add CMMC, SEC, AI Gov)
   - Enterprise: $1,999/month (all frameworks + white-glove onboarding)
8. **Support** (Salesforce Partner Portal):
   - Email: support@solentra.io
   - Documentation: docs.elaro.app
   - Community: community.elaro.app
   - SLA: 24-hour response (business days)

#### Task 13: Installation Guide

**Document**: `docs/Installation-Guide.pdf`

**Sections**:
1. **Prerequisites**: Enterprise Edition+, API v66.0, My Domain enabled
2. **Package Installation**: AppExchange URL, one-click install
3. **Permission Set Assignment**:
   - Elaro_Admin → Compliance Managers
   - Elaro_User → Auditors, GRC team
   - Elaro_Health_Check_User → All users (optional)
4. **Post-Install Configuration**:
   - Enable Elaro_Feature_Flags__c Custom Setting
   - Configure Compliance_Rule__mdt (activate default rules)
   - Set up Holiday__c records (SEC filing deadline calculation)
   - Configure Trust Center Site (if using public trust page)
5. **Data Migration** (if upgrading from v2.x):
   - Export legacy Compliance_Finding__c records
   - Map to new schema
   - Re-import via Data Loader
6. **Verification Steps**:
   - Run Health Check scan
   - Verify Command Center shows action items
   - Test Assessment Wizard (HIPAA sample)
7. **Troubleshooting**: Common issues (Permission denied, Tooling API errors)

---

### Week 52: Launch Readiness + Final QA

#### Task 14: Final Quality Gates (ALL MUST PASS)

```bash
# Code Analyzer (zero HIGH findings)
sf scanner run --target force-app --format table --severity-threshold 1
sf scanner run --target force-app-healthcheck --format table --severity-threshold 1

# Apex Tests (85%+ per class)
sf apex run test --target-org elaro-dev --test-level RunLocalTests --code-coverage --wait 30

# LWC Jest Tests (all passing)
npm run test:unit

# Linting (max 3 warnings)
npm run lint

# Formatting (no changes)
npm run fmt:check

# WCAG 2.1 AA (zero violations)
# Manual: Run axe DevTools on all dashboards

# Performance (all SLAs met)
# Manual: Execute performance-test.apex script

# Security (clean Checkmarx scan)
# Manual: Verify Checkmarx report has zero HIGH findings
```

#### Task 15: Launch Checklist

**Pre-Launch** (48 hours before):
- [ ] AppExchange security review approved
- [ ] Final package version built (v3.1.0)
- [ ] Installation guide published (docs.elaro.app)
- [ ] Demo video uploaded (YouTube)
- [ ] Support email configured (support@solentra.io)
- [ ] Pricing tiers finalized (Salesforce billing)
- [ ] Marketing site updated (solentra.io/elaro)
- [ ] Press release drafted
- [ ] Social media posts scheduled (LinkedIn, Twitter)

**Launch Day** (go-live):
- [ ] Publish AppExchange listing (make public)
- [ ] Send announcement to Salesforce Partner Newsletter
- [ ] Post on LinkedIn (Derick + Solentra company page)
- [ ] Email existing customers (upgrade offer)
- [ ] Monitor AppExchange reviews (respond within 24 hours)
- [ ] Track installations (Salesforce LMA dashboard)

**Post-Launch** (Week 1):
- [ ] Daily review of support tickets (triage within 4 hours)
- [ ] Monitor Salesforce error logs (setup ElaroLogger alerts)
- [ ] Track NPS score (in-app survey after 7 days)
- [ ] Gather customer feedback (feature requests, bugs)
- [ ] Plan v3.2.0 roadmap (based on Week 1 feedback)

---

## Integration Assumptions (Team 1 Dependencies)

**CRITICAL**: Verify these Team 1 deliverables exist before wiring integration

| Deliverable | Expected Class/API | Fallback Strategy |
|-------------|-------------------|-------------------|
| Orchestration Engine | `ComplianceOrchestrationService.enqueueAction()` | Disable Command Center action execution |
| Rule Engine | `ComplianceRuleService.evaluateControls()` | Manual-only assessments (no auto-scan) |
| Cursor Framework | `Database.Cursor` API (GA Spring '26) | Fall back to Batch Apex (200 records/batch) |
| CMMC Data Model | `CMMC_Control__c` object, 171 control records | Load test data manually |
| NIS2/DORA Rules | `Compliance_Rule__mdt` records for NIS2/DORA | Ship without NIS2/DORA (add in v3.2.0) |

**Risk Mitigation**: All integrations use feature flags (graceful degradation if Team 1 not ready)

---

## Success Criteria (Launch Gate)

- [ ] Zero Checkmarx HIGH/CRITICAL findings
- [ ] Zero Code Analyzer violations (severity 1-3)
- [ ] 90%+ overall Apex test coverage
- [ ] 85%+ per-class Apex test coverage
- [ ] 100% LWC Jest tests passing
- [ ] WCAG 2.1 AA compliant (zero Level A/AA violations)
- [ ] Performance SLAs met (500 rules in <60s, 10K records in <5min)
- [ ] AppExchange security review approved
- [ ] Installation guide published
- [ ] Demo video published
- [ ] Support infrastructure live (email, docs, community)

---

## Agent 8 Execution Prompt

**To Claude Code**: Execute this agent sequentially (Tasks 1-15). After each task, run:

```bash
sf scanner run --target force-app --format table --severity-threshold 1
sf apex run test --target-org elaro-dev --test-level RunLocalTests --wait 10
npm run test:unit
```

Checkpoint progress in `.claude/plans/agent-8-progress.md` after each task.

If a quality gate fails, STOP and remediate before proceeding. Integration bugs are expensive this late.

**Timeline**: 6 weeks. **Deadline**: End of Q4. **No extensions** (AppExchange launch date committed to customers).

---

**End of Agent 8**
