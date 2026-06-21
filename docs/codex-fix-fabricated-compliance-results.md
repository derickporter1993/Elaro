# Codex Fix Plan — Fabricated Compliance Results

> **Branch:** `codex/fix-fabricated-compliance-results` from current `main`
> **Scope:** 4 sites in 3 production classes that report fabricated PASS / placeholder scores / no-op detection in live compliance code paths. For a court-defensible compliance product, shipping `result.passed = true; // Simplified check` is a legal-exposure class of defect, not a bug class — a regulator asking "how did this control pass?" is the failure mode this fix prevents.
> **Standard violated:** `CLAUDE.md` future standard #1 ("no fabricated compliance results"). Standards-gate 5 in `scripts/standards-gates.sh` catches this pattern; the gate has to stay in report-only mode until this backlog clears.
> **Estimated effort:** ~1 week per framework, executable one framework at a time as separate PRs into the fix branch.
> **Required prerequisite:** `Compliance_Audit_Gap__e` Platform Event must exist (HighVolume, PublishImmediately). If not present at HEAD, create it as part of the first PR — schema below in §0.

## Pattern: the two acceptable resolutions per site

For every flagged site, the fix is ONE of:

**Pattern A — Real implementation** (preferred). Compute the result from actual signals: `SecuritySettings`, `Profile`, `PermissionSet`, `LoginHistory`, `SetupAuditTrail`, `OrgWideEmailAddress`, `SessionSettings`, the relevant `__History` object, `Network`/`Site` config, etc. Use Tooling API via the existing `ToolingApiService.queryTooling()` pattern when SOQL-out-of-reach.

**Pattern B — Honest `NOT_EVALUATED`** (acceptable). When the implementation isn't built yet, set:
```apex
result.passed = null;                // not false — false means "evaluated and failed"
result.status = 'NOT_EVALUATED';
result.finding = 'This control requires manual review until automated evaluation is implemented. See Compliance_Audit_Gap__e for tracking.';
result.score = 0;                    // do NOT contribute to composite score
```
AND publish a `Compliance_Audit_Gap__e` Platform Event so the gap is surfaced on the compliance dashboard, not hidden:
```apex
EventBus.publish(new Compliance_Audit_Gap__e(
    Framework__c = 'HIPAA',
    Regulation_Reference__c = '45 CFR 164.312(d)',
    Source_Class__c = 'HIPAAModule',
    Source_Method__c = 'evaluateAuthentication',
    Error_Detail__c = 'Control not yet automated — manual evaluation required',
    Timestamp__c = System.now()
));
```

**Forbidden:** `result.passed = true` with a placeholder comment. **Forbidden:** silently returning `[]` from a detector that ships as "AI anomaly detection." Either implement, or be honest.

## §0 — Prerequisite (PR 1 of N): Compliance_Audit_Gap__e Platform Event

If `force-app/main/default/objects/Compliance_Audit_Gap__e/` does not exist at branch base, create it. Schema:

| Field | Type | Required |
|---|---|---|
| `Framework__c` | Text(40) | yes |
| `Regulation_Reference__c` | Text(80) | no |
| `Source_Class__c` | Text(80) | yes |
| `Source_Method__c` | Text(80) | yes |
| `Record_Id__c` | Text(18) | no |
| `Object_Name__c` | Text(80) | no |
| `Error_Detail__c` | LongTextArea(32768) | no |
| `Timestamp__c` | DateTime | yes |

Event-level config: `eventType = HighVolume`, `publishBehavior = PublishImmediately`. Same shape as the existing `LogEvent__e` (if it exists) — match its `.object-meta.xml` style exactly. **Verification:** `xmllint --noout` on every field-meta.xml and the object-meta.xml.

## §1 — HIPAAModule.cls:266-275 (evaluateAuthentication)

