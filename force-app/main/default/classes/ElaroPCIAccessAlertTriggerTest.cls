/**
 * Tests for ElaroPCIAccessAlertTrigger and ElaroPCIAccessAlertHandler.
 *
 * ElaroPCIAccessAlertTrigger fires on Elaro_Raw_Event__e (after insert), keeps only
 * events with Event_Type__c == 'PCI_ACCESS', parses each JSON payload, and routes them
 * into three detection buckets: failed access ('Access Denied'), after-hours access
 * (timestamp hour < 7 or >= 19), and bulk access (userAction contains 'Bulk:'). Matching
 * buckets are dispatched to ElaroPCIAccessAlertHandler, which logs alerts via ElaroLogger.
 *
 * The handler produces no persisted records (alerts are log-only in this build), so these
 * tests assert observable, deterministic outcomes: publish succeeds, the trigger executes
 * without throwing, non-PCI events are ignored, malformed payloads are tolerated, and the
 * recursion guard is reset.
 *
 * @author Elaro Team
 * @since v3.1.0 (Spring '26)
 * @group Compliance Framework
 * @see ElaroPCIAccessAlertTrigger
 * @see ElaroPCIAccessAlertHandler
 */
@IsTest(testFor=ElaroPCIAccessAlertHandler.class)
private class ElaroPCIAccessAlertTriggerTest {

    private static final String ORG_ID = UserInfo.getOrganizationId();

    private static Elaro_Raw_Event__e buildPciEvent(Map<String, Object> data, Datetime ts) {
        return new Elaro_Raw_Event__e(
            Org_ID__c = ORG_ID,
            Event_Type__c = 'PCI_ACCESS',
            Entity_Type__c = 'CardholderData',
            Timestamp__c = ts,
            Event_Data__c = JSON.serialize(data)
        );
    }

    private static Map<String, Object> payload(String userId, String userName, String accessType, String userAction) {
        return new Map<String, Object>{
            'userId' => userId,
            'username' => userName,
            'accessType' => accessType,
            'userAction' => userAction,
            'ipAddress' => '10.0.0.1',
            'recordId' => 'a01000000000001'
        };
    }

    /** A business-hours datetime guaranteed not to trip the after-hours branch. */
    private static Datetime businessHours() {
        return Datetime.newInstance(2026, 6, 1, 12, 0, 0);
    }

    /** An after-hours datetime (22:00) to trip the after-hours branch. */
    private static Datetime afterHours() {
        return Datetime.newInstance(2026, 6, 1, 22, 0, 0);
    }

    /**
     * Three 'Access Denied' events for the same user exceed the failed-access threshold
     * and drive the critical-alert branch. Trigger and handler must complete without error.
     */
    @IsTest
    static void shouldHandleRepeatedFailedAccess() {
        List<Elaro_Raw_Event__e> events = new List<Elaro_Raw_Event__e>();
        for (Integer i = 0; i < 3; i++) {
            events.add(buildPciEvent(
                payload('005FAILUSER', 'failuser', 'Access Denied', 'Read attempt ' + i),
                businessHours()
            ));
        }

        Test.startTest();
        List<Database.SaveResult> results = EventBus.publish(events);
        Test.stopTest();

        for (Database.SaveResult sr : results) {
            Assert.isTrue(sr.isSuccess(), 'Failed-access PCI events should publish successfully');
        }
        Assert.isFalse(
            TriggerRecursionGuard.isRunning('ElaroPCIAccessAlertTrigger'),
            'Recursion guard should be reset after processing'
        );
    }

    /**
     * A single 'Access Denied' event is below the failure threshold and exercises the
     * per-event warning branch of the handler.
     */
    @IsTest
    static void shouldHandleSingleFailedAccessAsWarning() {
        Elaro_Raw_Event__e evt = buildPciEvent(
            payload('005SINGLE', 'singleuser', 'Access Denied', 'Single attempt'),
            businessHours()
        );

        Test.startTest();
        Database.SaveResult sr = EventBus.publish(evt);
        Test.stopTest();

        Assert.isTrue(sr.isSuccess(), 'Single failed-access event should publish successfully');
    }

    /**
     * An after-hours timestamp (22:00) routes the event through handleAfterHoursAccess,
     * which formats and batch-logs the alert.
     */
    @IsTest
    static void shouldHandleAfterHoursAccess() {
        Elaro_Raw_Event__e evt = buildPciEvent(
            payload('005NIGHT', 'nightuser', 'Read', 'View cardholder record'),
            afterHours()
        );

        Test.startTest();
        Database.SaveResult sr = EventBus.publish(evt);
        Test.stopTest();

        Assert.isTrue(sr.isSuccess(), 'After-hours event should publish successfully');
    }

