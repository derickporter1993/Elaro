/**
 * Core orchestrator that executes a sequence of Steps as Queueable jobs.
 * Implements System.Queueable and System.Finalizer for retry and error handling.
 *
 * On SUCCESS: advances to next step or restarts current step (if shouldRestart()).
 * On UNHANDLED_EXCEPTION: logs error, retries up to maxRetries with exponential backoff.
 *
 * @author Elaro Team
 * @since v3.1.0 (Spring '26)
 * @group Async Framework
 * @see Step
 * @see StepContext
 * @see ElaroAsyncFeatureFlags
 */
public inherited sharing class StepProcessor implements Queueable, Finalizer {

    private List<Step> steps;
    private StepContext ctx;
    private Integer maxRetries;
    private static final Integer DEFAULT_MAX_RETRIES = 3;
    private static final Integer MAX_STACK_DEPTH = 10;

    /**
     * Constructs a StepProcessor for the given steps and context.
     * @param steps Ordered list of steps to execute
     * @param ctx The shared workflow context
     */
    public StepProcessor(List<Step> steps, StepContext ctx) {
        this.steps = steps;
        this.ctx = ctx;
        this.maxRetries = ElaroAsyncFeatureFlags.getMaxRetryCount() ?? DEFAULT_MAX_RETRIES;
    }

    /**
     * Queueable execute: runs the current step, captures metrics, publishes log event.
     * @param qCtx The Queueable context
     */
    public void execute(QueueableContext qCtx) {
        System.attachFinalizer(this);

        if (!ElaroAsyncFeatureFlags.isFrameworkEnabled()) {
            publishStepLog('StepProcessor', false, 'Framework disabled via feature flag', 0);
            return;
        }
        if (ctx.currentStepIndex >= steps.size()) {
            return;
        }
        if (Limits.getQueueableJobs() >= Limits.getLimitQueueableJobs() - 1) {
            publishStepLog('StepProcessor', false, 'Queueable limit approaching, halting', 0);
            return;
        }

        Step current = steps[ctx.currentStepIndex];
        Long startTime = System.currentTimeMillis();
        Integer startQueries = Limits.getQueries();
        Integer startDml = Limits.getDmlStatements();

        current.execute(ctx);

        Long executionTime = System.currentTimeMillis() - startTime;
        StepExecutionMetric metric = new StepExecutionMetric(current.getName(), executionTime, true);
        metric.soqlQueriesUsed = Limits.getQueries() - startQueries;
        metric.dmlStatementsUsed = Limits.getDmlStatements() - startDml;
        ctx.metrics.add(metric);

        publishStepLog(current.getName(), true, null, executionTime);
    }

    /**
     * Finalizer execute: handles post-execution logic for success and failure.
     * On success, advances to next step or re-enqueues for cursor continuation.
     * On failure, retries with exponential backoff up to maxRetries.
     * @param fCtx The Finalizer context
     */
    public void execute(FinalizerContext fCtx) {
        if (fCtx.getResult() == ParentJobResult.SUCCESS) {
            Step current = steps[ctx.currentStepIndex];
            if (current.shouldRestart() || ctx.getBoolean('needsRestart')) {
                ctx.remove('needsRestart');
                ctx.retryCount = 0;
                enqueueNext();
            } else {
                current.finalize(ctx);
                ctx.currentStepIndex++;
                if (ctx.currentStepIndex < steps.size()) {
                    ctx.cursorPosition = 0;
                    ctx.retryCount = 0;
                    enqueueNext();
                }
            }
        } else if (fCtx.getResult() == ParentJobResult.UNHANDLED_EXCEPTION) {
            String error = fCtx.getException()?.getMessage() ?? 'Unknown error';
            ctx.errorHistory.add(Datetime.now().format() + ': ' + error);
            String stepName = (ctx.currentStepIndex < steps.size())
                ? steps[ctx.currentStepIndex].getName()
                : 'Unknown';
            publishStepLog(stepName, false, error, 0);

            ctx.retryCount++;
            if (ctx.retryCount <= maxRetries) {
                Integer delayMinutes = (Integer) Math.pow(2, ctx.retryCount - 1);
                AsyncOptions options = new AsyncOptions();
                options.setMaximumQueueableStackDepth(MAX_STACK_DEPTH);
                options.setMinimumQueueableDelayInMinutes(delayMinutes);
                System.enqueueJob(this, options);
            }
        }
    }

    /**
     * Enqueues this processor for the next execution cycle.
     */
    private void enqueueNext() {
        AsyncOptions options = new AsyncOptions();
        options.setMaximumQueueableStackDepth(MAX_STACK_DEPTH);
        System.enqueueJob(this, options);
    }

    /**
     * Publishes a StepLog__e Platform Event for observability.
     * @param stepName The step name
     * @param success Whether the step succeeded
     * @param errorMsg Error message if failed
     * @param execTimeMs Execution time in milliseconds
     */
    private void publishStepLog(String stepName, Boolean success, String errorMsg, Long execTimeMs) {
        StepLog__e logEvent = new StepLog__e(
            Step_Name__c = stepName,
            Success__c = success,
            Error_Message__c = (errorMsg != null) ? errorMsg.left(5000) : null,
            Execution_Time_Ms__c = execTimeMs,
            Records_Processed__c = ctx.totalRecordsProcessed,
            Workflow_Id__c = (ctx.workflowId != null) ? String.valueOf(ctx.workflowId) : null,
            Timestamp__c = Datetime.now(),
            CPU_Time_Ms__c = Limits.getCpuTime()
        );
        EventBus.publish(logEvent);
    }

    /**
     * Convenience factory: runs steps with a fresh StepContext.
     * @param steps Ordered list of steps to execute
     * @return The enqueued job Id
     */
    public static Id run(List<Step> steps) {
        return run(steps, new StepContext());
    }

    /**
     * Factory: runs steps with the provided StepContext.
     * @param steps Ordered list of steps to execute
     * @param ctx The shared workflow context
     * @return The enqueued job Id
     */
    public static Id run(List<Step> steps, StepContext ctx) {
        StepProcessor processor = new StepProcessor(steps, ctx);
        return System.enqueueJob(processor);
    }
}
