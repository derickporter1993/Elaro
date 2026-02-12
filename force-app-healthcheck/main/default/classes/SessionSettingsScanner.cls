/**
 * Evaluates org session security settings via Tooling API and generates findings
 * for non-compliant configurations including session timeout, HTTPS enforcement,
 * IP locking, and XSS protection.
 *
 * @author Elaro Team
 * @since v1.0.0 (Spring '26)
 * @group Health Check
 * @see ToolingApiService
 * @see ScanFinding
 */
public inherited sharing class SessionSettingsScanner {

    private static final String CATEGORY = 'Session';

    /**
     * Inner class to hold session settings scan results.
     */
    public class SessionResult {
        @AuraEnabled public Integer score { get; set; }
        @AuraEnabled public List<ScanFinding> findings { get; set; }

        public SessionResult() {
            this.score = 100;
            this.findings = new List<ScanFinding>();
        }
    }

    /**
     * Executes the session settings scan against the Tooling API.
     *
     * @return SessionResult containing a security score and findings
     * @throws AuraHandledException if Tooling API query fails
     */
    public SessionResult scan() {
        SessionResult result = new SessionResult();

        Map<String, Object> response = ToolingApiService.queryTooling(
            'SELECT Id, Metadata FROM SecuritySettings'
        );
        List<Object> records = (List<Object>) response.get('records');

        if (records == null || records.isEmpty()) {
            result.findings.add(new ScanFinding(
                CATEGORY, 'SecuritySettings', 'Unable to query', 'Settings accessible',
                'MEDIUM_RISK', 'Could not retrieve session security settings'
            ));
            result.score = 50;
            return result;
        }

        Map<String, Object> record = (Map<String, Object>) records[0];
        Map<String, Object> metadata = (Map<String, Object>) record.get('Metadata');

        if (metadata == null) {
            result.score = 50;
            return result;
        }

        Map<String, Object> sessionSettings = (Map<String, Object>) metadata.get('sessionSettings');
        if (sessionSettings == null) {
            result.score = 50;
            return result;
        }

        Integer penaltyPerFinding = 20;

        checkBooleanSetting(result, sessionSettings, 'requireHttps',
            true, 'Require HTTPS', 'HIGH_RISK',
            'All connections should use HTTPS for data protection',
            'SecuritySession/home', penaltyPerFinding);

        checkBooleanSetting(result, sessionSettings, 'lockSessionsToIp',
            true, 'Lock Sessions to IP', 'MEDIUM_RISK',
            'Session IP binding prevents session hijacking',
            'SecuritySession/home', penaltyPerFinding);

        checkBooleanSetting(result, sessionSettings, 'enableXssProtection',
            true, 'XSS Protection', 'HIGH_RISK',
            'Cross-site scripting protection should be enabled',
            'SecuritySession/home', penaltyPerFinding);

        checkBooleanSetting(result, sessionSettings, 'enableClickjackNonsetupSFDC',
            true, 'Clickjack Protection (Non-Setup)', 'MEDIUM_RISK',
            'Clickjack protection for non-Setup Salesforce pages',
            'SecuritySession/home', penaltyPerFinding);

        checkBooleanSetting(result, sessionSettings, 'enableCspOnEmail',
            true, 'Content Security Policy on Email', 'LOW_RISK',
            'CSP headers protect against content injection in emails',
            'SecuritySession/home', penaltyPerFinding);

        Object timeoutVal = sessionSettings.get('sessionTimeout');
        if (timeoutVal != null) {
            String timeoutStr = String.valueOf(timeoutVal);
            if (timeoutStr != 'TWO_HOURS' && timeoutStr != 'FOUR_HOURS'
                && timeoutStr != 'EIGHT_HOURS') {
                result.findings.add(new ScanFinding(
                    CATEGORY, 'Session Timeout', timeoutStr,
                    'TWO_HOURS or less',
                    'MEDIUM_RISK',
                    'Session timeout should be 12 hours or less to reduce hijacking risk'
                ));
                result.score = Math.max(0, result.score - penaltyPerFinding);
            }
        }

        return result;
    }

    /**
     * Checks a boolean session setting and creates a finding if non-compliant.
     */
    private void checkBooleanSetting(SessionResult result, Map<String, Object> settings,
            String settingKey, Boolean expectedValue, String settingLabel,
            String severity, String description, String setupPath, Integer penalty) {

        Object val = settings.get(settingKey);
        Boolean currentVal = val != null ? (Boolean) val : false;

        if (currentVal != expectedValue) {
            result.findings.add(new ScanFinding(
                CATEGORY, settingLabel, String.valueOf(currentVal),
                String.valueOf(expectedValue), severity, description
            ));
            result.score = Math.max(0, result.score - penalty);
        }
    }
}
