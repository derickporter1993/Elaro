/**
 * Periodic evaluation driver for the Workforce Access Risk Engine (issue #213, HIPAA pack).
 *
 * Implements both Schedulable (to kick off a run on a schedule) and Database.Batchable (to
 * evaluate active users in bulk). No-op when the HIPAA pack is disabled.
 *
 * Example: System.schedule('Elaro Workforce Access Risk', '0 0 4 * * ?', new WorkforceAccessRiskBatch());
 *
 * @author Elaro Team
 * @since v3.2.0 (Spring '26)
 * @group HIPAA Pack
 * @see WorkforceAccessRiskService
 */
public with sharing class WorkforceAccessRiskBatch implements Database.Batchable<SObject>, Schedulable {

    private static final Integer BATCH_SIZE = 200;

    /**
     * Schedulable entry point — launches the batch.
     *
     * @param ctx Schedulable context
     */
    public void execute(SchedulableContext ctx) {
        if (FeatureFlags.isHipaaPackEnabled()) {
            Database.executeBatch(this, BATCH_SIZE);
        }
    }

    /**
     * Batch start — selects active users to evaluate.
     *
     * @param bc Batchable context
     * @return Query locator over active users
     */
    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([SELECT Id FROM User WHERE IsActive = true WITH USER_MODE]);
    }

    /**
     * Batch execute — evaluates a chunk of users.
     *
     * @param bc Batchable context
     * @param scope Users in this chunk
     */
    public void execute(Database.BatchableContext bc, List<User> scope) {
        if (!FeatureFlags.isHipaaPackEnabled()) {
            return;
        }
        List<Id> userIds = new List<Id>();
        for (User u : scope) {
            userIds.add(u.Id);
        }
        try {
            new WorkforceAccessRiskService().evaluateUsers(userIds);
        } catch (Exception e) {
            ElaroLogger.error('WorkforceAccessRiskBatch.execute', e.getMessage(), e.getStackTraceString());
        }
    }

    /**
     * Batch finish — logs completion.
     *
     * @param bc Batchable context
     */
    public void finish(Database.BatchableContext bc) {
        ElaroLogger.info('WorkforceAccessRiskBatch.finish', 'Workforce access risk evaluation complete');
    }
}
