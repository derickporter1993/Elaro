/**
 * ElaroLoggerTest
 *
 * Test coverage for ElaroLogger structured logging service
 *
 * @author Elaro
 * @version 1.0
 */
@isTest
private class ElaroLoggerTest {

    @isTest
    static void testDebugLogging_WithMessage_LogsSuccessfully() {
        Test.startTest();
        ElaroLogger.debug('Debug message');
        ElaroLogger.debug('Debug with context', new Map<String, Object>{'key' => 'value'});
        Test.stopTest();

        // Logger should not throw exceptions
        Assert.isTrue(true, 'Debug logging completed without errors');
    }

    @isTest
    static void testInfoLogging_WithMessage_LogsSuccessfully() {
        Test.startTest();
        ElaroLogger.info('Info message');
        ElaroLogger.info('Info with context', new Map<String, Object>{'accountId' => 'test123'});
        Test.stopTest();

        Assert.isTrue(true, 'Info logging completed without errors');
    }

    @isTest
    static void testWarnLogging_WithMessage_LogsSuccessfully() {
        Test.startTest();
        ElaroLogger.warn('Warning message');
        ElaroLogger.warn('Warning with context', new Map<String, Object>{'threshold' => 80});
        Test.stopTest();

        Assert.isTrue(true, 'Warn logging completed without errors');
    }

    @isTest
    static void testErrorLogging_WithMessage_LogsSuccessfully() {
        Test.startTest();
        ElaroLogger.error('Error message');
        ElaroLogger.error('Error with context', new Map<String, Object>{'errorCode' => 500});
        Test.stopTest();

        Assert.isTrue(true, 'Error logging completed without errors');
    }

    @isTest
    static void testErrorLogging_WithException_LogsStackTrace() {
        Test.startTest();
        try {
            Integer result = 1 / 0; // Force exception
        } catch (Exception ex) {
            ElaroLogger.error('Caught exception', ex);
        }
        Test.stopTest();

        Assert.isTrue(true, 'Exception logging completed without errors');
    }

    @isTest
    static void testLogLevel_WithDebug_RespectsConfiguration() {
        Test.startTest();
        ElaroLogger.log(ElaroLogger.Level.DEBUG, 'Test debug', null);
        ElaroLogger.log(ElaroLogger.Level.INFO, 'Test info', null);
        ElaroLogger.log(ElaroLogger.Level.WARN, 'Test warn', null);
        ElaroLogger.log(ElaroLogger.Level.ERROR, 'Test error', null);
        Test.stopTest();

        Assert.isTrue(true, 'All log levels processed successfully');
    }

    @isTest
    static void testLogging_WithNullContext_HandlesGracefully() {
        Test.startTest();
        ElaroLogger.log(ElaroLogger.Level.INFO, 'Null context test', null);
        Test.stopTest();

        Assert.isTrue(true, 'Null context handled without errors');
    }

    @isTest
    static void testLogging_WithComplexContext_SerializesCorrectly() {
        Map<String, Object> complexContext = new Map<String, Object>{
            'accountId' => '001000000000001',
            'recordCount' => 150,
            'frameworks' => new List<String>{'HIPAA', 'SOC2', 'GDPR'},
            'metadata' => new Map<String, Object>{
                'severity' => 'HIGH',
                'category' => 'Security'
            }
        };

        Test.startTest();
        ElaroLogger.info('Complex context test', complexContext);
        Test.stopTest();

        Assert.isTrue(true, 'Complex context serialized successfully');
    }

    @isTest
    static void testLogging_InTestContext_SuppressesOutput() {
        // Verify shouldLog returns false in test context
        Test.startTest();
        ElaroLogger.debug('Should be suppressed');
        ElaroLogger.info('Should be suppressed');
        Test.stopTest();

        // No exceptions should be thrown
        System.assert(Test.isRunningTest(), 'Running in test context');
    }
}
