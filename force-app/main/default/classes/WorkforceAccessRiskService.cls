/**
 * Workforce Access Risk Engine (issue #213, HIPAA pack).
 *
 * Evaluates each user's read access to classified PHI-bearing objects (from the PHI Field
 * Registry produced by #212) and scores their exposure against the HIPAA "minimum necessary"
 * principle. Over-privileged users are flagged and logged.
 *
 * The risk score is the percentage of classified PHI-bearing objects the user can read;
 * over-privileged = access to at least half of the PHI surface. Deterministic, no AI.
 *
 * All access is read via WITH USER_MODE and persisted via "upsert as user". Gated by the
 * HIPAA vertical-pack kill switch ({@link FeatureFlags#isHipaaPackEnabled}).
 *
 * @author Elaro Team
 * @since v3.2.0 (Spring '26)
 * @group HIPAA Pack
 * @see PHIClassificationService
 * @see Workforce_Access_Risk__c
 * @see WorkforceAccessRiskBatch
 */
public inherited sharing class WorkforceAccessRiskService {

    private static final Decimal OVER_PRIVILEGED_THRESHOLD = 50;

    /** Test seam: inject a user-to-PHI-objects map to avoid simulating ObjectPermissions/PSA. */
    @TestVisible
    private static Map<Id, Set<String>> accessOverrideForTest;

    /**
     * Result of evaluating a single user's PHI access risk.
     */
    public class RiskResult {
        @AuraEnabled
        public Id userId;
        @AuraEnabled
        public Decimal riskScore;
        @AuraEnabled
        public String riskLevel;
        @AuraEnabled
        public Boolean overPrivileged;
        @AuraEnabled
        public Integer phiObjectCount;
    }

    /**
     * Evaluates PHI access risk for the given users and upserts Workforce_Access_Risk__c records.
     *
     * @param userIds Users to evaluate
     * @return One RiskResult per user (empty if no users)
     * @throws AuraHandledException if the HIPAA pack is disabled or persistence fails
     */
    public List<RiskResult> evaluateUsers(List<Id> userIds) {
        if (!FeatureFlags.isHipaaPackEnabled()) {
            throw new AuraHandledException('The HIPAA pack is disabled for this org.');
        }

        List<RiskResult> results = new List<RiskResult>();
        try {
            if (userIds == null || userIds.isEmpty()) {
                return results;
            }

            Set<String> phiObjects = getPhiObjects();
            Integer totalPhi = phiObjects.size();
            Map<Id, Set<String>> userAccess = (accessOverrideForTest != null)
                ? accessOverrideForTest
                : buildUserPhiAccess(userIds, phiObjects);

            List<Workforce_Access_Risk__c> toUpsert = new List<Workforce_Access_Risk__c>();
            Datetime evaluatedAt = Datetime.now();

            for (Id userId : userIds) {
                Set<String> accessible = userAccess.containsKey(userId)
                    ? userAccess.get(userId)
                    : new Set<String>();
                Integer count = accessible.size();

                Decimal score = 0;
                if (totalPhi > 0) {
                    score = ((Decimal) count / (Decimal) totalPhi * 100).setScale(2);
                }
                String level = toRiskLevel(score);
                Boolean overPrivileged = score >= OVER_PRIVILEGED_THRESHOLD;

                Workforce_Access_Risk__c rec = new Workforce_Access_Risk__c();
                rec.User__c = userId;
                rec.User_Key__c = String.valueOf(userId);
                rec.Name = String.valueOf(userId);
                rec.Risk_Score__c = score;
                rec.Risk_Level__c = level;
                rec.Over_Privileged__c = overPrivileged;
                rec.PHI_Object_Count__c = count;
                rec.PHI_Objects_Total__c = totalPhi;
                rec.Findings__c = buildFindings(count, totalPhi, accessible);
                rec.Evaluated_Date__c = evaluatedAt;
                toUpsert.add(rec);

                if (overPrivileged) {
                    ElaroLogger.warn(
                        'WorkforceAccessRiskService.evaluateUsers',
                        'Over-privileged PHI access for user ' + userId + ': ' + count + '/' + totalPhi +
                        ' PHI objects (' + level + ')'
                    );
                }

                RiskResult result = new RiskResult();
                result.userId = userId;
                result.riskScore = score;
                result.riskLevel = level;
                result.overPrivileged = overPrivileged;
                result.phiObjectCount = count;
                results.add(result);
            }

            if (!toUpsert.isEmpty()) {
                upsert as user toUpsert User_Key__c;
            }
            ElaroLogger.info('WorkforceAccessRiskService.evaluateUsers', 'Evaluated ' + results.size() + ' user(s)');
            return results;
        } catch (Exception e) {
            ElaroLogger.error('WorkforceAccessRiskService.evaluateUsers', e.getMessage(), e.getStackTraceString());
            throw new AuraHandledException('Unable to evaluate workforce access risk. ' + e.getMessage());
        }
    }

    /**
     * Returns the distinct object API names that contain at least one PHI or Sensitive field.
     *
     * @return Set of PHI-bearing object API names
     */
    public static Set<String> getPhiObjects() {
        Set<String> objects = new Set<String>();
        for (PHI_Field_Registry__c rec : [
            SELECT Object_API_Name__c
            FROM PHI_Field_Registry__c
            WHERE Classification__c IN ('PHI', 'Sensitive')
            AND Object_API_Name__c != null
            WITH USER_MODE
        ]) {
            objects.add(rec.Object_API_Name__c);
        }
        return objects;
    }

    /**
     * Builds a map of user to the set of PHI-bearing objects they can read, by joining
     * ObjectPermissions (read) to the users' PermissionSetAssignments (which include the
     * profile-owned permission set).
     *
     * @param userIds Users to evaluate
     * @param phiObjects PHI-bearing object API names
     * @return Map of user Id to accessible PHI object API names
     */
    private Map<Id, Set<String>> buildUserPhiAccess(List<Id> userIds, Set<String> phiObjects) {
        Map<Id, Set<String>> userToObjects = new Map<Id, Set<String>>();
        if (phiObjects.isEmpty()) {
            return userToObjects;
        }

        Map<Id, Set<String>> permSetToObjects = new Map<Id, Set<String>>();
        for (ObjectPermissions op : [
            SELECT ParentId, SobjectType
            FROM ObjectPermissions
            WHERE PermissionsRead = true
            AND SobjectType IN :phiObjects
            WITH USER_MODE
        ]) {
            if (!permSetToObjects.containsKey(op.ParentId)) {
                permSetToObjects.put(op.ParentId, new Set<String>());
            }
            permSetToObjects.get(op.ParentId).add(op.SobjectType);
        }
        if (permSetToObjects.isEmpty()) {
            return userToObjects;
        }

        for (PermissionSetAssignment psa : [
            SELECT AssigneeId, PermissionSetId
            FROM PermissionSetAssignment
            WHERE AssigneeId IN :userIds
            AND PermissionSetId IN :permSetToObjects.keySet()
            WITH USER_MODE
        ]) {
            if (!userToObjects.containsKey(psa.AssigneeId)) {
                userToObjects.put(psa.AssigneeId, new Set<String>());
            }
            userToObjects.get(psa.AssigneeId).addAll(permSetToObjects.get(psa.PermissionSetId));
        }
        return userToObjects;
    }

    /**
     * Maps a numeric score to a categorized risk level.
     *
     * @param score Risk score 0-100
     * @return Critical (>=75), High (>=50), Medium (>=25), else Low
     */
    private String toRiskLevel(Decimal score) {
        if (score >= 75) {
            return 'Critical';
        }
        if (score >= 50) {
            return 'High';
        }
        if (score >= 25) {
            return 'Medium';
        }
        return 'Low';
    }

    /**
     * Builds a human-readable findings summary.
     *
     * @param count Number of PHI objects accessible
     * @param total Total PHI objects
     * @param accessible The accessible PHI object names
     * @return Findings text
     */
    private String buildFindings(Integer count, Integer total, Set<String> accessible) {
        if (total == 0) {
            return 'No PHI-bearing objects are classified yet; run PHI classification (#212) first.';
        }
        String objects = String.join(new List<String>(accessible), ', ');
        return 'User can read ' + count + ' of ' + total + ' PHI-bearing objects' +
            (String.isBlank(objects) ? '.' : ': ' + objects + '.');
    }
}
