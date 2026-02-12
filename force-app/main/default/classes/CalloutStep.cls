/**
 * Abstract step for HTTP callouts that respects callout-after-DML restrictions.
 * If DML occurred earlier in the same transaction, this step must be deferred
 * to a separate Queueable execution via StepProcessor.
 *
 * Includes automatic retry with configurable max retries for 5xx server errors.
 *
 * @author Elaro Team
 * @since v3.1.0 (Spring '26)
 * @group Async Framework
 * @see Step
 * @see StepContext
 */
public abstract inherited sharing class CalloutStep implements Step {

    /**
     * Builds the HTTP request to send. Called on each attempt (including retries).
     * @param ctx The shared workflow context
     * @return The configured HttpRequest
     */
    public abstract HttpRequest buildRequest(StepContext ctx);

    /**
     * Handles a successful HTTP response (2xx status).
     * @param res The HTTP response
     * @param ctx The shared workflow context
     */
    public abstract void handleResponse(HttpResponse res, StepContext ctx);

    /**
     * Maximum number of retries for 5xx server errors.
     * Override to change the default of 2.
     * @return Max retry count
     */
    public virtual Integer getMaxRetries() {
        return 2;
    }

    /**
     * Executes the callout step with retry logic for server errors.
     * @param ctx The shared workflow context
     * @throws AuraHandledException on 4xx client errors or max retries exceeded
     */
    public void execute(StepContext ctx) {
        if (Limits.getCallouts() >= Limits.getLimitCallouts() - 1) {
            ctx.put('needsRestart', true);
            return;
        }

        HttpRequest req = buildRequest(ctx);
        Http http = new Http();
        HttpResponse res = http.send(req);
        Integer statusCode = res.getStatusCode();

        if (statusCode >= 200 && statusCode < 300) {
            handleResponse(res, ctx);
        } else if (statusCode >= 500) {
            Integer retryCount = ctx.getInteger('calloutRetryCount');
            if (retryCount < getMaxRetries()) {
                ctx.put('calloutRetryCount', retryCount + 1);
                ctx.put('needsRestart', true);
            } else {
                ctx.errorHistory.add(getName() + ': HTTP ' + statusCode + ' after ' + getMaxRetries() + ' retries');
                throw new AuraHandledException('Callout failed: HTTP ' + statusCode);
            }
        } else {
            ctx.errorHistory.add(getName() + ': HTTP ' + statusCode + ' - ' + res.getBody());
            throw new AuraHandledException('Callout failed: HTTP ' + statusCode);
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
     * CalloutSteps run once and do not restart (retries are handled internally).
     * @return Always false
     */
    public Boolean shouldRestart() {
        return false;
    }
}
