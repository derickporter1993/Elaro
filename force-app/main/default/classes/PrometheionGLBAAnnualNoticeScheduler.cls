/**
 * GLBAAnnualNoticeScheduler - Scheduled job for GLBA annual privacy notices
 *
 * Automatically sends annual privacy notices to customers who are due.
 * Should be scheduled to run daily to ensure timely notice delivery.
 *
 * Schedule Example:
 * System.schedule('GLBA Annual Notice Check', '0 0 6 * * ?', new GLBAAnnualNoticeScheduler());
 *
 * @author Prometheion
 * @version 1.1
 */
public with sharing class PrometheionGLBAAnnualNoticeScheduler implements Schedulable {

    private static final String SCHEDULER_NAME = 'PrometheionGLBAAnnualNoticeScheduler';
    private static final Integer DEFAULT_BATCH_SIZE = 200;

    /**
     * Execute the scheduled job
     * @param sc - SchedulableContext
     */
    public void execute(SchedulableContext sc) {
        System.debug(LoggingLevel.INFO, '[' + SCHEDULER_NAME + '] Starting execution');
        
        try {
            // Check if it's a business day
            if (!SchedulerErrorHandler.isBusinessDay()) {
                System.debug(LoggingLevel.INFO, '[' + SCHEDULER_NAME + '] Skipping - not a business day');
                return;
            }
            
            // Queue the batch job to send annual notices
            Integer batchSize = getBatchSize();
            Id batchId = Database.executeBatch(new PrometheionGLBAAnnualNoticeBatch(), batchSize);
            
            System.debug(LoggingLevel.INFO, '[' + SCHEDULER_NAME + '] Batch job queued with ID: ' + batchId);
            
            // Log successful scheduling
            SchedulerErrorHandler.logSuccess(SCHEDULER_NAME, 'GLBA batch scheduled successfully. BatchId: ' + batchId);
            
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, '[' + SCHEDULER_NAME + '] Failed: ' + e.getMessage());
            System.debug(LoggingLevel.ERROR, '[' + SCHEDULER_NAME + '] Stack trace: ' + e.getStackTraceString());
            
            // Log the error
            SchedulerErrorHandler.logError(SCHEDULER_NAME, e);
            
            // Notify admins of failure
            SchedulerErrorHandler.notifyOnFailure(SCHEDULER_NAME, e.getMessage(), e.getStackTraceString());
        }
    }

    /**
     * Get batch size from Custom Metadata or use default
     * @return Batch size
     */
    private Integer getBatchSize() {
        try {
            Prometheion_Scheduler_Config__mdt config = Prometheion_Scheduler_Config__mdt.getInstance('GLBAAnnualNotice');
            if (config != null && config.Batch_Size__c != null) {
                return config.Batch_Size__c.intValue();
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, '[' + SCHEDULER_NAME + '] Could not load config: ' + e.getMessage());
        }
        return DEFAULT_BATCH_SIZE;
    }

    /**
     * Schedule the job to run daily at 6 AM
     * @return Job ID
     */
    public static String scheduleDaily() {
        String cronExp = '0 0 6 * * ?'; // 6 AM every day
        return System.schedule(
            'GLBA Annual Notice Distribution - Daily',
            cronExp,
            new PrometheionGLBAAnnualNoticeScheduler()
        );
    }

}
