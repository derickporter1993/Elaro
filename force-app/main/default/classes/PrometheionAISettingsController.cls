public with sharing class PrometheionAISettingsController {
    @AuraEnabled(cacheable=true)
    public static Prometheion_AI_Settings__c getSettings() {
        // Validate read access
        if (!PrometheionSecurityUtils.hasReadAccess('Prometheion_AI_Settings__c')) {
            throw new AuraHandledException('Insufficient access to AI Settings');
        }
        
        Prometheion_AI_Settings__c settings = Prometheion_AI_Settings__c.getInstance();
        if (settings == null) {
            // Return in-memory default (don't create record here - let saveSettings handle it)
            settings = new Prometheion_AI_Settings__c(
                Enable_AI_Reasoning__c = true,
                Confidence_Threshold__c = 0.85,
                Require_Human_Approval__c = true,
                Auto_Remediation_Enabled__c = false,
                Blacklisted_Users__c = ''
            );
        }
        return settings;
    }

    @AuraEnabled
    public static void saveSettings(Prometheion_AI_Settings__c settings) {
        // Input validation
        if (settings == null) {
            throw new AuraHandledException('Settings cannot be null');
        }
        
        // Validate Confidence_Threshold__c range (0.0 to 1.0)
        if (settings.Confidence_Threshold__c != null) {
            if (settings.Confidence_Threshold__c < 0.0 || settings.Confidence_Threshold__c > 1.0) {
                throw new AuraHandledException('Confidence threshold must be between 0.0 and 1.0');
            }
        }
        
        // Validate CRUD access
        PrometheionSecurityUtils.validateCRUDAccess('Prometheion_AI_Settings__c', PrometheionSecurityUtils.DmlOperation.UPSERT);
        
        // Validate FLS for required fields
        List<String> requiredFields = new List<String>{
            'Enable_AI_Reasoning__c', 'Confidence_Threshold__c', 
            'Require_Human_Approval__c', 'Auto_Remediation_Enabled__c'
        };
        PrometheionSecurityUtils.validateFLSAccess('Prometheion_AI_Settings__c', requiredFields, true);
        
        try {
            // Strip inaccessible fields before upsert
            List<SObject> accessibleSettings = PrometheionSecurityUtils.stripInaccessibleFields(
                AccessType.UPDATABLE,
                new List<SObject>{settings}
            );
            if (accessibleSettings.isEmpty()) {
                throw new AuraHandledException('Insufficient field-level security access');
            }
            upsert accessibleSettings;
        } catch (PrometheionSecurityUtils.SecurityException e) {
            throw new AuraHandledException('Security error: ' + e.getMessage());
        } catch (Exception e) {
            throw new AuraHandledException('Error saving settings: ' + e.getMessage());
        }
    }
}
