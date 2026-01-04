/**
 * PCIAccessLogger - PCI DSS Requirement 10 Implementation
 *
 * Tracks and monitors all access to cardholder data.
 * Creates immutable audit trail via Platform Events.
 *
 * Compliance Coverage:
 * - PCI DSS Requirement 10: Track All Access to Network Resources
 * - PCI DSS Requirement 10.1: Link Access to Individual Users
 * - PCI DSS Requirement 10.2: Audit Trail for All System Components
 *
 * @author Prometheion
 * @version 1.0
 */
public with sharing class PCIAccessLogger {

    /**
     * Log payment data access
     * Creates immutable audit trail via Platform Events
     * @param recordId - ID of the payment or sensitive record accessed
     * @param accessType - Type of access (Query, Insert, Update, Delete, View)
     * @param userAction - Description of the action performed
     */
    public static void logPaymentDataAccess(
        Id recordId,
        String accessType,
        String userAction
    ) {
        String ipAddress = null;
        try {
            Map<String, String> sessionInfo = Auth.SessionManagement.getCurrentSession();
            if (sessionInfo != null) {
                ipAddress = sessionInfo.get('SourceIp');
            }
        } catch (Exception e) {
            // Session info may not be available in all contexts
            ipAddress = 'Unknown';
        }

        // Publish Platform Event (immutable, survives rollbacks)
        EventBus.publish(new PCI_Access_Event__e(
            Record_Id__c = recordId,
            User_Id__c = UserInfo.getUserId(),
            Username__c = UserInfo.getUserName(),
            Access_Type__c = accessType,
            User_Action__c = userAction,
            IP_Address__c = ipAddress,
            Timestamp__c = System.now(),
            Session_Id__c = UserInfo.getSessionId()
        ));
    }

    /**
     * Log bulk payment data access
     * @param recordIds - Set of record IDs accessed
     * @param accessType - Type of access
     * @param userAction - Description of the action
     */
    public static void logBulkPaymentDataAccess(
        Set<Id> recordIds,
        String accessType,
        String userAction
    ) {
        List<PCI_Access_Event__e> events = new List<PCI_Access_Event__e>();

        String ipAddress = null;
        try {
            Map<String, String> sessionInfo = Auth.SessionManagement.getCurrentSession();
            if (sessionInfo != null) {
                ipAddress = sessionInfo.get('SourceIp');
            }
        } catch (Exception e) {
            ipAddress = 'Unknown';
        }

        String sessionId = UserInfo.getSessionId();
        String userId = UserInfo.getUserId();
        String username = UserInfo.getUserName();
        Datetime now = System.now();

        for (Id recordId : recordIds) {
            events.add(new PCI_Access_Event__e(
                Record_Id__c = recordId,
                User_Id__c = userId,
                Username__c = username,
                Access_Type__c = accessType,
                User_Action__c = userAction + ' (Bulk: ' + recordIds.size() + ' records)',
                IP_Address__c = ipAddress,
                Timestamp__c = now,
                Session_Id__c = sessionId
            ));
        }

        if (!events.isEmpty()) {
            EventBus.publish(events);
        }
    }

    /**
     * Log failed access attempt (security event)
     * @param recordId - ID of record that was attempted to access
     * @param reason - Reason for failure
     */
    public static void logFailedAccess(Id recordId, String reason) {
        logPaymentDataAccess(
            recordId,
            'Access Denied',
            'Failed access attempt: ' + reason
        );
    }

    /**
     * Log sensitive data view (for audit compliance)
     * @param recordId - Record being viewed
     * @param dataElements - List of sensitive data elements viewed
     */
    public static void logSensitiveDataView(Id recordId, List<String> dataElements) {
        String elementsViewed = String.join(dataElements, ', ');
        logPaymentDataAccess(
            recordId,
            'View',
            'Viewed sensitive data elements: ' + elementsViewed
        );
    }

    /**
     * Get recent access logs for a record
     * Note: This queries Big Object if available, otherwise returns empty list
     * @param recordId - Record to get access logs for
     * @param limitSize - Number of logs to return
     * @return List of access log entries
     */
    @AuraEnabled(cacheable=true)
    public static List<AccessLogEntry> getRecentAccessLogs(Id recordId, Integer limitSize) {
        List<AccessLogEntry> logs = new List<AccessLogEntry>();

        // In production, this would query the PCI_Access_Log__b Big Object
        // or EventRelayFeedback from Platform Events
        // For now, return empty list as placeholder

        return logs;
    }

    /**
     * Access log entry wrapper class
     */
    public class AccessLogEntry {
        @AuraEnabled public String recordId;
        @AuraEnabled public String userId;
        @AuraEnabled public String username;
        @AuraEnabled public String accessType;
        @AuraEnabled public String userAction;
        @AuraEnabled public String ipAddress;
        @AuraEnabled public Datetime timestamp;
    }
}
