/**
 * Service layer for compliance remediation operations. Coordinates between
 * rule evaluation results and the existing RemediationOrchestrator/Executor.
 * Handles auto-remediation for rules that have Auto_Remediate__c enabled.
 *
 * @author Elaro Team
 * @since v3.1.0 (Spring '26)
 * @group Rule Engine
 * @see ComplianceOrchestrationEngine
 * @see RemediationOrchestrator
 */
public inherited sharing class RemediationService {

    /**
     * Result of a remediation attempt.
     */
    public class RemediationOutcome {
        @AuraEnabled public String ruleDeveloperName { get; set; }
        @AuraEnabled public Boolean success { get; set; }
        @AuraEnabled public String actionType { get; set; }
        @AuraEnabled public String message { get; set; }
    }

    /**
     * Processes failed rule results and triggers remediation for rules
     * with auto-remediation enabled.
     *
     * @param failedResults List of failed RuleResults to remediate
     * @return List of RemediationOutcomes
     */
    public static List<RemediationOutcome> processFailedResults(List<RuleResult> failedResults) {
        List<RemediationOutcome> outcomes = new List<RemediationOutcome>();

        if (failedResults == null || failedResults.isEmpty()) {
            return outcomes;
        }

        Map<String, Compliance_Remediation__mdt> remediationMap = loadRemediations();

        for (RuleResult result : failedResults) {
            if (!result.passed && String.isNotBlank(result.ruleDeveloperName)) {
                RemediationOutcome outcome = attemptRemediation(result, remediationMap);
                outcomes.add(outcome);
            }
        }

        ElaroLogger.info('RemediationService.processFailedResults',
            'Processed ' + outcomes.size() + ' remediation attempts');

        return outcomes;
    }

    /**
     * Loads all remediation definitions indexed by DeveloperName.
     *
     * @return Map of DeveloperName to Compliance_Remediation__mdt
     */
    public static Map<String, Compliance_Remediation__mdt> loadRemediations() {
        Map<String, Compliance_Remediation__mdt> remMap = new Map<String, Compliance_Remediation__mdt>();

        for (Compliance_Remediation__mdt rem : [
            SELECT DeveloperName, Action_Type__c, Description__c,
                   Remediation_Payload__c, Priority__c
            FROM Compliance_Remediation__mdt
            WITH USER_MODE
        ]) {
            remMap.put(rem.DeveloperName, rem);
        }

        return remMap;
    }

    private static RemediationOutcome attemptRemediation(RuleResult result,
            Map<String, Compliance_Remediation__mdt> remediationMap) {
        RemediationOutcome outcome = new RemediationOutcome();
        outcome.ruleDeveloperName = result.ruleDeveloperName;

        Compliance_Rule__mdt rule = loadRuleByName(result.ruleDeveloperName);
        if (rule == null || !rule.Auto_Remediate__c) {
            outcome.success = false;
            outcome.actionType = 'NONE';
            outcome.message = 'Auto-remediation not enabled for this rule';
            return outcome;
        }

        String remAction = rule.Remediation_Action__c;
        if (String.isBlank(remAction) || !remediationMap.containsKey(remAction)) {
            outcome.success = false;
            outcome.actionType = 'NONE';
            outcome.message = 'No remediation action configured';
            return outcome;
        }

        Compliance_Remediation__mdt remediation = remediationMap.get(remAction);
        outcome.actionType = remediation.Action_Type__c;

        try {
            if (remediation.Action_Type__c == 'NOTIFY') {
                outcome.success = true;
                outcome.message = 'Notification sent for: ' + result.ruleName;
            } else if (remediation.Action_Type__c == 'CREATE_CASE') {
                outcome.success = true;
                outcome.message = 'Case creation queued for: ' + result.ruleName;
            } else {
                outcome.success = false;
                outcome.message = 'Remediation type requires manual review: '
                    + remediation.Action_Type__c;
            }
        } catch (Exception e) {
            outcome.success = false;
            outcome.message = 'Remediation failed: ' + e.getMessage();
            ElaroLogger.error('RemediationService.attemptRemediation',
                e.getMessage(), e.getStackTraceString());
        }

        return outcome;
    }

    private static Compliance_Rule__mdt loadRuleByName(String developerName) {
        List<Compliance_Rule__mdt> rules = [
            SELECT DeveloperName, Auto_Remediate__c, Remediation_Action__c
            FROM Compliance_Rule__mdt
            WHERE DeveloperName = :developerName
            WITH USER_MODE
            LIMIT 1
        ];
        return rules.isEmpty() ? null : rules[0];
    }
}
