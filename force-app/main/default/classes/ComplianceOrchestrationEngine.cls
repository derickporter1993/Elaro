/**
 * Orchestrates compliance workflow execution by reading workflow templates,
 * dispatching rule evaluations, recording step results, and publishing alerts
 * for failures. Creates Workflow_Execution__c and Step_Execution__c audit records.
 *
 * @author Elaro Team
 * @since v3.1.0 (Spring '26)
 * @group Rule Engine
 * @see WorkflowTemplateReader
 * @see ComplianceRuleEvaluator
 * @see ComplianceScoreAggregator
 */
public inherited sharing class ComplianceOrchestrationEngine {

    /**
     * Result of a complete workflow execution including all step results.
     */
    public class WorkflowExecutionResult {
        @AuraEnabled public Id workflowExecutionId { get; set; }
        @AuraEnabled public String templateName { get; set; }
        @AuraEnabled public String framework { get; set; }
        @AuraEnabled public String status { get; set; }
        @AuraEnabled public List<RuleResult> ruleResults { get; set; }
        @AuraEnabled public Decimal complianceScore { get; set; }
        @AuraEnabled public Integer totalRules { get; set; }
        @AuraEnabled public Integer rulesPassed { get; set; }
        @AuraEnabled public Integer rulesFailed { get; set; }
    }

    /**
     * Executes a compliance workflow by template DeveloperName.
     *
     * @param templateDevName The workflow template to execute
     * @return WorkflowExecutionResult with all step results and score
     * @throws AuraHandledException if template not found or execution fails
     */
    public static WorkflowExecutionResult executeWorkflow(String templateDevName) {
        WorkflowTemplateReader.WorkflowTemplate template =
            WorkflowTemplateReader.loadTemplate(templateDevName);

        if (template == null) {
            throw new AuraHandledException('Workflow template not found: ' + templateDevName);
        }

        return executeForFramework(template.framework, template.templateName);
    }

    /**
     * Executes all active rules for a framework and records results.
     *
     * @param framework The compliance framework name
     * @param templateName Display name for audit trail
     * @return WorkflowExecutionResult with all step results and score
     */
    public static WorkflowExecutionResult executeForFramework(String framework, String templateName) {
        Workflow_Execution__c execution = new Workflow_Execution__c(
            Template_Name__c = templateName ?? framework + ' Evaluation',
            Framework__c = framework,
            Status__c = 'RUNNING',
            Started_At__c = Datetime.now()
        );
        insert as user execution;

        List<RuleResult> results = ComplianceRuleEvaluator.evaluateFramework(framework);

        List<Step_Execution__c> stepRecords = new List<Step_Execution__c>();
        for (RuleResult result : results) {
            stepRecords.add(createStepRecord(execution.Id, result));
        }

        if (!stepRecords.isEmpty()) {
            insert as user stepRecords;
        }

        Integer passed = 0;
        Integer failed = 0;
        for (RuleResult result : results) {
            if (result.passed) {
                passed++;
            } else {
                failed++;
            }
        }

        Decimal score = ComplianceScoreAggregator.calculateScore(results);

        execution.Status__c = 'COMPLETED';
        execution.Completed_At__c = Datetime.now();
        execution.Total_Rules__c = results.size();
        execution.Rules_Passed__c = passed;
        execution.Rules_Failed__c = failed;
        execution.Compliance_Score__c = score;
        update as user execution;

        publishFailureAlerts(results, framework);

        WorkflowExecutionResult wfResult = new WorkflowExecutionResult();
        wfResult.workflowExecutionId = execution.Id;
        wfResult.templateName = execution.Template_Name__c;
        wfResult.framework = framework;
        wfResult.status = 'COMPLETED';
        wfResult.ruleResults = results;
        wfResult.complianceScore = score;
        wfResult.totalRules = results.size();
        wfResult.rulesPassed = passed;
        wfResult.rulesFailed = failed;

        ElaroLogger.info('ComplianceOrchestrationEngine.executeForFramework',
            'Completed ' + framework + ' evaluation: ' + passed + '/' + results.size()
            + ' passed, score=' + score);

        return wfResult;
    }

    private static Step_Execution__c createStepRecord(Id workflowId, RuleResult result) {
        return new Step_Execution__c(
            Workflow_Execution__c = workflowId,
            Rule_Developer_Name__c = result.ruleDeveloperName,
            Rule_Name__c = result.ruleName,
            Status__c = result.passed ? 'PASSED' : 'FAILED',
            Severity__c = result.severity,
            Finding_Details__c = result.findingDetails,
            Execution_Time_Ms__c = result.executionTimeMs,
            Executed_At__c = result.evaluatedAt
        );
    }

    private static void publishFailureAlerts(List<RuleResult> results, String framework) {
        for (RuleResult result : results) {
            if (!result.passed && result.severity != null) {
                try {
                    ComplianceAlertPublisher.publishAlert(
                        framework,
                        result.controlReference,
                        result.severity,
                        result.findingDetails ?? 'Rule evaluation failed: ' + result.ruleName,
                        'FINDING',
                        null
                    );
                } catch (Exception e) {
                    ElaroLogger.error('ComplianceOrchestrationEngine.publishFailureAlerts',
                        e.getMessage(), e.getStackTraceString());
                }
            }
        }
    }
}
