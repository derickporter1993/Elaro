/**
 * Captures execution metrics for a single step run.
 * Collected by StepContext and used for performance monitoring and audit logging.
 *
 * @author Elaro Team
 * @since v3.1.0 (Spring '26)
 * @group Async Framework
 */
public inherited sharing class StepExecutionMetric {
    public String stepName { get; set; }
    public Long executionTimeMs { get; set; }
    public Boolean success { get; set; }
    public String errorMessage { get; set; }
    public Integer recordsProcessed { get; set; }
    public Integer soqlQueriesUsed { get; set; }
    public Integer dmlStatementsUsed { get; set; }

    /**
     * Constructs a metric with step name, execution time, and success status.
     * @param stepName The name of the step
     * @param executionTimeMs Duration in milliseconds
     * @param success Whether the step succeeded
     */
    public StepExecutionMetric(String stepName, Long executionTimeMs, Boolean success) {
        this.stepName = stepName;
        this.executionTimeMs = executionTimeMs;
        this.success = success;
        this.recordsProcessed = 0;
    }

    /**
     * Constructs a metric with step name, execution time, success status, and error message.
     * @param stepName The name of the step
     * @param executionTimeMs Duration in milliseconds
     * @param success Whether the step succeeded
     * @param errorMessage The error message if the step failed
     */
    public StepExecutionMetric(String stepName, Long executionTimeMs, Boolean success, String errorMessage) {
        this(stepName, executionTimeMs, success);
        this.errorMessage = errorMessage;
    }
}
