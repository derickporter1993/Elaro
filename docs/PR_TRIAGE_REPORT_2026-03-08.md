# PR Triage Report — March 8, 2026

**16 open PRs reviewed.** Below is the disposition for each.

---

## CLOSE — Already Handled by Automated Cleanup Workflow

These PRs were already closed by the automated stale-PR cleanup workflow (commit `4369535` / `24bb634`) but still appear as open. They should be confirmed closed.

| PR | Title | Reason to Close |
|----|-------|-----------------|
| #173 | Refactor Apex callout mock classes | Duplicate of #174/#175; closed by cleanup workflow |
| #174 | Refactor Apex callout mock classes | Duplicate of #173/#175; closed by cleanup workflow |
| #175 | Refactor Apex callout mock classes | Duplicate of #173/#174; includes unrelated CSV; closed by cleanup workflow |
| #172 | Add Winter '26 / Spring '26 code review artifacts | Remediation commits merged separately; closed by cleanup workflow |
| #176 | Add Salesforce 2026 security remediation actions and guide | Metadata + docs only; closed by cleanup workflow |
| #178 | fix: downgrade @eslint/js to ^9.x | Approved but closed by cleanup workflow; superseded by #186 |
| #180 | docs: mark PagerDuty secret handling as resolved | Draft (Copilot); approved; closed by cleanup workflow |
| #181 | docs: correct stale PagerDuty key management status | Draft (Copilot); duplicate of #180; closed by cleanup workflow |

**Action:** Verify these are closed. If any still show as open, close them manually with comment: "Superseded by cleanup workflow or subsequent PRs."

---

## CLOSE — Superseded or Needs Rework

| PR | Title | Reason |
|----|-------|--------|
| #185 | fix: resolve npm audit + prettier failures blocking CI | Draft (Copilot). Approved, but the `minimatch` fix is now covered by dependabot #184 and the eslint conflict is addressed by #186. Close as superseded. |
| #177 | Refactor graph indexer fallback & scoring; add SF2026 remediation metadata | Has 8 Copilot-flagged issues: missing tests for fallback scoring, XML encoding errors, per-record logging overhead, static map allocation. Overlaps with #176 on metadata. **Needs rework before merge.** Close and reopen a focused PR if the graph indexer refactor is still desired. |
| #187 | fix(security): add batch failure notifications and HTTP response validation | Good core fix but includes 3 unrelated review artifact files (1,700+ line checklist, security findings with vulnerability details). **Security risk from exposing findings publicly.** Close and resubmit with only the batch notification + HTTP validation changes. |

---

## MERGE — Dependabot Dependency Updates

These are safe, well-scoped dependency bumps. Merge in this order to avoid conflicts:

| Priority | PR | Title | Risk | Notes |
|----------|----|-------|------|-------|
| 1 | #184 | bump minimatch 3.1.2 → 3.1.4 | Low | ReDoS fix + perf improvements. Patch version. |
| 2 | #189 | bump lint-staged 16.2.7 → 16.3.2 | Low | Minor version. Better process cleanup. |
| 3 | #190 | bump @lwc/eslint-plugin-lwc 3.3.0 → 3.4.0 | Low | Minor version. New SSR rules + fast-xml-parser bump. |
| 4 | #188 | bump actions/upload-artifact v6 → v7 | Medium | Major version. ESM migration. Verify CI workflows still pass after merge. |
| 5 | #186 | bump eslint 9.39.2 → 10.0.2 | **High** | **Major version with breaking changes.** Must verify: eslint config compatibility, `@eslint/js` peer dep alignment, all lint rules still work. Run `npm run lint` after merge. Consider deferring if CI is unstable. |

**Recommended merge approach:** Merge #184 first, then #189, #190, #188. Defer #186 (eslint major bump) until the team can validate breaking changes.

---

## Summary

| Action | Count | PRs |
|--------|-------|-----|
| Already closed (verify) | 8 | #172, #173, #174, #175, #176, #178, #180, #181 |
| Close (superseded/rework) | 3 | #177, #185, #187 |
| Merge (dependency bumps) | 5 | #184, #186, #188, #189, #190 |
| **Total** | **16** | |

### Immediate Actions Required

1. Confirm PRs #172-#181 are closed; close any that are still open
2. Close #185 (superseded) and #177 (needs rework)
3. Close #187, strip review artifacts, resubmit as clean PR
4. Merge dependabot PRs in order: #184 → #189 → #190 → #188
5. Evaluate #186 (eslint 10.x) carefully before merging — breaking changes likely
