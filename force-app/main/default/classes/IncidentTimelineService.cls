/**
 * Manages incident timeline events for SEC materiality assessments.
 * Tracks key incident response milestones (detection, containment,
 * investigation, notification) and evaluates SLA compliance for each
 * phase of the response lifecycle.
 *
 * SLA Thresholds:
 * - Detection to Containment: 4 hours
 * - Detection to Investigation Start: 24 hours
 * - Containment to Notification: 72 hours
 *
 * @author Elaro Team
 * @since v3.1.0 (Spring '26)
 * @group SEC Module
 * @see MaterialityAssessmentService
 * @see Incident_Timeline__c
 */
public inherited sharing class IncidentTimelineService {

    /**
     * SLA hour thresholds for incident response phases.
     */
    private static final Integer SLA_DETECTION_TO_CONTAINMENT_HOURS = 4;
    private static final Integer SLA_DETECTION_TO_INVESTIGATION_HOURS = 24;
    private static final Integer SLA_CONTAINMENT_TO_NOTIFICATION_HOURS = 72;

    /**
     * Event type constants used for SLA deadline calculations.
     */
    public static final String EVENT_DETECTION = 'Detection';
    public static final String EVENT_CONTAINMENT = 'Containment';
    public static final String EVENT_INVESTIGATION = 'Investigation_Start';
    public static final String EVENT_NOTIFICATION = 'Notification';
    public static final String EVENT_REMEDIATION = 'Remediation';
    public static final String EVENT_DETERMINATION = 'Materiality_Determination';
    public static final String EVENT_FILING = 'SEC_Filing';
    public static final String EVENT_BOARD_NOTIFICATION = 'Board_Notification';

    /**
     * SLA status values.
     */
    public static final String SLA_ON_TRACK = 'On_Track';
    public static final String SLA_AT_RISK = 'At_Risk';
    public static final String SLA_BREACHED = 'Breached';
    public static final String SLA_NOT_APPLICABLE = 'N/A';

    /**
     * Adds a timeline event to a materiality assessment and evaluates the
     * SLA deadline based on event type and prior events in the timeline.
     *
     * @param assessmentId The parent Materiality_Assessment__c record Id
     * @param eventDate When the event occurred
     * @param eventType The type of event (e.g., Detection, Containment, Investigation_Start)
     * @param description Description of the event
     * @param performedBy Name or identifier of who performed the action
     * @return The newly created Incident_Timeline__c record
     * @throws AuraHandledException if creation fails
     */
    public static Incident_Timeline__c addTimelineEvent(
        Id assessmentId,
        DateTime eventDate,
        String eventType,
        String description,
        String performedBy
    ) {
        DateTime slaDeadline = calculateSLADeadline(assessmentId, eventType, eventDate);
        String slaStatus = determineSLAStatus(eventDate, slaDeadline);

        Incident_Timeline__c timelineEvent = new Incident_Timeline__c(
            Materiality_Assessment__c = assessmentId,
            Event_Date__c = eventDate,
            Event_Type__c = eventType,
            Event_Description__c = description,
            Performed_By__c = performedBy,
            SLA_Deadline__c = slaDeadline,
            SLA_Status__c = slaStatus
        );

        try {
            insert as user timelineEvent;
            ElaroLogger.info(
                'IncidentTimelineService.addTimelineEvent',
                'Added timeline event ' + eventType + ' for assessment ' + assessmentId
                    + '. SLA status: ' + slaStatus
            );
        } catch (Exception e) {
            ElaroLogger.error(
                'IncidentTimelineService.addTimelineEvent',
                e.getMessage(),
                e.getStackTraceString()
            );
            throw new AuraHandledException('Failed to add timeline event. Please try again.');
        }

        return timelineEvent;
    }

    /**
     * Retrieves the full incident timeline for a materiality assessment,
     * ordered chronologically by event date.
     *
     * @param assessmentId The parent Materiality_Assessment__c record Id
     * @return List of timeline events ordered by Event_Date__c ASC
     */
    public static List<Incident_Timeline__c> getTimeline(Id assessmentId) {
        return [
            SELECT Id, Materiality_Assessment__c, Event_Date__c, Event_Type__c,
                Event_Description__c, Performed_By__c, SLA_Status__c, SLA_Deadline__c
            FROM Incident_Timeline__c
            WHERE Materiality_Assessment__c = :assessmentId
            WITH USER_MODE
            ORDER BY Event_Date__c ASC
        ];
    }

    /**
     * Re-evaluates SLA status for all timeline events in an assessment.
     * Useful when events are added out of chronological order or when
     * deadlines change due to AG delay grants.
     *
     * @param assessmentId The parent Materiality_Assessment__c record Id
     * @throws AuraHandledException if evaluation or update fails
     */
    public static void evaluateSLAStatus(Id assessmentId) {
        List<Incident_Timeline__c> events = [
            SELECT Id, Event_Date__c, Event_Type__c, SLA_Status__c, SLA_Deadline__c
            FROM Incident_Timeline__c
            WHERE Materiality_Assessment__c = :assessmentId
            WITH USER_MODE
            ORDER BY Event_Date__c ASC
        ];

        if (events.isEmpty()) {
            return;
        }

        Map<String, DateTime> eventDatesByType = new Map<String, DateTime>();
        List<Incident_Timeline__c> eventsToUpdate = new List<Incident_Timeline__c>();

        for (Incident_Timeline__c evt : events) {
            eventDatesByType.put(evt.Event_Type__c, evt.Event_Date__c);
        }

        for (Incident_Timeline__c evt : events) {
            DateTime slaDeadline = calculateSLADeadlineFromMap(evt.Event_Type__c, eventDatesByType);
            String newSlaStatus = determineSLAStatus(evt.Event_Date__c, slaDeadline);

            if (evt.SLA_Deadline__c != slaDeadline || evt.SLA_Status__c != newSlaStatus) {
                evt.SLA_Deadline__c = slaDeadline;
                evt.SLA_Status__c = newSlaStatus;
                eventsToUpdate.add(evt);
            }
        }

        if (!eventsToUpdate.isEmpty()) {
            try {
                update as user eventsToUpdate;
                ElaroLogger.info(
                    'IncidentTimelineService.evaluateSLAStatus',
                    'Re-evaluated SLA status for ' + eventsToUpdate.size()
                        + ' events on assessment ' + assessmentId
                );
            } catch (Exception e) {
                ElaroLogger.error(
                    'IncidentTimelineService.evaluateSLAStatus',
                    e.getMessage(),
                    e.getStackTraceString()
                );
                throw new AuraHandledException('Failed to evaluate SLA status. Please try again.');
            }
        }
    }

    /**
     * Calculates the SLA deadline for a new event based on prior events in the assessment.
     *
     * @param assessmentId The assessment to query prior events from
     * @param eventType The type of the new event
     * @param eventDate The date of the new event
     * @return The SLA deadline, or null if no SLA applies
     */
    private static DateTime calculateSLADeadline(Id assessmentId, String eventType, DateTime eventDate) {
        Map<String, DateTime> priorEvents = new Map<String, DateTime>();

        for (Incident_Timeline__c evt : [
            SELECT Event_Type__c, Event_Date__c
            FROM Incident_Timeline__c
            WHERE Materiality_Assessment__c = :assessmentId
            WITH USER_MODE
            ORDER BY Event_Date__c ASC
        ]) {
            if (!priorEvents.containsKey(evt.Event_Type__c)) {
                priorEvents.put(evt.Event_Type__c, evt.Event_Date__c);
            }
        }

        priorEvents.put(eventType, eventDate);
        return calculateSLADeadlineFromMap(eventType, priorEvents);
    }

    /**
     * Calculates the SLA deadline based on event type and a map of all event dates.
     *
     * @param eventType The event type to calculate SLA for
     * @param eventDatesByType Map of event types to their dates
     * @return The SLA deadline DateTime, or null if no SLA applies
     */
    private static DateTime calculateSLADeadlineFromMap(String eventType, Map<String, DateTime> eventDatesByType) {
        DateTime detectionDate = eventDatesByType.get(EVENT_DETECTION);
        DateTime containmentDate = eventDatesByType.get(EVENT_CONTAINMENT);

        if (eventType == EVENT_CONTAINMENT && detectionDate != null) {
            return detectionDate.addHours(SLA_DETECTION_TO_CONTAINMENT_HOURS);
        }
        if (eventType == EVENT_INVESTIGATION && detectionDate != null) {
            return detectionDate.addHours(SLA_DETECTION_TO_INVESTIGATION_HOURS);
        }
        if (eventType == EVENT_NOTIFICATION && containmentDate != null) {
            return containmentDate.addHours(SLA_CONTAINMENT_TO_NOTIFICATION_HOURS);
        }

        return null;
    }

    /**
     * Determines the SLA status based on the event date relative to the deadline.
     *
     * @param eventDate When the event occurred
     * @param slaDeadline The SLA deadline (null if no SLA applies)
     * @return SLA status string (On_Track, Breached, or N/A)
     */
    private static String determineSLAStatus(DateTime eventDate, DateTime slaDeadline) {
        if (slaDeadline == null) {
            return SLA_NOT_APPLICABLE;
        }
        return eventDate <= slaDeadline ? SLA_ON_TRACK : SLA_BREACHED;
    }
}
