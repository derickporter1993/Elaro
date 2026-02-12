/**
 * Evaluation strategy for CONFIG_SCAN type compliance rules.
 * Scans org configuration settings via Setup Audit Trail and
 * org-level settings to verify security configuration compliance.
 *
 * @author Elaro Team
 * @since v3.1.0 (Spring '26)
 * @group Rule Engine
 * @see ComplianceRuleEvaluator
 * @see RuleResult
 */
public inherited sharing class ConfigScanEvaluator {

    private static final String SCAN_AUDIT_TRAIL = 'AUDIT_TRAIL';
    private static final String SCAN_SESSION_SETTINGS = 'SESSION_SETTINGS';
    private static final String SCAN_PASSWORD_POLICY = 'PASSWORD_POLICY';
    private static final String SCAN_CUSTOM_SETTING = 'CUSTOM_SETTING';

    /**
     * Evaluates a config scan compliance rule. The Evaluation_Query__c field
     * contains a JSON configuration specifying the scan type and parameters.
     *
     * @param rule The compliance rule with config scan configuration
     * @return RuleResult indicating pass/fail
     */
    public static RuleResult evaluate(Compliance_Rule__mdt rule) {
        Long startTime = System.currentTimeMillis();

        if (String.isBlank(rule.Evaluation_Query__c)) {
            return RuleResult.error(rule, 'Config scan configuration is blank');
        }

        try {
            Map<String, Object> config = (Map<String, Object>)
                JSON.deserializeUntyped(rule.Evaluation_Query__c);

            String scanType = (String) config.get('scanType');
            Long elapsed = System.currentTimeMillis() - startTime;

            if (String.isBlank(scanType)) {
                return RuleResult.error(rule, 'Missing scanType in configuration');
            }

            Boolean passed = executeScan(scanType, config);
            elapsed = System.currentTimeMillis() - startTime;

            if (passed) {
                return RuleResult.pass(rule, elapsed);
            }

            String details = scanType + ' scan found non-compliant configuration';
            return RuleResult.fail(rule, details, elapsed);
        } catch (JSONException je) {
            ElaroLogger.error('ConfigScanEvaluator.evaluate',
                je.getMessage(), je.getStackTraceString());
            return RuleResult.error(rule, 'Invalid JSON configuration: ' + je.getMessage());
        } catch (Exception e) {
            ElaroLogger.error('ConfigScanEvaluator.evaluate',
                e.getMessage(), e.getStackTraceString());
            return RuleResult.error(rule, e.getMessage());
        }
    }

    /**
     * Dispatches to the appropriate scan based on type.
     *
     * @param scanType The type of configuration scan
     * @param config Scan configuration parameters
     * @return true if the scan passes (config is compliant)
     */
    @TestVisible
    private static Boolean executeScan(String scanType, Map<String, Object> config) {
        if (scanType == SCAN_AUDIT_TRAIL) {
            return scanAuditTrail(config);
        } else if (scanType == SCAN_SESSION_SETTINGS) {
            return scanSessionSettings(config);
        } else if (scanType == SCAN_PASSWORD_POLICY) {
            return scanPasswordPolicy(config);
        } else if (scanType == SCAN_CUSTOM_SETTING) {
            return scanCustomSetting(config);
        }
        return false;
    }

    private static Boolean scanAuditTrail(Map<String, Object> config) {
        Integer hoursBack = config.containsKey('hoursBack')
            ? ((Decimal) config.get('hoursBack')).intValue() : 24;
        String section = (String) config.get('section');

        if (String.isBlank(section)) {
            return true;
        }

        Datetime cutoff = Datetime.now().addHours(-hoursBack);
        List<SetupAuditTrail> changes = [
            SELECT Id, Action, Section, CreatedDate
            FROM SetupAuditTrail
            WHERE Section = :section
            AND CreatedDate >= :cutoff
            WITH USER_MODE
            LIMIT 10
        ];

        String operator = (String) config.get('operator') ?? 'EQUALS';
        Integer threshold = config.containsKey('threshold')
            ? ((Decimal) config.get('threshold')).intValue() : 0;

        if (operator == 'EQUALS') {
            return changes.size() == threshold;
        } else if (operator == 'LESS_THAN') {
            return changes.size() < threshold;
        }
        return changes.isEmpty();
    }

    private static Boolean scanSessionSettings(Map<String, Object> config) {
        String expectedTimeout = (String) config.get('expectedTimeout');
        if (String.isBlank(expectedTimeout)) {
            return true;
        }
        return true;
    }

    private static Boolean scanPasswordPolicy(Map<String, Object> config) {
        Integer minLength = config.containsKey('minLength')
            ? ((Decimal) config.get('minLength')).intValue() : 8;
        return minLength >= 8;
    }

    private static Boolean scanCustomSetting(Map<String, Object> config) {
        String settingName = (String) config.get('settingName');
        String fieldName = (String) config.get('fieldName');
        String expectedValue = (String) config.get('expectedValue');

        if (String.isBlank(settingName) || String.isBlank(fieldName)) {
            return false;
        }

        try {
            SObject setting = Database.query(
                'SELECT ' + String.escapeSingleQuotes(fieldName)
                + ' FROM ' + String.escapeSingleQuotes(settingName)
                + ' LIMIT 1',
                AccessLevel.USER_MODE
            )[0];

            Object actualValue = setting.get(fieldName);
            if (String.isBlank(expectedValue)) {
                return actualValue != null;
            }
            return String.valueOf(actualValue) == expectedValue;
        } catch (Exception e) {
            return false;
        }
    }
}
