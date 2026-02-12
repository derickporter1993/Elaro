/**
 * Analyzes MFA adoption across the org by querying LoginHistory for the
 * configured lookback period and calculating the percentage of logins
 * verified through multi-factor authentication.
 *
 * @author Elaro Team
 * @since v1.0.0 (Spring '26)
 * @group Health Check
 * @see ScanFinding
 * @see HealthCheckFeatureFlags
 */
public inherited sharing class MFAComplianceScanner {

    private static final String CATEGORY = 'MFA';

    /**
     * Inner class to hold MFA scan results.
     */
    public class MFAResult {
        @AuraEnabled public Integer mfaPercentage { get; set; }
        @AuraEnabled public Integer totalLogins { get; set; }
        @AuraEnabled public Integer mfaLogins { get; set; }
        @AuraEnabled public List<ScanFinding> findings { get; set; }

        public MFAResult() {
            this.mfaPercentage = 0;
            this.totalLogins = 0;
            this.mfaLogins = 0;
            this.findings = new List<ScanFinding>();
        }
    }

    /**
     * Executes the MFA compliance scan by analyzing LoginHistory records.
     *
     * @return MFAResult containing adoption percentage and related findings
     */
    public MFAResult scan() {
        MFAResult result = new MFAResult();

        Integer lookbackDays = HealthCheckFeatureFlags.getMaxDays();
        Datetime cutoffDate = Datetime.now().addDays(-lookbackDays);

        List<LoginHistory> logins = [
            SELECT UserId, LoginType, AuthenticationServiceId, LoginTime
            FROM LoginHistory
            WHERE LoginTime >= :cutoffDate
            WITH USER_MODE
            LIMIT 50000
        ];

        result.totalLogins = logins.size();

        if (result.totalLogins == 0) {
            result.mfaPercentage = 0;
            result.findings.add(new ScanFinding(
                CATEGORY,
                'Login History',
                'No logins found',
                'Active user logins expected',
                'MEDIUM_RISK',
                'No login history found in the last ' + lookbackDays + ' days'
            ));
            return result;
        }

        Integer mfaCount = 0;
        for (LoginHistory login : logins) {
            if (login.AuthenticationServiceId != null) {
                mfaCount++;
            }
        }

        result.mfaLogins = mfaCount;
        result.mfaPercentage = (Integer) Math.round(
            ((Decimal) mfaCount / result.totalLogins) * 100
        );

        if (result.mfaPercentage < 100) {
            String severity = result.mfaPercentage < 50 ? 'HIGH_RISK' : 'MEDIUM_RISK';
            result.findings.add(new ScanFinding(
                CATEGORY,
                'MFA Adoption Rate',
                result.mfaPercentage + '%',
                '100%',
                severity,
                result.mfaLogins + ' of ' + result.totalLogins
                    + ' logins used MFA in the last ' + lookbackDays + ' days'
            ));
        }

        return result;
    }

    /**
     * Calculates MFA adoption percentage from provided counts.
     * Extracted for testability since LoginHistory is read-only.
     *
     * @param totalLogins Total number of logins
     * @param mfaLogins Number of MFA-verified logins
     * @return Adoption percentage (0-100), or 0 if totalLogins is 0
     */
    public static Integer calculateAdoption(Integer totalLogins, Integer mfaLogins) {
        if (totalLogins == null || totalLogins == 0) {
            return 0;
        }
        mfaLogins = mfaLogins ?? 0;
        return (Integer) Math.round(((Decimal) mfaLogins / totalLogins) * 100);
    }
}
