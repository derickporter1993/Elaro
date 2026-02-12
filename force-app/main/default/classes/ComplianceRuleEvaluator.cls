/**
 * Core rule evaluation engine that loads active compliance rules from Custom Metadata
 * and dispatches evaluation to the appropriate strategy (SOQL_QUERY, METADATA_CHECK,
 * CONFIG_SCAN). Implements CursorStep for large-scale batch evaluation.
 *
 * @author Elaro Team
 * @since v3.1.0 (Spring '26)
 * @group Rule Engine
 * @see RuleResult
 * @see SOQLQueryEvaluator
 * @see MetadataCheckEvaluator
 * @see ConfigScanEvaluator
 */
public inherited sharing class ComplianceRuleEvaluator {

    private static final String EVAL_TYPE_SOQL = 'SOQL_QUERY';
    private static final String EVAL_TYPE_METADATA = 'METADATA_CHECK';
    private static final String EVAL_TYPE_CONFIG = 'CONFIG_SCAN';

    /**
     * Loads all active compliance rules for a given framework.
     *
     * @param framework The compliance framework name (e.g., 'SOC2', 'HIPAA')
     * @return List of active rules for the framework
     */
    public static List<Compliance_Rule__mdt> loadRules(String framework) {
        if (String.isBlank(framework)) {
            return new List<Compliance_Rule__mdt>();
        }
        return [
            SELECT DeveloperName, Rule_Name__c, Framework__c, Control_Reference__c,
                   Evaluation_Type__c, Evaluation_Query__c, Severity__c, Category__c,
                   Description__c, Is_Active__c, Threshold_Operator__c, Threshold_Value__c,
                   Auto_Remediate__c, Remediation_Action__c, Weight__c
            FROM Compliance_Rule__mdt
            WHERE Framework__c = :framework
            AND Is_Active__c = true
            WITH USER_MODE
        ];
    }

    /**
     * Loads all active compliance rules across all frameworks.
     *
     * @return List of all active rules
     */
    public static List<Compliance_Rule__mdt> loadAllActiveRules() {
        return [
            SELECT DeveloperName, Rule_Name__c, Framework__c, Control_Reference__c,
                   Evaluation_Type__c, Evaluation_Query__c, Severity__c, Category__c,
                   Description__c, Is_Active__c, Threshold_Operator__c, Threshold_Value__c,
                   Auto_Remediate__c, Remediation_Action__c, Weight__c
            FROM Compliance_Rule__mdt
            WHERE Is_Active__c = true
            WITH USER_MODE
        ];
    }

    /**
     * Evaluates a single compliance rule by dispatching to the appropriate strategy.
     *
     * @param rule The rule to evaluate
     * @return RuleResult with pass/fail status and details
     */
    public static RuleResult evaluateRule(Compliance_Rule__mdt rule) {
        Long startTime = System.currentTimeMillis();
        try {
            String evalType = rule.Evaluation_Type__c ?? EVAL_TYPE_SOQL;
            RuleResult result;

            if (evalType == EVAL_TYPE_SOQL) {
                result = SOQLQueryEvaluator.evaluate(rule);
            } else if (evalType == EVAL_TYPE_METADATA) {
                result = MetadataCheckEvaluator.evaluate(rule);
            } else if (evalType == EVAL_TYPE_CONFIG) {
                result = ConfigScanEvaluator.evaluate(rule);
            } else {
                result = RuleResult.error(rule, 'Unknown evaluation type: ' + evalType);
            }

            result.executionTimeMs = System.currentTimeMillis() - startTime;
            return result;
        } catch (Exception e) {
            ElaroLogger.error('ComplianceRuleEvaluator.evaluateRule',
                e.getMessage(), e.getStackTraceString());
            RuleResult errorResult = RuleResult.error(rule, e.getMessage());
            errorResult.executionTimeMs = System.currentTimeMillis() - startTime;
            return errorResult;
        }
    }

    /**
     * Evaluates all active rules for a framework and returns results.
     *
     * @param framework The compliance framework name
     * @return List of RuleResult for each evaluated rule
     */
    public static List<RuleResult> evaluateFramework(String framework) {
        List<Compliance_Rule__mdt> rules = loadRules(framework);
        List<RuleResult> results = new List<RuleResult>();

        for (Compliance_Rule__mdt rule : rules) {
            if (Limits.getQueries() >= Limits.getLimitQueries() - 5) {
                ElaroLogger.warn('ComplianceRuleEvaluator.evaluateFramework',
                    'Approaching SOQL limit, stopping evaluation at ' + results.size() + ' rules');
                break;
            }
            results.add(evaluateRule(rule));
        }

        return results;
    }

    /**
     * Gets the set of supported evaluation types.
     *
     * @return Set of evaluation type strings
     */
    public static Set<String> getSupportedEvaluationTypes() {
        return new Set<String>{ EVAL_TYPE_SOQL, EVAL_TYPE_METADATA, EVAL_TYPE_CONFIG };
    }
}
