/**
 * Null object implementation of Step. Does nothing.
 * Use when a step is disabled by feature flag or as a placeholder
 * in workflow templates.
 *
 * @author Elaro Team
 * @since v3.1.0 (Spring '26)
 * @group Async Framework
 * @see Step
 */
public inherited sharing class NoOpStep implements Step {

    /**
     * No-op execution — intentionally does nothing.
     * @param ctx The shared workflow context
     */
    public void execute(StepContext ctx) {
        /* intentionally empty */
    }

    /**
     * No-op finalization — intentionally does nothing.
     * @param ctx The shared workflow context
     */
    public void finalize(StepContext ctx) {
        /* intentionally empty */
    }

    /**
     * Returns the step name.
     * @return Always 'NoOp'
     */
    public String getName() {
        return 'NoOp';
    }

    /**
     * NoOpStep never restarts.
     * @return Always false
     */
    public Boolean shouldRestart() {
        return false;
    }
}
