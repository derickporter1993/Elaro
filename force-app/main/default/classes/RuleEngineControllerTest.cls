/**
 * Tests for RuleEngineController LWC endpoints.
 *
 * @author Elaro Team
 * @since v3.1.0 (Spring '26)
 * @group Rule Engine
 * @see RuleEngineController
 */
@IsTest(testFor=RuleEngineController.class)
private class RuleEngineControllerTest {

    @IsTest
    static void shouldEvaluateFramework() {
        Test.startTest();
        ComplianceOrchestrationEngine.WorkflowExecutionResult result =
            RuleEngineController.evaluateFramework('SOC2');
        Test.stopTest();

        Assert.isNotNull(result, 'Result should not be null');
        Assert.areEqual('COMPLETED', result.status, 'Status should be COMPLETED');
        Assert.areEqual('SOC2', result.framework, 'Framework should match');
    }

    @IsTest
    static void shouldThrowForBlankFramework() {
        Test.startTest();
        try {
            RuleEngineController.evaluateFramework('');
            Assert.fail('Should have thrown AuraHandledException');
        } catch (AuraHandledException e) {
            Assert.isTrue(e.getMessage().contains('required'),
                'Exception should indicate framework is required');
        }
        Test.stopTest();
    }

    @IsTest
    static void shouldThrowForNullFramework() {
        Test.startTest();
        try {
            RuleEngineController.evaluateFramework(null);
            Assert.fail('Should have thrown AuraHandledException');
        } catch (AuraHandledException e) {
            Assert.isTrue(e.getMessage().contains('required'),
                'Exception should indicate framework is required');
        }
        Test.stopTest();
    }

    @IsTest
    static void shouldGetFrameworkScores() {
        Test.startTest();
        List<ComplianceScoreAggregator.ScoreSummary> summaries =
            RuleEngineController.getFrameworkScores();
        Test.stopTest();

        Assert.isNotNull(summaries, 'Summaries should not be null');
    }

    @IsTest
    static void shouldGetExecutionHistoryWithDefault() {
        // Create test execution records
        Workflow_Execution__c exec1 = new Workflow_Execution__c(
            Template_Name__c = 'Test 1',
            Framework__c = 'SOC2',
            Status__c = 'COMPLETED',
            Started_At__c = Datetime.now().addHours(-2),
            Completed_At__c = Datetime.now().addHours(-1)
        );
        Workflow_Execution__c exec2 = new Workflow_Execution__c(
            Template_Name__c = 'Test 2',
            Framework__c = 'HIPAA',
            Status__c = 'COMPLETED',
            Started_At__c = Datetime.now().addHours(-1),
            Completed_At__c = Datetime.now()
        );
        insert as user new List<Workflow_Execution__c>{ exec1, exec2 };

        Test.startTest();
        List<Workflow_Execution__c> history =
            RuleEngineController.getExecutionHistory(null);
        Test.stopTest();

        Assert.isTrue(history.size() >= 2,
            'Should return at least 2 execution records');
    }

    @IsTest
    static void shouldGetExecutionHistoryWithCustomLimit() {
        Workflow_Execution__c exec = new Workflow_Execution__c(
            Template_Name__c = 'Test',
            Framework__c = 'SOC2',
            Status__c = 'COMPLETED',
            Started_At__c = Datetime.now()
        );
        insert as user exec;

        Test.startTest();
        List<Workflow_Execution__c> history =
            RuleEngineController.getExecutionHistory(1);
        Test.stopTest();

        Assert.areEqual(1, history.size(), 'Should return exactly 1 record');
    }

    @IsTest
    static void shouldCapExecutionHistoryAt100() {
        Test.startTest();
        List<Workflow_Execution__c> history =
            RuleEngineController.getExecutionHistory(500);
        Test.stopTest();

        // Even though 500 was requested, limit is capped at 100
        Assert.isTrue(history.size() <= 100,
            'Should never return more than 100 records');
    }

    @IsTest
    static void shouldGetActiveRulesForFramework() {
        Test.startTest();
        List<Compliance_Rule__mdt> rules =
            RuleEngineController.getActiveRules('SOC2');
        Test.stopTest();

        Assert.isNotNull(rules, 'Rules should not be null');
    }

    @IsTest
    static void shouldGetAllActiveRulesWhenFrameworkBlank() {
        Test.startTest();
        List<Compliance_Rule__mdt> rules =
            RuleEngineController.getActiveRules('');
        Test.stopTest();

        Assert.isNotNull(rules, 'Rules should not be null');
    }

    @IsTest
    static void shouldGetAllActiveRulesWhenFrameworkNull() {
        Test.startTest();
        List<Compliance_Rule__mdt> rules =
            RuleEngineController.getActiveRules(null);
        Test.stopTest();

        Assert.isNotNull(rules, 'Rules should not be null');
    }

    @IsTest
    static void shouldGetActiveFrameworks() {
        Test.startTest();
        Set<String> frameworks = RuleEngineController.getActiveFrameworks();
        Test.stopTest();

        Assert.isNotNull(frameworks, 'Frameworks set should not be null');
    }

    // ─── Permission Context Tests (System.runAs) ────────────────────────

    /**
     * getExecutionHistory reads Workflow_Execution__c WITH USER_MODE. A Standard
     * User without the Elaro Rule Engine permission set has no access to that
     * object, so the call must not leak execution history: it returns nothing
     * or raises an AuraHandledException.
     */
    @IsTest
    static void shouldDenyExecutionHistoryForUnauthorizedUser() {
        Workflow_Execution__c exec = new Workflow_Execution__c(
            Template_Name__c = 'Secret',
            Framework__c = 'SOC2',
            Status__c = 'COMPLETED',
            Started_At__c = Datetime.now()
        );
        insert as user exec;

        User minimal = ComplianceTestDataFactory.createTestUser();
        insert minimal;

        Test.startTest();
        System.runAs(minimal) {
            try {
                List<Workflow_Execution__c> history =
                    RuleEngineController.getExecutionHistory(null);
                Assert.areEqual(0, history.size(),
                    'Unauthorized user must not see workflow execution history');
            } catch (AuraHandledException e) {
                Assert.isNotNull(e.getMessage(),
                    'A denied read may instead surface an authorization error');
            }
        }
        Test.stopTest();
    }

    /**
     * With the Elaro Rule Engine User permission set (read on Workflow_Execution__c)
     * the same otherwise-minimal user can read execution history.
     */
    @IsTest
    static void shouldAllowExecutionHistoryWithPermissionSet() {
        Workflow_Execution__c exec = new Workflow_Execution__c(
            Template_Name__c = 'Visible',
            Framework__c = 'SOC2',
            Status__c = 'COMPLETED',
            Started_At__c = Datetime.now()
        );
        insert as user exec;

        User authorized = ComplianceTestDataFactory.createTestUser();
        insert authorized;

        PermissionSet ps = [
            SELECT Id FROM PermissionSet WHERE Name = 'Elaro_Rule_Engine_User' LIMIT 1
        ];
        insert new PermissionSetAssignment(
            AssigneeId = authorized.Id, PermissionSetId = ps.Id
        );

        Test.startTest();
        System.runAs(authorized) {
            List<Workflow_Execution__c> history =
                RuleEngineController.getExecutionHistory(null);
            Assert.isTrue(history.size() >= 1,
                'Authorized user should be able to read execution history');
        }
        Test.stopTest();
    }
}
