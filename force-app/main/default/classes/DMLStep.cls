/**
 * Abstract step for DML operations with auto-chunking to stay within governor limits.
 * DML is always performed 'as user' — never in system context.
 * Auto-chunks records into batches of 200 (configurable).
 *
 * @author Elaro Team
 * @since v3.1.0 (Spring '26)
 * @group Async Framework
 * @see Step
 * @see StepContext
 */
public abstract inherited sharing class DMLStep implements Step {

    /** Number of records per DML batch (default 200) */
    protected Integer batchSize = 200;

    /**
     * Returns the records to process via DML.
     * @param ctx The shared workflow context
     * @return List of SObjects for DML, or null/empty to skip
     */
    public abstract List<SObject> getRecordsToProcess(StepContext ctx);

    /**
     * Processes a single batch of records. Implementations should perform
     * DML using 'as user' syntax (e.g., insert as user batch).
     * @param batch The chunked records
     * @param ctx The shared workflow context
     */
    public abstract void processBatch(List<SObject> batch, StepContext ctx);

    /**
     * Executes the DML step with auto-chunking and governor limit circuit breakers.
     * @param ctx The shared workflow context
     */
    public void execute(StepContext ctx) {
        if (Limits.getDmlStatements() >= Limits.getLimitDmlStatements() - 5) {
            ctx.put('needsRestart', true);
            return;
        }

        List<SObject> allRecords = getRecordsToProcess(ctx);
        if (allRecords == null || allRecords.isEmpty()) {
            return;
        }

        Integer totalRecords = allRecords.size();
        for (Integer i = 0; i < totalRecords; i += batchSize) {
            if (Limits.getDmlStatements() >= Limits.getLimitDmlStatements() - 2) {
                ctx.put('needsRestart', true);
                ctx.put('dmlResumeIndex', i);
                return;
            }
            Integer endIndex = Math.min(i + batchSize, totalRecords);
            List<SObject> batch = new List<SObject>();
            for (Integer j = i; j < endIndex; j++) {
                batch.add(allRecords[j]);
            }
            processBatch(batch, ctx);
        }
        ctx.addRecordsProcessed(totalRecords);
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
     * DMLSteps run once and do not restart.
     * @return Always false
     */
    public Boolean shouldRestart() {
        return false;
    }
}
