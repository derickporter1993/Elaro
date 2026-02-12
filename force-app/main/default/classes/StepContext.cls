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
    public Map<String, Object> state { get; set; }
    public Integer cursorPosition { get; set; }
    public Integer currentStepIndex { get; set; }
    public List<StepExecutionMetric> metrics { get; set; }
    public List<String> errorHistory { get; set; }
    public Id workflowId { get; set; }
    public Integer retryCount { get; set; }
    public Integer totalRecordsProcessed { get; set; }

    /**
     * Constructs a new StepContext with default empty state.
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
     * Gets a value from the state map by key.
     * @param key The state key
     * @return The value, or null if not found
     */
    public Object get(String key) {
        return state.get(key);
    }

    /**
     * Puts a value into the state map.
     * @param key The state key
     * @param value The value to store
     */
    public void put(String key, Object value) {
        state.put(key, value);
    }

    /**
     * Gets a String value from state, returning empty string if null.
     * @param key The state key
     * @return The String value, or empty string if null
     */
    public String getString(String key) {
        return (String) state.get(key) ?? '';
    }

    /**
     * Gets an Integer value from state, returning 0 if null.
     * @param key The state key
     * @return The Integer value, or 0 if null
     */
    public Integer getInteger(String key) {
        return (Integer) state.get(key) ?? 0;
    }

    /**
     * Gets a Boolean value from state, returning false if null.
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
     * Adds to the running total of records processed across all steps.
     * @param count The number of records processed in this batch
     */
    public void addRecordsProcessed(Integer count) {
        this.totalRecordsProcessed += count;
    }
}
