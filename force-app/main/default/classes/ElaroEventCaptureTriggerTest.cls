/**
 * Tests for ElaroEventCaptureTrigger and ElaroEventProcessor.
 *
 * ElaroEventCaptureTrigger fires on Elaro_Event__e (after insert) and delegates to
 * ElaroEventProcessor, which validates each event and indexes it to the compliance
 * graph via ElaroGraphIndexer. The processor is defensive: blank entity data is
 * skipped and downstream indexing failures are caught and logged rather than thrown,
 * so platform-event delivery never fails.
 *
 * Platform events are delivered synchronously between Test.startTest() and
 * Test.stopTest(), so the trigger executes within that window.
 *
 * @author Elaro Team
 * @since v3.1.0 (Spring '26)
 * @group Event Monitoring
 * @see ElaroEventCaptureTrigger
 * @see ElaroEventProcessor
 */
@IsTest(testFor=ElaroEventProcessor.class)
private class ElaroEventCaptureTriggerTest {

    private static Elaro_Event__e buildEvent(String entityType, String entityId) {
        return new Elaro_Event__e(
            Event_Type__c = 'METADATA_CHANGE',
            Entity_Type__c = entityType,
            Entity_Id__c = entityId,
            Framework__c = 'SOC2',
            Timestamp__c = System.now(),
            Correlation_Id__c = 'CORR-' + entityId,
            Event_Data__c = JSON.serialize(new Map<String, Object>{ 'k' => 'v' })
        );
    }

    /**
     * Publishing a well-formed event with an unsupported entity type should not throw.
     * ElaroGraphIndexer rejects unknown entity types, and the processor swallows that
     * exception so platform-event delivery succeeds.
     */
    @IsTest
    static void shouldProcessEventWithoutThrowing() {
        Elaro_Event__e evt = buildEvent('PERMISSION_SET', '0PS000000000000AAA');

        Test.startTest();
        Database.SaveResult sr = EventBus.publish(evt);
        Test.stopTest();

        Assert.isTrue(sr.isSuccess(), 'Platform event publish should succeed');
        Assert.isFalse(
            TriggerRecursionGuard.isRunning('ElaroEventCaptureTrigger'),
            'Recursion guard should be reset in the finally block after processing'
        );
    }

    /**
     * Events missing the entity type/id hit the processor's early-return guard.
     * Delivery must still succeed and the trigger must not throw.
     */
    @IsTest
    static void shouldSkipEventsMissingEntityData() {
        Elaro_Event__e missingType = buildEvent(null, '0PS000000000001AAA');
        Elaro_Event__e missingId = buildEvent('PERMISSION_SET', null);

        Test.startTest();
        List<Database.SaveResult> results = EventBus.publish(new List<Elaro_Event__e>{ missingType, missingId });
        Test.stopTest();

        for (Database.SaveResult sr : results) {
            Assert.isTrue(sr.isSuccess(), 'Publishing guard-path events should still succeed');
        }
    }

    /**
     * Bulk publish of 200 events must be processed in a single trigger invocation
     * without throwing or exceeding limits.
     */
    @IsTest
    static void shouldProcessBulkEvents() {
        List<Elaro_Event__e> events = new List<Elaro_Event__e>();
        for (Integer i = 0; i < 200; i++) {
            events.add(buildEvent('PERMISSION_SET', '0PS00000000' + String.valueOf(1000 + i).substring(1) + 'AAA'));
        }

        Test.startTest();
        List<Database.SaveResult> results = EventBus.publish(events);
        Test.stopTest();

        Assert.areEqual(200, results.size(), 'All 200 events should report a save result');
        for (Database.SaveResult sr : results) {
            Assert.isTrue(sr.isSuccess(), 'Each bulk event publish should succeed');
        }
    }

    /**
     * Directly drive the processor's single-event path with a null argument to cover
     * the null guard without relying on platform-event delivery.
     */
    @IsTest
    static void shouldHandleNullEventDirectly() {
        Test.startTest();
        ElaroEventProcessor.processEvent(null);
        ElaroEventProcessor.processEvents(null);
        ElaroEventProcessor.processEvents(new List<Elaro_Event__e>());
        Test.stopTest();

        Assert.isFalse(
            TriggerRecursionGuard.isRunning('ElaroEventCaptureTrigger'),
            'No trigger context means the guard should never be set'
        );
    }
}
