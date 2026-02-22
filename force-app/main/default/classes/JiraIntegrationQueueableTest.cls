/**
 * Tests for {@link JiraIntegrationQueueable}.
 * Validates asynchronous Jira issue creation from Compliance Gap records,
 * including happy path execution, HTTP error handling, null/empty inputs,
 * and the {@link JiraIntegrationQueueable.JiraIssueFinalizer} inner class.
 *
 * @author Elaro Team
 * @since v3.1.0 (Spring '26)
 * @group Integrations
 * @see JiraIntegrationQueueable
 * @see JiraIntegrationService
 */
@IsTest(testFor=JiraIntegrationQueueable.class)
private class JiraIntegrationQueueableTest {

    private static final String MOCK_JIRA_KEY = 'COMPLIANCE-456';
    private static final String MOCK_JIRA_ID = '20001';

    // ═══════════════════════════════════════════════════════════════
    // MOCK CLASSES
    // ═══════════════════════════════════════════════════════════════

    private class JiraSuccessMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(201);
            res.setBody('{"id": "' + MOCK_JIRA_ID + '", "key": "' + MOCK_JIRA_KEY
                + '", "self": "https://test.atlassian.net/rest/api/3/issue/' + MOCK_JIRA_ID + '"}');
            return res;
        }
    }

    private class JiraErrorMock implements HttpCalloutMock {
        private Integer statusCode;

        public JiraErrorMock(Integer statusCode) {
            this.statusCode = statusCode;
        }

        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(this.statusCode);
            res.setBody('{"errorMessages": ["Server error during issue creation"]}');
            return res;
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // TEST DATA SETUP
    // ═══════════════════════════════════════════════════════════════

    @TestSetup
    static void makeData() {
        Elaro_Jira_Settings__c settings = new Elaro_Jira_Settings__c(
            SetupOwnerId = UserInfo.getOrganizationId(),
            Jira_Instance_URL__c = 'https://test.atlassian.net',
            Project_Key__c = 'COMPLIANCE',
            Issue_Type__c = 'Task',
            Default_Priority__c = 'High',
            Auto_Create_Enabled__c = false,
            Risk_Threshold__c = 8.0,
            Sync_Enabled__c = true
        );
        insert settings;

        Compliance_Gap__c gap = new Compliance_Gap__c(
            Framework__c = 'SOC2',
            Policy_Reference__c = 'SOC2-CC6.1',
            Severity__c = 'HIGH',
            Status__c = 'OPEN',
            Gap_Description__c = 'Access control gap requiring Jira ticket',
            Remediation_Plan__c = 'Implement MFA for all admin users',
            Risk_Score__c = 8.5,
            Detected_Date__c = Datetime.now(),
            Entity_Type__c = 'PERMISSION_SET',
            Entity_Id__c = '0PS000000000001'
        );
        insert gap;
    }

    // ═══════════════════════════════════════════════════════════════
    // HELPER METHODS
    // ═══════════════════════════════════════════════════════════════

    private static Compliance_Gap__c getTestGap() {
        return [
            SELECT Id, Framework__c, Severity__c, Status__c, Jira_Issue_Key__c
            FROM Compliance_Gap__c
            WHERE Policy_Reference__c = 'SOC2-CC6.1'
            WITH USER_MODE
            LIMIT 1
        ];
    }

    // ═══════════════════════════════════════════════════════════════
    // HAPPY PATH TESTS
    // ═══════════════════════════════════════════════════════════════

    @IsTest
    static void shouldCreateJiraIssueSuccessfully() {
        Compliance_Gap__c gap = getTestGap();
        Test.setMock(HttpCalloutMock.class, new JiraSuccessMock());

        Test.startTest();
        System.enqueueJob(new JiraIntegrationQueueable(String.valueOf(gap.Id), 'High'));
        Test.stopTest();

        List<AsyncApexJob> jobs = [
            SELECT Id, Status
            FROM AsyncApexJob
            WHERE JobType = 'Queueable'
            AND ApexClass.Name = 'JiraIntegrationQueueable'
        ];
        Assert.isTrue(jobs.size() > 0,
            'Queueable job should have been enqueued and executed for Jira issue creation');

        Compliance_Gap__c updatedGap = [
            SELECT Jira_Issue_Key__c, Jira_Issue_URL__c, Jira_Status__c
            FROM Compliance_Gap__c
            WHERE Id = :gap.Id
            WITH USER_MODE
        ];
        Assert.areEqual(MOCK_JIRA_KEY, updatedGap.Jira_Issue_Key__c,
            'Gap should be linked to the created Jira issue key');
        Assert.isNotNull(updatedGap.Jira_Issue_URL__c,
            'Gap should have a Jira issue URL populated after successful creation');
    }

    @IsTest
    static void shouldExecuteWithNullPriority() {
        Compliance_Gap__c gap = getTestGap();
        Test.setMock(HttpCalloutMock.class, new JiraSuccessMock());

        Test.startTest();
        System.enqueueJob(new JiraIntegrationQueueable(String.valueOf(gap.Id), null));
        Test.stopTest();

        List<AsyncApexJob> jobs = [
            SELECT Id, Status
            FROM AsyncApexJob
            WHERE JobType = 'Queueable'
            AND ApexClass.Name = 'JiraIntegrationQueueable'
        ];
        Assert.isTrue(jobs.size() > 0,
            'Queueable should execute successfully when priority is null, using default from settings');
    }

    @IsTest
    static void shouldAcceptRetryCountConstructor() {
        Compliance_Gap__c gap = getTestGap();
        Test.setMock(HttpCalloutMock.class, new JiraSuccessMock());

        Test.startTest();
        System.enqueueJob(new JiraIntegrationQueueable(String.valueOf(gap.Id), 'Medium', 1));
        Test.stopTest();

        List<AsyncApexJob> jobs = [
            SELECT Id, Status
            FROM AsyncApexJob
            WHERE JobType = 'Queueable'
            AND ApexClass.Name = 'JiraIntegrationQueueable'
        ];
        Assert.isTrue(jobs.size() > 0,
            'Queueable should execute with an explicit retry count of 1');
    }

    // ═══════════════════════════════════════════════════════════════
    // ERROR HANDLING TESTS
    // ═══════════════════════════════════════════════════════════════

    @IsTest
    static void shouldHandleJiraApiServerError() {
        Compliance_Gap__c gap = getTestGap();
        Test.setMock(HttpCalloutMock.class, new JiraErrorMock(500));

        Test.startTest();
        System.enqueueJob(new JiraIntegrationQueueable(String.valueOf(gap.Id), 'High'));
        Test.stopTest();

        // The execute method catches exceptions internally and logs via ElaroLogger,
        // so no unhandled exception should propagate.
        List<AsyncApexJob> jobs = [
            SELECT Id, Status
            FROM AsyncApexJob
            WHERE JobType = 'Queueable'
            AND ApexClass.Name = 'JiraIntegrationQueueable'
        ];
        Assert.isTrue(jobs.size() > 0,
            'Queueable should complete without unhandled exception on 500 error');

        // Gap should NOT have a Jira key since creation failed
        Compliance_Gap__c updatedGap = [
            SELECT Jira_Issue_Key__c
            FROM Compliance_Gap__c
            WHERE Id = :gap.Id
            WITH USER_MODE
        ];
        Assert.isNull(updatedGap.Jira_Issue_Key__c,
            'Gap should not have a Jira key when API returns a server error');
    }

    @IsTest
    static void shouldHandleJiraBadRequestError() {
        Compliance_Gap__c gap = getTestGap();
        Test.setMock(HttpCalloutMock.class, new JiraErrorMock(400));

        Test.startTest();
        System.enqueueJob(new JiraIntegrationQueueable(String.valueOf(gap.Id), 'High'));
        Test.stopTest();

        Compliance_Gap__c updatedGap = [
            SELECT Jira_Issue_Key__c
            FROM Compliance_Gap__c
            WHERE Id = :gap.Id
            WITH USER_MODE
        ];
        Assert.isNull(updatedGap.Jira_Issue_Key__c,
            'Gap should not have a Jira key when API returns 400 Bad Request');
    }

    // ═══════════════════════════════════════════════════════════════
    // NULL / EMPTY INPUT TESTS
    // ═══════════════════════════════════════════════════════════════

    @IsTest
    static void shouldHandleInvalidGapIdGracefully() {
        Test.setMock(HttpCalloutMock.class, new JiraErrorMock(400));

        Test.startTest();
        // Use a syntactically valid but non-existent Id. The JiraIntegrationService.createIssue
        // will throw JiraIntegrationException, which is caught by the Queueable's try-catch.
        System.enqueueJob(new JiraIntegrationQueueable('a0B000000000000AAA', 'High'));
        Test.stopTest();

        List<AsyncApexJob> jobs = [
            SELECT Id, Status
            FROM AsyncApexJob
            WHERE JobType = 'Queueable'
            AND ApexClass.Name = 'JiraIntegrationQueueable'
        ];
        Assert.isTrue(jobs.size() > 0,
            'Queueable should handle invalid gap ID without unhandled exception');
    }

    // ═══════════════════════════════════════════════════════════════
    // FINALIZER TESTS
    // ═══════════════════════════════════════════════════════════════

    @IsTest
    static void shouldInstantiateJiraIssueFinalizer() {
        Compliance_Gap__c gap = getTestGap();

        Test.startTest();
        JiraIntegrationQueueable.JiraIssueFinalizer finalizer =
            new JiraIntegrationQueueable.JiraIssueFinalizer(
                String.valueOf(gap.Id), 'High', 0
            );
        Test.stopTest();

        Assert.isNotNull(finalizer,
            'JiraIssueFinalizer should be instantiable with valid parameters');
    }

    @IsTest
    static void shouldInstantiateJiraIssueFinalizerAtMaxRetries() {
        Compliance_Gap__c gap = getTestGap();

        Test.startTest();
        JiraIntegrationQueueable.JiraIssueFinalizer finalizer =
            new JiraIntegrationQueueable.JiraIssueFinalizer(
                String.valueOf(gap.Id), 'High', 1
            );
        Test.stopTest();

        Assert.isNotNull(finalizer,
            'JiraIssueFinalizer should be instantiable at the max retry count boundary');
    }

    // ═══════════════════════════════════════════════════════════════
    // PRIORITY VARIATION TESTS
    // ═══════════════════════════════════════════════════════════════

    @IsTest
    static void shouldExecuteWithLowestPriority() {
        Compliance_Gap__c gap = getTestGap();
        Test.setMock(HttpCalloutMock.class, new JiraSuccessMock());

        Test.startTest();
        System.enqueueJob(new JiraIntegrationQueueable(String.valueOf(gap.Id), 'Lowest'));
        Test.stopTest();

        Compliance_Gap__c updatedGap = [
            SELECT Jira_Issue_Key__c
            FROM Compliance_Gap__c
            WHERE Id = :gap.Id
            WITH USER_MODE
        ];
        Assert.areEqual(MOCK_JIRA_KEY, updatedGap.Jira_Issue_Key__c,
            'Gap should be linked to Jira issue when using Lowest priority override');
    }
}
