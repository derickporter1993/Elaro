/**
 * PCIAccessAlertTrigger - PCI DSS Requirement 10 Real-time Alerting
 *
 * Listens for PCI Access Events and triggers alerts for:
 * - Failed access attempts
 * - Access to sensitive data outside business hours
 * - Bulk data access patterns
 *
 * @author Prometheion
 * @version 1.0
 */
trigger PCIAccessAlertTrigger on PCI_Access_Event__e (after insert) {

    List<PCI_Access_Event__e> failedAccessEvents = new List<PCI_Access_Event__e>();
    List<PCI_Access_Event__e> afterHoursEvents = new List<PCI_Access_Event__e>();
    List<PCI_Access_Event__e> bulkAccessEvents = new List<PCI_Access_Event__e>();

    // Track access counts by user for bulk detection
    Map<String, Integer> accessCountByUser = new Map<String, Integer>();

    for (PCI_Access_Event__e event : Trigger.new) {
        // Check for failed access
        if (event.Access_Type__c == 'Access Denied') {
            failedAccessEvents.add(event);
        }

        // Check for after-hours access (before 7 AM or after 7 PM)
        if (event.Timestamp__c != null) {
            Integer hour = event.Timestamp__c.hour();
            if (hour < 7 || hour >= 19) {
                afterHoursEvents.add(event);
            }
        }

        // Track access count by user
        String userId = event.User_Id__c;
        if (accessCountByUser.containsKey(userId)) {
            accessCountByUser.put(userId, accessCountByUser.get(userId) + 1);
        } else {
            accessCountByUser.put(userId, 1);
        }

        // Check for bulk action indicator
        if (event.User_Action__c != null && event.User_Action__c.contains('Bulk:')) {
            bulkAccessEvents.add(event);
        }
    }

    // Process alerts
    if (!failedAccessEvents.isEmpty()) {
        PrometheionPCIAccessAlertHandler.handleFailedAccess(failedAccessEvents);
    }

    if (!afterHoursEvents.isEmpty()) {
        PrometheionPCIAccessAlertHandler.handleAfterHoursAccess(afterHoursEvents);
    }

    if (!bulkAccessEvents.isEmpty()) {
        PrometheionPCIAccessAlertHandler.handleBulkAccess(bulkAccessEvents);
    }
}
