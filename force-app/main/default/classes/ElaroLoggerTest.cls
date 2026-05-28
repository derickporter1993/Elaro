/**
 * Tests for {@link ElaroLogger} durable Platform Event publication.
 *
 * @author Elaro
 * @since v3.1.0 (Spring '26)
 * @group Logging
 * @see ElaroLogger
 */
@IsTest(testFor=ElaroLogger.class)
private class ElaroLoggerTest {

    @IsTest
    static void shouldPublishLogEventWithCorrectFields() {
        ElaroLogger.publishedEvents.clear();

        Test.startTest();
        ElaroLogger.info('hello world');
        Test.stopTest();

        Assert.areEqual(1, ElaroLogger.publishedEvents.size(), 'Exactly one event should be published');
        LogEvent__e e = ElaroLogger.publishedEvents[0];
        Assert.areEqual('INFO', e.Level__c, 'Level__c should match enum name');
        Assert.areEqual('hello world', e.Message__c, 'Message__c should match input');
        Assert.areEqual(UserInfo.getUserId(), e.User_Id__c, 'User_Id__c should be the current user');
        Assert.isNotNull(e.Timestamp__c, 'Timestamp__c should be populated');
        Assert.isNull(e.Context__c, 'Context__c should be null when no context provided');
    }

    @IsTest
    static void shouldSerializeContextToJson() {
        ElaroLogger.publishedEvents.clear();

        Map<String, Object> ctx = new Map<String, Object>{
            'frameworks' => new List<String>{ 'HIPAA', 'SOC2' },
            'severity' => 'HIGH'
        };

        Test.startTest();
        ElaroLogger.warn('threshold exceeded', ctx);
        Test.stopTest();

        Assert.areEqual(1, ElaroLogger.publishedEvents.size(), 'Exactly one event should be published');
        LogEvent__e e = ElaroLogger.publishedEvents[0];
        Assert.areEqual('WARN', e.Level__c, 'Level__c should be WARN');
        Assert.isNotNull(e.Context__c, 'Context__c should be populated');
        Assert.isTrue(e.Context__c.contains('HIPAA'), 'Context__c should serialize list members');
        Assert.isTrue(e.Context__c.contains('HIGH'), 'Context__c should serialize string values');
    }

    @IsTest
    static void shouldEmitOneEventPerCallAtEachLevel() {
        ElaroLogger.publishedEvents.clear();

        Test.startTest();
        ElaroLogger.debug('a');
        ElaroLogger.info('b');
        ElaroLogger.warn('c');
        ElaroLogger.error('d');
        Test.stopTest();

        Assert.areEqual(4, ElaroLogger.publishedEvents.size(), 'Four events should be published');
        Assert.areEqual('DEBUG', ElaroLogger.publishedEvents[0].Level__c, 'First event should be DEBUG');
        Assert.areEqual('INFO', ElaroLogger.publishedEvents[1].Level__c, 'Second event should be INFO');
        Assert.areEqual('WARN', ElaroLogger.publishedEvents[2].Level__c, 'Third event should be WARN');
        Assert.areEqual('ERROR', ElaroLogger.publishedEvents[3].Level__c, 'Fourth event should be ERROR');
    }

    @IsTest
    static void shouldCaptureExceptionMetadataInContext() {
        ElaroLogger.publishedEvents.clear();

        Test.startTest();
        try {
            Integer crash = 1 / 0;
        } catch (Exception ex) {
            ElaroLogger.error('division failed', ex);
        }
        Test.stopTest();

        Assert.areEqual(1, ElaroLogger.publishedEvents.size(), 'Exactly one event should be published');
        LogEvent__e e = ElaroLogger.publishedEvents[0];
        Assert.areEqual('ERROR', e.Level__c, 'Level__c should be ERROR');
        Assert.isNotNull(e.Context__c, 'Context__c should contain exception metadata');
        Assert.isTrue(e.Context__c.contains('exceptionType'), 'exceptionType key should be present');
        Assert.isTrue(e.Context__c.contains('stackTrace'), 'stackTrace key should be present');
    }

    @IsTest
    static void shouldTruncateOversizeMessage() {
        ElaroLogger.publishedEvents.clear();

        String oversize = 'x'.repeat(131073); // one character over the LongTextArea max

        Test.startTest();
        ElaroLogger.info(oversize);
        Test.stopTest();

        Assert.areEqual(1, ElaroLogger.publishedEvents.size(), 'Exactly one event should be published');
        Assert.areEqual(
            131072,
            ElaroLogger.publishedEvents[0].Message__c.length(),
            'Message__c should be clamped to the LongTextArea maximum'
        );
    }

    @IsTest
    static void shouldHandleNullContextGracefully() {
        ElaroLogger.publishedEvents.clear();

        Test.startTest();
        ElaroLogger.log(ElaroLogger.Level.INFO, 'null context', null);
        Test.stopTest();

        Assert.areEqual(1, ElaroLogger.publishedEvents.size(), 'Exactly one event should be published');
        Assert.isNull(
            ElaroLogger.publishedEvents[0].Context__c,
            'Context__c should be null when no context map is provided'
        );
    }

    @IsTest
    static void shouldEncodeSourceInMessageForSourceOverloads() {
        ElaroLogger.publishedEvents.clear();

        Test.startTest();
        ElaroLogger.info('MyController.runScan', 'started');
        ElaroLogger.error('MyController.runScan', 'failed', 'fake stack trace');
        Test.stopTest();

        Assert.areEqual(2, ElaroLogger.publishedEvents.size(), 'Two events should be published');
        Assert.areEqual(
            'MyController.runScan: started',
            ElaroLogger.publishedEvents[0].Message__c,
            'INFO source overload should concatenate source and message'
        );
        Assert.isNotNull(
            ElaroLogger.publishedEvents[1].Context__c,
            'ERROR source overload should place stackTrace into Context__c'
        );
        Assert.isTrue(
            ElaroLogger.publishedEvents[1].Context__c.contains('fake stack trace'),
            'stackTrace value should be present in Context__c'
        );
    }
}
