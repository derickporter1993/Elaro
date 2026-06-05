# Elaro — AppExchange Submission Checklist

Pre-submission gates for the things **grep and CI cannot check** — they require human
verification, a registered org, or a manual scan. Each item is tagged with the standard or
audit finding it came from. The mechanizable gates live in `scripts/standards-gates.sh` and
the CI `security-scan` job; this checklist is the human layer on top.

> **Scope rule (CLAUDE.md #0):** every check below applies to **both** package roots —
> `force-app/` (Elaro) and `force-app-healthcheck/` (Elaro Health Check). The worst audit
> finding (`UserInfo.getSessionId()`) shipped because tooling ignored the second root.

---

## 1. Packaging

- [ ] `elaro` namespace registered in the DevHub (Setup → Packaging → Namespaces). *(Audit: CRITICAL AX-001)*
- [ ] `elaroHC` namespace registered; `force-app-healthcheck` packageDirectory has `"namespace": "elaroHC"`. *(CRITICAL AX-002)*
- [ ] `packageAliases` in `sfdx-project.json` hold real Package IDs — no `0HoXXXXXXXXXXXX` placeholder. *(AX-007)*
- [ ] `sf package version create -p "Elaro" --installation-key <key>` succeeds.
- [ ] `sf package version create -p "Elaro Health Check" --installation-key <key>` succeeds.
- [ ] Every object/field/Apex class/LWC/tab is covered by at least one Permission Set (2GP cannot use profiles).

## 2. Security review (the non-greppable gates)

- [ ] **Checkmarx** scan: zero P1/P2 findings (separate workflow from the Solentra scanner).
- [ ] **Code Analyzer** clean over **both** roots: `sf scanner run --target force-app --target force-app-healthcheck --pmdconfig config/pmd-ruleset.xml --severity-threshold 2` → no HIGH.
- [ ] No `UserInfo.getSessionId()` for callout auth — use Named/External Credential. *(Finding: ToolingApiService.cls:40; CLAUDE.md #5)*
- [ ] No Public CMDT carrying executable content (SOQL strings, Apex class names). Verify `Compliance_Rule__mdt`, `Executive_KPI__mdt`, `Framework_Config__mdt` are `<visibility>Protected</visibility>`. *(Finding: Public-CMDT; CLAUDE.md #6)*
- [ ] Every external callout has its auth header wired (no `NoAuthentication` Named Credential masking a missing key). Verify `Elaro_Claude_API`. *(Finding: Claude API no x-api-key; CLAUDE.md #5)*
- [ ] Guest/Site `@RestResource` classes **fail closed** — a blank secret denies, never allows. Verify `JiraWebhookHandler.validateWebhookSecret`. *(Finding: fail-open webhook; CLAUDE.md #3)*
- [ ] No REST handler returns `e.getMessage()` to an external caller. *(Finding: JiraWebhookHandler:69; CLAUDE.md #4)*
- [ ] AI-generated SOQL is parsed (not substring-matched), runs USER_MODE + stripInaccessible, behind a kill switch. Verify `NaturalLanguageQueryService`. *(CLAUDE.md #8)*
- [ ] No placeholder crypto/tokenization in PCI/HIPAA paths. Verify `PCIDataProtectionService`. *(CLAUDE.md #10)*

## 3. Compliance integrity (Elaro is court-defensible — TOP PRIORITY)

- [ ] **No fabricated compliance results.** No control returns a hardcoded `passed = true`, fixed score component (`// Placeholder`/`// Simplified check`), fabricated benchmark, or no-op `[]` detector in a live path. Audit-flagged: `HIPAAModule`, `HIPAASecurityRuleService`, `AIGovernanceService.calculateScore` (+10 transparency), `BenchmarkingService`, `AnomalyDetectionService`. Each must compute from real signals or report `NOT_EVALUATED`. *(CLAUDE.md #1)*
- [ ] No unwired scaffolding ships. Run the dead-code sweep; the audit flagged ~25 orphaned classes (the 10-class `Step` framework, 5 unwired compliance services, 3 never-enqueued queueables, `EventWindowService`, `BenchmarkingService`). Wire or delete. *(CLAUDE.md #2)*

## 4. Test coverage

- [ ] 85%+ per-class Apex coverage in **both** packages: `sf apex run test --test-level RunLocalTests --code-coverage`.
- [ ] No assertion-free test classes (PMD `ApexUnitTestClassShouldHaveAsserts`).
- [ ] LWC Jest suite green: `npm run test:unit`.

## 5. LWC / UX

- [ ] All user-facing strings — **including toast titles/messages** — via `@salesforce/label` (no hardcoded English). *(Finding: ~31 components + 193 toast literals; CLAUDE.md #12)*
- [ ] Every `target="_blank"` carries `rel="noopener noreferrer"`; URL schemes validated before `href`/`window.open`. *(Finding: jiraIssueCard; CLAUDE.md #12)*
- [ ] WCAG 2.1 AA: ARIA labels, keyboard nav, focus management on modals.
- [ ] Every component handles loading / error / empty states.

## 6. Install / runbook review

- [ ] Install handler behavior verified (`ElaroInstallHandler`).
- [ ] Protected vs Public CMDT reviewed per type — executable content is Protected.
- [ ] Permission-set least privilege: no `viewAllRecords`/`modifyAllRecords` on a **User-tier** set unless org-wide visibility is intended; Admin and User sets differ. *(Finding: Elaro_AI_Governance_User; CLAUDE.md #13)*
- [ ] Feature-flag kill switches present and wired for every major module (`FeatureFlags.requireEnabled`).

## 7. Listing assets (Salesforce Partner Console — not in repo)

- [ ] Icons, screenshots, listing copy.
- [ ] AppExchange Security Review form completed.
- [ ] Documentation bundle assembled (`assemble-appexchange-package.sh`).

---

**Gate to submit:** every box in sections 1–6 checked. Sections 1, 2, and 3 are blockers;
a single unchecked item there means do-not-submit. Salesforce's own review SLA is 60–90 days
after submission, so the engineering cost of a rejected submission is measured in months —
this checklist is cheap insurance against that.
