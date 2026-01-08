/**
 * PrometheionEventProcessor
 * 
 * Processes Prometheion_Event__e Platform Events and indexes to Compliance Graph
 * 
 * @author Prometheion
 * @version 1.0
 */
public with sharing class PrometheionEventProcessor {
    
    /**
     * Process Platform Event and index to Compliance Graph
     * @param event Prometheion Event
     */
    public static void processEvent(Prometheion_Event__e event) {
        if (event == null) {
            return;
        }
        
        try {
            // Extract event data
            String entityType = event.Entity_Type__c;
            String entityId = event.Entity_Id__c;
            String framework = event.Framework__c;
            String eventType = event.Event_Type__c;
            
            if (String.isBlank(entityType) || String.isBlank(entityId)) {
                System.debug(LoggingLevel.WARN, '[PrometheionEventProcessor] Missing entity type or ID');
                return;
            }
            
            // Index to Compliance Graph using PrometheionGraphIndexer
            String nodeId = PrometheionGraphIndexer.indexChange(
                entityType,
                entityId,
                null, // parentNodeId
                String.isNotBlank(framework) ? framework : PrometheionConstants.FRAMEWORK_SOC2
            );
            
            System.debug(LoggingLevel.INFO, 
                '[PrometheionEventProcessor] Event processed - NodeId: ' + nodeId + 
                ', EntityType: ' + entityType + 
                ', EntityId: ' + entityId);
            
        } catch (Exception e) {
            String correlationId = event.Correlation_Id__c != null ? event.Correlation_Id__c : 
                'EVT-' + System.now().getTime();
            System.debug(LoggingLevel.ERROR, 
                '[PrometheionEventProcessor] Error processing event - CorrelationId: ' + correlationId + 
                ', Error: ' + e.getMessage() + 
                ', StackTrace: ' + e.getStackTraceString());
        }
    }
    
    /**
     * Process batch of Platform Events
     * @param events List of Prometheion Events
     */
    public static void processEvents(List<Prometheion_Event__e> events) {
        if (events == null || events.isEmpty()) {
            return;
        }
        
        for (Prometheion_Event__e event : events) {
            processEvent(event);
        }
    }
}
