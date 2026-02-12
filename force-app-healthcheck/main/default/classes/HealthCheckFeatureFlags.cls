/**
 * Provides access to the Health Check Feature Flags hierarchy custom setting.
 * Acts as a kill switch for subscriber orgs to disable scanning features.
 *
 * @author Elaro Team
 * @since v1.0.0 (Spring '26)
 * @group Health Check
 */
public inherited sharing class HealthCheckFeatureFlags {

    /**
     * Checks whether the Health Check scanning feature is enabled.
     * Defaults to true if no custom setting record exists.
     *
     * @return True if scanning is enabled
     */
    public static Boolean isEnabled() {
        Health_Check_Feature_Flags__c flags = Health_Check_Feature_Flags__c.getInstance();
        return flags?.Health_Check_Enabled__c ?? true;
    }

    /**
     * Returns the maximum number of days to look back for LoginHistory
     * and SetupAuditTrail queries.
     * Defaults to 90 if no custom setting record exists.
     *
     * @return Number of lookback days
     */
    public static Integer getMaxDays() {
        Health_Check_Feature_Flags__c flags = Health_Check_Feature_Flags__c.getInstance();
        Decimal days = flags?.Max_LoginHistory_Days__c;
        return days != null ? days.intValue() : 90;
    }
}
