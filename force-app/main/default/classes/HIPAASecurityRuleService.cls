/**
 * HIPAASecurityRuleService
 *
 * Technical safeguards per HIPAA Security Rule (45 CFR 164.312).
 * Evaluates access controls, audit controls, integrity, and transmission security.
 *
 * @author Elaro
 * @version 1.0
 * @since v3.1.0 (Spring '26)
 * @group Compliance Framework
 */
public with sharing class HIPAASecurityRuleService extends ComplianceServiceBase {

    /**
     * Get framework name
     */
    public override String getFrameworkName() {
        return 'HIPAA';
    }

    /**
     * Get framework score multiplier
     */
    protected override Decimal getFrameworkMultiplier() {
        return 0.95;
    }

    /**
     * Evaluate HIPAA Security Rule controls
     */
    protected override List<Violation> evaluateControls() {
        List<Violation> violations = new List<Violation>();
        violations.addAll(checkAccessControls().violations);
        violations.addAll(checkAuditControls().violations);
        violations.addAll(checkIntegrityControls().violations);
        return violations;
    }

    /**
     * Evaluate all technical safeguards
     */
    @AuraEnabled(cacheable=false)
    public static TechnicalSafeguardResult evaluateTechnicalSafeguards() {
        try {
            HIPAASecurityRuleService service = new HIPAASecurityRuleService();
            TechnicalSafeguardResult result = new TechnicalSafeguardResult();
            result.evaluationDate = DateTime.now();

            result.accessControlResult = service.checkAccessControls();
            result.auditControlResult = service.checkAuditControls();
            result.integrityControlResult = service.checkIntegrityControls();
            result.transmissionResult = service.checkTransmissionSecurity();

            // Calculate overall score
            Decimal totalScore = result.accessControlResult.score +
                                result.auditControlResult.score +
                                result.integrityControlResult.score +
                                result.transmissionResult.score;
            result.overallScore = (totalScore / 4).setScale(2);
            result.overallCompliant = result.overallScore >= 80;

            // Collect all gaps
            result.gaps = new List<String>();
            result.gaps.addAll(result.accessControlResult.gaps);
            result.gaps.addAll(result.auditControlResult.gaps);
            result.gaps.addAll(result.integrityControlResult.gaps);
            result.gaps.addAll(result.transmissionResult.gaps);

            return result;
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            ElaroLogger.error('HIPAASecurityRuleService.evaluateTechnicalSafeguards', e.getMessage(), e.getStackTraceString());
            throw new AuraHandledException('Unable to complete the operation. Please verify you have the required permissions and try again.');
        }
    }

    /**
     * Check access controls - §164.312(a)(1)
     */
    @AuraEnabled(cacheable=false)
    public static AccessControlResult checkAccessControls() {
        try {
            HIPAASecurityRuleService service = new HIPAASecurityRuleService();
            return service.evaluateAccessControls();
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            ElaroLogger.error('HIPAASecurityRuleService.checkAccessControls', e.getMessage(), e.getStackTraceString());
            throw new AuraHandledException('Unable to complete the operation. Please verify you have the required permissions and try again.');
        }
    }

    /**
     * Check audit controls - §164.312(b)
     */
    @AuraEnabled(cacheable=false)
    public static AuditControlResult checkAuditControls() {
        try {
            HIPAASecurityRuleService service = new HIPAASecurityRuleService();
            return service.evaluateAuditControls();
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            ElaroLogger.error('HIPAASecurityRuleService.checkAuditControls', e.getMessage(), e.getStackTraceString());
            throw new AuraHandledException('Unable to complete the operation. Please verify you have the required permissions and try again.');
        }
    }

    /**
     * Check integrity controls - §164.312(c)(1)
     */
    @AuraEnabled(cacheable=false)
    public static IntegrityControlResult checkIntegrityControls() {
        try {
            HIPAASecurityRuleService service = new HIPAASecurityRuleService();
            return service.evaluateIntegrityControls();
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            ElaroLogger.error('HIPAASecurityRuleService.checkIntegrityControls', e.getMessage(), e.getStackTraceString());
            throw new AuraHandledException('Unable to complete the operation. Please verify you have the required permissions and try again.');
        }
    }

    /**
     * Check transmission security - §164.312(e)(1)
     */
    @AuraEnabled(cacheable=false)
    public static TransmissionResult checkTransmissionSecurity() {
        try {
            HIPAASecurityRuleService service = new HIPAASecurityRuleService();
            return service.evaluateTransmissionSecurity();
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            ElaroLogger.error('HIPAASecurityRuleService.checkTransmissionSecurity', e.getMessage(), e.getStackTraceString());
            throw new AuraHandledException('Unable to complete the operation. Please verify you have the required permissions and try again.');
        }
    }

    /**
     * Get encryption status for PHI objects
     */
    @AuraEnabled(cacheable=false)
    public static Map<String, EncryptionInfo> getEncryptionStatus() {
        try {
            Map<String, EncryptionInfo> status = new Map<String, EncryptionInfo>();

            Set<String> phiObjects = new Set<String>{'Contact', 'Lead', 'Account', 'Case'};

            for (String objectName : phiObjects) {
                EncryptionInfo info = new EncryptionInfo();
                info.objectName = objectName;
                info.encryptedFields = new List<String>();
                info.unencryptedPHIFields = new List<String>();

                // Check for encrypted fields using Shield
                try {
                    Schema.SObjectType objType = Schema.getGlobalDescribe().get(objectName);
                    if (objType != null) {
                        Map<String, Schema.SObjectField> fields = objType.getDescribe().fields.getMap();
                        for (String fieldName : fields.keySet()) {
                            Schema.DescribeFieldResult fieldDesc = fields.get(fieldName).getDescribe();
                            if (fieldDesc.isEncrypted()) {
                                info.encryptedFields.add(fieldName);
                            } else if (isPHIFieldName(fieldName)) {
                                info.unencryptedPHIFields.add(fieldName);
                            }
                        }
                    }
                } catch (Exception e) {
                    ElaroLogger.error( 'Error checking encryption: ' + e.getMessage());
                }

                info.shieldEnabled = !info.encryptedFields.isEmpty();
                info.compliant = info.unencryptedPHIFields.isEmpty();

                status.put(objectName, info);
            }

            return status;
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            ElaroLogger.error('HIPAASecurityRuleService.getEncryptionStatus', e.getMessage(), e.getStackTraceString());
            throw new AuraHandledException('Unable to complete the operation. Please verify you have the required permissions and try again.');
        }
    }

    // ========== Private Evaluation Methods ==========

    private AccessControlResult evaluateAccessControls() {
        AccessControlResult result = new AccessControlResult();
        result.violations = new List<Violation>();
        result.gaps = new List<String>();
        result.score = 100;

        // §164.312(a)(2)(i) - Unique User Identification
        // Salesforce enforces globally unique usernames, but a shared-credential
        // risk is only inferable from login telemetry, which we evaluate below.
        result.uniqueUserIdStatus = checkUniqueUserIds();
        if (result.uniqueUserIdStatus == ElaroConstants.STATUS_NON_COMPLIANT) {
            result.uniqueUserIdCompliant = false;
            result.gaps.add('Shared accounts detected');
            result.score -= 15;
            result.violations.add(new Violation(
                'Shared User Accounts',
                'Users may be sharing credentials (detected by login patterns)',
                'HIGH',
                'HIPAA-164.312(a)(2)(i)',
                'Ensure each user has unique credentials',
                7.5
            ));
        } else if (result.uniqueUserIdStatus == ElaroConstants.STATUS_NOT_EVALUATED) {
            // Not verifiable in this context — surface honestly, do not score.
            result.uniqueUserIdCompliant = false;
            result.gaps.add('Unique user identification could not be automatically '
                + 'verified (no login history available to assess shared-credential risk)');
        } else {
            result.uniqueUserIdCompliant = true;
        }

        // §164.312(a)(2)(iii) - Automatic Logoff
        // Session timeout lives in org Session Settings, which plain Apex cannot read.
        // Mark NOT_EVALUATED instead of assuming a pass.
        result.autoLogoffStatus = checkAutoLogoff();
        result.autoLogoffConfigured = false;
        result.gaps.add('Automatic logoff (session timeout) could not be automatically '
            + 'verified from Apex; review Session Settings or provide Security Health '
            + 'Check evidence');

        // §164.312(a)(2)(iv) - Encryption
        // Real check via Schema.DescribeFieldResult.isEncrypted() over PHI fields.
        result.encryptionStatus = checkEncryption();
        result.encryptionEnabled = (result.encryptionStatus == ElaroConstants.STATUS_COMPLIANT);
        if (result.encryptionStatus == ElaroConstants.STATUS_NON_COMPLIANT) {
            result.gaps.add('Shield Platform Encryption not enabled on detected PHI fields');
            result.score -= 20;
            result.violations.add(new Violation(
                'Missing Encryption',
                'PHI data is not encrypted at rest',
                'CRITICAL',
                'HIPAA-164.312(a)(2)(iv)',
                'Enable Shield Platform Encryption for PHI fields',
                9.0
            ));
        } else if (result.encryptionStatus == ElaroConstants.STATUS_NOT_EVALUATED) {
            result.gaps.add('Encryption status could not be evaluated (no PHI fields '
                + 'detected on the inspected objects)');
        }

        result.compliant = result.score >= 80;
        return result;
    }

    private AuditControlResult evaluateAuditControls() {
        AuditControlResult result = new AuditControlResult();
        result.violations = new List<Violation>();
        result.gaps = new List<String>();
        result.score = 100;

        // Check audit trail coverage
        result.auditTrailEnabled = checkAuditTrailEnabled();
        if (!result.auditTrailEnabled) {
            result.gaps.add('Field History Tracking not enabled on PHI objects');
            result.score -= 25;
            result.violations.add(new Violation(
                'Incomplete Audit Trail',
                'Field History Tracking not enabled on all PHI objects',
                'HIGH',
                'HIPAA-164.312(b)',
                'Enable Field History Tracking on PHI fields',
                8.0
            ));
        }

        // Check retention period (HIPAA requires 6 years)
        result.retentionPeriodDays = 2190; // 6 years
        // HIPAA 6-year retention depends on Field Audit Trail configuration, which is
        // not introspectable from Apex. Do NOT assert compliance — mark NOT_EVALUATED.
        result.retentionStatus = ElaroConstants.STATUS_NOT_EVALUATED;
        result.retentionCompliant = false;
        result.gaps.add('Audit log retention (6-year HIPAA requirement) could not be '
            + 'automatically verified; confirm Field Audit Trail configuration manually');

        result.compliant = result.score >= 80;
        return result;
    }

    private IntegrityControlResult evaluateIntegrityControls() {
        IntegrityControlResult result = new IntegrityControlResult();
        result.violations = new List<Violation>();
        result.gaps = new List<String>();
        result.score = 100;

        // Check for validation rules on PHI objects via EntityDefinition.
        result.validationRulesStatus = checkValidationRules();
        result.validationRulesEnabled =
            (result.validationRulesStatus == ElaroConstants.STATUS_COMPLIANT);
        if (result.validationRulesStatus == ElaroConstants.STATUS_NON_COMPLIANT) {
            result.gaps.add('No active validation rules detected on PHI objects');
        } else if (result.validationRulesStatus == ElaroConstants.STATUS_NOT_EVALUATED) {
            result.gaps.add('Validation rule coverage could not be evaluated for PHI objects');
        }

        // Check bulk delete restrictions — not reliably introspectable from Apex.
        result.bulkDeleteStatus = checkBulkDeleteRestrictions();
        result.bulkDeleteRestricted = false;
        result.gaps.add('Bulk/mass-delete restrictions could not be automatically '
            + 'verified from Apex; review profile and permission set "Mass Delete" '
            + 'and object delete permissions manually');

        result.compliant = result.score >= 80;
        return result;
    }

    private TransmissionResult evaluateTransmissionSecurity() {
        TransmissionResult result = new TransmissionResult();
        result.violations = new List<Violation>();
        result.gaps = new List<String>();
        result.score = 100;

        // Salesforce enforces TLS 1.2+ for all inbound/outbound HTTPS traffic at the
        // platform level — this transport guarantee is attestable.
        result.tlsVersion = 'TLS 1.2+';
        result.tlsCompliant = true;

        // The org-specific minimum TLS version and end-to-end ePHI transmission posture
        // (e.g. session-level TLS enforcement) are not readable from Apex. Report the
        // API/transmission configuration as NOT_EVALUATED rather than asserting a pass.
        result.apiSecurityStatus = ElaroConstants.STATUS_NOT_EVALUATED;
        result.apiSecurityEnabled = false;
        result.gaps.add('API/transmission security configuration (minimum TLS version, '
            + 'session-level TLS enforcement) could not be automatically verified; '
            + 'confirm via Security Health Check');

        result.compliant = result.score >= 80;
        return result;
    }

    // ========== Private Helper Methods ==========

    /**
     * Assesses unique-user-identification risk (§164.312(a)(2)(i)).
     *
     * Salesforce enforces globally unique usernames, so the real risk is shared
     * credentials. We infer this from LoginHistory: a single user logging in from many
     * distinct source IPs in a short window is a credential-sharing signal. When there
     * is no login history to analyze, we cannot make a verdict and return NOT_EVALUATED.
     *
     * @return ElaroConstants status (COMPLIANT, NON_COMPLIANT, or NOT_EVALUATED)
     */
    private String checkUniqueUserIds() {
        DateTime last30Days = DateTime.now().addDays(-30);

        List<AggregateResult> ipSpread = [
            SELECT UserId, COUNT_DISTINCT(SourceIp) ipCount
            FROM LoginHistory
            WHERE LoginTime >= :last30Days
            WITH USER_MODE
            GROUP BY UserId
            HAVING COUNT_DISTINCT(SourceIp) > 5
            LIMIT 50
        ];

        Integer totalLogins = [
            SELECT COUNT()
            FROM LoginHistory
            WHERE LoginTime >= :last30Days
            WITH USER_MODE
            LIMIT 1
        ];

        if (totalLogins == 0) {
            // No telemetry to evaluate shared-credential risk.
            return ElaroConstants.STATUS_NOT_EVALUATED;
        }

        // Users authenticating from an unusually high number of distinct IPs signal
        // possible credential sharing.
        return ipSpread.isEmpty()
            ? ElaroConstants.STATUS_COMPLIANT
            : ElaroConstants.STATUS_NON_COMPLIANT;
    }

    /**
     * Automatic-logoff / session-timeout configuration (§164.312(a)(2)(iii)) lives in
     * org Session Settings and is not readable from plain Apex.
     *
     * @return ElaroConstants.STATUS_NOT_EVALUATED — never assume a pass
     */
    private String checkAutoLogoff() {
        return ElaroConstants.STATUS_NOT_EVALUATED;
    }

    /**
     * Encryption-at-rest check (§164.312(a)(2)(iv)) using
     * Schema.DescribeFieldResult.isEncrypted() over detected PHI fields on PHI objects.
     *
     * @return COMPLIANT when every detected PHI field is encrypted, NON_COMPLIANT when
     *         at least one detected PHI field is unencrypted, NOT_EVALUATED when no PHI
     *         fields could be detected to evaluate
     */
    private String checkEncryption() {
        Set<String> phiObjects = new Set<String>{ 'Contact', 'Lead', 'Account', 'Case' };
        Integer phiFieldsFound = 0;
        Integer unencryptedPhiFields = 0;

        for (String objectName : phiObjects) {
            Schema.SObjectType objType = Schema.getGlobalDescribe().get(objectName);
            if (objType == null) {
                continue;
            }
            Map<String, Schema.SObjectField> fields = objType.getDescribe().fields.getMap();
            for (String fieldName : fields.keySet()) {
                if (!isPHIFieldName(fieldName)) {
                    continue;
                }
                phiFieldsFound++;
                if (!fields.get(fieldName).getDescribe().isEncrypted()) {
                    unencryptedPhiFields++;
                }
            }
        }

        if (phiFieldsFound == 0) {
            // Nothing to assess — do not assert encrypted or unencrypted.
            return ElaroConstants.STATUS_NOT_EVALUATED;
        }
        return unencryptedPhiFields == 0
            ? ElaroConstants.STATUS_COMPLIANT
            : ElaroConstants.STATUS_NON_COMPLIANT;
    }

    private Boolean checkAuditTrailEnabled() {
        // Check Field History Tracking on PHI objects
        Set<String> phiObjects = new Set<String>{'Contact', 'Lead'};
        for (String objectName : phiObjects) {
            try {
                Schema.SObjectType objType = Schema.getGlobalDescribe().get(objectName);
                if (objType != null) {
                    Map<String, Schema.SObjectField> fields = objType.getDescribe().fields.getMap();
                    Boolean hasTracking = false;
                    for (Schema.SObjectField field : fields.values()) {
                        if (field.getDescribe().isHistoryTracked() != null && field.getDescribe().isHistoryTracked()) {
                            hasTracking = true;
                            break;
                        }
                    }
                    if (!hasTracking) {
                        return false;
                    }
                }
            } catch (Exception e) {
                return false;
            }
        }
        return true;
    }

    /**
     * Bulk/mass-delete restriction check (§164.312(c)(1)).
     *
     * Whether mass delete is restricted depends on a combination of profile-level
     * "Mass Delete" permission, object delete permissions, and UI restrictions that
     * cannot be reliably introspected from Apex.
     *
     * @return ElaroConstants.STATUS_NOT_EVALUATED — never assume a pass
     */
    private String checkBulkDeleteRestrictions() {
        return ElaroConstants.STATUS_NOT_EVALUATED;
    }

    /**
     * Validation-rule coverage check for PHI objects (§164.312(c)(1) integrity).
     *
     * Queries EntityDefinition for active validation rules on the PHI objects. Real,
     * verifiable evidence of integrity controls.
     *
     * @return COMPLIANT when at least one PHI object has active validation rules,
     *         NON_COMPLIANT when none do, NOT_EVALUATED if the metadata cannot be read
     */
    private String checkValidationRules() {
        Set<String> phiObjects = new Set<String>{ 'Contact', 'Lead', 'Account', 'Case' };
        try {
            List<EntityDefinition> entities = [
                SELECT QualifiedApiName,
                    (SELECT Id FROM ValidationRules WHERE Active = true)
                FROM EntityDefinition
                WHERE QualifiedApiName IN :phiObjects
                WITH USER_MODE
                LIMIT 50
            ];

            if (entities.isEmpty()) {
                return ElaroConstants.STATUS_NOT_EVALUATED;
            }

            for (EntityDefinition entity : entities) {
                List<ValidationRule> rules = entity.ValidationRules;
                if (rules != null && !rules.isEmpty()) {
                    return ElaroConstants.STATUS_COMPLIANT;
                }
            }
            return ElaroConstants.STATUS_NON_COMPLIANT;
        } catch (Exception e) {
            // EntityDefinition child-relationship querying may be unavailable in some
            // contexts — report honestly rather than fabricating a verdict.
            ElaroLogger.error('HIPAASecurityRuleService.checkValidationRules',
                e.getMessage(), e.getStackTraceString());
            return ElaroConstants.STATUS_NOT_EVALUATED;
        }
    }

    private static Boolean isPHIFieldName(String fieldName) {
        Set<String> phiPatterns = new Set<String>{'SSN', 'DOB', 'BIRTH', 'MEDICAL', 'HEALTH'};
        String upper = fieldName.toUpperCase();
        for (String pattern : phiPatterns) {
            if (upper.contains(pattern)) {
                return true;
            }
        }
        return false;
    }

    // ========== Inner Classes ==========

    public class TechnicalSafeguardResult {
        @AuraEnabled public DateTime evaluationDate;
        @AuraEnabled public AccessControlResult accessControlResult;
        @AuraEnabled public AuditControlResult auditControlResult;
        @AuraEnabled public IntegrityControlResult integrityControlResult;
        @AuraEnabled public TransmissionResult transmissionResult;
        @AuraEnabled public Decimal overallScore;
        @AuraEnabled public Boolean overallCompliant;
        @AuraEnabled public List<String> gaps;
    }

    public class AccessControlResult {
        @AuraEnabled public Boolean uniqueUserIdCompliant;
        // Honest evaluation status (ElaroConstants.STATUS_*) for controls that may be
        // NOT_EVALUATED rather than a true/false verdict.
        @AuraEnabled public String uniqueUserIdStatus;
        @AuraEnabled public Boolean autoLogoffConfigured;
        @AuraEnabled public String autoLogoffStatus;
        @AuraEnabled public Boolean encryptionEnabled;
        @AuraEnabled public String encryptionStatus;
        @AuraEnabled public Boolean compliant;
        @AuraEnabled public Decimal score;
        @AuraEnabled public List<String> gaps;
        @AuraEnabled public List<Violation> violations;
    }

    public class AuditControlResult {
        @AuraEnabled public Boolean auditTrailEnabled;
        @AuraEnabled public Integer retentionPeriodDays;
        @AuraEnabled public Boolean retentionCompliant;
        @AuraEnabled public String retentionStatus;
        @AuraEnabled public Boolean compliant;
        @AuraEnabled public Decimal score;
        @AuraEnabled public List<String> gaps;
        @AuraEnabled public List<Violation> violations;
    }

    public class IntegrityControlResult {
        @AuraEnabled public Boolean validationRulesEnabled;
        @AuraEnabled public String validationRulesStatus;
        @AuraEnabled public Boolean bulkDeleteRestricted;
        @AuraEnabled public String bulkDeleteStatus;
        @AuraEnabled public Boolean compliant;
        @AuraEnabled public Decimal score;
        @AuraEnabled public List<String> gaps;
        @AuraEnabled public List<Violation> violations;
    }

    public class TransmissionResult {
        @AuraEnabled public String tlsVersion;
        @AuraEnabled public Boolean tlsCompliant;
        @AuraEnabled public Boolean apiSecurityEnabled;
        @AuraEnabled public String apiSecurityStatus;
        @AuraEnabled public Boolean compliant;
        @AuraEnabled public Decimal score;
        @AuraEnabled public List<String> gaps;
        @AuraEnabled public List<Violation> violations;
    }

    public class EncryptionInfo {
        @AuraEnabled public String objectName;
        @AuraEnabled public Boolean shieldEnabled;
        @AuraEnabled public List<String> encryptedFields;
        @AuraEnabled public List<String> unencryptedPHIFields;
        @AuraEnabled public Boolean compliant;
    }
}
