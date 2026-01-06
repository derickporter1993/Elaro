public with sharing class PrometheionComplianceScorer {
    @AuraEnabled(cacheable=true)
    public static Decimal calculateReadinessScore() {
        try {
            Decimal accessScore = calculateAccessGovernanceScore();
            Decimal configScore = calculateConfigHealthScore();
            Decimal automationScore = calculateAutomationSafetyScore();
            Decimal evidenceScore = calculateEvidenceScore();

            return (accessScore + configScore + automationScore + evidenceScore) / 4;
        } catch (Exception e) {
            throw new AuraHandledException('Error calculating readiness score: ' + e.getMessage());
        }
    }

    private static Decimal calculateAccessGovernanceScore() {
        // Validate read access
        if (!PrometheionSecurityUtils.hasReadAccess('PermissionSet')) {
            return 0.0;
        }
        
        // Simplified scoring logic
        Integer totalPermSets = [SELECT COUNT() FROM PermissionSet WHERE IsCustom = true WITH SECURITY_ENFORCED];
        Integer documentedPermSets = [SELECT COUNT() FROM PermissionSet WHERE IsCustom = true AND Description != null WITH SECURITY_ENFORCED];

        if (totalPermSets == 0) return 50.0;
        return (Decimal.valueOf(documentedPermSets) / Decimal.valueOf(totalPermSets)) * 100;
    }

    private static Decimal calculateConfigHealthScore() {
        // Validate read access
        if (!PrometheionSecurityUtils.hasReadAccess('FlowDefinitionView')) {
            return 0.0;
        }
        
        // Simplified scoring logic
        Integer totalFlows = [SELECT COUNT() FROM FlowDefinitionView WHERE IsActive = true WITH SECURITY_ENFORCED];
        Integer safeFlows = [SELECT COUNT() FROM FlowDefinitionView WHERE IsActive = true AND ProcessType = 'Workflow' WITH SECURITY_ENFORCED];

        if (totalFlows == 0) return 75.0;
        return (Decimal.valueOf(safeFlows) / Decimal.valueOf(totalFlows)) * 100;
    }

    private static Decimal calculateAutomationSafetyScore() {
        // Validate read access
        if (!PrometheionSecurityUtils.hasReadAccess('ApexTrigger')) {
            return 0.0;
        }
        
        // Scoring logic: Use number of active triggers and number with descriptions as a proxy for safety
        Integer totalTriggers = [SELECT COUNT() FROM ApexTrigger WHERE Status = 'Active' WITH SECURITY_ENFORCED];
        Integer describedTriggers = [SELECT COUNT() FROM ApexTrigger WHERE Status = 'Active' AND Description != null WITH SECURITY_ENFORCED];

        if (totalTriggers == 0) return 50.0;
        return (Decimal.valueOf(describedTriggers) / Decimal.valueOf(totalTriggers)) * 100;
    }

    private static Decimal calculateEvidenceScore() {
        // Validate read access
        if (!PrometheionSecurityUtils.hasReadAccess('Prometheion_Compliance_Graph__b')) {
            return 0.0;
        }
        
        // Check if we have recent compliance graph entries
        List<Prometheion_Compliance_Graph__b> recentEntries = [
            SELECT Id
            FROM Prometheion_Compliance_Graph__b
            WHERE Timestamp__c >= LAST_N_DAYS:30
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];

        return recentEntries.isEmpty() ? 0.0 : 90.0;
    }
}
