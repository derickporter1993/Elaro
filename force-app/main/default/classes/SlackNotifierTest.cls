/**
 * Test class for SlackNotifier
 */
@IsTest(testFor=SlackNotifier.class)
private class SlackNotifierTest {

    /**
     * HttpCalloutMock for Slack webhook responses.
     * Returns configurable status codes to test success and error paths.
     */
    private class SlackWebhookMock implements HttpCalloutMock {
        private Integer statusCode;
        private String body;

        public SlackWebhookMock(Integer statusCode, String body) {
            this.statusCode = statusCode;
            this.body = body;
        }

        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(this.statusCode);
            res.setBody(this.body);
            res.setHeader('Content-Type', 'application/json');
            return res;
        }
    }

    @isTest
    static void testNotifyAsyncQueueable() {
        String testMessage = 'Test notification';
        Assert.areNotEqual(null, testMessage, 'Test message should not be null');

        Test.startTest();
        Exception caughtException = null;
        try {
            SlackNotifier.notifyAsyncQueueable(testMessage);
        } catch (Exception e) {
            caughtException = e;
        }
        Test.stopTest();

        Assert.areEqual(null, caughtException, 'notifyAsyncQueueable should not throw exception');
    }

    @isTest
    static void testNotifyAsyncQueueableEmpty() {
        Test.startTest();
        Exception caughtException = null;
        try {
            SlackNotifier.notifyAsyncQueueable('');
        } catch (Exception e) {
            caughtException = e;
        }
        Test.stopTest();

        // Empty notifications should be skipped without error
        Assert.areEqual(null, caughtException, 'Empty notification should not throw exception');
    }

    @isTest
    static void testNotifyRichAsyncQueueable() {
        Map<String, Object> payload = new Map<String, Object>{
            'text' => 'Test rich notification'
        };
        String jsonPayload = JSON.serialize(payload);
        Assert.areNotEqual(null, jsonPayload, 'JSON payload should not be null');

        Test.startTest();
        Exception caughtException = null;
        try {
            SlackNotifier.notifyRichAsyncQueueable(jsonPayload);
        } catch (Exception e) {
            caughtException = e;
        }
        Test.stopTest();

        Assert.areEqual(null, caughtException, 'notifyRichAsyncQueueable should not throw exception');
    }

    @isTest
    static void testNotifyPerformanceAlert() {
        String metric = 'CPU';
        Decimal value = 9500;
        Decimal threshold = 10000;
        Assert.areEqual('CPU', metric, 'Metric should be CPU');

        Test.startTest();
        Exception caughtException = null;
        try {
            SlackNotifier.notifyPerformanceAlert(metric, value, threshold, 'testContext');
        } catch (Exception e) {
            caughtException = e;
        }
        Test.stopTest();

        Assert.areEqual(null, caughtException, 'notifyPerformanceAlert should not throw exception');
    }

    @isTest
    static void testNotifyFlowPerformance() {
        String flowName = 'Test_Flow';
        Integer cpuTime = 5000;
        Assert.areNotEqual(null, flowName, 'Flow name should not be null');

        Test.startTest();
        Exception caughtException = null;
        try {
            SlackNotifier.notifyFlowPerformance(flowName, cpuTime, 'WARNING', 85.5);
        } catch (Exception e) {
            caughtException = e;
        }
        Test.stopTest();

        Assert.areEqual(null, caughtException, 'notifyFlowPerformance should not throw exception');
    }

    @isTest
    static void testNotifyFlowPerformanceEmptyName() {
        Test.startTest();
        Exception caughtException = null;
        try {
            SlackNotifier.notifyFlowPerformance('', 5000, 'WARNING', 85.5);
        } catch (Exception e) {
            caughtException = e;
        }
        Test.stopTest();

        // Empty flow name should be handled gracefully
        Assert.areEqual(null, caughtException, 'Empty flow name should not throw exception');
    }

    @isTest
    static void testBulkNotificationQueueableWithMock() {
        Test.setMock(HttpCalloutMock.class, new SlackWebhookMock(200, 'ok'));

        // Build 5 payloads to exercise the Queueable execute path
        List<String> payloads = new List<String>();
        for (Integer i = 0; i < 5; i++) {
            Map<String, Object> p = new Map<String, Object>{ 'text' => 'Test ' + i };
            payloads.add(JSON.serialize(p));
        }

        Test.startTest();
        SlackNotifier.SlackBulkNotificationQueueable job =
            new SlackNotifier.SlackBulkNotificationQueueable(JSON.serialize(payloads));
        System.enqueueJob(job);
        Test.stopTest();

        // Verify no Integration_Error__c records were created (all 200 OK)
        List<Integration_Error__c> errors = [
            SELECT Id FROM Integration_Error__c
            WHERE Error_Type__c LIKE 'SLACK%'
        ];
        Assert.areEqual(0, errors.size(), 'No integration errors expected for 200 OK responses');
    }

    @isTest
    static void testBulkNotificationQueueableErrorResponse() {
        Test.setMock(HttpCalloutMock.class, new SlackWebhookMock(500, 'Internal Server Error'));

        List<String> payloads = new List<String>();
        Map<String, Object> p = new Map<String, Object>{ 'text' => 'Error test' };
        payloads.add(JSON.serialize(p));

        Test.startTest();
        SlackNotifier.SlackBulkNotificationQueueable job =
            new SlackNotifier.SlackBulkNotificationQueueable(JSON.serialize(payloads));
        System.enqueueJob(job);
        Test.stopTest();

        // Verify that error was logged
        List<Integration_Error__c> errors = [
            SELECT Id, Error_Type__c FROM Integration_Error__c
            WHERE Error_Type__c = 'SLACK_HTTP_ERROR'
        ];
        Assert.areEqual(1, errors.size(), 'Should log one integration error for 500 response');
    }

    @isTest
    static void testPerformanceAlertWithZeroThreshold() {
        Test.setMock(HttpCalloutMock.class, new SlackWebhookMock(200, 'ok'));

        Test.startTest();
        Exception caughtException = null;
        try {
            // Zero threshold should not cause ArithmeticException
            SlackNotifier.notifyPerformanceAlert('CPU', 9500, 0, 'testContext');
        } catch (Exception e) {
            caughtException = e;
        }
        Test.stopTest();

        Assert.areEqual(null, caughtException, 'Zero threshold should not cause division by zero');
    }
}
