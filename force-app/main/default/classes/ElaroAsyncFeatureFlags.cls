/**
 * Accessor for Elaro_Async_Framework_Flags__c hierarchy custom setting.
 * Provides type-safe access to async framework configuration with sensible defaults.
 *
 * @author Elaro Team
 * @since v3.1.0 (Spring '26)
 * @group Async Framework
 * @see Elaro_Async_Framework_Flags__c
 * @see StepProcessor
 */
public inherited sharing class ElaroAsyncFeatureFlags {

    /**
     * Whether the async framework is enabled.
     * @return true if enabled (defaults to true when setting is absent)
     */
    public static Boolean isFrameworkEnabled() {
        Elaro_Async_Framework_Flags__c flags = Elaro_Async_Framework_Flags__c.getInstance();
        return flags?.Use_New_Async_Framework__c ?? true;
    }

    /**
     * Maximum retry count for failed steps.
     * @return Max retries (defaults to 3 when setting is absent)
     */
    public static Integer getMaxRetryCount() {
        Elaro_Async_Framework_Flags__c flags = Elaro_Async_Framework_Flags__c.getInstance();
        return (flags?.Max_Retry_Count__c != null) ? Integer.valueOf(flags.Max_Retry_Count__c) : 3;
    }

    /**
     * Maximum cursor fetch size per transaction.
     * @return Max fetch size (defaults to 200 when setting is absent)
     */
    public static Integer getMaxFetchSize() {
        Elaro_Async_Framework_Flags__c flags = Elaro_Async_Framework_Flags__c.getInstance();
        return (flags?.Max_Cursor_Fetch_Size__c != null) ? Integer.valueOf(flags.Max_Cursor_Fetch_Size__c) : 200;
    }

    /**
     * Whether step execution logging via StepLog__e is enabled.
     * @return true if logging is enabled (defaults to true when setting is absent)
     */
    public static Boolean isStepLoggingEnabled() {
        Elaro_Async_Framework_Flags__c flags = Elaro_Async_Framework_Flags__c.getInstance();
        return flags?.Enable_Step_Logging__c ?? true;
    }
}
