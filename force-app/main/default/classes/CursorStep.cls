/**
 * Abstract step that wraps Database.getCursor() for processing large datasets.
 * Subclasses implement getCursorQuery(), getCursorBinds(), and innerExecute().
 * The framework handles cursor creation, position tracking, and re-enqueueing.
 *
 * CURSOR LIMITS (Spring '26 GA):
 * - 50 million rows per cursor
 * - 10 fetch() calls per transaction (each counts against SOQL query limit)
 * - Max 2,000 records per fetch() call
 * - 10,000 cursor instances per 24 hours (standard)
 * - Cursors do NOT support Big Objects — use standard SOQL with LIMIT for Big Objects
 *
 * Uses a virtual CursorWrapper to enable test mocking via CursorLike subclass.
 * NEVER instantiate real cursors in unit tests.
 *
 * @author Elaro Team
 * @since v3.1.0 (Spring '26)
 * @group Async Framework
 * @see Step
 * @see StepProcessor
 */
public abstract inherited sharing class CursorStep implements Step {

    /** Number of records to fetch per cursor call (max 2000) */
    protected Integer fetchSize = 200;
    /** Whether more records remain to be fetched */
    protected Boolean hasMoreRecords = false;

    /** Wrapper around the real or mock cursor */
    @TestVisible
    protected CursorWrapper cursorWrapper;

    /**
     * Returns the SOQL query string for the cursor.
     * @return SOQL query string (do NOT include WITH USER_MODE — handled by framework)
     */
    public abstract String getCursorQuery();

    /**
     * Returns bind variable map for the cursor query.
     * Return null or empty map if no binds are needed.
     * @return Map of bind variable names to values
     */
    public abstract Map<String, Object> getCursorBinds();

    /**
     * Processes a batch of records fetched by the cursor.
     * Must be idempotent — may be re-executed on retry.
     * @param records The fetched SObject records
     * @param ctx The shared workflow context
     */
    public abstract void innerExecute(List<SObject> records, StepContext ctx);

    /**
     * Virtual wrapper around Database.Cursor to enable test mocking.
     * Production code uses the real cursor; tests inject CursorLike.
     */
    public virtual class CursorWrapper {
        private Database.Cursor realCursor;

        /**
         * Wraps a real Database.Cursor instance.
         * @param cursor The platform cursor
         */
        public CursorWrapper(Database.Cursor cursor) {
            this.realCursor = cursor;
        }

        /** Protected no-arg constructor for CursorLike subclass */
        @TestVisible
        protected CursorWrapper() {}

        /**
         * Fetches records from the cursor at the given position.
         * @param position The zero-based start position
         * @param count Number of records to fetch
         * @return List of fetched SObjects
         */
        public virtual List<SObject> fetch(Integer position, Integer count) {
            return realCursor.fetch(position, count);
        }

        /**
         * Returns the total number of records matched by the cursor query.
         * @return Total record count
         */
        public virtual Integer getNumRecords() {
            return realCursor.getNumRecords();
        }
    }

    /**
     * Test-only cursor implementation backed by an in-memory List.
     * Inject via cursorWrapper field in test classes.
     */
    public class CursorLike extends CursorWrapper {
        private List<SObject> testData;

        /**
         * Constructs a mock cursor from test data.
         * @param data The in-memory records to simulate cursor results
         */
        public CursorLike(List<SObject> data) {
            super();
            this.testData = data;
        }

        /**
         * Returns a slice of the test data simulating a cursor fetch.
         * @param position The zero-based start position
         * @param count Number of records to return
         * @return Sublist of test data
         */
        public override List<SObject> fetch(Integer position, Integer count) {
            Integer endPos = Math.min(position + count, testData.size());
            List<SObject> chunk = new List<SObject>();
            for (Integer i = position; i < endPos; i++) {
                chunk.add(testData[i]);
            }
            return chunk;
        }

        /**
         * Returns the total size of the test data.
         * @return Number of test records
         */
        public override Integer getNumRecords() {
            return testData.size();
        }
    }

    /**
     * Executes the cursor step: creates cursor if needed, fetches a batch, delegates to innerExecute.
     * Includes circuit breakers for SOQL query and CPU time limits.
     * @param ctx The shared workflow context
     */
    public void execute(StepContext ctx) {
        if (Limits.getQueries() >= Limits.getLimitQueries() - 5) {
            ctx.put('needsRestart', true);
            return;
        }
        if (Limits.getCpuTime() >= Limits.getLimitCpuTime() - 2000) {
            ctx.put('needsRestart', true);
            return;
        }

        if (this.cursorWrapper == null) {
            Map<String, Object> binds = getCursorBinds();
            Database.Cursor realCursor = (binds != null && !binds.isEmpty())
                ? Database.getCursorWithBinds(getCursorQuery(), binds, AccessLevel.USER_MODE)
                : Database.getCursor(getCursorQuery());
            this.cursorWrapper = new CursorWrapper(realCursor);
        }

        Integer totalRecords = cursorWrapper.getNumRecords();
        Integer position = ctx.cursorPosition;

        if (position >= totalRecords) {
            this.hasMoreRecords = false;
            return;
        }

        Integer actualFetchSize = Math.min(this.fetchSize, 2000);
        List<SObject> records = cursorWrapper.fetch(position, actualFetchSize);

        if (!records.isEmpty()) {
            innerExecute(records, ctx);
            ctx.addRecordsProcessed(records.size());
        }

        ctx.cursorPosition = position + records.size();
        this.hasMoreRecords = (ctx.cursorPosition < totalRecords);
    }

    /**
     * Called after the cursor is exhausted. Subclasses implement cleanup logic.
     * @param ctx The shared workflow context
     */
    public abstract void finalize(StepContext ctx);

    /**
     * Returns a human-readable name for logging and auditing.
     * @return The step name
     */
    public abstract String getName();

    /**
     * Returns true if more records remain to be fetched from the cursor.
     * @return true if cursor has more records
     */
    public Boolean shouldRestart() {
        return this.hasMoreRecords;
    }

    /**
     * Sets the fetch size, clamped between 1 and 2000.
     * @param size Desired fetch size
     */
    protected void setFetchSize(Integer size) {
        this.fetchSize = Math.min(Math.max(size, 1), 2000);
    }
}
