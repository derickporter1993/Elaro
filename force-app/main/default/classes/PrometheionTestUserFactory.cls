/**
 * @description User factory for Prometheion security testing
 * Creates test users with various permission sets for security and sharing tests
 *
 * @group Testing
 * @author Prometheion Team
 * @version 3.0
 *
 * @example
 * // Create admin user
 * User admin = PrometheionTestUserFactory.createPrometheionAdmin();
 *
 * // Create auditor user
 * User auditor = PrometheionTestUserFactory.createPrometheionAuditor();
 *
 * // Run code as different user
 * System.runAs(auditor) {
 *     // Test code with auditor permissions
 * }
 */
@isTest
public class PrometheionTestUserFactory {

    private static Integer userCounter = 0;

    /**
     * @description Create Prometheion Admin user
     * User with full Prometheion_Admin permission set
     * @return User with Prometheion_Admin permission set assigned
     */
    public static User createPrometheionAdmin() {
        User admin = createBaseUser('Admin');
        assignPermissionSet(admin.Id, 'Prometheion_Admin');
        return admin;
    }

    /**
     * @description Create Prometheion Auditor user
     * User with Prometheion_Auditor permission set (read-only)
     * @return User with Prometheion_Auditor permission set assigned
     */
    public static User createPrometheionAuditor() {
        User auditor = createBaseUser('Auditor');
        assignPermissionSet(auditor.Id, 'Prometheion_Auditor');
        return auditor;
    }

    /**
     * @description Create Prometheion standard user
     * User with Prometheion_User permission set
     * @return User with Prometheion_User permission set assigned
     */
    public static User createPrometheionUser() {
        User user = createBaseUser('User');
        assignPermissionSet(user.Id, 'Prometheion_User');
        return user;
    }

    /**
     * @description Create Prometheion AI User
     * User with Prometheion_AI_User permission set for AI features
     * @return User with Prometheion_AI_User permission set assigned
     */
    public static User createPrometheionAIUser() {
        User aiUser = createBaseUser('AIUser');
        assignPermissionSet(aiUser.Id, 'Prometheion_AI_User');
        return aiUser;
    }

    /**
     * @description Create standard user with NO Prometheion permissions
     * For testing permission denial scenarios
     * @return User with no Prometheion permission sets
     */
    public static User createStandardUser() {
        return createBaseUser('Standard');
    }

    /**
     * @description Create base user with Standard User profile
     * @param userType Suffix for username (Admin, Auditor, etc.)
     * @return Inserted User record
     */
    private static User createBaseUser(String userType) {
        Profile standardProfile = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];

        String uniqueId = String.valueOf(Datetime.now().getTime()) + String.valueOf(++userCounter);
        User u = new User(
            FirstName = 'Test',
            LastName = userType + ' ' + uniqueId,
            Email = 'test' + userType.toLowerCase() + uniqueId + '@prometheion.test',
            Username = 'test' + userType.toLowerCase() + uniqueId + '@prometheion.test.sandbox',
            Alias = ('t' + userType.left(3) + uniqueId).right(8),
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = standardProfile.Id
        );

        insert u;
        return u;
    }

    /**
     * @description Assign permission set to user
     * @param userId User ID to assign permission set to
     * @param permissionSetName API name of permission set
     */
    private static void assignPermissionSet(Id userId, String permissionSetName) {
        try {
            PermissionSet ps = [
                SELECT Id FROM PermissionSet
                WHERE Name = :permissionSetName
                LIMIT 1
            ];

            insert new PermissionSetAssignment(
                AssigneeId = userId,
                PermissionSetId = ps.Id
            );
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'Could not assign permission set ' + permissionSetName + ': ' + e.getMessage());
        }
    }

    /**
     * @description Create multiple users with same permission set
     * Useful for sharing tests with multiple users
     * @param count Number of users to create
     * @param permissionSetName Permission set to assign
     * @return List of created users
     */
    public static List<User> createMultipleUsers(Integer count, String permissionSetName) {
        List<User> users = new List<User>();

        for (Integer i = 0; i < count; i++) {
            User u = createBaseUser('Bulk' + i);
            if (String.isNotBlank(permissionSetName)) {
                assignPermissionSet(u.Id, permissionSetName);
            }
            users.add(u);
        }

        return users;
    }

    /**
     * @description Create user hierarchy for sharing tests
     * Creates users in manager-subordinate relationship
     * @param levels Number of hierarchy levels
     * @return Map of level to user list
     */
    public static Map<Integer, List<User>> createUserHierarchy(Integer levels) {
        Map<Integer, List<User>> hierarchy = new Map<Integer, List<User>>();
        User previousManager = null;

        for (Integer level = 0; level < levels; level++) {
            User manager = createBaseUser('Manager_L' + level);

            if (previousManager != null) {
                manager.ManagerId = previousManager.Id;
                update manager;
            }

            hierarchy.put(level, new List<User>{manager});
            previousManager = manager;
        }

        return hierarchy;
    }

    /**
     * @description Create users for permission set comparison testing
     * Returns map of permission set name to user with that permission
     * @return Map of permission set name to user
     */
    public static Map<String, User> createPermissionSetTestUsers() {
        Map<String, User> permissionUsers = new Map<String, User>();

        permissionUsers.put('Prometheion_Admin', createPrometheionAdmin());
        permissionUsers.put('Prometheion_Auditor', createPrometheionAuditor());
        permissionUsers.put('Prometheion_User', createPrometheionUser());
        permissionUsers.put('Prometheion_AI_User', createPrometheionAIUser());
        permissionUsers.put('No_Permissions', createStandardUser());

        return permissionUsers;
    }

    /**
     * @description Check if user has specific permission set
     * @param userId User ID to check
     * @param permissionSetName Permission set name to check for
     * @return True if user has the permission set
     */
    public static Boolean userHasPermissionSet(Id userId, String permissionSetName) {
        List<PermissionSetAssignment> assignments = [
            SELECT Id
            FROM PermissionSetAssignment
            WHERE AssigneeId = :userId
            AND PermissionSet.Name = :permissionSetName
            LIMIT 1
        ];

        return !assignments.isEmpty();
    }

    /**
     * @description Get all permission sets assigned to user
     * @param userId User ID
     * @return List of permission set names
     */
    public static List<String> getUserPermissionSets(Id userId) {
        List<String> permissionSetNames = new List<String>();

        for (PermissionSetAssignment psa : [
            SELECT PermissionSet.Name
            FROM PermissionSetAssignment
            WHERE AssigneeId = :userId
        ]) {
            permissionSetNames.add(psa.PermissionSet.Name);
        }

        return permissionSetNames;
    }
}
