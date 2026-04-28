/**
 * Tests for RemediationWorkflowService covering lifecycle stage transitions,
 * SLA deadline calculations, overdue detection, and validation rules.
 *
 * @author Elaro Team
 * @since v3.1.0 (Spring '26)
 * @group Compliance Lifecycle
 * @see RemediationWorkflowService
 */
@IsTest(testFor=RemediationWorkflowService.class)
private class RemediationWorkflowServiceTest {

    @TestSetup
    static void makeData() {
        List<Compliance_Gap__c> gaps = new List<Compliance_Gap__c>{
            new Compliance_Gap__c(
                Framework__c = 'SOC2',
                Policy_Reference__c = 'CC6.1',
                Severity__c = 'CRITICAL',
                Status__c = 'OPEN',
                Lifecycle_Stage__c = 'DISCOVERY',
                Detected_Date__c = Datetime.now().addDays(-10),
                Gap_Description__c = 'Critical SOC2 gap'
            ),
            new Compliance_Gap__c(
                Framework__c = 'HIPAA',
                Policy_Reference__c = '164.312(a)',
                Severity__c = 'HIGH',
                Status__c = 'OPEN',
                Lifecycle_Stage__c = 'ASSESSMENT',
                Detected_Date__c = Datetime.now().addDays(-5),
                Gap_Description__c = 'High HIPAA gap'
            ),
            new Compliance_Gap__c(
                Framework__c = 'GDPR',
                Policy_Reference__c = 'Art32',
                Severity__c = 'MEDIUM',
                Status__c = 'IN_PROGRESS',
                Lifecycle_Stage__c = 'REMEDIATION',
                Detected_Date__c = Datetime.now().addDays(-20),
                Gap_Description__c = 'Medium GDPR gap'
            ),
            new Compliance_Gap__c(
                Framework__c = 'SOC2',
                Policy_Reference__c = 'CC7.2',
                Severity__c = 'LOW',
                Status__c = 'OPEN',
                Lifecycle_Stage__c = 'DISCOVERY',
                Detected_Date__c = Datetime.now().addDays(-100),
                SLA_Deadline__c = Datetime.now().addDays(-10),
                Gap_Description__c = 'Overdue low gap'
            )
        };
        insert as user gaps;
    }

    @IsTest
    static void shouldAdvanceFromDiscoveryToAssessment() {
        Compliance_Gap__c gap = [SELECT Id FROM Compliance_Gap__c WHERE Severity__c = 'CRITICAL' LIMIT 1];

        Test.startTest();
        Compliance_Gap__c updated = RemediationWorkflowService.advanceStage(gap.Id);
        Test.stopTest();

        Assert.areEqual('ASSESSMENT', updated.Lifecycle_Stage__c, 'Should advance to Assessment');
    }

    @IsTest
    static void shouldAdvanceFromAssessmentToRemediation() {
        Compliance_Gap__c gap = [SELECT Id FROM Compliance_Gap__c WHERE Severity__c = 'HIGH' LIMIT 1];

        Test.startTest();
        Compliance_Gap__c updated = RemediationWorkflowService.advanceStage(gap.Id);
        Test.stopTest();

        Assert.areEqual('REMEDIATION', updated.Lifecycle_Stage__c, 'Should advance to Remediation');
        Assert.areEqual('IN_PROGRESS', updated.Status__c, 'Status should change to In Progress');
    }

    @IsTest
    static void shouldAdvanceFromRemediationToValidation() {
        Compliance_Gap__c gap = [SELECT Id FROM Compliance_Gap__c WHERE Severity__c = 'MEDIUM' LIMIT 1];

        Test.startTest();
        Compliance_Gap__c updated = RemediationWorkflowService.advanceStage(gap.Id);
        Test.stopTest();

        Assert.areEqual('VALIDATION', updated.Lifecycle_Stage__c, 'Should advance to Validation');
    }

    @IsTest
    static void shouldSetStageDirectly() {
        Compliance_Gap__c gap = [SELECT Id FROM Compliance_Gap__c WHERE Severity__c = 'CRITICAL' LIMIT 1];

        Test.startTest();
        Compliance_Gap__c updated = RemediationWorkflowService.setStage(gap.Id, 'REMEDIATION');
        Test.stopTest();

        Assert.areEqual('REMEDIATION', updated.Lifecycle_Stage__c, 'Should jump to Remediation');
        Assert.areEqual('IN_PROGRESS', updated.Status__c, 'Status should be In Progress');
    }

    @IsTest
    static void shouldRejectBackwardTransition() {
        Compliance_Gap__c gap = [SELECT Id FROM Compliance_Gap__c WHERE Severity__c = 'MEDIUM' LIMIT 1];

        Test.startTest();
        try {
            RemediationWorkflowService.setStage(gap.Id, 'DISCOVERY');
            Assert.fail('Should have thrown exception for backward transition');
        } catch (AuraHandledException e) {
            Assert.isTrue(e.getMessage().contains('Cannot move backwards'),
                'Error should mention backward transition');
        }
        Test.stopTest();
    }

    @IsTest
    static void shouldRejectInvalidStage() {
        Compliance_Gap__c gap = [SELECT Id FROM Compliance_Gap__c WHERE Severity__c = 'CRITICAL' LIMIT 1];

        Test.startTest();
        try {
            RemediationWorkflowService.setStage(gap.Id, 'INVALID_STAGE');
            Assert.fail('Should have thrown exception for invalid stage');
        } catch (AuraHandledException e) {
            Assert.isTrue(e.getMessage().contains('Invalid target stage'),
                'Error should mention invalid stage');
        }
        Test.stopTest();
    }

