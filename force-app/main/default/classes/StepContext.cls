/**
 * Serializable context object passed between steps in a workflow.
 * Stores cursor position, execution metrics, error history, and arbitrary state.
 * StepContext is the ONLY communication channel between steps.
 * NEVER use static variables, Custom Settings, or Platform Cache to pass state between steps.
 *
 * @author Elaro Team
 * @since v3.1.0 (Spring '26)
 * @group Async Framework
 * @see Step
 * @see StepProcessor
 */
public inherited sharing class StepContext {
    /** Arbitrary key-value state shared across steps */
    public Map<String, Object> state { get; set; }
    /** Current cursor fetch position for CursorStep */
    public Integer cursorPosition { get; set; }
    /** Index of the currently executing step in the workflow */
    public Integer currentStepIndex { get; set; }
    /** Execution metrics collected from each step run */
    public List<StepExecutionMetric> metrics { get; set; }
    /** Chronological error messages for debugging */
    public List<String> errorHistory { get; set; }
    /** Optional reference to a Workflow_Execution__c record */
    public Id workflowId { get; set; }
    /** Number of consecutive retries for the current step */
    public Integer retryCount { get; set; }
    /** Running total of records processed across all steps */
    public Integer totalRecordsProcessed { get; set; }

    /**
     * Constructs a new StepContext with default values.
     */
    public StepContext() {
        this.state = new Map<String, Object>();
        this.cursorPosition = 0;
        this.currentStepIndex = 0;
        this.metrics = new List<StepExecutionMetric>();
        this.errorHistory = new List<String>();
        this.retryCount = 0;
        this.totalRecordsProcessed = 0;
    }

    /**
     * Retrieves a value from the state map.
     * @param key The state key
     * @return The value, or null if not present
     */
    public Object get(String key) {
        return state.get(key);
    }

    /**
     * Stores a value in the state map.
     * @param key The state key
     * @param value The value to store
     */
    public void put(String key, Object value) {
        state.put(key, value);
    }

    /**
     * Retrieves a String value with empty-string default.
     * @param key The state key
     * @return The String value, or empty string if null
     */
    public String getString(String key) {
        return (String) state.get(key) ?? '';
    }

    /**
     * Retrieves an Integer value with zero default.
     * @param key The state key
     * @return The Integer value, or 0 if null
     */
    public Integer getInteger(String key) {
        return (Integer) state.get(key) ?? 0;
    }

    /**
     * Retrieves a Boolean value with false default.
     * @param key The state key
     * @return The Boolean value, or false if null
     */
    public Boolean getBoolean(String key) {
        return (Boolean) state.get(key) ?? false;
    }

    /**
     * Checks whether the state map contains a given key.
     * @param key The state key
     * @return true if the key exists
     */
    public Boolean hasKey(String key) {
        return state.containsKey(key);
    }

    /**
     * Removes a key from the state map.
     * @param key The state key to remove
     */
    public void remove(String key) {
        state.remove(key);
    }

    /**
     * Increments the running total of records processed.
     * @param count Number of records to add
     */
    public void addRecordsProcessed(Integer count) {
        this.totalRecordsProcessed += count;
    }
}