**File:** `force-app/main/default/classes/HIPAAModule.cls:266-275`
**Control:** HIPAA Security Rule, 45 CFR 164.312(d) — Person or Entity Authentication
**Current:**
```apex
private IComplianceModule.ControlResult evaluateAuthentication(Id auditPackageId) {
    IComplianceModule.ControlResult result = new IComplianceModule.ControlResult();
    result.controlId = '164.312(d)';
    // Check organization security settings
    result.passed = true; // Simplified check
    result.score = 85;
    result.status = 'PARTIAL';
    result.finding = 'Authentication controls in place. Recommend reviewing MFA enforcement.';
```
**Pattern A (preferred):** the data IS available — `SecuritySettings` (via Tooling API: `SELECT SessionSettings.RequireSecuretransactions, PasswordPolicies, NetworkAccess FROM SecuritySettings`), `Profile.UserType` filtering, and `SessionSettings.SessionTimeout`. Compute the real score:
- Query `PermissionSet` records with `PermissionsAuthorApex = true` or that grant `MultiFactorAuth-enforcing` permissions; count users assigned vs total active users
- Query `SetupAuditTrail` for `Section IN ('Identity Verification','Session Settings')` in last 90 days
- `result.passed = (mfaCoverage >= 0.95 && sessionTimeoutMin <= 120 && hasIpRestrictions);`
- Score weighted: 40% MFA coverage, 30% session config, 20% IP restrictions, 10% audit trail recency
**Pattern B fallback:** if Tooling API is out-of-scope this sprint, use Pattern B. Issue a Compliance_Audit_Gap event with `Regulation_Reference__c = '45 CFR 164.312(d)'`.
**Acceptance:** the line `result.passed = true; // Simplified check` is gone. New `HIPAAModuleTest.shouldEvaluateAuthenticationFromRealSignals` (or `shouldReportNOT_EVALUATEDWithGapEvent` for Pattern B) asserts the computed value matches the input state.

## §2 — HIPAASecurityRuleService.cls:284 (validationRulesEnabled)

**File:** `force-app/main/default/classes/HIPAASecurityRuleService.cls:284`
**Control:** HIPAA Security Rule, 45 CFR 164.312(c)(1) — Integrity
**Current:**
```apex
// Check for validation rules on PHI objects
result.validationRulesEnabled = true; // Simplified check
```
**Pattern A:** query the Tooling API for `ValidationRule` records where `EntityDefinitionId` is in the PHI object allowlist (defined in `HIPAAPrivacyRuleService.PHI_OBJECTS`):
```apex
String soql = 'SELECT EntityDefinitionId, Active FROM ValidationRule WHERE Active = true ' +
              'AND EntityDefinition.QualifiedApiName IN :phiObjectNames';
Map<String, Object> resp = ToolingApiService.queryTooling(soql);
result.validationRulesEnabled = ((Integer) ((Map<String, Object>) resp.get('totalSize'))) >= phiObjectNames.size();
```
If `false`, append the missing objects to `result.gaps`.
**Acceptance:** the `// Simplified check` comment is gone; `HIPAASecurityRuleServiceTest` has a test that mocks `ToolingApiService.queryTooling` and asserts both `true` and `false` branches.

## §3 — AIGovernanceService.cls:113 (transparencyScore)

**File:** `force-app/main/default/classes/AIGovernanceService.cls:108-115`
**Standard:** EU AI Act Article 13 — Transparency; NIST AI RMF Govern-1.4
**Current:**
```apex
Decimal registrationScore = detectedCount > 0 ?
    (Decimal.valueOf(registeredCount) / Decimal.valueOf(detectedCount)) * 40 : 40;
Decimal classificationScore = registeredCount > 0 ?
    (Decimal.valueOf(classifiedCount) / Decimal.valueOf(registeredCount)) * 30 : 0;
// Check for oversight records (placeholder for actual oversight validation)
Decimal oversightScore = oversightCount > 0 ? 20 : 0;
Decimal transparencyScore = 10; // Placeholder

return registrationScore + classificationScore + oversightScore + transparencyScore;
```
**Pattern A:** compute transparency from real fields on `AI_System_Registry__c`. The audit indicates this object exists; transparency-relevant fields likely include `Model_Card_URL__c`, `Data_Sources_Documented__c`, `Explainability_Method__c`, `Bias_Assessment_Completed__c`, `User_Notification_Enabled__c`. Score 0-10 based on count populated:
```apex
Decimal transparencyScore = 0;
for (AI_System_Registry__c sys : registeredSystems) {
    Integer transparencyFields = 0;
    if (String.isNotBlank(sys.Model_Card_URL__c)) transparencyFields++;
    if (sys.Data_Sources_Documented__c == true) transparencyFields++;
    if (String.isNotBlank(sys.Explainability_Method__c)) transparencyFields++;
    if (sys.Bias_Assessment_Completed__c == true) transparencyFields++;
    if (sys.User_Notification_Enabled__c == true) transparencyFields++;
    transparencyScore += (transparencyFields / 5.0) * 10;
}
transparencyScore = registeredSystems.isEmpty() ? 0 : transparencyScore / registeredSystems.size();
```
**Stop and ask:** field names above are inferences from EU AI Act Article 13 requirements; the actual `AI_System_Registry__c` field schema is on the user side. **Codex must first read `force-app/main/default/objects/AI_System_Registry__c/fields/` and adapt the field list to what's actually present**. If the object lacks transparency fields entirely, that's a meta-finding — either add the fields (a schema change, separate PR) or apply Pattern B with a Compliance_Audit_Gap publish.
**Acceptance:** the `// Placeholder` comment is gone; new test sets `AI_System_Registry__c` records with varying transparency-field completeness and asserts the score reflects them.

