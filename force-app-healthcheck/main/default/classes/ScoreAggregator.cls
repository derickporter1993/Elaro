/**
 * Aggregates results from all five scanners into a weighted composite score
 * and generates prioritized recommendations for remediation.
 *
 * Weighting: Security Health Check 40%, MFA 20%, Permissions 15%,
 * Sessions 15%, Audit Trail 10%.
 *
 * @author Elaro Team
 * @since v1.0.0 (Spring '26)
 * @group Health Check
 * @see HealthCheckResult
 * @see ScanRecommendation
 */
public inherited sharing class ScoreAggregator {

    private static final Decimal WEIGHT_HEALTH_CHECK = 0.40;
    private static final Decimal WEIGHT_MFA = 0.20;
    private static final Decimal WEIGHT_PERMISSIONS = 0.15;
    private static final Decimal WEIGHT_SESSION = 0.15;
    private static final Decimal WEIGHT_AUDIT = 0.10;

    /**
     * Builds the final HealthCheckResult from individual scanner outputs.
     *
     * @param healthCheckScore Native Security Health Check score (0-100)
     * @param healthCheckFindings Findings from HealthCheckScanner
     * @param mfaPercentage MFA adoption percentage (0-100)
     * @param mfaFindings Findings from MFAComplianceScanner
     * @param totalUsers Total login count for MFA display
     * @param mfaUsers MFA-verified login count
     * @param permissionScore Permission hygiene score (0-100)
     * @param permissionFindings Findings from ProfilePermissionScanner
     * @param sessionScore Session settings score (0-100)
     * @param sessionFindings Findings from SessionSettingsScanner
     * @param auditScore Audit trail risk score (0-100)
     * @param auditFindings Findings from AuditTrailScanner
     * @return Fully populated HealthCheckResult
     */
    public HealthCheckResult aggregate(
            Integer healthCheckScore, List<ScanFinding> healthCheckFindings,
            Integer mfaPercentage, List<ScanFinding> mfaFindings,
            Integer totalUsers, Integer mfaUsers,
            Integer permissionScore, List<ScanFinding> permissionFindings,
            Integer sessionScore, List<ScanFinding> sessionFindings,
            Integer auditScore, List<ScanFinding> auditFindings) {

        HealthCheckResult result = new HealthCheckResult();

        healthCheckScore = clamp(healthCheckScore ?? 0);
        Integer mfaScore = clamp(mfaPercentage ?? 0);
        permissionScore = clamp(permissionScore ?? 0);
        sessionScore = clamp(sessionScore ?? 0);
        auditScore = clamp(auditScore ?? 0);

        result.categoryScores.put('SecurityHealthCheck', healthCheckScore);
        result.categoryScores.put('MFA', mfaScore);
        result.categoryScores.put('Permissions', permissionScore);
        result.categoryScores.put('Session', sessionScore);
        result.categoryScores.put('AuditTrail', auditScore);

        Decimal weighted =
            (healthCheckScore * WEIGHT_HEALTH_CHECK)
            + (mfaScore * WEIGHT_MFA)
            + (permissionScore * WEIGHT_PERMISSIONS)
            + (sessionScore * WEIGHT_SESSION)
            + (auditScore * WEIGHT_AUDIT);

        result.overallScore = clamp(weighted.intValue());

        result.mfaPercentage = clamp(mfaPercentage ?? 0);
        result.totalUsers = totalUsers ?? 0;
        result.mfaUsers = mfaUsers ?? 0;

        result.findings.addAll(healthCheckFindings ?? new List<ScanFinding>());
        result.findings.addAll(mfaFindings ?? new List<ScanFinding>());
        result.findings.addAll(permissionFindings ?? new List<ScanFinding>());
        result.findings.addAll(sessionFindings ?? new List<ScanFinding>());
        result.findings.addAll(auditFindings ?? new List<ScanFinding>());

        result.recommendations = buildRecommendations(result);
        result.scanTimestamp = Datetime.now();

        return result;
    }

    /**
     * Generates prioritized recommendations based on scan results.
     */
    private List<ScanRecommendation> buildRecommendations(HealthCheckResult result) {
        List<ScanRecommendation> recs = new List<ScanRecommendation>();

        Integer mfaScore = result.categoryScores.get('MFA') ?? 0;
        if (mfaScore < 100) {
            Integer priority = mfaScore < 50 ? 1 : 2;
            recs.add(new ScanRecommendation(
                'Enable MFA for All Users',
                'Multi-factor authentication protects against credential theft. '
                    + 'Current adoption is ' + mfaScore + '%.',
                'SecurityMfa/home',
                priority,
                'MFA'
            ));
        }

        Integer permScore = result.categoryScores.get('Permissions') ?? 100;
        if (permScore < 100) {
            recs.add(new ScanRecommendation(
                'Review Over-Provisioned Permissions',
                'ModifyAllData and ViewAllData should only be assigned to System Administrators.',
                'PermSets/home',
                1,
                'Permissions'
            ));
        }

        Integer sessionScore = result.categoryScores.get('Session') ?? 100;
        if (sessionScore < 100) {
            recs.add(new ScanRecommendation(
                'Harden Session Settings',
                'Enable HTTPS enforcement, IP session binding, and XSS protection.',
                'SecuritySession/home',
                2,
                'Session'
            ));
        }

        Integer healthCheckScore = result.categoryScores.get('SecurityHealthCheck') ?? 100;
        if (healthCheckScore < 70) {
            recs.add(new ScanRecommendation(
                'Address Security Health Check Risks',
                'Your Salesforce Security Health Check score is ' + healthCheckScore
                    + '. Review and remediate HIGH and MEDIUM risk items.',
                'HealthCheck/home',
                healthCheckScore < 50 ? 1 : 2,
                'SecurityHealthCheck'
            ));
        }

        Integer auditScore = result.categoryScores.get('AuditTrail') ?? 100;
        if (auditScore < 80) {
            recs.add(new ScanRecommendation(
                'Investigate High-Risk Configuration Changes',
                'Multiple security-sensitive changes detected in audit trail. Review for unauthorized modifications.',
                'SecurityEvents/home',
                3,
                'AuditTrail'
            ));
        }

        recs.sort();
        return recs;
    }

    /**
     * Clamps a score to the 0-100 range.
     */
    private static Integer clamp(Integer value) {
        return Math.max(0, Math.min(100, value));
    }
}
