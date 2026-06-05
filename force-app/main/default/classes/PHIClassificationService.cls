/**
 * PHI Data Classification Engine (issue #212, HIPAA pack).
 *
 * Deterministically classifies the fields of an SObject as PHI, Sensitive, or Non-Sensitive
 * using field name patterns and field-type heuristics driven by PHI_Classification_Rule__mdt,
 * and persists the results to the canonical PHI_Field_Registry__c so other HIPAA-pack engines
 * (e.g., Workforce Access Risk #213) can consume them instead of hardcoding PHI logic.
 *
 * Version 1 is intentionally deterministic (no AI dependency). Classification is "most severe
 * wins": a field matching both a Sensitive and a PHI rule is recorded as PHI.
 *
 * Gated by the HIPAA vertical-pack kill switch ({@link FeatureFlags#isHipaaPackEnabled}).
 *
 * @author Elaro Team
 * @since v3.2.0 (Spring '26)
 * @group HIPAA Pack
 * @see PHI_Field_Registry__c
 * @see PHI_Classification_Rule__mdt
 * @see FeatureFlags
 */
public inherited sharing class PHIClassificationService {

    @TestVisible
    private static final String CLASS_PHI = 'PHI';
    @TestVisible
    private static final String CLASS_SENSITIVE = 'Sensitive';
    @TestVisible
    private static final String CLASS_NON_SENSITIVE = 'Non-Sensitive';

    private static final String METHOD_NAME_PATTERN = 'Name Pattern';
    private static final String METHOD_TYPE_HEURISTIC = 'Field Type Heuristic';

    private static final String MATCH_FIELD_TYPE = 'FieldType';

    /**
     * Summary of a classification run for a single object.
     */
    public class ClassificationResult {
        @AuraEnabled
        public String objectApiName;
        @AuraEnabled
        public Integer fieldsEvaluated = 0;
        @AuraEnabled
        public Integer phiCount = 0;
        @AuraEnabled
        public Integer sensitiveCount = 0;
        @AuraEnabled
        public Integer nonSensitiveCount = 0;
    }

    /**
     * Classifies every field of the given object and upserts the results to PHI_Field_Registry__c.
     *
     * @param objectApiName API name of the object to classify (e.g., 'Contact')
     * @return ClassificationResult summarizing the run
     * @throws AuraHandledException if the HIPAA pack is disabled, the object is unknown, or persistence fails
     */
    public ClassificationResult classifyObject(String objectApiName) {
        if (!FeatureFlags.isHipaaPackEnabled()) {
            throw new AuraHandledException('The HIPAA pack is disabled for this org.');
        }

        try {
            if (String.isBlank(objectApiName)) {
                throw new IllegalArgumentException('objectApiName is required.');
            }
            Schema.SObjectType sObjType = Schema.getGlobalDescribe().get(objectApiName);
            if (sObjType == null) {
                throw new IllegalArgumentException('Unknown object: ' + objectApiName);
            }

            List<PHI_Classification_Rule__mdt> rules = getActiveRules();
            Map<String, Schema.SObjectField> fieldMap = sObjType.getDescribe().fields.getMap();

            ClassificationResult result = new ClassificationResult();
            result.objectApiName = objectApiName;
            List<PHI_Field_Registry__c> toUpsert = new List<PHI_Field_Registry__c>();
            Datetime evaluatedAt = Datetime.now();

            for (String fieldName : fieldMap.keySet()) {
                Schema.DescribeFieldResult dfr = fieldMap.get(fieldName).getDescribe();
                FieldVerdict verdict = classifyField(dfr, rules);

                String key = objectApiName + '.' + dfr.getName();
                PHI_Field_Registry__c rec = new PHI_Field_Registry__c();
                rec.Field_Key__c = key;
                rec.Name = key.length() > 80 ? key.left(80) : key;
                rec.Object_API_Name__c = objectApiName;
                rec.Field_API_Name__c = dfr.getName();
                rec.Classification__c = verdict.classification;
                rec.Detection_Method__c = verdict.method;
                rec.Rationale__c = verdict.rationale;
                rec.Last_Evaluated__c = evaluatedAt;
                toUpsert.add(rec);

                result.fieldsEvaluated++;
                if (CLASS_PHI.equals(verdict.classification)) {
                    result.phiCount++;
                } else if (CLASS_SENSITIVE.equals(verdict.classification)) {
                    result.sensitiveCount++;
                } else {
                    result.nonSensitiveCount++;
                }
            }

            if (!toUpsert.isEmpty()) {
                upsert as user toUpsert Field_Key__c;
            }

            ElaroLogger.info(
                'PHIClassificationService.classifyObject',
                'Classified ' + result.fieldsEvaluated + ' fields on ' + objectApiName +
                ' (PHI=' + result.phiCount + ', Sensitive=' + result.sensitiveCount + ')'
            );
            return result;
        } catch (Exception e) {
            ElaroLogger.error('PHIClassificationService.classifyObject', e.getMessage(), e.getStackTraceString());
            throw new AuraHandledException('Unable to classify PHI fields for ' + objectApiName + '. ' + e.getMessage());
        }
    }

    /**
     * Returns the distinct PHI/Sensitive field API names already recorded for an object.
     * Used by downstream HIPAA-pack engines (e.g., Workforce Access Risk) to reason about
     * PHI exposure without re-scanning schema.
     *
     * @param objectApiName API name of the object
     * @return Set of field API names classified as PHI or Sensitive
     */
    public static Set<String> getPhiFieldNames(String objectApiName) {
        Set<String> result = new Set<String>();
        if (String.isBlank(objectApiName)) {
            return result;
        }
        for (PHI_Field_Registry__c rec : [
            SELECT Field_API_Name__c
            FROM PHI_Field_Registry__c
            WHERE Object_API_Name__c = :objectApiName
            AND Classification__c IN (:CLASS_PHI, :CLASS_SENSITIVE)
            WITH USER_MODE
        ]) {
            if (String.isNotBlank(rec.Field_API_Name__c)) {
                result.add(rec.Field_API_Name__c);
            }
        }
        return result;
    }

    /**
     * Applies the rule set and built-in type heuristics to a single field, "most severe wins".
     *
     * @param dfr Field describe result
     * @param rules Active classification rules
     * @return FieldVerdict with classification, detection method, and rationale
     */
    private FieldVerdict classifyField(Schema.DescribeFieldResult dfr, List<PHI_Classification_Rule__mdt> rules) {
        FieldVerdict verdict = new FieldVerdict();
        verdict.classification = CLASS_NON_SENSITIVE;
        verdict.method = METHOD_TYPE_HEURISTIC;
        verdict.rationale = 'No PHI or sensitive pattern matched; defaulted to Non-Sensitive.';

        String haystack = (dfr.getName() + ' ' + dfr.getLabel()).toLowerCase();
        String typeName = String.valueOf(dfr.getType());

        for (PHI_Classification_Rule__mdt rule : rules) {
            if (String.isBlank(rule.Pattern__c) || String.isBlank(rule.Classification__c)) {
                continue;
            }
            Boolean matched;
            String method;
            if (MATCH_FIELD_TYPE.equalsIgnoreCase(rule.Match_Type__c)) {
                matched = rule.Pattern__c.equalsIgnoreCase(typeName);
                method = METHOD_TYPE_HEURISTIC;
            } else {
                matched = haystack.contains(rule.Pattern__c.toLowerCase());
                method = METHOD_NAME_PATTERN;
            }
            if (matched && severity(rule.Classification__c) > severity(verdict.classification)) {
                verdict.classification = rule.Classification__c;
                verdict.method = method;
                verdict.rationale = String.isNotBlank(rule.Rationale__c)
                    ? rule.Rationale__c
                    : ('Matched rule pattern "' + rule.Pattern__c + '".');
            }
        }

        String typeClass = typeHeuristic(dfr.getType());
        if (typeClass != null && severity(typeClass) > severity(verdict.classification)) {
            verdict.classification = typeClass;
            verdict.method = METHOD_TYPE_HEURISTIC;
            verdict.rationale = 'Field type ' + typeName + ' is treated as ' + typeClass + '.';
        }

        return verdict;
    }

    /**
     * Built-in deterministic type heuristics that never downgrade a rule match.
     *
     * @param dt Field display type
     * @return CLASS_SENSITIVE for email/phone/encrypted types, otherwise null
     */
    private String typeHeuristic(Schema.DisplayType dt) {
        if (dt == Schema.DisplayType.EMAIL || dt == Schema.DisplayType.PHONE || dt == Schema.DisplayType.ENCRYPTEDSTRING) {
            return CLASS_SENSITIVE;
        }
        return null;
    }

    /**
     * Severity ranking for "most severe wins" comparisons.
     *
     * @param classification Classification value
     * @return 3 for PHI, 2 for Sensitive, 1 otherwise
     */
    private Integer severity(String classification) {
        if (CLASS_PHI.equalsIgnoreCase(classification)) {
            return 3;
        }
        if (CLASS_SENSITIVE.equalsIgnoreCase(classification)) {
            return 2;
        }
        return 1;
    }

    /**
     * Loads the active classification rules.
     *
     * @return Active PHI_Classification_Rule__mdt records
     */
    private List<PHI_Classification_Rule__mdt> getActiveRules() {
        return [
            SELECT Pattern__c, Match_Type__c, Classification__c, Rationale__c
            FROM PHI_Classification_Rule__mdt
            WHERE Is_Active__c = true
            WITH USER_MODE
        ];
    }

    /**
     * Internal verdict holder for a single field.
     */
    private class FieldVerdict {
        private String classification;
        private String method;
        private String rationale;
    }
}
