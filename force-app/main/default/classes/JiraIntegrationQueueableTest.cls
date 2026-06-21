/**
 * Test class for JiraIntegrationQueueable (top-level).
 *
 * This Queueable delegates to JiraIntegrationService.createIssue and attaches a
 * JiraIssueFinalizer for retry/error logging. These tests enqueue it directly
 * with a real compliance gap and a mocked Jira API, asserting the gap is linked
 * on success and the job completes (gap unlinked) on failure.
 *
 * @author Elaro Team
 * @since v1.0.0 (Spring '26)
 * @group Tests
 * @see JiraIntegrationQueueable
 */
@IsTest(testFor=JiraIntegrationQueueable.class)
private class JiraIntegrationQueueableTest {

    private class JiraMock implements HttpCalloutMock {
        private Integer statusCode;
        public JiraMock(Integer statusCode) {
            this.statusCode = statusCode;
        }
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(this.statusCode);
            if (this.statusCode == 201) {
                res.setStatus('Created');
                res.setBody('{"id":"10002","key":"COMP-2"}');
            } else {
                res.setStatus('Server Error');
                res.setBody('{"errorMessages":["boom"]}');
            }
            return res;
        }
    }

    @TestSetup
    static void makeData() {
        insert new Compliance_Gap__c(
            Framework__c = 'HIPAA',
            Policy_Reference__c = '164.312',
            Gap_Description__c = 'Encryption gap',
            Severity__c = 'CRITICAL',
            Status__c = 'OPEN',
            Detected_Date__c = Datetime.now()
        );
    }

    @IsTest
    static void shouldCreateAndLinkJiraIssue() {
        Test.setMock(HttpCalloutMock.class, new JiraMock(201));
        Compliance_Gap__c gap = [SELECT Id FROM Compliance_Gap__c WITH USER_MODE LIMIT 1];

        Test.startTest();
        System.enqueueJob(new JiraIntegrationQueueable(gap.Id, 'Highest'));
        Test.stopTest();

        Assert.areEqual(1, Limits.getCallouts(), 'Queueable should make one Jira callout');

        Compliance_Gap__c updated = [
            SELECT Id, Jira_Issue_Key__c
            FROM Compliance_Gap__c
            WHERE Id = :gap.Id
            WITH USER_MODE
        ];
        Assert.areEqual('COMP-2', updated.Jira_Issue_Key__c, 'Gap should be linked to the created Jira issue');
    }

    @IsTest
    static void shouldSwallowFailureAndLeaveGapUnlinked() {
        Test.setMock(HttpCalloutMock.class, new JiraMock(500));
        Compliance_Gap__c gap = [SELECT Id FROM Compliance_Gap__c WITH USER_MODE LIMIT 1];

        Test.startTest();
        System.enqueueJob(new JiraIntegrationQueueable(gap.Id, null));
        Test.stopTest();

        Compliance_Gap__c updated = [
            SELECT Id, Jira_Issue_Key__c
            FROM Compliance_Gap__c
            WHERE Id = :gap.Id
            WITH USER_MODE
        ];
        Assert.isNull(updated.Jira_Issue_Key__c, 'Gap should remain unlinked when Jira creation fails');

        List<AsyncApexJob> jobs = [
            SELECT Id, Status
            FROM AsyncApexJob
            WHERE JobType = 'Queueable'
            AND ApexClass.Name = 'JiraIntegrationQueueable'
        ];
        Assert.areEqual('Completed', jobs[0].Status, 'Queueable should complete even when creation fails');
    }

    @IsTest
    static void finalizerShouldConstructWithRetryContext() {
        JiraIntegrationQueueable.JiraIssueFinalizer finalizer =
            new JiraIntegrationQueueable.JiraIssueFinalizer('a01000000000000AAA', 'High', 0);
        Assert.isNotNull(finalizer, 'Finalizer should be constructable with retry context');
    }
}
