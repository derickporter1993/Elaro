/**
 * Captures execution metrics for a single step run.
 * Collected by StepContext and used for performance monitoring and audit logging.
 *
 * @author Elaro Team
 * @since v3.1.0 (Spring '26)
 * @group Async Framework
 * @see StepContext
 * @see StepProcessor
 */
public inherited sharing class StepExecutionMetric {
    /** Name of the step that was executed */
    public String stepName { get; set; }
    /** Wall-clock execution time in milliseconds */
    public Long executionTimeMs { get; set; }
    /** Whether the step completed without exception */
    public Boolean success { get; set; }
    /** Error message if the step failed */
    public String errorMessage { get; set; }
    /** Number of records processed in this execution */
    public Integer recordsProcessed { get; set; }
    /** SOQL queries consumed during execution */
    public Integer soqlQueriesUsed { get; set; }
    /** DML statements consumed during execution */
    public Integer dmlStatementsUsed { get; set; }

    /**
     * Constructs a metric for a successful or failed step run.
     * @param stepName The step name
     * @param executionTimeMs Wall-clock time in milliseconds
     * @param success Whether the step succeeded
     */
    public StepExecutionMetric(String stepName, Long executionTimeMs, Boolean success) {
        this.stepName = stepName;
        this.executionTimeMs = executionTimeMs;
        this.success = success;
        this.recordsProcessed = 0;
    }

    /**
     * Constructs a metric for a failed step run with error detail.
     * @param stepName The step name
     * @param executionTimeMs Wall-clock time in milliseconds
     * @param success Whether the step succeeded
     * @param errorMessage The error message
     */
    public StepExecutionMetric(String stepName, Long executionTimeMs, Boolean success, String errorMessage) {
        this(stepName, executionTimeMs, success);
        this.errorMessage = errorMessage;
    }
}
