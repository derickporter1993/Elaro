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

    /** Module identifier for the Command Center kill switch. */
    public static final String MODULE_COMMAND_CENTER = 'COMMAND_CENTER';
    /** Module identifier for the Event Monitoring kill switch. */
    public static final String MODULE_EVENT_MONITORING = 'EVENT_MONITORING';
    /** Module identifier for the AI Governance kill switch. */
    public static final String MODULE_AI_GOVERNANCE = 'AI_GOVERNANCE';
    /** Module identifier for the SEC Cybersecurity Disclosure kill switch. */
    public static final String MODULE_SEC = 'SEC_MODULE';
    /** Module identifier for the Trust Center kill switch. */
    public static final String MODULE_TRUST_CENTER = 'TRUST_CENTER';
    /** Module identifier for the Assessment Wizard kill switch. */
    public static final String MODULE_ASSESSMENT_WIZARD = 'ASSESSMENT_WIZARD';

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

    /**
     * @description Returns whether the named module is enabled for the current user context.
     *
     * @param moduleName One of the MODULE_* identifiers
     * @return {@code true} if enabled or unknown; {@code false} if explicitly disabled
     */
    public static Boolean isEnabled(String moduleName) {
        switch on moduleName {
            when 'COMMAND_CENTER' {
                return isCommandCenterEnabled();
            }
            when 'EVENT_MONITORING' {
                return isEventMonitoringEnabled();
            }
            when 'AI_GOVERNANCE' {
                return isAIGovernanceEnabled();
            }
            when 'SEC_MODULE' {
                return isSECModuleEnabled();
            }
            when 'TRUST_CENTER' {
                return isTrustCenterEnabled();
            }
            when 'ASSESSMENT_WIZARD' {
                return isAssessmentWizardEnabled();
            }
            when else {
                // Unknown modules are treated as enabled so a typo never silently
                // disables a feature; add a MODULE_* constant for every real module.
                return true;
            }
        }
    }

    /**
     * @description Throws an {@link AuraHandledException} when the named module is disabled,
     * for use as a guard at the top of module controller entry points.
     *
     * @param moduleName One of the MODULE_* identifiers
     * @throws AuraHandledException with a stable Custom Label message when disabled
     */
    public static void requireEnabled(String moduleName) {
        if (!isEnabled(moduleName)) {
            throw new AuraHandledException(System.Label.Feature_Disabled);
        }
    }
}
