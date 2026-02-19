/**
 * Centralized feature flag utility for enabling or disabling major Elaro modules
 * at the org, profile, or user level via the {@link Elaro_Feature_Flags__c} Hierarchy
 * Custom Setting. All flags default to {@code true} (enabled) when no custom setting
 * record exists, ensuring features are available out-of-the-box after package installation.
 *
 * Subscribers can disable individual modules by creating an Org Default or User-level
 * custom setting record with the corresponding flag set to {@code false}.
 *
 * @author Elaro Team
 * @since v3.1.0 (Spring '26)
 * @group Utilities
 * @see Elaro_Feature_Flags__c
 */
public inherited sharing class FeatureFlags {

    /**
     * Checks whether the Command Center module is enabled for the current user context.
     *
     * @return {@code true} if Command Center is enabled or no custom setting exists; {@code false} if explicitly disabled
     */
    public static Boolean isCommandCenterEnabled() {
        Elaro_Feature_Flags__c flags = Elaro_Feature_Flags__c.getInstance();
        return flags?.Command_Center_Enabled__c ?? true;
    }

    /**
     * Checks whether the Event Monitoring module is enabled for the current user context.
     *
     * @return {@code true} if Event Monitoring is enabled or no custom setting exists; {@code false} if explicitly disabled
     */
    public static Boolean isEventMonitoringEnabled() {
        Elaro_Feature_Flags__c flags = Elaro_Feature_Flags__c.getInstance();
        return flags?.Event_Monitoring_Enabled__c ?? true;
    }

    /**
     * Checks whether the AI Governance module (EU AI Act / NIST AI RMF) is enabled
     * for the current user context.
     *
     * @return {@code true} if AI Governance is enabled or no custom setting exists; {@code false} if explicitly disabled
     */
    public static Boolean isAIGovernanceEnabled() {
        Elaro_Feature_Flags__c flags = Elaro_Feature_Flags__c.getInstance();
        return flags?.AI_Governance_Enabled__c ?? true;
    }

    /**
     * Checks whether the SEC Cybersecurity Disclosure module is enabled for the current user context.
     *
     * @return {@code true} if SEC Module is enabled or no custom setting exists; {@code false} if explicitly disabled
     */
    public static Boolean isSECModuleEnabled() {
        Elaro_Feature_Flags__c flags = Elaro_Feature_Flags__c.getInstance();
        return flags?.SEC_Module_Enabled__c ?? true;
    }

    /**
     * Checks whether the Trust Center module is enabled for the current user context.
     *
     * @return {@code true} if Trust Center is enabled or no custom setting exists; {@code false} if explicitly disabled
     */
    public static Boolean isTrustCenterEnabled() {
        Elaro_Feature_Flags__c flags = Elaro_Feature_Flags__c.getInstance();
        return flags?.Trust_Center_Enabled__c ?? true;
    }

    /**
     * Checks whether the Assessment Wizard module is enabled for the current user context.
     *
     * @return {@code true} if Assessment Wizard is enabled or no custom setting exists; {@code false} if explicitly disabled
     */
    public static Boolean isAssessmentWizardEnabled() {
        Elaro_Feature_Flags__c flags = Elaro_Feature_Flags__c.getInstance();
        return flags?.Assessment_Wizard_Enabled__c ?? true;
    }
}
