/**
 * Unit tests for the PHI Data Classification Engine (#212): {@link PHIClassificationService}
 * and {@link PHIClassificationScheduler}. Runs against the standard Contact object, whose
 * Email/Phone fields are classified Sensitive via type heuristics, so assertions hold even
 * independently of the seeded PHI_Classification_Rule__mdt records.
 *
 * @author Elaro Team
 * @since v3.2.0 (Spring '26)
 * @group HIPAA Pack
 * @see PHIClassificationService
 */
@IsTest
private class PHIClassificationServiceTest {

    @IsTest
    static void shouldClassifyContactFields() {
        PHIClassificationService service = new PHIClassificationService();

        Test.startTest();
        PHIClassificationService.ClassificationResult result = service.classifyObject('Contact');
        Test.stopTest();

        Assert.isNotNull(result, 'Result should not be null');
        Assert.isTrue(result.fieldsEvaluated > 0, 'Should evaluate Contact fields');
        Assert.areEqual(
            result.fieldsEvaluated,
            result.phiCount + result.sensitiveCount + result.nonSensitiveCount,
            'Every evaluated field should receive exactly one classification'
        );
        Assert.isTrue(result.sensitiveCount > 0, 'Contact has Email/Phone fields treated as Sensitive');

        List<PHI_Field_Registry__c> saved = [
            SELECT Field_Key__c, Classification__c
            FROM PHI_Field_Registry__c
            WHERE Object_API_Name__c = 'Contact'
        ];
        Assert.isFalse(saved.isEmpty(), 'Classification results should be persisted');
    }

    @IsTest
    static void shouldExposePhiFieldNames() {
        new PHIClassificationService().classifyObject('Contact');

        Set<String> phiFields = PHIClassificationService.getPhiFieldNames('Contact');
        Assert.isFalse(phiFields.isEmpty(), 'Contact should expose at least one PHI/Sensitive field');
        Assert.isTrue(PHIClassificationService.getPhiFieldNames('').isEmpty(), 'Blank object yields an empty set');
    }

    @IsTest
    static void shouldUpsertIdempotently() {
        PHIClassificationService service = new PHIClassificationService();
        service.classifyObject('Contact');
        Integer afterFirst = [SELECT COUNT() FROM PHI_Field_Registry__c WHERE Object_API_Name__c = 'Contact'];
        service.classifyObject('Contact');
        Integer afterSecond = [SELECT COUNT() FROM PHI_Field_Registry__c WHERE Object_API_Name__c = 'Contact'];
        Assert.areEqual(afterFirst, afterSecond, 'Re-running classification should upsert, not duplicate');
    }

    @IsTest
    static void shouldThrowWhenObjectUnknown() {
        try {
            new PHIClassificationService().classifyObject('Definitely_Not_A_Real_Object__x');
            Assert.fail('Expected AuraHandledException for an unknown object');
        } catch (AuraHandledException e) {
            Assert.isNotNull(e, 'Should throw for an unknown object');
        }
    }

    @IsTest
    static void shouldRespectHipaaPackKillSwitch() {
        Elaro_Feature_Flags__c flags = Elaro_Feature_Flags__c.getOrgDefaults();
        flags.HIPAA_Pack_Enabled__c = false;
        upsert flags;

        try {
            new PHIClassificationService().classifyObject('Contact');
            Assert.fail('Expected AuraHandledException when the HIPAA pack is disabled');
        } catch (AuraHandledException e) {
            Assert.isNotNull(e, 'Should throw when the HIPAA pack is disabled');
        }
    }

    @IsTest
    static void shouldRefreshViaScheduler() {
        // Seed the registry so the scheduler has objects to refresh.
        new PHIClassificationService().classifyObject('Contact');

        Test.startTest();
        new PHIClassificationScheduler().execute(null);
        Test.stopTest();

        Integer count = [SELECT COUNT() FROM PHI_Field_Registry__c WHERE Object_API_Name__c = 'Contact'];
        Assert.isTrue(count > 0, 'Scheduler refresh should keep the registry populated');
    }
}
