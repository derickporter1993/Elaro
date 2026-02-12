/**
 * Data Transfer Object representing the result of a single compliance rule evaluation.
 * Carries pass/fail status, severity, finding details, and metadata for audit trail.
 *
 * @author Elaro Team
 * @since v3.1.0 (Spring '26)
 * @group Rule Engine
 * @see ComplianceRuleEvaluator
 */
public inherited sharing class RuleResult {

    @AuraEnabled public String ruleDeveloperName { get; set; }
    @AuraEnabled public String ruleName { get; set; }
    @AuraEnabled public String framework { get; set; }
    @AuraEnabled public String controlReference { get; set; }
    @AuraEnabled public String category { get; set; }
    @AuraEnabled public String severity { get; set; }
    @AuraEnabled public Boolean passed { get; set; }
    @AuraEnabled public String findingDetails { get; set; }
    @AuraEnabled public Long executionTimeMs { get; set; }
    @AuraEnabled public Decimal weight { get; set; }
    @AuraEnabled public String evaluationType { get; set; }
    @AuraEnabled public Datetime evaluatedAt { get; set; }

    /**
     * Creates a passing result.
     *
     * @param rule The evaluated rule metadata record
     * @param executionTimeMs Time taken to evaluate in milliseconds
     * @return RuleResult with passed=true
     */
    public static RuleResult pass(Compliance_Rule__mdt rule, Long executionTimeMs) {
        RuleResult result = fromRule(rule);
        result.passed = true;
        result.executionTimeMs = executionTimeMs;
        return result;
    }

    /**
     * Creates a failing result with finding details.
     *
     * @param rule The evaluated rule metadata record
     * @param findingDetails Description of what failed
     * @param executionTimeMs Time taken to evaluate in milliseconds
     * @return RuleResult with passed=false
     */
    public static RuleResult fail(Compliance_Rule__mdt rule, String findingDetails, Long executionTimeMs) {
        RuleResult result = fromRule(rule);
        result.passed = false;
        result.findingDetails = findingDetails;
        result.executionTimeMs = executionTimeMs;
        return result;
    }

    /**
     * Creates an error result when evaluation could not be completed.
     *
     * @param rule The rule that caused the error
     * @param errorMessage Error description
     * @return RuleResult with passed=false and error details
     */
    public static RuleResult error(Compliance_Rule__mdt rule, String errorMessage) {
        RuleResult result = fromRule(rule);
        result.passed = false;
        result.findingDetails = 'Evaluation error: ' + errorMessage;
        result.executionTimeMs = 0;
        return result;
    }

    private static RuleResult fromRule(Compliance_Rule__mdt rule) {
        RuleResult result = new RuleResult();
        result.ruleDeveloperName = rule.DeveloperName;
        result.ruleName = rule.Rule_Name__c ?? rule.DeveloperName;
        result.framework = rule.Framework__c;
        result.controlReference = rule.Control_Reference__c ?? '';
        result.category = rule.Category__c ?? '';
        result.severity = rule.Severity__c ?? 'MEDIUM';
        result.evaluationType = rule.Evaluation_Type__c ?? 'SOQL_QUERY';
        result.weight = rule.Weight__c ?? 1;
        result.evaluatedAt = Datetime.now();
        return result;
    }
}
