/**
 * Test class for OrchestrationService.OrchestrationScanQueueable.
 *
 * The Queueable runs an asynchronous multi-framework scan and persists an
 * aggregated Compliance_Score__c record. These tests enqueue it directly (the
 * async path that triggerScan() skips during tests) and assert the persisted
 * score record and job completion.
 *
 * @author Elaro Team
 * @since v1.0.0 (Spring '26)
 * @group Tests
 * @see OrchestrationService
 */
@IsTest(testFor=OrchestrationService.class)
private class OrchestrationScanQueueableTest {

    @IsTest
    static void shouldPersistAggregatedScore() {
        List<String> frameworks = new List<String>(
            ComplianceServiceFactory.getSupportedFrameworks()
        );
        Assert.isFalse(frameworks.isEmpty(), 'Precondition: there should be supported frameworks');

        Test.startTest();
        System.enqueueJob(
            new OrchestrationService.OrchestrationScanQueueable('SCAN-TEST-1', frameworks)
        );
        Test.stopTest();

        // Real effect: persistScanResults() inserts an aggregated Compliance_Score__c.
        List<Compliance_Score__c> scores = [
            SELECT Id, Org_ID__c, Entity_Type__c, Risk_Score__c, Framework_Scores__c, Calculated_At__c
            FROM Compliance_Score__c
            WITH USER_MODE
            ORDER BY Calculated_At__c DESC
        ];
        Assert.isFalse(scores.isEmpty(), 'Queueable should persist an aggregated Compliance_Score__c');
        Assert.areEqual(UserInfo.getOrganizationId(), scores[0].Org_ID__c, 'Org Id should be stamped on the score');
        Assert.areEqual('Organization', scores[0].Entity_Type__c, 'Entity type should be Organization');
        Assert.isNotNull(scores[0].Risk_Score__c, 'Risk score should be calculated');
        Assert.isNotNull(scores[0].Framework_Scores__c, 'Per-framework scores JSON should be persisted');
    }

    @IsTest
    static void shouldScanSpecificFrameworks() {
        List<String> frameworks = new List<String>{
            ComplianceServiceFactory.FRAMEWORK_SOC2,
            ComplianceServiceFactory.FRAMEWORK_HIPAA
        };

        Test.startTest();
        System.enqueueJob(
            new OrchestrationService.OrchestrationScanQueueable('SCAN-TEST-2', frameworks)
        );
        Test.stopTest();

        // The persisted Framework_Scores__c JSON should contain the requested frameworks.
        Compliance_Score__c score = [
            SELECT Framework_Scores__c
            FROM Compliance_Score__c
            WITH USER_MODE
            ORDER BY Calculated_At__c DESC
            LIMIT 1
        ];
        Assert.isNotNull(score.Framework_Scores__c, 'Framework scores JSON should exist');
        Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(score.Framework_Scores__c);
        Assert.isTrue(
            parsed.containsKey(ComplianceServiceFactory.FRAMEWORK_SOC2)
                || parsed.containsKey(ComplianceServiceFactory.FRAMEWORK_HIPAA),
            'Requested frameworks should be represented in the persisted score JSON'
        );
    }

    @IsTest
    static void shouldCompleteJobWithEmptyFrameworkList() {
        // Negative path: an empty framework list yields no successful scores but the
        // Queueable must still complete without an unhandled exception.
        Test.startTest();
        System.enqueueJob(
            new OrchestrationService.OrchestrationScanQueueable('SCAN-TEST-3', new List<String>())
        );
        Test.stopTest();

        List<AsyncApexJob> jobs = [
            SELECT Id, Status, NumberOfErrors
            FROM AsyncApexJob
            WHERE JobType = 'Queueable'
            AND ApexClass.Name = 'OrchestrationService'
        ];
        Assert.isFalse(jobs.isEmpty(), 'A Queueable AsyncApexJob should have been created');
        Assert.areEqual('Completed', jobs[0].Status, 'Queueable job should complete even with no frameworks');
    }
}