    @IsTest
    static void shouldCalculateSLADeadlineForCritical() {
        Compliance_Gap__c gap = [SELECT Id, Detected_Date__c FROM Compliance_Gap__c WHERE Severity__c = 'CRITICAL' LIMIT 1];

        Test.startTest();
        Compliance_Gap__c updated = RemediationWorkflowService.calculateSLADeadline(gap.Id);
        Test.stopTest();

        Assert.isNotNull(updated.SLA_Deadline__c, 'SLA deadline should be set');
        Datetime expectedDeadline = gap.Detected_Date__c.addDays(7);
        Assert.areEqual(expectedDeadline, updated.SLA_Deadline__c,
            'Critical SLA should be 7 days from detection');
    }

    @IsTest
    static void shouldCalculateSLADeadlineBatch() {
        List<Compliance_Gap__c> gaps = [SELECT Id FROM Compliance_Gap__c WHERE Severity__c IN ('CRITICAL', 'HIGH')];
        List<Id> gapIds = new List<Id>();
        for (Compliance_Gap__c g : gaps) {
            gapIds.add(g.Id);
        }

        Test.startTest();
        List<Compliance_Gap__c> updated = RemediationWorkflowService.calculateSLADeadlines(gapIds);
        Test.stopTest();

        Assert.areEqual(gapIds.size(), updated.size(), 'Should update all provided gaps');
        for (Compliance_Gap__c g : updated) {
            Assert.isNotNull(g.SLA_Deadline__c, 'Each gap should have SLA deadline set');
        }
    }

    @IsTest
    static void shouldGetOverdueGaps() {
        Test.startTest();
        List<Compliance_Gap__c> overdue = RemediationWorkflowService.getOverdueGaps();
        Test.stopTest();

        Assert.isFalse(overdue.isEmpty(), 'Should find overdue gaps');
        for (Compliance_Gap__c gap : overdue) {
            Assert.isTrue(gap.SLA_Deadline__c < Datetime.now(),
                'Overdue gap should have deadline in the past');
        }
    }

    @IsTest
    static void shouldGetGapsApproachingDeadline() {
        Compliance_Gap__c gap = [SELECT Id FROM Compliance_Gap__c WHERE Severity__c = 'CRITICAL' LIMIT 1];
        gap.SLA_Deadline__c = Datetime.now().addDays(3);
        update as user gap;

        Test.startTest();
        List<Compliance_Gap__c> approaching = RemediationWorkflowService.getGapsApproachingDeadline(7);
        Test.stopTest();

        Assert.isFalse(approaching.isEmpty(), 'Should find gaps approaching deadline');
    }

    @IsTest
    static void shouldGetLifecycleStageSummary() {
        Test.startTest();
        Map<String, Integer> summary = RemediationWorkflowService.getLifecycleStageSummary();
        Test.stopTest();

        Assert.isNotNull(summary, 'Summary should not be null');
        Assert.isTrue(summary.containsKey('DISCOVERY'), 'Summary should contain Discovery stage');
        Assert.isTrue(summary.get('DISCOVERY') >= 1, 'Discovery should have at least 1 gap');
    }

    @IsTest
    static void shouldReturnStageOrder() {
        Test.startTest();
        List<String> stages = RemediationWorkflowService.getStageOrder();
        Test.stopTest();

        Assert.areEqual(6, stages.size(), 'Should have 6 lifecycle stages');
        Assert.areEqual('DISCOVERY', stages[0], 'First stage should be Discovery');
        Assert.areEqual('CLOSED', stages[5], 'Last stage should be Closed');
    }

    @IsTest
    static void shouldReturnSLAConfiguration() {
        Test.startTest();
        Map<String, Integer> config = RemediationWorkflowService.getSLAConfiguration();
        Test.stopTest();

        Assert.areEqual(7, config.get('CRITICAL'), 'Critical SLA should be 7 days');
        Assert.areEqual(14, config.get('HIGH'), 'High SLA should be 14 days');
        Assert.areEqual(30, config.get('MEDIUM'), 'Medium SLA should be 30 days');
        Assert.areEqual(90, config.get('LOW'), 'Low SLA should be 90 days');
    }

    @IsTest
    static void shouldThrowForInvalidGapId() {
        Test.startTest();
        try {
            RemediationWorkflowService.advanceStage(UserInfo.getUserId());
            Assert.fail('Should throw for non-gap ID');
        } catch (AuraHandledException e) {
            Assert.isTrue(e.getMessage().contains('not found'), 'Should indicate gap not found');
        }
        Test.stopTest();
    }

    @IsTest
    static void shouldCloseFinalStage() {
        Compliance_Gap__c gap = [SELECT Id FROM Compliance_Gap__c WHERE Severity__c = 'MEDIUM' LIMIT 1];
        RemediationWorkflowService.setStage(gap.Id, 'MONITORING');

        Test.startTest();
        Compliance_Gap__c updated = RemediationWorkflowService.advanceStage(gap.Id);
        Test.stopTest();

        Assert.areEqual('CLOSED', updated.Lifecycle_Stage__c, 'Should be closed');
        Assert.areEqual('VERIFIED', updated.Status__c, 'Status should be Verified');
        Assert.isNotNull(updated.Actual_Remediation_Date__c, 'Actual remediation date should be set');
    }
}
