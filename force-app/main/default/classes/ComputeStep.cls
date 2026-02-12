/**
 * Abstract step for non-query computational work.
 * Subclasses implement compute() to perform calculations, transformations,
 * or aggregations using data already in StepContext.
 *
 * @author Elaro Team
 * @since v3.1.0 (Spring '26)
 * @group Async Framework
 * @see Step
 * @see StepContext
 */
public abstract inherited sharing class ComputeStep implements Step {

    /**
     * Performs the computation using data from the context.
     * @param ctx The shared workflow context
     * @return The computed result to store in context, or null
     */
    public abstract Object compute(StepContext ctx);

    /**
     * Returns the state key under which the compute result is stored.
     * Return null to discard the result.
     * @return The key for StepContext.put(), or null
     */
    public abstract String getResultKey();

    /**
     * Executes the compute step: calls compute() and stores the result.
     * @param ctx The shared workflow context
     */
    public void execute(StepContext ctx) {
        Object result = compute(ctx);
        if (getResultKey() != null) {
            ctx.put(getResultKey(), result);
        }
    }

    /**
     * Called after execution completes. Subclasses implement cleanup logic.
     * @param ctx The shared workflow context
     */
    public abstract void finalize(StepContext ctx);

    /**
     * Returns a human-readable name for logging and auditing.
     * @return The step name
     */
    public abstract String getName();

    /**
     * ComputeSteps run once and do not restart.
     * @return Always false
     */
    public Boolean shouldRestart() {
        return false;
    }
}
