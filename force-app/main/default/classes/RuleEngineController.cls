/**
 * Lightning controller for Rule Engine operations. Provides @AuraEnabled
 * endpoints for running compliance evaluations, viewing results, and
 * managing rule configurations.
 *
 * @author Elaro Team
 * @since v3.1.0 (Spring '26)
 * @group Rule Engine
 * @see ComplianceOrchestrationEngine
 * @see ComplianceScoreAggregator
 * @see ComplianceRuleEvaluator
 */
public with sharing class RuleEngineController {

    /**
     * Runs a full compliance evaluation for a specified framework.
     *
     * @param framework The compliance framework to evaluate (e.g., 'SOC2', 'HIPAA')
     * @return WorkflowExecutionResult with scores and findings
     */
    @AuraEnabled
    public static ComplianceOrchestrationEngine.WorkflowExecutionResult evaluateFramework(
            String framework) {
        try {
            if (String.isBlank(framework)) {
                throw new AuraHandledException('Framework parameter is required');
            }
            return ComplianceOrchestrationEngine.executeForFramework(
                framework, framework + ' Compliance Evaluation');
        } catch (AuraHandledException ae) {
            throw ae;
        } catch (Exception e) {
            ElaroLogger.error('RuleEngineController.evaluateFramework',
                e.getMessage(), e.getStackTraceString());
            throw new AuraHandledException(
                'Unable to complete compliance evaluation. Please verify your permissions and try again.');
        }
    }

    /**
     * Gets the most recent compliance scores for all active frameworks.
     *
     * @return List of ScoreSummaries for each framework
     */
    @AuraEnabled(cacheable=true)
    public static List<ComplianceScoreAggregator.ScoreSummary> getFrameworkScores() {
        try {
            List<ComplianceScoreAggregator.ScoreSummary> summaries =
                new List<ComplianceScoreAggregator.ScoreSummary>();

            Set<String> frameworks = getActiveFrameworks();
            for (String framework : frameworks) {
                Decimal score = ComplianceScoreAggregator.getLatestScore(framework);
                ComplianceScoreAggregator.ScoreSummary summary =
                    new ComplianceScoreAggregator.ScoreSummary();
                summary.framework = framework;
                summary.score = score ?? 0;
                summary.rating = ElaroConstants.getRatingFromScore(summary.score);
                summaries.add(summary);
            }

            return summaries;
        } catch (Exception e) {
            ElaroLogger.error('RuleEngineController.getFrameworkScores',
                e.getMessage(), e.getStackTraceString());
            throw new AuraHandledException(
                'Unable to retrieve compliance scores. Please try again.');
        }
    }

    /**
     * Gets recent workflow execution history.
     *
     * @param limitCount Maximum number of records to return
     * @return List of recent Workflow_Execution__c records
     */
    @AuraEnabled(cacheable=true)
    public static List<Workflow_Execution__c> getExecutionHistory(Integer limitCount) {
        try {
            Integer queryLimit = (limitCount != null && limitCount > 0) ? limitCount : 20;
            queryLimit = Math.min(queryLimit, 100);

            return [
                SELECT Id, Name, Template_Name__c, Framework__c, Status__c,
                       Started_At__c, Completed_At__c, Total_Rules__c,
                       Rules_Passed__c, Rules_Failed__c, Compliance_Score__c
                FROM Workflow_Execution__c
                WITH USER_MODE
                ORDER BY Started_At__c DESC NULLS LAST
                LIMIT :queryLimit
            ];
        } catch (Exception e) {
            ElaroLogger.error('RuleEngineController.getExecutionHistory',
                e.getMessage(), e.getStackTraceString());
            throw new AuraHandledException(
                'Unable to retrieve execution history. Please try again.');
        }
    }

    /**
     * Gets the active compliance rules for a framework.
     *
     * @param framework The framework to query
     * @return List of active Compliance_Rule__mdt records
     */
    @AuraEnabled(cacheable=true)
    public static List<Compliance_Rule__mdt> getActiveRules(String framework) {
        try {
            if (String.isBlank(framework)) {
                return ComplianceRuleEvaluator.loadAllActiveRules();
            }
            return ComplianceRuleEvaluator.loadRules(framework);
        } catch (Exception e) {
            ElaroLogger.error('RuleEngineController.getActiveRules',
                e.getMessage(), e.getStackTraceString());
            throw new AuraHandledException(
                'Unable to retrieve compliance rules. Please try again.');
        }
    }

    /**
     * Gets the set of frameworks that have active rules defined.
     *
     * @return Set of framework names
     */
    @AuraEnabled(cacheable=true)
    public static Set<String> getActiveFrameworks() {
        try {
            Set<String> frameworks = new Set<String>();
            for (Compliance_Rule__mdt rule : [
                SELECT Framework__c
                FROM Compliance_Rule__mdt
                WHERE Is_Active__c = true
                WITH USER_MODE
            ]) {
                if (String.isNotBlank(rule.Framework__c)) {
                    frameworks.add(rule.Framework__c);
                }
            }
            return frameworks;
        } catch (Exception e) {
            ElaroLogger.error('RuleEngineController.getActiveFrameworks',
                e.getMessage(), e.getStackTraceString());
            throw new AuraHandledException(
                'Unable to retrieve active frameworks. Please try again.');
        }
    }
}
