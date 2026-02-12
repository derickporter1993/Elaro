/**
 * Contract for all executable steps in the Elaro async processing framework.
 * Each step represents a discrete unit of work that can be composed into workflows.
 *
 * Implementations must be idempotent: if execute() processes records 1-2000 and
 * fails at record 1500, the Finalizer will re-run the entire step. Use upsert
 * with external IDs or check-before-insert patterns.
 *
 * @author Elaro Team
 * @since v3.1.0 (Spring '26)
 * @group Async Framework
 * @see StepContext
 * @see StepProcessor
 */
public interface Step {
    /**
     * Execute the step's work. Must be idempotent.
     * @param ctx The shared context carrying state between steps
     */
    void execute(StepContext ctx);

    /**
     * Called after the step completes all iterations (cursor exhausted or single-run complete).
     * Use for cleanup, summary logging, or state preparation for next step.
     * @param ctx The shared context carrying state between steps
     */
    void finalize(StepContext ctx);

    /**
     * Returns a human-readable name for logging and auditing.
     * @return The step name
     */
    String getName();

    /**
     * Whether the step should be re-enqueued after a successful execute() call.
     * CursorSteps return true while records remain. Single-run steps return false.
     * @return true if the step should restart, false if it is complete
     */
    Boolean shouldRestart();
}
