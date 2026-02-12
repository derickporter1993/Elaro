/**
 * Scans the SetupAuditTrail for high-risk administrative changes within
 * the configured lookback period. Classifies changes by security-sensitive
 * sections and generates risk-rated findings.
 *
 * @author Elaro Team
 * @since v1.0.0 (Spring '26)
 * @group Health Check
 * @see ScanFinding
 * @see HealthCheckFeatureFlags
 */
public inherited sharing class AuditTrailScanner {

    private static final String CATEGORY = 'AuditTrail';

    private static final Set<String> HIGH_RISK_SECTIONS = new Set<String>{
        'Manage Users',
        'Security Controls',
        'Sharing Rules',
        'Permission Sets',
        'Session Settings',
        'Certificate and Key Management',
        'Connected Apps',
        'Auth. Providers',
        'Named Credentials',
        'Login Access Policies'
    };

    /**
     * Inner class to hold audit trail scan results.
     */
    public class AuditResult {
        @AuraEnabled public Integer score { get; set; }
        @AuraEnabled public List<ScanFinding> findings { get; set; }

        public AuditResult() {
            this.score = 100;
            this.findings = new List<ScanFinding>();
        }
    }

    /**
     * Executes the audit trail scan for the configured lookback period.
     *
     * @return AuditResult containing a risk score and categorized findings
     */
    public AuditResult scan() {
        AuditResult result = new AuditResult();

        Integer lookbackDays = HealthCheckFeatureFlags.getMaxDays();
        Datetime cutoffDate = Datetime.now().addDays(-lookbackDays);

        List<SetupAuditTrail> trails = [
            SELECT Id, Action, Section, CreatedDate, CreatedBy.Username, Display
            FROM SetupAuditTrail
            WHERE CreatedDate >= :cutoffDate
            WITH USER_MODE
            ORDER BY CreatedDate DESC
            LIMIT 2000
        ];

        if (trails.isEmpty()) {
            return result;
        }

        Integer highRiskCount = 0;
        Integer penaltyPerHighRisk = 5;
        Integer maxFindings = 50;

        for (SetupAuditTrail trail : trails) {
            if (!HIGH_RISK_SECTIONS.contains(trail.Section)) {
                continue;
            }

            highRiskCount++;

            if (result.findings.size() < maxFindings) {
                String displayText = trail.Display ?? 'No description available';
                String username = trail.CreatedBy?.Username ?? 'Unknown User';

                result.findings.add(new ScanFinding(
                    CATEGORY,
                    trail.Section ?? 'Unknown Section',
                    trail.Action ?? 'Unknown Action',
                    'Review and verify this change',
                    'MEDIUM_RISK',
                    displayText + ' (by ' + username
                        + ' on ' + trail.CreatedDate?.format('yyyy-MM-dd HH:mm') + ')'
                ));
            }
        }

        result.score = Math.max(0, 100 - (highRiskCount * penaltyPerHighRisk));

        return result;
    }

    /**
     * Classifies whether a given SetupAuditTrail section is high-risk.
     * Extracted for testability since SetupAuditTrail is read-only.
     *
     * @param section The Section value from SetupAuditTrail
     * @return True if the section is classified as high-risk
     */
    public static Boolean isHighRiskSection(String section) {
        return section != null && HIGH_RISK_SECTIONS.contains(section);
    }
}
