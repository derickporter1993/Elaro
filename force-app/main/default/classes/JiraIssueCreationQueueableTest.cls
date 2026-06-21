/**
 * Test class for JiraIntegrationService.JiraIssueCreationQueueable.
 *
 * JiraIntegrationService.createIssueAsync skips enqueuing in test context, so the
 * inner Queueable's callout path is otherwise uncovered. These tests enqueue it
 * directly with a real compliance gap and a mocked Jira API and assert the real
 * effect: the gap is linked to the created Jira issue.
 *
 * @author Elaro Team
 * @since v1.0.0 (Spring '26)
 * @group Tests
 * @see JiraIntegrationService
 */
@IsTest(testFor=JiraIntegrationService.class)
private class JiraIssueCreationQueueableTest {

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
                res.setBody('{"id":"10001","key":"COMP-1","self":"https://jira.example.com/rest/api/3/issue/10001"}');
            } else {
                res.setStatus('Bad Request');
                res.setBody('{"errorMessages":["Invalid project"]}');
            }
            return res;
        }
    }

    @TestSetup
    static void makeData() {
        insert new Compliance_Gap__c(
            Framework__c = 'SOC2',
            Policy_Reference__c = 'CC6.1',
            Gap_Description__c = 'Access control gap',
            Severity__c = 'HIGH',
            Status__c = 'OPEN',
            Detected_Date__c = Datetime.now()
        );
    }

    @IsTest
    static void shouldCreateJiraIssueAndLinkGap() {
        Test.setMock(HttpCalloutMock.class, new JiraMock(201));
        Compliance_Gap__c gap = [
            SELECT Id FROM Compliance_Gap__c WITH USER_MODE LIMIT 1
        ];

        Test.startTest();
        System.enqueueJob(new JiraIntegrationService.JiraIssueCreationQueueable(gap.Id, 'High'));
        Test.stopTest();

        Assert.areEqual(1, Limits.getCallouts(), 'Queueable should make one Jira callout');

        // Real effect: the gap is linked to the created Jira issue.
        Compliance_Gap__c updated = [
            SELECT Id, Jira_Issue_Key__c, Jira_Status__c, Jira_Last_Sync__c
            FROM Compliance_Gap__c
            WHERE Id = :gap.Id
            WITH USER_MODE
        ];
        Assert.areEqual('COMP-1', updated.Jira_Issue_Key__c, 'Gap should be linked to the new Jira issue key');
        Assert.areEqual('To Do', updated.Jira_Status__c, 'Gap Jira status should be initialized to To Do');
        Assert.isNotNull(updated.Jira_Last_Sync__c, 'Gap should record the Jira sync timestamp');
    }

    @IsTest
    static void shouldSwallowErrorOnFailedCreation() {
        Test.setMock(HttpCalloutMock.class, new JiraMock(400));
        Compliance_Gap__c gap = [
            SELECT Id FROM Compliance_Gap__c WITH USER_MODE LIMIT 1
        ];

        Test.startTest();
        System.enqueueJob(new JiraIntegrationService.JiraIssueCreationQueueable(gap.Id, null));
        Test.stopTest();

        // The queueable swallows the failure; the gap must remain unlinked.
        Compliance_Gap__c updated = [
            SELECT Id, Jira_Issue_Key__c
            FROM Compliance_Gap__c
            WHERE Id = :gap.Id
            WITH USER_MODE
        ];
        Assert.isNull(updated.Jira_Issue_Key__c, 'Gap should remain unlinked when Jira creation fails');

        List<AsyncApexJob> jobs = [
            SELECT Id, Status, NumberOfErrors
            FROM AsyncApexJob
            WHERE JobType = 'Queueable'
            AND ApexClass.Name = 'JiraIntegrationService'
        ];
        Assert.areEqual('Completed', jobs[0].Status, 'Queueable should complete even when creation fails');
    }
}
