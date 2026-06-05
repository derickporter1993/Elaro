/**
 * Scheduled refresh for the PHI Data Classification Engine (issue #212, HIPAA pack).
 *
 * Re-classifies every object that already has entries in PHI_Field_Registry__c so the registry
 * stays current as schema evolves. Runs the work in a Queueable outside of test context for
 * better error isolation. No-op when the HIPAA pack is disabled.
 *
 * Example: System.schedule('Elaro PHI Classification Refresh', '0 0 3 * * ?', new PHIClassificationScheduler());
 *
 * @author Elaro Team
 * @since v3.2.0 (Spring '26)
 * @group HIPAA Pack
 * @see PHIClassificationService
 */
public with sharing class PHIClassificationScheduler implements Schedulable {

    /**
     * Schedulable entry point.
     *
     * @param ctx Schedulable context
     */
    public void execute(SchedulableContext ctx) {
        if (Test.isRunningTest()) {
            refresh();
        } else {
            System.enqueueJob(new RefreshQueueable());
        }
    }

    /**
     * Re-classifies all objects currently represented in PHI_Field_Registry__c.
     */
    @TestVisible
    private static void refresh() {
        if (!FeatureFlags.isHipaaPackEnabled()) {
            return;
        }
        Set<String> objectNames = new Set<String>();
        for (PHI_Field_Registry__c rec : [
            SELECT Object_API_Name__c
            FROM PHI_Field_Registry__c
            WHERE Object_API_Name__c != null
            WITH USER_MODE
        ]) {
            objectNames.add(rec.Object_API_Name__c);
        }

        PHIClassificationService service = new PHIClassificationService();
        for (String objectName : objectNames) {
            service.classifyObject(objectName);
        }
        ElaroLogger.info(
            'PHIClassificationScheduler.refresh',
            'Refreshed PHI classification for ' + objectNames.size() + ' object(s)'
        );
    }

    /**
     * Queueable wrapper for asynchronous refresh.
     */
    public class RefreshQueueable implements Queueable {
        /**
         * @param context Queueable context
         */
        public void execute(QueueableContext context) {
            try {
                refresh();
            } catch (Exception e) {
                ElaroLogger.error('PHIClassificationScheduler.RefreshQueueable', e.getMessage(), e.getStackTraceString());
            }
        }
    }
}
