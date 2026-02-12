/**
 * Scans PermissionSets and Profiles for over-provisioned access by detecting
 * ModifyAllData and ViewAllData permissions assigned to non-System Administrator users.
 *
 * @author Elaro Team
 * @since v1.0.0 (Spring '26)
 * @group Health Check
 * @see ScanFinding
 */
public inherited sharing class ProfilePermissionScanner {

    private static final String CATEGORY = 'Permissions';
    private static final String SYS_ADMIN = 'System Administrator';

    /**
     * Inner class to hold permission scan results.
     */
    public class PermissionResult {
        @AuraEnabled public Integer score { get; set; }
        @AuraEnabled public List<ScanFinding> findings { get; set; }

        public PermissionResult() {
            this.score = 100;
            this.findings = new List<ScanFinding>();
        }
    }

    /**
     * Executes the permission scan to detect over-provisioned access.
     *
     * @return PermissionResult containing a hygiene score and findings
     */
    public PermissionResult scan() {
        PermissionResult result = new PermissionResult();

        List<PermissionSet> riskyPerms = [
            SELECT Id, Name, Label, PermissionsModifyAllData, PermissionsViewAllData,
                   IsOwnedByProfile, Profile.Name
            FROM PermissionSet
            WHERE PermissionsModifyAllData = true OR PermissionsViewAllData = true
            WITH USER_MODE
        ];

        if (riskyPerms.isEmpty()) {
            return result;
        }

        Set<Id> riskyPermSetIds = new Set<Id>();
        for (PermissionSet ps : riskyPerms) {
            riskyPermSetIds.add(ps.Id);
        }

        Map<Id, Integer> assignmentCounts = new Map<Id, Integer>();
        for (AggregateResult ar : [
            SELECT PermissionSetId, COUNT(Id) userCount
            FROM PermissionSetAssignment
            WHERE PermissionSetId IN :riskyPermSetIds
            WITH USER_MODE
            GROUP BY PermissionSetId
        ]) {
            assignmentCounts.put(
                (Id) ar.get('PermissionSetId'),
                (Integer) ar.get('userCount')
            );
        }

        Integer penaltyPerFinding = 15;
        for (PermissionSet ps : riskyPerms) {
            String profileName = ps.IsOwnedByProfile ? ps.Profile?.Name : null;

            if (profileName == SYS_ADMIN) {
                continue;
            }

            String permName = ps.IsOwnedByProfile
                ? 'Profile: ' + (profileName ?? 'Unknown')
                : 'Permission Set: ' + (ps.Label ?? ps.Name);

            List<String> dangerousPerms = new List<String>();
            if (ps.PermissionsModifyAllData) {
                dangerousPerms.add('ModifyAllData');
            }
            if (ps.PermissionsViewAllData) {
                dangerousPerms.add('ViewAllData');
            }

            Integer userCount = assignmentCounts.get(ps.Id) ?? 0;

            result.findings.add(new ScanFinding(
                CATEGORY,
                permName,
                String.join(dangerousPerms, ', '),
                'Remove or restrict these permissions',
                'HIGH_RISK',
                permName + ' has ' + String.join(dangerousPerms, ' and ')
                    + ' assigned to ' + userCount + ' user(s)'
            ));

            result.score = Math.max(0, result.score - penaltyPerFinding);
        }

        return result;
    }
}
