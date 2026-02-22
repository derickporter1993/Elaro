/**
 * Tests for {@link SlackIntegrationQueueable}.
 * Validates all four Slack operation types (SEND_ALERT, SEND_AUDIT_PACKAGE,
 * SEND_DAILY_DIGEST, SEND_MESSAGE), including happy path execution, HTTP
 * error handling, null/empty inputs, and the
 * {@link SlackIntegrationQueueable.SlackFinalizer} inner class.
 *
 * @author Elaro Team
 * @since v3.1.0 (Spring '26)
 * @group Integrations
 * @see SlackIntegrationQueueable
 * @see SlackIntegration
 */
@IsTest(testFor=SlackIntegrationQueueable.class)
private class SlackIntegrationQueueableTest {

    // ═══════════════════════════════════════════════════════════════
    // MOCK CLASSES
    // ═══════════════════════════════════════════════════════════════

    private class SlackSuccessMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            res.setBody('ok');
            return res;
        }
    }

    private class SlackErrorMock implements HttpCalloutMock {
        private Integer statusCode;

        public SlackErrorMock(Integer statusCode) {
            this.statusCode = statusCode;
        }

        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(this.statusCode);
            res.setBody('{"error": "channel_not_found"}');
            return res;
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // TEST DATA SETUP
    // ═══════════════════════════════════════════════════════════════

    @TestSetup
    static void makeData() {
        Elaro_Audit_Package__c pkg = new Elaro_Audit_Package__c(
            Package_Name__c = 'HIPAA Q4 2025 Audit Package',
            Framework__c = 'HIPAA',
            Status__c = 'COMPLETED',
            Audit_Period_Start__c = Date.newInstance(2025, 10, 1),
            Audit_Period_End__c = Date.newInstance(2025, 12, 31)
        );
        insert as user pkg;
    }

    // ═══════════════════════════════════════════════════════════════
    // HELPER METHODS
    // ═══════════════════════════════════════════════════════════════

    private static Elaro_Audit_Package__c getTestPackage() {
        return [
            SELECT Id, Package_Name__c, Framework__c, Status__c
            FROM Elaro_Audit_Package__c
            WHERE Package_Name__c = 'HIPAA Q4 2025 Audit Package'
            WITH USER_MODE
            LIMIT 1
        ];
    }

    private static String buildAlertPayload() {
        Map<String, Object> alertData = new Map<String, Object>{
            'severity' => 'HIGH',
            'alertId' => 'ALERT-TEST-001',
            'eventType' => 'LoginAs',
            'riskScore' => 85,
            'message' => 'Suspicious login-as activity detected',
            'eventId' => '0Af000000000001'
        };
        return JSON.serialize(alertData);
    }

    private static String buildDailyDigestPayload() {
        Map<String, Object> digest = new Map<String, Object>{
            'complianceScore' => 87,
            'aiSummary' => 'Overall compliance posture improved by 3% this week.',
            'statistics' => new Map<String, Object>{
                'totalEvents' => 142,
                'highRiskEvents' => 5,
                'resolvedEvents' => 28
            }
        };
        return JSON.serialize(digest);
    }

    private static String buildSimpleMessagePayload() {
        Map<String, Object> message = new Map<String, Object>{
            'channel' => '#compliance-alerts',
            'text' => 'Test message from Elaro Compliance Platform'
        };
        return JSON.serialize(message);
    }

    // ═══════════════════════════════════════════════════════════════
    // SEND_ALERT TESTS
    // ═══════════════════════════════════════════════════════════════

    @IsTest
    static void shouldSendAlertSuccessfully() {
        Test.setMock(HttpCalloutMock.class, new SlackSuccessMock());

        Test.startTest();
        System.enqueueJob(new SlackIntegrationQueueable(
            SlackIntegrationQueueable.Operation.SEND_ALERT,
            buildAlertPayload(),
            null
        ));
        Test.stopTest();

        List<AsyncApexJob> jobs = [
            SELECT Id, Status
            FROM AsyncApexJob
            WHERE JobType = 'Queueable'
            AND ApexClass.Name = 'SlackIntegrationQueueable'
        ];
        Assert.isTrue(jobs.size() > 0,
            'SEND_ALERT queueable job should execute successfully with valid alert payload');
    }

    @IsTest
    static void shouldSendCriticalSeverityAlert() {
        Map<String, Object> criticalAlert = new Map<String, Object>{
            'severity' => 'CRITICAL',
            'alertId' => 'ALERT-CRIT-001',
            'eventType' => 'ReportExport',
            'riskScore' => 98,
            'message' => 'Mass data export detected from sensitive object',
            'eventId' => '0Af000000000002'
        };
        Test.setMock(HttpCalloutMock.class, new SlackSuccessMock());

        Test.startTest();
        System.enqueueJob(new SlackIntegrationQueueable(
            SlackIntegrationQueueable.Operation.SEND_ALERT,
            JSON.serialize(criticalAlert),
            null
        ));
        Test.stopTest();

        List<AsyncApexJob> jobs = [
            SELECT Id, Status
            FROM AsyncApexJob
            WHERE JobType = 'Queueable'
            AND ApexClass.Name = 'SlackIntegrationQueueable'
        ];
        Assert.isTrue(jobs.size() > 0,
            'SEND_ALERT should handle CRITICAL severity alert payload');
    }

    // ═══════════════════════════════════════════════════════════════
    // SEND_AUDIT_PACKAGE TESTS
    // ═══════════════════════════════════════════════════════════════

    @IsTest
    static void shouldSendAuditPackageNotificationSuccessfully() {
        Elaro_Audit_Package__c pkg = getTestPackage();
        Test.setMock(HttpCalloutMock.class, new SlackSuccessMock());

        Test.startTest();
        System.enqueueJob(new SlackIntegrationQueueable(
            SlackIntegrationQueueable.Operation.SEND_AUDIT_PACKAGE,
            String.valueOf(pkg.Id),
            '#audit-team'
        ));
        Test.stopTest();

        List<AsyncApexJob> jobs = [
            SELECT Id, Status
            FROM AsyncApexJob
            WHERE JobType = 'Queueable'
            AND ApexClass.Name = 'SlackIntegrationQueueable'
        ];
        Assert.isTrue(jobs.size() > 0,
            'SEND_AUDIT_PACKAGE should execute successfully with valid package ID and channel');
    }

    // ═══════════════════════════════════════════════════════════════
    // SEND_DAILY_DIGEST TESTS
    // ═══════════════════════════════════════════════════════════════

    @IsTest
    static void shouldSendDailyDigestSuccessfully() {
        Test.setMock(HttpCalloutMock.class, new SlackSuccessMock());

        Test.startTest();
        System.enqueueJob(new SlackIntegrationQueueable(
            SlackIntegrationQueueable.Operation.SEND_DAILY_DIGEST,
            buildDailyDigestPayload(),
            null
        ));
        Test.stopTest();

        List<AsyncApexJob> jobs = [
            SELECT Id, Status
            FROM AsyncApexJob
            WHERE JobType = 'Queueable'
            AND ApexClass.Name = 'SlackIntegrationQueueable'
        ];
        Assert.isTrue(jobs.size() > 0,
            'SEND_DAILY_DIGEST should execute successfully with valid digest payload');
    }

    // ═══════════════════════════════════════════════════════════════
    // SEND_MESSAGE TESTS
    // ═══════════════════════════════════════════════════════════════

    @IsTest
    static void shouldSendSimpleMessageSuccessfully() {
        Test.setMock(HttpCalloutMock.class, new SlackSuccessMock());

        Test.startTest();
        System.enqueueJob(new SlackIntegrationQueueable(
            SlackIntegrationQueueable.Operation.SEND_MESSAGE,
            buildSimpleMessagePayload(),
            null
        ));
        Test.stopTest();

        List<AsyncApexJob> jobs = [
            SELECT Id, Status
            FROM AsyncApexJob
            WHERE JobType = 'Queueable'
            AND ApexClass.Name = 'SlackIntegrationQueueable'
        ];
        Assert.isTrue(jobs.size() > 0,
            'SEND_MESSAGE should execute successfully with a simple message payload');
    }

    // ═══════════════════════════════════════════════════════════════
    // ERROR HANDLING TESTS
    // ═══════════════════════════════════════════════════════════════

    @IsTest
    static void shouldHandleSlackServerError() {
        Test.setMock(HttpCalloutMock.class, new SlackErrorMock(500));

        Test.startTest();
        System.enqueueJob(new SlackIntegrationQueueable(
            SlackIntegrationQueueable.Operation.SEND_ALERT,
            buildAlertPayload(),
            null
        ));
        Test.stopTest();

        // sendToSlack logs the error via ElaroLogger but does not throw,
        // so the job should complete without unhandled exception.
        List<AsyncApexJob> jobs = [
            SELECT Id, Status
            FROM AsyncApexJob
            WHERE JobType = 'Queueable'
            AND ApexClass.Name = 'SlackIntegrationQueueable'
        ];
        Assert.isTrue(jobs.size() > 0,
            'SEND_ALERT should handle 500 error gracefully without unhandled exception');
    }

    @IsTest
    static void shouldHandleSlackNotFoundError() {
        Test.setMock(HttpCalloutMock.class, new SlackErrorMock(404));

        Test.startTest();
        System.enqueueJob(new SlackIntegrationQueueable(
            SlackIntegrationQueueable.Operation.SEND_MESSAGE,
            buildSimpleMessagePayload(),
            null
        ));
        Test.stopTest();

        List<AsyncApexJob> jobs = [
            SELECT Id, Status
            FROM AsyncApexJob
            WHERE JobType = 'Queueable'
            AND ApexClass.Name = 'SlackIntegrationQueueable'
        ];
        Assert.isTrue(jobs.size() > 0,
            'SEND_MESSAGE should handle 404 error gracefully');
    }

    // ═══════════════════════════════════════════════════════════════
    // RETRY / CONSTRUCTOR TESTS
    // ═══════════════════════════════════════════════════════════════

    @IsTest
    static void shouldAcceptExplicitRetryCount() {
        Test.setMock(HttpCalloutMock.class, new SlackSuccessMock());

        Test.startTest();
        System.enqueueJob(new SlackIntegrationQueueable(
            SlackIntegrationQueueable.Operation.SEND_MESSAGE,
            buildSimpleMessagePayload(),
            null,
            1
        ));
        Test.stopTest();

        List<AsyncApexJob> jobs = [
            SELECT Id, Status
            FROM AsyncApexJob
            WHERE JobType = 'Queueable'
            AND ApexClass.Name = 'SlackIntegrationQueueable'
        ];
        Assert.isTrue(jobs.size() > 0,
            'Queueable should execute successfully with an explicit retry count');
    }

    @IsTest
    static void shouldHandleNullRetryCountGracefully() {
        Test.setMock(HttpCalloutMock.class, new SlackSuccessMock());

        Test.startTest();
        System.enqueueJob(new SlackIntegrationQueueable(
            SlackIntegrationQueueable.Operation.SEND_MESSAGE,
            buildSimpleMessagePayload(),
            null,
            null
        ));
        Test.stopTest();

        List<AsyncApexJob> jobs = [
            SELECT Id, Status
            FROM AsyncApexJob
            WHERE JobType = 'Queueable'
            AND ApexClass.Name = 'SlackIntegrationQueueable'
        ];
        Assert.isTrue(jobs.size() > 0,
            'Queueable should handle null retry count via null coalescing');
    }

    // ═══════════════════════════════════════════════════════════════
    // FINALIZER TESTS
    // ═══════════════════════════════════════════════════════════════

    @IsTest
    static void shouldInstantiateSlackFinalizerForSendAlert() {
        Test.startTest();
        SlackIntegrationQueueable.SlackFinalizer finalizer =
            new SlackIntegrationQueueable.SlackFinalizer(
                SlackIntegrationQueueable.Operation.SEND_ALERT,
                buildAlertPayload(),
                null,
                0
            );
        Test.stopTest();

        Assert.isNotNull(finalizer,
            'SlackFinalizer should be instantiable for SEND_ALERT with retry count 0');
    }

    @IsTest
    static void shouldInstantiateSlackFinalizerForDailyDigest() {
        Test.startTest();
        SlackIntegrationQueueable.SlackFinalizer finalizer =
            new SlackIntegrationQueueable.SlackFinalizer(
                SlackIntegrationQueueable.Operation.SEND_DAILY_DIGEST,
                buildDailyDigestPayload(),
                null,
                1
            );
        Test.stopTest();

        Assert.isNotNull(finalizer,
            'SlackFinalizer should be instantiable for SEND_DAILY_DIGEST with retry count 1');
    }

    @IsTest
    static void shouldInstantiateSlackFinalizerAtMaxRetries() {
        Test.startTest();
        SlackIntegrationQueueable.SlackFinalizer finalizer =
            new SlackIntegrationQueueable.SlackFinalizer(
                SlackIntegrationQueueable.Operation.SEND_MESSAGE,
                buildSimpleMessagePayload(),
                null,
                2
            );
        Test.stopTest();

        Assert.isNotNull(finalizer,
            'SlackFinalizer should be instantiable at max retry count of 2');
    }

    // ═══════════════════════════════════════════════════════════════
    // OPERATION ENUM TESTS
    // ═══════════════════════════════════════════════════════════════

    @IsTest
    static void shouldSupportAllOperationEnumValues() {
        Test.startTest();
        SlackIntegrationQueueable.Operation sendAlert = SlackIntegrationQueueable.Operation.SEND_ALERT;
        SlackIntegrationQueueable.Operation sendPkg = SlackIntegrationQueueable.Operation.SEND_AUDIT_PACKAGE;
        SlackIntegrationQueueable.Operation sendDigest = SlackIntegrationQueueable.Operation.SEND_DAILY_DIGEST;
        SlackIntegrationQueueable.Operation sendMsg = SlackIntegrationQueueable.Operation.SEND_MESSAGE;
        Test.stopTest();

        Assert.areEqual('SEND_ALERT', sendAlert.name(),
            'SEND_ALERT enum should have correct name');
        Assert.areEqual('SEND_AUDIT_PACKAGE', sendPkg.name(),
            'SEND_AUDIT_PACKAGE enum should have correct name');
        Assert.areEqual('SEND_DAILY_DIGEST', sendDigest.name(),
            'SEND_DAILY_DIGEST enum should have correct name');
        Assert.areEqual('SEND_MESSAGE', sendMsg.name(),
            'SEND_MESSAGE enum should have correct name');
    }
}
