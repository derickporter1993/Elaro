/**
 * Unit tests for the Workforce Access Risk Engine (#213): {@link WorkforceAccessRiskService}
 * and {@link WorkforceAccessRiskBatch}. Uses the @TestVisible access-injection seam for
 * deterministic scoring assertions, plus a real-query path and the batch/scheduler entry points.
 *
 * @author Elaro Team
 * @since v3.2.0 (Spring '26)
 * @group HIPAA Pack
 * @see WorkforceAccessRiskService
 */
@IsTest
private class WorkforceAccessRiskServiceTest {

    private static void seedPhiObjects() {
        List<PHI_Field_Registry__c> recs = new List<PHI_Field_Registry__c>();
        for (String obj : new List<String>{ 'Account', 'Contact', 'Lead', 'Case' }) {
            recs.add(
                new PHI_Field_Registry__c(
                    Field_Key__c = obj + '.TestField',
                    Name = obj + '.TestField',
                    Object_API_Name__c = obj,
                    Field_API_Name__c = 'TestField',
                    Classification__c = 'PHI',
                    Detection_Method__c = 'Manual',
                    Last_Evaluated__c = Datetime.now()
                )
            );
        }
        insert recs;
    }

    @IsTest
    static void shouldScoreOverPrivilegedUser() {
        seedPhiObjects(); // 4 PHI-bearing objects
        Id uid = UserInfo.getUserId();
        WorkforceAccessRiskService.accessOverrideForTest = new Map<Id, Set<String>>{
            uid => new Set<String>{ 'Account', 'Contact' } // 2 of 4 => 50% => High, over-privileged
        };

        Test.startTest();
        List<WorkforceAccessRiskService.RiskResult> results = new WorkforceAccessRiskService()
            .evaluateUsers(new List<Id>{ uid });
        Test.stopTest();

        Assert.areEqual(1, results.size(), 'One result expected');
        WorkforceAccessRiskService.RiskResult result = results[0];
        Assert.isTrue(result.riskScore == 50, 'Score should be 50% of the PHI surface, got ' + result.riskScore);
        Assert.areEqual('High', result.riskLevel, 'Should be High');
        Assert.isTrue(result.overPrivileged, 'Should be flagged over-privileged');

        List<Workforce_Access_Risk__c> saved = [
            SELECT User__c, Risk_Level__c, Over_Privileged__c, PHI_Object_Count__c, PHI_Objects_Total__c
            FROM Workforce_Access_Risk__c
            WHERE User__c = :uid
        ];
        Assert.areEqual(1, saved.size(), 'Risk record should be persisted');
        Assert.areEqual('High', saved[0].Risk_Level__c, 'Persisted level should be High');
        Assert.isTrue(saved[0].PHI_Object_Count__c == 2, 'Should count 2 accessible PHI objects');
        Assert.isTrue(saved[0].PHI_Objects_Total__c == 4, 'Total PHI objects should be 4');
    }

    @IsTest
    static void shouldScoreLowAccessUser() {
        seedPhiObjects();
        Id uid = UserInfo.getUserId();
        WorkforceAccessRiskService.accessOverrideForTest = new Map<Id, Set<String>>{ uid => new Set<String>() };

        Test.startTest();
        List<WorkforceAccessRiskService.RiskResult> results = new WorkforceAccessRiskService()
            .evaluateUsers(new List<Id>{ uid });
        Test.stopTest();

        Assert.areEqual('Low', results[0].riskLevel, 'No PHI access => Low');
        Assert.isFalse(results[0].overPrivileged, 'No PHI access => not over-privileged');
        Assert.isTrue(results[0].riskScore == 0, 'No PHI access => score 0');
    }

    @IsTest
    static void shouldReturnEmptyForNoUsers() {
        List<WorkforceAccessRiskService.RiskResult> results = new WorkforceAccessRiskService()
            .evaluateUsers(new List<Id>());
        Assert.isTrue(results.isEmpty(), 'No users => empty results');
    }

    @IsTest
    static void shouldEvaluateViaRealAccessQueries() {
        // No override: exercises buildUserPhiAccess (ObjectPermissions + PermissionSetAssignment).
        seedPhiObjects();
        Id uid = UserInfo.getUserId();

        Test.startTest();
        List<WorkforceAccessRiskService.RiskResult> results = new WorkforceAccessRiskService()
            .evaluateUsers(new List<Id>{ uid });
        Test.stopTest();

        Assert.areEqual(1, results.size(), 'Should evaluate the running user');
        Assert.isNotNull(results[0].riskLevel, 'Risk level should be assigned');
        List<Workforce_Access_Risk__c> saved = [SELECT Id FROM Workforce_Access_Risk__c WHERE User__c = :uid];
        Assert.areEqual(1, saved.size(), 'A risk record should be persisted');
    }

    @IsTest
    static void shouldRespectKillSwitch() {
        Elaro_Feature_Flags__c flags = Elaro_Feature_Flags__c.getOrgDefaults();
        flags.HIPAA_Pack_Enabled__c = false;
        upsert flags;

        try {
            new WorkforceAccessRiskService().evaluateUsers(new List<Id>{ UserInfo.getUserId() });
            Assert.fail('Expected AuraHandledException when the HIPAA pack is disabled');
        } catch (AuraHandledException e) {
            Assert.isNotNull(e, 'Should throw when the HIPAA pack is disabled');
        }
    }

    @IsTest
    static void shouldRunBatch() {
        seedPhiObjects();
        Id uid = UserInfo.getUserId();
        WorkforceAccessRiskService.accessOverrideForTest = new Map<Id, Set<String>>{
            uid => new Set<String>{ 'Account' }
        };

        Test.startTest();
        WorkforceAccessRiskBatch batch = new WorkforceAccessRiskBatch();
        batch.execute(null, new List<User>{ new User(Id = uid) });
        batch.finish(null);
        Test.stopTest();

        List<Workforce_Access_Risk__c> saved = [SELECT Id FROM Workforce_Access_Risk__c WHERE User__c = :uid];
        Assert.isFalse(saved.isEmpty(), 'Batch execute should persist a risk record');
    }

    @IsTest
    static void shouldScheduleBatch() {
        Test.startTest();
        new WorkforceAccessRiskBatch().execute((SchedulableContext) null);
        Test.stopTest();
        Assert.isTrue(true, 'Schedulable execute should launch the batch without error');
    }
}