## §4 — AnomalyDetectionService.cls:108-117 (detectUnusualAccessPatterns)

**File:** `force-app/main/default/classes/AnomalyDetectionService.cls:108-117`
**Surface:** `@AuraEnabled detectAnomalies` advertises "anomaly detection"; this sub-detector silently returns `[]` so its anomaly class is *never* surfaced.
**Current:**
```apex
private static List<Anomaly> detectUnusualAccessPatterns(Datetime startDate) {
    List<Anomaly> anomalies = new List<Anomaly>();
    // Simplified - in production, analyze login patterns, API usage, etc.
    // For now, return empty list
    return anomalies;
}
```
**Pattern A:** query `LoginHistory` for the time window and flag:
- Logins from countries the user hasn't logged in from in the prior 90 days
- > 3 failed logins in 15 minutes for the same UserId
- Successful logins outside `User.TimeZoneSidKey`-derived business hours (>2σ from the user's modal login hour)
- `LoginGeo` mismatch with prior session

Each match → `new Anomaly(type='UNUSUAL_ACCESS', severity, description, entityId, detectedDate)`.

Concrete starter query:
```apex
List<LoginHistory> recent = [
    SELECT UserId, LoginTime, SourceIp, Status, CountryIso
    FROM LoginHistory
    WHERE LoginTime >= :startDate
      AND Status != 'Success'
    WITH USER_MODE
    ORDER BY UserId, LoginTime
    LIMIT 5000
];
```
**Pattern B fallback:** if `LoginHistory` access requires elevated permission unavailable to the running user, transition to NOT_EVALUATED + Compliance_Audit_Gap publish, and **remove the call** from `detectAnomalies` (line 41) so the surface honestly reflects what's analyzed — better to say "we detect 2 anomaly classes" than to silently ship 3 of which 1 is dead.
**Acceptance:** the `// For now, return empty list` comment is gone; new `AnomalyDetectionServiceTest.shouldDetectFailedLoginBurst` and `shouldDetectGeoAnomaly` tests insert `LoginHistory` records (or mock via test factory) and assert the returned anomalies.

## Per-PR checklist (every framework PR)

- [ ] Pattern A or Pattern B applied — no `passed = true; // Simplified` survives
- [ ] If Pattern B: `Compliance_Audit_Gap__e` published; the metric is excluded from composite scoring (does not add to total)
- [ ] Tests cover both the new compute path AND the gap-event publish path
- [ ] `grep -nE "passed\s*=\s*true;\s*//\s*(Simplified|Placeholder)" force-app/main/default/classes/` — zero hits in scope of the PR
- [ ] `npm run test:unit` — 900/900 stays green (Jest unaffected; Apex is CI-gated)
- [ ] Standards-gate 5 either clears (if all sites in the file are fixed) OR shows reduced count
- [ ] CLAUDE.md `## STANDARDS ADDED FROM THE 2026-06-05 AUDIT` section #1 — confirm wording matches what's enforced

## Sequencing

PR 1: §0 prerequisite (Compliance_Audit_Gap__e schema, if needed) — 30 min
PR 2: §1 HIPAAModule — 1-2 days (Tooling API integration is the longest pole)
PR 3: §2 HIPAASecurityRuleService — 0.5 day (single site, same Tooling pattern as PR 2)
PR 4: §3 AIGovernanceService — 0.5 day after Codex reads the actual field schema
PR 5: §4 AnomalyDetectionService — 1-2 days (LoginHistory query + 2-3 anomaly detection algorithms)

Total: ~1 week of focused work, 5 PRs, each independently mergeable.

## Stop-and-ask triggers (Codex must pause for the user)

- **§1 / §2** — if `ToolingApiService.queryTooling()` is not available at HEAD (it was added in a prior session that may not have landed). Verify presence; if missing, this becomes a 2-PR chain (build the Tooling service first).
- **§3** — before composing the new `transparencyScore` formula, read the actual `AI_System_Registry__c` field schema and propose the field list to the user. The 5 fields cited above are inferences from the EU AI Act Article 13, not from the repo.
- **§4** — Pattern A requires `LoginHistory` access; some compliance tiers don't grant it to the running user. Confirm the running-user permission model before implementing Pattern A vs falling back to Pattern B.
