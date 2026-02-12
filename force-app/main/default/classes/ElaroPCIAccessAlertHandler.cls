/**
 * PCIAccessAlertHandler - Handles PCI DSS security alerts
 *
 * Processes various security events and triggers appropriate alerts:
 * - Failed access attempts
 * - After-hours access
 * - Bulk data access
 * - Suspicious patterns
 *
 * @author Elaro
 * @version 1.0
 */
public with sharing class ElaroPCIAccessAlertHandler {

    private static final Integer FAILED_ACCESS_THRESHOLD = 3;
    private static final Integer BULK_ACCESS_THRESHOLD = 50;

    /**
     * Handle failed access attempts
     * @param events - List of failed access events
     */
    public static void handleFailedAccess(List<Elaro_Raw_Event__e> events) {
        // Group by user to detect repeated failures
        Map<String, List<Elaro_Raw_Event__e>> eventsByUser = new Map<String, List<Elaro_Raw_Event__e>>();

        for (Elaro_Raw_Event__e event : events) {
            if (!eventsByUser.containsKey(parseEventField(event, 'userId'))) {
                eventsByUser.put(parseEventField(event, 'userId'), new List<Elaro_Raw_Event__e>());
            }
            eventsByUser.get(parseEventField(event, 'userId')).add(event);
        }

        // Check for users with multiple failures
        for (String userId : eventsByUser.keySet()) {
            List<Elaro_Raw_Event__e> userEvents = eventsByUser.get(userId);

            if (userEvents.size() >= FAILED_ACCESS_THRESHOLD) {
                // Critical alert - potential security incident
                sendSecurityAlert(
                    'CRITICAL: Multiple Failed Access Attempts',
                    'User ' + parseEventField(userEvents[0], 'username') + ' has ' + userEvents.size() +
                    ' failed attempts to access cardholder data.\n' +
                    'IP Address: ' + parseEventField(userEvents[0], 'ipAddress') + '\n' +
                    'Action: Investigate immediately and consider account lockout.',
                    'Critical'
                );
            } else {
                // Warning level
                for (Elaro_Raw_Event__e event : userEvents) {
                    logSecurityEvent(event, 'Failed Access Attempt');
                }
            }
        }
    }

    /**
     * Handle after-hours access events
     * @param events - List of after-hours events
     */
    public static void handleAfterHoursAccess(List<Elaro_Raw_Event__e> events) {
        if (events.isEmpty()) {
            return;
        }
        
        // Batch alerts by aggregating events
        List<String> eventDetails = new List<String>();
        for (Elaro_Raw_Event__e event : events) {
            String timeStr = event.Timestamp__c.format('HH:mm:ss');
            String detail = String.format(
                '- User {0} at {1} (IP: {2}, Type: {3}, Record: {4})',
                new List<String>{
                    parseEventField(event, 'username'),
                    timeStr,
                    parseEventField(event, 'ipAddress'),
                    parseEventField(event, 'accessType'),
                    parseEventField(event, 'recordId')
                }
            );
            eventDetails.add(detail);
        }
        
        // Single batched alert for all after-hours events
        String batchedBody = String.format(
            'Detected {0} after-hours access event(s) to cardholder data:\n\n{1}\n\nAction: Verify these accesses were authorized.',
            new List<String>{
                String.valueOf(events.size()),
                String.join(eventDetails, '\n')
            }
        );
        
        sendSecurityAlert(
            'WARNING: After-Hours Access to Payment Data',
            batchedBody,
            'Warning'
        );
        
        // Batch log all events
        batchLogSecurityEvents(events, 'After-Hours Access');
    }

    /**
     * Handle bulk access events
     * @param events - List of bulk access events
     */
    public static void handleBulkAccess(List<Elaro_Raw_Event__e> events) {
        if (events.isEmpty()) {
            return;
        }
        
        // Separate high-volume events from normal ones
        List<String> highVolumeDetails = new List<String>();
        List<Elaro_Raw_Event__e> allEvents = new List<Elaro_Raw_Event__e>();
        
        for (Elaro_Raw_Event__e event : events) {
            String action = parseEventField(event, 'userAction');
            Integer recordCount = extractRecordCount(action);
            allEvents.add(event);

            if (recordCount >= BULK_ACCESS_THRESHOLD) {
                String detail = String.format(
                    '- User {0} accessed {1} records (IP: {2}, Type: {3})',
                    new List<String>{
                        parseEventField(event, 'username'),
                        String.valueOf(recordCount),
                        parseEventField(event, 'ipAddress'),
                        parseEventField(event, 'accessType')
                    }
                );
                highVolumeDetails.add(detail);
            }
        }
        
        // Send single alert for all high-volume events
        if (!highVolumeDetails.isEmpty()) {
            String batchedBody = String.format(
                'Detected {0} large bulk access event(s) to payment data:\n\n{1}\n\nAction: Review if these volumes are appropriate for user roles.',
                new List<String>{
                    String.valueOf(highVolumeDetails.size()),
                    String.join(highVolumeDetails, '\n')
                }
            );
            
            sendSecurityAlert(
                'ALERT: Large Bulk Access to Payment Data',
                batchedBody,
                'High'
            );
        }
        
        // Batch log all events
        batchLogSecurityEvents(allEvents, 'Bulk Data Access');
    }

    /**
     * Extract record count from action string
     * @param action - User action string
     * @return Record count
     */
    private static Integer extractRecordCount(String action) {
        if (String.isBlank(action)) return 0;

        // Pattern: "Bulk: 123 records"
        Pattern p = Pattern.compile('Bulk:\\s*(\\d+)\\s*records');
        Matcher m = p.matcher(action);

        if (m.find()) {
            return Integer.valueOf(m.group(1));
        }
        return 0;
    }

    /**
     * Send security alert to appropriate channels
     * @param subject - Alert subject
     * @param body - Alert body
     * @param severity - Severity level
     */
    private static void sendSecurityAlert(String subject, String body, String severity) {
        // Log the alert
        ElaroLogger.error('[PCIAccessAlertHandler] ' + severity + ': ' + subject + '\n' + body);

        // In production, would:
        // 1. Send email to security team
        // 2. Post to Slack/Teams security channel
        // 3. Create case for investigation
        // 4. Send to SIEM system
    }

    /**
     * Log security event for audit
     * @param event - PCI Access Event
     * @param eventType - Type of security event
     */
    private static void logSecurityEvent(Elaro_Raw_Event__e event, String eventType) {
        ElaroLogger.warn('[PCIAccessAlertHandler] Security Event: ' + eventType + '\n' +
            'User: ' + parseEventField(event, 'username') + '\n' +
            'Timestamp: ' + event.Timestamp__c + '\n' +
            'IP: ' + parseEventField(event, 'ipAddress') + '\n' +
            'Action: ' + parseEventField(event, 'userAction'));
    }
    
    /**
     * Batch log multiple security events for audit (governor limit optimization)
     * @param events - List of PCI Access Events
     * @param eventType - Type of security event
     */
    private static void batchLogSecurityEvents(List<Elaro_Raw_Event__e> events, String eventType) {
        if (events.isEmpty()) {
            return;
        }
        
        List<String> eventSummaries = new List<String>();
        for (Elaro_Raw_Event__e event : events) {
            eventSummaries.add(String.format(
                'User: {0}, Time: {1}, IP: {2}, Action: {3}',
                new List<String>{
                    parseEventField(event, 'username'),
                    String.valueOf(event.Timestamp__c),
                    parseEventField(event, 'ipAddress'),
                    parseEventField(event, 'userAction')
                }
            ));
        }
        
        ElaroLogger.warn(String.format(
            '[PCIAccessAlertHandler] Security Events ({0}): {1}\nEvents:\n{2}',
            new List<String>{
                String.valueOf(events.size()),
                eventType,
                String.join(eventSummaries, '\n')
            }
        ));
    }

    /**
     * Create security incident case
     * @param subject - Incident subject
     * @param description - Incident description
     * @param priority - Case priority
     */
    public static void createSecurityIncident(String subject, String description, String priority) {
        // Would create a Case record for security team to investigate
        ElaroLogger.error('[PCIAccessAlertHandler] Creating security incident: ' + subject);
    }

    /**
     * Parse field from generic event JSON payload
     * @param event - The Elaro_Raw_Event__e
     * @param fieldName - Name of field to extract from JSON
     * @return Field value as String, or empty string if not found
     */
    private static String parseEventField(Elaro_Raw_Event__e event, String fieldName) {
        try {
            if (String.isBlank(event.Event_Data__c)) {
                return '';
            }

            Map<String, Object> data = (Map<String, Object>) JSON.deserializeUntyped(event.Event_Data__c);
            Object value = data.get(fieldName);
            return value != null ? String.valueOf(value) : '';
        } catch (Exception e) {
            ElaroLogger.warn('Failed to parse event field ' + fieldName + ': ' + e.getMessage());
            return '';
        }
    }
}
