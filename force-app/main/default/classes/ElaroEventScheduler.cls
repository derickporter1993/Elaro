/**
 * ElaroEventScheduler
 * 
 * Schedulable class to run batch event loading on a schedule
 * 
 * @author Elaro
 * @version 1.0
 * @since v3.1.0 (Spring '26)
 * @group Event Monitoring
 */
public with sharing class ElaroEventScheduler implements Schedulable {
    
    private String eventType;
    private Integer daysBack;
    private String framework;
    
    public ElaroEventScheduler(String eventType, Integer daysBack, String framework) {
        this.eventType = eventType;
        this.daysBack = daysBack != null ? daysBack : 7;
        this.framework = framework != null ? framework : ElaroConstants.FRAMEWORK_SOC2;
    }
    
    public ElaroEventScheduler() {
        this('LOGIN', 7, ElaroConstants.FRAMEWORK_SOC2);
    }
    
    /** Initiates a batch event load for the configured event type, date range, and framework. */
    public void execute(SchedulableContext ctx) {
        Date endDate = Date.today();
        Date startDate = endDate.addDays(-this.daysBack);
        
        ElaroEventMonitoringService.startBatchEventLoad(
            this.eventType,
            startDate,
            endDate,
            this.framework
        );
    }
}
