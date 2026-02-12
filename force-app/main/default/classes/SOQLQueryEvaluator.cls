/**
 * Evaluation strategy for SOQL_QUERY type compliance rules.
 * Executes the rule's SOQL query and compares results against threshold.
 *
 * @author Elaro Team
 * @since v3.1.0 (Spring '26)
 * @group Rule Engine
 * @see ComplianceRuleEvaluator
 * @see RuleResult
 */
public inherited sharing class SOQLQueryEvaluator {

    private static final String OP_EQUALS = 'EQUALS';
    private static final String OP_NOT_EQUALS = 'NOT_EQUALS';
    private static final String OP_GREATER_THAN = 'GREATER_THAN';
    private static final String OP_LESS_THAN = 'LESS_THAN';
    private static final String OP_CONTAINS = 'CONTAINS';
    private static final String OP_NOT_CONTAINS = 'NOT_CONTAINS';

    /**
     * Evaluates a SOQL-based compliance rule. The query should return a COUNT()
     * or a list of records. The result count is compared against the threshold.
     *
     * @param rule The compliance rule with Evaluation_Query__c populated
     * @return RuleResult indicating pass/fail
     */
    public static RuleResult evaluate(Compliance_Rule__mdt rule) {
        Long startTime = System.currentTimeMillis();

        if (String.isBlank(rule.Evaluation_Query__c)) {
            return RuleResult.error(rule, 'Evaluation query is blank');
        }

        try {
            List<SObject> queryResults = Database.query(
                rule.Evaluation_Query__c, AccessLevel.USER_MODE
            );
            Integer resultCount = queryResults.size();

            String operator = rule.Threshold_Operator__c ?? OP_EQUALS;
            String thresholdStr = rule.Threshold_Value__c ?? '0';

            Boolean passed = compareThreshold(resultCount, operator, thresholdStr);
            Long elapsed = System.currentTimeMillis() - startTime;

            if (passed) {
                return RuleResult.pass(rule, elapsed);
            }

            String details = 'Query returned ' + resultCount + ' records. '
                + 'Expected: ' + operator + ' ' + thresholdStr;
            return RuleResult.fail(rule, details, elapsed);
        } catch (Exception e) {
            ElaroLogger.error('SOQLQueryEvaluator.evaluate',
                e.getMessage(), e.getStackTraceString());
            return RuleResult.error(rule, e.getMessage());
        }
    }

    /**
     * Compares the actual count against the threshold using the specified operator.
     *
     * @param actual The actual count from query results
     * @param operator The comparison operator
     * @param thresholdStr The threshold value as a string
     * @return true if the comparison passes
     */
    @TestVisible
    private static Boolean compareThreshold(Integer actual, String operator, String thresholdStr) {
        Decimal threshold;
        try {
            threshold = Decimal.valueOf(thresholdStr);
        } catch (Exception e) {
            return thresholdStr == String.valueOf(actual);
        }

        if (operator == OP_EQUALS) {
            return actual == threshold;
        } else if (operator == OP_NOT_EQUALS) {
            return actual != threshold;
        } else if (operator == OP_GREATER_THAN) {
            return actual > threshold;
        } else if (operator == OP_LESS_THAN) {
            return actual < threshold;
        }
        return actual == threshold;
    }
}
