/**
 * Lightning controller for the Health Check Dashboard. Orchestrates all five
 * scanners and returns the aggregated result to the LWC front-end.
 *
 * @author Elaro Team
 * @since v1.0.0 (Spring '26)
 * @group Health Check
 * @see HealthCheckResult
 * @see ScoreAggregator
 */
public with sharing class HealthCheckController {

    /**
     * Executes a full org security scan across all five scanner modules
     * and returns the aggregated result with composite score.
     *
     * This method is intentionally NOT cacheable because scanning is an
     * expensive operation that should only run on explicit user action.
     *
     * @return HealthCheckResult containing composite score, findings, and recommendations
     * @throws AuraHandledException if scanning is disabled or an error occurs
     */
    @AuraEnabled(cacheable=false)
    public static HealthCheckResult runFullScan() {
        if (!HealthCheckFeatureFlags.isEnabled()) {
            throw new AuraHandledException(
                'Health Check scanning is currently disabled. Contact your administrator.'
            );
        }

        HCLogger.info('HealthCheckController.runFullScan: Scan started');

        try {
            HealthCheckScanner.ScanResult hcResult = new HealthCheckScanner().scan();

            MFAComplianceScanner.MFAResult mfaResult = new MFAComplianceScanner().scan();

            ProfilePermissionScanner.PermissionResult permResult =
                new ProfilePermissionScanner().scan();

            SessionSettingsScanner.SessionResult sessionResult =
                new SessionSettingsScanner().scan();

            AuditTrailScanner.AuditResult auditResult = new AuditTrailScanner().scan();

            ScoreAggregator aggregator = new ScoreAggregator();
            HealthCheckResult result = aggregator.aggregate(
                hcResult.nativeScore, hcResult.findings,
                mfaResult.mfaPercentage, mfaResult.findings,
                mfaResult.totalLogins, mfaResult.mfaLogins,
                permResult.score, permResult.findings,
                sessionResult.score, sessionResult.findings,
                auditResult.score, auditResult.findings
            );

            HCLogger.info('HealthCheckController.runFullScan: Scan complete', new Map<String, Object>{
                'overallScore' => result.overallScore,
                'findingsCount' => result.findings.size()
            });

            return result;

        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            HCLogger.error('HealthCheckController.runFullScan', e);
            throw new AuraHandledException(
                'Unable to complete the security scan. Please verify you have '
                + 'the required permissions and try again.'
            );
        }
    }

    /**
     * Returns the timestamp of the last scan.
     * MVP implementation returns current time; future versions will query
     * a stored scan history object.
     *
     * @return Datetime of the last scan
     */
    @AuraEnabled(cacheable=true)
    public static Datetime getLastScanTimestamp() {
        return Datetime.now();
    }
}
