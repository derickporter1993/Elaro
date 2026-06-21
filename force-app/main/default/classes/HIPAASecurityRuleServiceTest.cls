/**
 * HIPAASecurityRuleServiceTest
 *
 * Test class for HIPAASecurityRuleService
 *
 * @author Elaro
 * @version 1.0
 */
@IsTest(testFor=HIPAASecurityRuleService.class)
public class HIPAASecurityRuleServiceTest {

    @TestSetup
    static void setup() {
        // Create test contacts (PHI objects)
        List<Contact> contacts = new List<Contact>();
        for (Integer i = 0; i < 10; i++) {
            contacts.add(new Contact(
                FirstName = 'Test',
                LastName = 'Patient ' + i,
                Email = 'patient' + i + '@test.com'
            ));
        }
        insert contacts;
    }

    @isTest
    static void testGetFrameworkName() {
        HIPAASecurityRuleService service = new HIPAASecurityRuleService();

        Test.startTest();
        String frameworkName = service.getFrameworkName();
        Test.stopTest();

        Assert.areEqual('HIPAA', frameworkName, 'Framework name should be HIPAA');
    }

    @isTest
    static void testGetViolations() {
        HIPAASecurityRuleService service = new HIPAASecurityRuleService();

        Test.startTest();
        List<ComplianceServiceBase.Violation> violations = service.getViolations();
        Test.stopTest();

        Assert.areNotEqual(null, violations, 'Violations should not be null');
    }

    @isTest
    static void testGetComplianceScore() {
        HIPAASecurityRuleService service = new HIPAASecurityRuleService();

        Test.startTest();
        Decimal score = service.getComplianceScore();
        Test.stopTest();

        Assert.isTrue(score >= 0 && score <= 100, 'Score should be between 0 and 100');
    }

    @isTest
    static void testEvaluateTechnicalSafeguards() {
        Test.startTest();
        HIPAASecurityRuleService.TechnicalSafeguardResult result =
            HIPAASecurityRuleService.evaluateTechnicalSafeguards();
        Test.stopTest();

        Assert.areNotEqual(null, result, 'Result should not be null');
        Assert.areNotEqual(null, result.evaluationDate, 'Evaluation date should be set');
        Assert.areNotEqual(null, result.accessControlResult, 'Access control result should not be null');
        Assert.areNotEqual(null, result.auditControlResult, 'Audit control result should not be null');
        Assert.areNotEqual(null, result.integrityControlResult, 'Integrity control result should not be null');
        Assert.areNotEqual(null, result.transmissionResult, 'Transmission result should not be null');
    }

    @isTest
    static void testCheckAccessControls() {
        Test.startTest();
        HIPAASecurityRuleService.AccessControlResult result =
            HIPAASecurityRuleService.checkAccessControls();
        Test.stopTest();

        Assert.areNotEqual(null, result, 'Result should not be null');
        Assert.areNotEqual(null, result.score, 'Score should be set');
        Assert.areNotEqual(null, result.gaps, 'Gaps should not be null');
        Assert.areNotEqual(null, result.violations, 'Violations should not be null');

        // Automatic logoff (session timeout) is not readable from Apex — it must be
        // reported as NOT_EVALUATED, never fabricated as a pass.
        Assert.areEqual(ElaroConstants.STATUS_NOT_EVALUATED, result.autoLogoffStatus,
            'Auto logoff must be NOT_EVALUATED (session settings are not Apex-readable)');
        Assert.isFalse(result.autoLogoffConfigured,
            'Auto logoff must not be asserted as configured when it cannot be verified');

        // Encryption status must be a real evaluated verdict, not a hardcoded value.
        Assert.isTrue(
            result.encryptionStatus == ElaroConstants.STATUS_COMPLIANT
                || result.encryptionStatus == ElaroConstants.STATUS_NON_COMPLIANT
                || result.encryptionStatus == ElaroConstants.STATUS_NOT_EVALUATED,
            'Encryption status should be a valid evaluation status, got: '
                + result.encryptionStatus);

        // Unique-user-identification status must be a real evaluated verdict.
        Assert.isTrue(
            result.uniqueUserIdStatus == ElaroConstants.STATUS_COMPLIANT
                || result.uniqueUserIdStatus == ElaroConstants.STATUS_NON_COMPLIANT
                || result.uniqueUserIdStatus == ElaroConstants.STATUS_NOT_EVALUATED,
            'Unique user ID status should be a valid evaluation status, got: '
                + result.uniqueUserIdStatus);
    }

    @isTest
    static void testCheckAuditControls() {
        Test.startTest();
        HIPAASecurityRuleService.AuditControlResult result =
            HIPAASecurityRuleService.checkAuditControls();
        Test.stopTest();

        Assert.areNotEqual(null, result, 'Result should not be null');
        Assert.areNotEqual(null, result.score, 'Score should be set');
        Assert.areNotEqual(null, result.retentionPeriodDays, 'Retention period should be set');

        // 6-year retention depends on Field Audit Trail config (not Apex-readable):
        // it must be NOT_EVALUATED, not a fabricated pass.
        Assert.areEqual(ElaroConstants.STATUS_NOT_EVALUATED, result.retentionStatus,
            'Retention must be NOT_EVALUATED (Field Audit Trail config is not Apex-readable)');
        Assert.isFalse(result.retentionCompliant,
            'Retention must not be asserted compliant when it cannot be verified');
    }

