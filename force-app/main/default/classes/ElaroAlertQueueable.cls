/**
 * Queueable class for processing alerts asynchronously
 * @group System Monitoring
 * @author Elaro Team
 * @since v3.1.0 (Spring '26)
 */
public with sharing class ElaroAlertQueueable implements Queueable, Database.AllowsCallouts {
    
    private ElaroComplianceAlert.AlertQueueItem queueItem;
    
    public ElaroAlertQueueable(ElaroComplianceAlert.AlertQueueItem queueItem) {
        this.queueItem = queueItem;
    }
    
    /** Processes the queued alert item by building alert metadata and dispatching the notification. */
    public void execute(QueueableContext context) {
        System.attachFinalizer(new ElaroAlertQueueableFinalizer());
        if (queueItem == null) {
            return;
        }
        
        try {
            // Add alert metadata to event data
            Map<String, Object> alertData = new Map<String, Object>(queueItem.eventData);
            alertData.put('alertId', queueItem.alertId);
            alertData.put('severity', queueItem.severity);
            alertData.put('channel', queueItem.channel);
            alertData.put('timestamp', Datetime.now());
            alertData.put('message', buildAlertMessage(queueItem));
            
            // Send notification
            ElaroComplianceAlert.sendAlertNotification(
                queueItem.channel,
                JSON.serialize(alertData)
            );
            
        } catch (Exception e) {
            ElaroLogger.error( 'Alert queue processing error: ' + e.getMessage());
        }
    }
    
    private String buildAlertMessage(ElaroComplianceAlert.AlertQueueItem item) {
        String eventType = item.eventData.containsKey('eventType')
            ? (String)item.eventData.get('eventType')
            : 'Unknown';

        return 'A ' + item.severity + ' compliance alert has been triggered for ' + eventType + ' event.';
    }

    /**
     * Transaction Finalizer for error logging and optional retry.
     */
    private class ElaroAlertQueueableFinalizer implements Finalizer {
        public void execute(FinalizerContext ctx) {
            if (ctx.getResult() == ParentJobResult.UNHANDLED_EXCEPTION) {
                ElaroLogger.error('ElaroAlertQueueable: Unhandled exception: ' + ctx.getException().getMessage());
            }
        }
    }
}
