/**
 * HIPAAPrivacyRuleServiceTest
 *
 * Test class for HIPAAPrivacyRuleService
 *
 * @author Elaro
 * @version 1.0
 */
@IsTest(testFor=HIPAAPrivacyRuleService.class)
public class HIPAAPrivacyRuleServiceTest {

    @TestSetup
    static void setup() {
        // Create test accounts
        List<Account> accounts = new List<Account>();
        for (Integer i = 0; i < 5; i++) {
            accounts.add(new Account(
                Name = 'Test Healthcare Account ' + i
            ));
        }
        insert accounts;

        // Create test contacts
        List<Contact> contacts = new List<Contact>();
        for (Integer i = 0; i < 10; i++) {
            contacts.add(new Contact(
                FirstName = 'Test',
                LastName = 'Patient ' + i,
                AccountId = accounts[Math.mod(i, accounts.size())].Id,
                Email = 'patient' + i + '@test.com'
            ));
        }
        insert contacts;
    }

    @IsTest
    static void testGetFrameworkName() {
        HIPAAPrivacyRuleService service = new HIPAAPrivacyRuleService();

        Test.startTest();
        String frameworkName = service.getFrameworkName();
        Test.stopTest();

        Assert.areEqual('HIPAA', frameworkName, 'Framework name should be HIPAA');
    }

    @IsTest
    static void testGetViolations() {
        HIPAAPrivacyRuleService service = new HIPAAPrivacyRuleService();

        Test.startTest();
        List<ComplianceServiceBase.Violation> violations = service.getViolations();
        Test.stopTest();

        Assert.areNotEqual(null, violations, 'Violations should not be null');
    }

    @IsTest
    static void testGetComplianceScore() {
        HIPAAPrivacyRuleService service = new HIPAAPrivacyRuleService();

        Test.startTest();
        Decimal score = service.getComplianceScore();
        Test.stopTest();

        Assert.isTrue(score >= 0 && score <= 100, 'Score should be between 0 and 100');
    }

    @IsTest
    static void testIdentifyPHIObjects() {
        Test.startTest();
        List<HIPAAPrivacyRuleService.PHIObjectInfo> phiObjects =
            HIPAAPrivacyRuleService.identifyPHIObjects();
        Test.stopTest();

        Assert.areNotEqual(null, phiObjects, 'PHI objects list should not be null');
        Assert.isTrue(phiObjects.size() > 0, 'Should identify at least one PHI object');
    }

    @IsTest
    static void testEvaluateMinimumNecessary() {
        Test.startTest();
        HIPAAPrivacyRuleService.MinimumNecessaryResult result =
            HIPAAPrivacyRuleService.evaluateMinimumNecessary();
        Test.stopTest();

        Assert.areNotEqual(null, result, 'Result should not be null');
        Assert.areNotEqual(null, result.evaluationDate, 'Evaluation date should be set');
        Assert.areNotEqual(null, result.profileAssessments, 'Profile assessments should not be null');
    }

    @IsTest
    static void testGetPHIAccessAudit() {
        Test.startTest();
        List<HIPAAPrivacyRuleService.PHIAccessRecord> accessRecords =
            HIPAAPrivacyRuleService.getPHIAccessAudit(30);
        Test.stopTest();

        Assert.areNotEqual(null, accessRecords, 'Access records should not be null');
    }

    @IsTest
    static void testGetPHIAccessAuditDefaultDays() {
        Test.startTest();
        List<HIPAAPrivacyRuleService.PHIAccessRecord> accessRecords =
            HIPAAPrivacyRuleService.getPHIAccessAudit(null);
        Test.stopTest();

        Assert.areNotEqual(null, accessRecords, 'Access records should not be null with null days');
    }

    @IsTest
    static void testGeneratePHIDisclosureLog() {
        Test.startTest();
        Id docId = HIPAAPrivacyRuleService.generatePHIDisclosureLog(
            Date.today().addDays(-30),
            Date.today()
        );
        Test.stopTest();

        Assert.areNotEqual(null, docId, 'Document ID should not be null');

        ContentDocument doc = [SELECT Title FROM ContentDocument WHERE Id = :docId];
        Assert.isTrue(doc.Title.contains('PHI_Disclosure_Log'), 'Title should contain PHI_Disclosure_Log');
    }

    @IsTest
    static void testGeneratePHIDisclosureLogDefaultDates() {
        Test.startTest();
        Id docId = HIPAAPrivacyRuleService.generatePHIDisclosureLog(null, null);
        Test.stopTest();

        Assert.areNotEqual(null, docId, 'Document ID should not be null with default dates');
    }

    @IsTest
    static void testBulkProcessing() {
        // Create bulk contacts
        List<Contact> bulkContacts = new List<Contact>();
        for (Integer i = 0; i < 200; i++) {
            bulkContacts.add(new Contact(
                FirstName = 'Bulk',
                LastName = 'Patient ' + i,
                Email = 'bulk' + i + '@test.com'
            ));
        }
        insert bulkContacts;

        Test.startTest();
        List<HIPAAPrivacyRuleService.PHIObjectInfo> phiObjects =
            HIPAAPrivacyRuleService.identifyPHIObjects();
        Test.stopTest();

        Assert.areNotEqual(null, phiObjects, 'Should handle bulk data');
    }

    @IsTest
    static void testPrivacyRuleEvaluation() {
        HIPAAPrivacyRuleService service = new HIPAAPrivacyRuleService();

        Test.startTest();
        // Test full evaluation through getViolations
        List<ComplianceServiceBase.Violation> violations = service.getViolations();

        // Test compliance score calculation
        Decimal score = service.getComplianceScore();
        Test.stopTest();

        Assert.areNotEqual(null, violations, 'Violations should not be null');
        Assert.isTrue(score >= 0, 'Score should be non-negative');
    }
}
