/**
 * Calculates weighted compliance scores from rule evaluation results.
 * Supports per-framework and aggregate scoring across all frameworks.
 *
 * @author Elaro Team
 * @since v3.1.0 (Spring '26)
 * @group Rule Engine
 * @see ComplianceRuleEvaluator
 * @see RuleResult
 */
public inherited sharing class ComplianceScoreAggregator {

    /**
     * Score summary for a framework or aggregate.
     */
    public class ScoreSummary {
        @AuraEnabled public String framework { get; set; }
        @AuraEnabled public Decimal score { get; set; }
        @AuraEnabled public Integer totalRules { get; set; }
        @AuraEnabled public Integer rulesPassed { get; set; }
        @AuraEnabled public Integer rulesFailed { get; set; }
        @AuraEnabled public String rating { get; set; }
        @AuraEnabled public Map<String, Decimal> categoryScores { get; set; }
    }

    /**
     * Calculates a weighted compliance score from a list of rule results.
     * Score = (sum of passed rule weights / total weight) * 100.
     *
     * @param results List of RuleResults from evaluation
     * @return Decimal score 0-100
     */
    public static Decimal calculateScore(List<RuleResult> results) {
        if (results == null || results.isEmpty()) {
            return 0;
        }

        Decimal totalWeight = 0;
        Decimal passedWeight = 0;

        for (RuleResult result : results) {
            Decimal weight = result.weight ?? 1;
            totalWeight += weight;
            if (result.passed) {
                passedWeight += weight;
            }
        }

        if (totalWeight == 0) {
            return 0;
        }

        return (passedWeight / totalWeight * 100).setScale(1, RoundingMode.HALF_UP);
    }

    /**
     * Generates a full score summary including category breakdowns.
     *
     * @param framework The framework being scored
     * @param results List of RuleResults from evaluation
     * @return ScoreSummary with score, counts, and category breakdowns
     */
    public static ScoreSummary generateSummary(String framework, List<RuleResult> results) {
        ScoreSummary summary = new ScoreSummary();
        summary.framework = framework;
        summary.totalRules = results?.size() ?? 0;
        summary.rulesPassed = 0;
        summary.rulesFailed = 0;
        summary.categoryScores = new Map<String, Decimal>();

        if (results == null || results.isEmpty()) {
            summary.score = 0;
            summary.rating = ElaroConstants.getRatingFromScore(0);
            return summary;
        }

        Map<String, List<RuleResult>> byCategory = new Map<String, List<RuleResult>>();

        for (RuleResult result : results) {
            if (result.passed) {
                summary.rulesPassed++;
            } else {
                summary.rulesFailed++;
            }

            String cat = String.isBlank(result.category) ? 'General' : result.category;
            if (!byCategory.containsKey(cat)) {
                byCategory.put(cat, new List<RuleResult>());
            }
            byCategory.get(cat).add(result);
        }

        for (String cat : byCategory.keySet()) {
            summary.categoryScores.put(cat, calculateScore(byCategory.get(cat)));
        }

        summary.score = calculateScore(results);
        summary.rating = ElaroConstants.getRatingFromScore(summary.score);

        return summary;
    }

    /**
     * Retrieves the most recent compliance score for a framework from
     * Workflow_Execution__c records.
     *
     * @param framework The framework to query
     * @return Most recent compliance score, or null if none found
     */
    public static Decimal getLatestScore(String framework) {
        if (String.isBlank(framework)) {
            return null;
        }

        List<Workflow_Execution__c> executions = [
            SELECT Compliance_Score__c
            FROM Workflow_Execution__c
            WHERE Framework__c = :framework
            AND Status__c = 'COMPLETED'
            WITH USER_MODE
            ORDER BY Completed_At__c DESC NULLS LAST
            LIMIT 1
        ];

        return executions.isEmpty() ? null : executions[0].Compliance_Score__c;
    }
}
