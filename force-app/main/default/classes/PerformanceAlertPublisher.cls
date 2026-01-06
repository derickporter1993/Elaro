public with sharing class PerformanceAlertPublisher {
    @AuraEnabled
    public static void publish(String metric, Decimal value, Decimal threshold, String contextRecordId, String stack) {
        // Input validation
        if (String.isBlank(metric)) {
            throw new AuraHandledException('Metric cannot be blank');
        }
        if (value == null || threshold == null) {
            throw new AuraHandledException('Value and threshold are required');
        }
        
        // Platform Events don't have CRUD/FLS, but validate field access if needed
        // Note: Platform Events are always accessible for publishing
        
        Performance_Alert__e evt = new Performance_Alert__e(
            Metric__c = metric, Value__c = value, Threshold__c = threshold,
            Context_Record__c = contextRecordId, Stack__c = stack
        );
        Database.SaveResult sr = EventBus.publish(evt);
        if (!sr.isSuccess()) {
            throw new AuraHandledException('Failed to publish Performance_Alert__e: ' + sr.getErrors()[0].getMessage());
        }
    }
}
