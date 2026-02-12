/**
 * Scans Salesforce Security Health Check settings via Tooling API and returns
 * the native org score along with risk-categorized findings.
 *
 * Queries SecurityHealthCheck for the overall score and SecurityHealthCheckRisks
 * for individual risk items, mapping each to a {@link ScanFinding}.
 *
 * @author Elaro Team
 * @since v1.0.0 (Spring '26)
 * @group Health Check
 * @see ToolingApiService
 * @see ScanFinding
 */
public inherited sharing class HealthCheckScanner {

    private static final String CATEGORY = 'SecurityHealthCheck';

    /**
     * Inner class to hold the scanner result: native score plus findings.
     */
    public class ScanResult {
        @AuraEnabled public Integer nativeScore { get; set; }
        @AuraEnabled public List<ScanFinding> findings { get; set; }

        public ScanResult() {
            this.nativeScore = 0;
            this.findings = new List<ScanFinding>();
        }
    }

    /**
     * Executes the Security Health Check scan by querying the Tooling API
     * for SecurityHealthCheck and SecurityHealthCheckRisks.
     *
     * @return ScanResult containing the org's native score and list of findings
     * @throws AuraHandledException if Tooling API queries fail
     */
    public ScanResult scan() {
        ScanResult result = new ScanResult();

        Map<String, Object> scoreResponse = ToolingApiService.queryTooling(
            'SELECT Id, Score FROM SecurityHealthCheck'
        );
        List<Object> scoreRecords = (List<Object>) scoreResponse.get('records');
        if (scoreRecords != null && !scoreRecords.isEmpty()) {
            Map<String, Object> scoreRecord = (Map<String, Object>) scoreRecords[0];
            Object scoreVal = scoreRecord.get('Score');
            result.nativeScore = scoreVal != null ? ((Decimal) scoreVal).intValue() : 0;
        }

        Map<String, Object> risksResponse = ToolingApiService.queryTooling(
            'SELECT Id, RiskType, Setting, SettingGroup, OrgValue, StandardValue'
            + ' FROM SecurityHealthCheckRisks'
        );
        List<Object> riskRecords = (List<Object>) risksResponse.get('records');
        if (riskRecords != null) {
            for (Object riskObj : riskRecords) {
                Map<String, Object> risk = (Map<String, Object>) riskObj;
                String riskType = (String) risk.get('RiskType');

                if (riskType == 'INFORMATIONAL') {
                    continue;
                }

                result.findings.add(new ScanFinding(
                    CATEGORY,
                    (String) risk.get('Setting') ?? 'Unknown Setting',
                    (String) risk.get('OrgValue') ?? 'Not Set',
                    (String) risk.get('StandardValue') ?? 'N/A',
                    riskType ?? 'LOW_RISK',
                    'Setting Group: ' + ((String) risk.get('SettingGroup') ?? 'General')
                ));
            }
        }

        return result;
    }
}
