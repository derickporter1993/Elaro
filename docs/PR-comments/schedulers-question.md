# PR Comment Draft — Schedulers Question

> **Paste destination:** the open PR (or a follow-up issue if no PR is currently open) discussing
> dead-code cleanup or scheduler scope.
> **Why a comment, not a fix:** the deferred decision from the dead-code plan. The schedulers
> have working tests but no automatic registration; intent needs confirmation before delete-or-document.

---

## Suggested comment text

**Schedulers `ConsentExpirationScheduler` and `RetentionEnforcementScheduler` — confirm intent before next sweep**

These two `Schedulable` classes have a coverage profile that makes "is this dead code?" genuinely ambiguous:

**What I verified at HEAD:**
- ✅ Both have test classes (`ConsentExpirationSchedulerTest`, `RetentionEnforcementSchedulerTest`)
- ✅ Both expose a `schedule()` static helper that calls `System.schedule(...)` with a CRON expression
- ✅ Tests exercise both `new <Scheduler>().execute(ctx)` and the `<Scheduler>.schedule()` helper
- ❌ `ElaroInstallHandler` does NOT call either `schedule()` method — they're not auto-registered at install
- ❌ No README / docs / runbook documents the manual `System.schedule(...)` step an admin would run

So they're either **(a)** intentionally admin-scheduled and the runbook is just undocumented, or **(b)** they were built end-to-end (class + helper + test) but never actually wired into any deployment.

**The decision affects whether we delete them in the next dead-code pass.** Three reasonable answers:

1. **They're admin-scheduled — add the runbook.** Add the CRON registration to `README.md` / `docs/user/SETUP_GUIDE.md` ("Post-install: run `RetentionEnforcementScheduler.schedule()` in Anonymous Apex"). Optionally surface a CLI command `elaro scheduler enable retention-enforcement` that wraps it. Leave the schedulers in place.

2. **They should auto-register at install — wire `ElaroInstallHandler`.** Add to `ElaroInstallHandler.onInstall`:
   ```apex
   try {
       if ([SELECT Id FROM CronTrigger WHERE CronJobDetail.Name = 'Elaro Retention Enforcement' LIMIT 1].isEmpty()) {
           RetentionEnforcementScheduler.schedule();
       }
   } catch (Exception e) {
       ElaroLogger.warn('ElaroInstallHandler', 'Could not auto-schedule RetentionEnforcement: ' + e.getMessage());
   }
   ```
   (Wrap in try-catch — install handlers must never fail the install.) Same pattern for `ConsentExpirationScheduler`. Document in CHANGELOG.

3. **They're dead — delete them.** If neither (1) nor (2), they ship as orphans. Delete both classes + tests in the next dead-code sweep, scrub any `<apexClass>` PS entries.

**My recommendation: (2) — auto-register at install.** GDPR consent expiration and HIPAA-mandated retention enforcement are both regulatory-clock requirements; relying on subscriber admins to remember to manually CRON-schedule them is a compliance-exposure pattern. Auto-registration with idempotency (the `CronTrigger` existence check above) gives reliable behavior without forcing a manual step.

Could you confirm? Once answered I'll either:
- (1) draft the runbook PR,
- (2) draft the InstallHandler wiring PR with tests, or
- (3) add both schedulers to the next dead-code deletion sweep.

---

## Notes for the person posting this

- Replace "I" with team voice if posting as the maintainer's account
- If the answer is (2), the InstallHandler change must be tested via `ElaroInstallHandlerTest` (use a fake `InstallContext` and assert `[SELECT COUNT() FROM CronTrigger WHERE CronJobDetail.Name LIKE 'Elaro%']` ≥ 2 after `onInstall(ctx)` runs)
- If the answer is (3), the deletion checklist: `.cls` + `-meta.xml` + `Test.cls` + `Test.cls-meta.xml` per scheduler; grep for `<apexClass>(ConsentExpirationScheduler|RetentionEnforcementScheduler)</apexClass>` in `permissionsets/` and scrub if present
