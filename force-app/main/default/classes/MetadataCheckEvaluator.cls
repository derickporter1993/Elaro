/**
 * Evaluation strategy for METADATA_CHECK type compliance rules.
 * Checks for the existence or configuration of Salesforce metadata
 * (Custom Objects, Fields, Permission Sets, etc.) using describe calls.
 *
 * @author Elaro Team
 * @since v3.1.0 (Spring '26)
 * @group Rule Engine
 * @see ComplianceRuleEvaluator
 * @see RuleResult
 */
public inherited sharing class MetadataCheckEvaluator {

    private static final String CHECK_OBJECT_EXISTS = 'OBJECT_EXISTS';
    private static final String CHECK_FIELD_ENCRYPTED = 'FIELD_ENCRYPTED';
    private static final String CHECK_FLS_ENFORCED = 'FLS_ENFORCED';
    private static final String CHECK_SHARING_ENABLED = 'SHARING_ENABLED';

    /**
     * Evaluates a metadata-based compliance rule. The Evaluation_Query__c field
     * contains a JSON configuration specifying the check type and target.
     *
     * @param rule The compliance rule with metadata check configuration
     * @return RuleResult indicating pass/fail
     */
    public static RuleResult evaluate(Compliance_Rule__mdt rule) {
        Long startTime = System.currentTimeMillis();

        if (String.isBlank(rule.Evaluation_Query__c)) {
            return RuleResult.error(rule, 'Metadata check configuration is blank');
        }

        try {
            Map<String, Object> config = (Map<String, Object>)
                JSON.deserializeUntyped(rule.Evaluation_Query__c);

            String checkType = (String) config.get('checkType');
            String target = (String) config.get('target');
            Long elapsed = System.currentTimeMillis() - startTime;

            if (String.isBlank(checkType) || String.isBlank(target)) {
                return RuleResult.error(rule, 'Missing checkType or target in configuration');
            }

            Boolean passed = executeCheck(checkType, target, config);
            elapsed = System.currentTimeMillis() - startTime;

            if (passed) {
                return RuleResult.pass(rule, elapsed);
            }

            String details = checkType + ' check failed for target: ' + target;
            return RuleResult.fail(rule, details, elapsed);
        } catch (JSONException je) {
            ElaroLogger.error('MetadataCheckEvaluator.evaluate',
                je.getMessage(), je.getStackTraceString());
            return RuleResult.error(rule, 'Invalid JSON configuration: ' + je.getMessage());
        } catch (Exception e) {
            ElaroLogger.error('MetadataCheckEvaluator.evaluate',
                e.getMessage(), e.getStackTraceString());
            return RuleResult.error(rule, e.getMessage());
        }
    }

    /**
     * Dispatches to the appropriate metadata check based on type.
     *
     * @param checkType The type of metadata check
     * @param target The target metadata element
     * @param config Additional configuration parameters
     * @return true if the check passes
     */
    @TestVisible
    private static Boolean executeCheck(String checkType, String target,
            Map<String, Object> config) {
        if (checkType == CHECK_OBJECT_EXISTS) {
            return checkObjectExists(target);
        } else if (checkType == CHECK_FIELD_ENCRYPTED) {
            return checkFieldEncrypted(target, (String) config.get('field'));
        } else if (checkType == CHECK_FLS_ENFORCED) {
            return checkFLSEnforced(target, (String) config.get('field'));
        } else if (checkType == CHECK_SHARING_ENABLED) {
            return checkSharingEnabled(target);
        }
        return false;
    }

    private static Boolean checkObjectExists(String objectName) {
        try {
            Schema.SObjectType objType = Schema.getGlobalDescribe().get(objectName);
            return objType != null;
        } catch (Exception e) {
            return false;
        }
    }

    private static Boolean checkFieldEncrypted(String objectName, String fieldName) {
        if (String.isBlank(fieldName)) {
            return false;
        }
        try {
            Schema.SObjectType objType = Schema.getGlobalDescribe().get(objectName);
            if (objType == null) {
                return false;
            }
            Schema.DescribeFieldResult fieldDesc = objType.getDescribe()
                .fields.getMap().get(fieldName)?.getDescribe();
            return fieldDesc?.isEncrypted() ?? false;
        } catch (Exception e) {
            return false;
        }
    }

    private static Boolean checkFLSEnforced(String objectName, String fieldName) {
        if (String.isBlank(fieldName)) {
            return false;
        }
        try {
            Schema.SObjectType objType = Schema.getGlobalDescribe().get(objectName);
            if (objType == null) {
                return false;
            }
            Schema.DescribeFieldResult fieldDesc = objType.getDescribe()
                .fields.getMap().get(fieldName)?.getDescribe();
            return fieldDesc?.isAccessible() ?? false;
        } catch (Exception e) {
            return false;
        }
    }

    private static Boolean checkSharingEnabled(String objectName) {
        try {
            Schema.SObjectType objType = Schema.getGlobalDescribe().get(objectName);
            if (objType == null) {
                return false;
            }
            Schema.DescribeSObjectResult objDescribe = objType.getDescribe();
            return objDescribe.isAccessible();
        } catch (Exception e) {
            return false;
        }
    }
}