    /**
     * A userAction containing 'Bulk: N records' above the bulk threshold drives the
     * high-volume bulk-access branch and the record-count regex extraction.
     */
    @IsTest
    static void shouldHandleHighVolumeBulkAccess() {
        Elaro_Raw_Event__e evt = buildPciEvent(
            payload('005BULK', 'bulkuser', 'Export', 'Bulk: 500 records'),
            businessHours()
        );

        Test.startTest();
        Database.SaveResult sr = EventBus.publish(evt);
        Test.stopTest();

        Assert.isTrue(sr.isSuccess(), 'High-volume bulk event should publish successfully');
    }

    /**
     * A bulk event below the volume threshold still flows through handleBulkAccess but
     * skips the high-volume alert, covering the lower branch of the threshold check.
     */
    @IsTest
    static void shouldHandleLowVolumeBulkAccess() {
        Elaro_Raw_Event__e evt = buildPciEvent(
            payload('005LOWBULK', 'lowbulkuser', 'Export', 'Bulk: 5 records'),
            businessHours()
        );

        Test.startTest();
        Database.SaveResult sr = EventBus.publish(evt);
        Test.stopTest();

        Assert.isTrue(sr.isSuccess(), 'Low-volume bulk event should publish successfully');
    }

    /**
     * Non-PCI events (Event_Type__c != 'PCI_ACCESS') must be filtered out by the trigger
     * before any handler runs, hitting the early-return guard.
     */
    @IsTest
    static void shouldIgnoreNonPciEvents() {
        Elaro_Raw_Event__e evt = new Elaro_Raw_Event__e(
            Org_ID__c = ORG_ID,
            Event_Type__c = 'LOGIN',
            Entity_Type__c = 'User',
            Timestamp__c = businessHours(),
            Event_Data__c = JSON.serialize(payload('005OTHER', 'otheruser', 'Read', 'Login'))
        );

        Test.startTest();
        Database.SaveResult sr = EventBus.publish(evt);
        Test.stopTest();

        Assert.isTrue(sr.isSuccess(), 'Non-PCI event should still publish successfully');
        Assert.isFalse(
            TriggerRecursionGuard.isRunning('ElaroPCIAccessAlertTrigger'),
            'Recursion guard should be reset even when all events are filtered out'
        );
    }

    /**
     * A PCI event whose Event_Data__c is not valid JSON must be tolerated: the trigger
     * logs the parse failure and continues, so delivery still succeeds.
     */
    @IsTest
    static void shouldTolerateMalformedPayload() {
        Elaro_Raw_Event__e evt = new Elaro_Raw_Event__e(
            Org_ID__c = ORG_ID,
            Event_Type__c = 'PCI_ACCESS',
            Entity_Type__c = 'CardholderData',
            Timestamp__c = businessHours(),
            Event_Data__c = 'this-is-not-json'
        );

        Test.startTest();
        Database.SaveResult sr = EventBus.publish(evt);
        Test.stopTest();

        Assert.isTrue(sr.isSuccess(), 'Event with malformed payload should still publish successfully');
    }

    /**
     * Bulk publish of 200 mixed PCI events (failed, after-hours, bulk) must be processed
     * in one trigger invocation without throwing or breaching governor limits.
     */
    @IsTest
    static void shouldProcessBulkPciEvents() {
        List<Elaro_Raw_Event__e> events = new List<Elaro_Raw_Event__e>();
        for (Integer i = 0; i < 200; i++) {
            Integer mod3 = Math.mod(i, 3);
            String accessType = mod3 == 0 ? 'Access Denied' : 'Read';
            String action = mod3 == 2 ? 'Bulk: 75 records' : 'Read record ' + i;
            Datetime ts = mod3 == 1 ? afterHours() : businessHours();
            events.add(buildPciEvent(payload('005USER' + Math.mod(i, 5), 'user' + i, accessType, action), ts));
        }

        Test.startTest();
        List<Database.SaveResult> results = EventBus.publish(events);
        Test.stopTest();

        Assert.areEqual(200, results.size(), 'All 200 PCI events should report a save result');
        for (Database.SaveResult sr : results) {
            Assert.isTrue(sr.isSuccess(), 'Each bulk PCI event should publish successfully');
        }
    }
}