    @isTest
    static void testCheckIntegrityControls() {
        Test.startTest();
        HIPAASecurityRuleService.IntegrityControlResult result =
            HIPAASecurityRuleService.checkIntegrityControls();
        Test.stopTest();

        Assert.areNotEqual(null, result, 'Result should not be null');
        Assert.areNotEqual(null, result.score, 'Score should be set');

        // Bulk-delete restriction is not introspectable from Apex — NOT_EVALUATED only.
        Assert.areEqual(ElaroConstants.STATUS_NOT_EVALUATED, result.bulkDeleteStatus,
            'Bulk delete restriction must be NOT_EVALUATED (not introspectable from Apex)');
        Assert.isFalse(result.bulkDeleteRestricted,
            'Bulk delete must not be asserted restricted when it cannot be verified');

        // Validation rule coverage is a real, evaluated check via EntityDefinition.
        Assert.isTrue(
            result.validationRulesStatus == ElaroConstants.STATUS_COMPLIANT
                || result.validationRulesStatus == ElaroConstants.STATUS_NON_COMPLIANT
                || result.validationRulesStatus == ElaroConstants.STATUS_NOT_EVALUATED,
            'Validation rules status should be a valid evaluation status, got: '
                + result.validationRulesStatus);
    }

    @isTest
    static void testCheckTransmissionSecurity() {
        Test.startTest();
        HIPAASecurityRuleService.TransmissionResult result =
            HIPAASecurityRuleService.checkTransmissionSecurity();
        Test.stopTest();

        Assert.areNotEqual(null, result, 'Result should not be null');
        Assert.areEqual('TLS 1.2+', result.tlsVersion, 'TLS version should be TLS 1.2+');
        Assert.areEqual(true, result.tlsCompliant, 'Should be TLS compliant');

        // Org-specific API/transmission posture is not Apex-readable — NOT_EVALUATED.
        Assert.areEqual(ElaroConstants.STATUS_NOT_EVALUATED, result.apiSecurityStatus,
            'API security must be NOT_EVALUATED (org TLS config is not Apex-readable)');
        Assert.isFalse(result.apiSecurityEnabled,
            'API security must not be asserted enabled when it cannot be verified');
    }

    @isTest
    static void testGetEncryptionStatus() {
        Test.startTest();
        Map<String, HIPAASecurityRuleService.EncryptionInfo> status =
            HIPAASecurityRuleService.getEncryptionStatus();
        Test.stopTest();

        Assert.areNotEqual(null, status, 'Status should not be null');
        Assert.isTrue(status.containsKey('Contact'), 'Should include Contact object');
        Assert.isTrue(status.containsKey('Lead'), 'Should include Lead object');
        Assert.isTrue(status.containsKey('Account'), 'Should include Account object');
        Assert.isTrue(status.containsKey('Case'), 'Should include Case object');
    }

    @isTest
    static void testEncryptionInfoDetails() {
        Test.startTest();
        Map<String, HIPAASecurityRuleService.EncryptionInfo> status =
            HIPAASecurityRuleService.getEncryptionStatus();
        Test.stopTest();

        HIPAASecurityRuleService.EncryptionInfo contactInfo = status.get('Contact');
        Assert.areNotEqual(null, contactInfo, 'Contact encryption info should not be null');
        Assert.areEqual('Contact', contactInfo.objectName, 'Object name should be Contact');
        Assert.areNotEqual(null, contactInfo.encryptedFields, 'Encrypted fields list should not be null');
        Assert.areNotEqual(null, contactInfo.unencryptedPHIFields, 'Unencrypted PHI fields list should not be null');
    }

    @isTest
    static void testOverallComplianceCalculation() {
        Test.startTest();
        HIPAASecurityRuleService.TechnicalSafeguardResult result =
            HIPAASecurityRuleService.evaluateTechnicalSafeguards();
        Test.stopTest();

        Assert.areNotEqual(null, result.overallScore, 'Overall score should be set');
        Assert.isTrue(result.overallScore >= 0 && result.overallScore <= 100,
            'Overall score should be between 0 and 100');
        Assert.areNotEqual(null, result.overallCompliant, 'Overall compliant flag should be set');
        Assert.areNotEqual(null, result.gaps, 'Gaps list should not be null');
    }

    @isTest
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
        HIPAASecurityRuleService.TechnicalSafeguardResult result =
            HIPAASecurityRuleService.evaluateTechnicalSafeguards();
        Test.stopTest();

        Assert.areNotEqual(null, result, 'Should handle bulk data');
    }
}
