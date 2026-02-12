/**
 * Step implementation that wraps a Flow.Interview, enabling declarative
 * flows to participate in the Step-Based Async Framework.
 *
 * The flow receives the entire StepContext state as input variables.
 *
 * @author Elaro Team
 * @since v3.1.0 (Spring '26)
 * @group Async Framework
 * @see Step
 * @see StepContext
 */
public inherited sharing class FlowStep implements Step {

    private String flowApiName;

    /**
     * Constructs a FlowStep for the given flow API name.
     * @param flowApiName The developer name of the flow to invoke
     */
    public FlowStep(String flowApiName) {
        this.flowApiName = flowApiName;
    }

    /**
     * Invokes the flow, passing the current context state as input variables.
     * @param ctx The shared workflow context
     */
    public void execute(StepContext ctx) {
        Map<String, Object> inputs = new Map<String, Object>();
        inputs.putAll(ctx.state);
        Flow.Interview flow = Flow.Interview.createInterview(flowApiName, inputs);
        flow.start();
    }

    /**
     * No-op finalization — flow cleanup is handled by the runtime.
     * @param ctx The shared workflow context
     */
    public void finalize(StepContext ctx) {
        /* Flow cleanup handled by runtime */
    }

    /**
     * Returns the step name including the flow API name.
     * @return The step name in format FlowStep:flowApiName
     */
    public String getName() {
        return 'FlowStep:' + flowApiName;
    }

    /**
     * FlowSteps run once and do not restart.
     * @return Always false
     */
    public Boolean shouldRestart() {
        return false;
    }
}
