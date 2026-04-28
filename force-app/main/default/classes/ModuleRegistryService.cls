/**
 * Dynamically loads and manages compliance modules registered via Elaro_Module_Registry__mdt.
 * Enables third-party module registration without modifying ComplianceServiceFactory.
 * Modules must implement IComplianceModule interface.
 *
 * @author Elaro Team
 * @since v3.1.0 (Spring '26)
 * @group Architecture
 * @see IComplianceModule
 * @see ComplianceServiceFactory
 * @see Elaro_Module_Registry__mdt
 */
public inherited sharing class ModuleRegistryService {

    private static Map<String, Object> moduleCache = new Map<String, Object>();

    /**
     * Loads all active registered modules ordered by priority.
     *
     * @return List of module registry records
     */
    public static List<Elaro_Module_Registry__mdt> getActiveModules() {
        return [
            SELECT DeveloperName, Class_Name__c, Framework__c, Is_Active__c,
                   Priority__c, Description__c
            FROM Elaro_Module_Registry__mdt
            WHERE Is_Active__c = true
            WITH USER_MODE
            ORDER BY Priority__c ASC NULLS LAST
        ];
    }

    /**
     * Instantiates a module by its class name using Type.forName().
     * Validates that the class exists and can be instantiated.
     *
     * @param className The fully qualified Apex class name
     * @return The instantiated module object, or null if class not found
     * @throws AuraHandledException if the class cannot be instantiated
     */
    public static Object instantiateModule(String className) {
        if (String.isBlank(className)) {
            throw new AuraHandledException('Module class name cannot be blank');
        }

        if (moduleCache.containsKey(className)) {
            return moduleCache.get(className);
        }

        Type moduleType = Type.forName(className);
        if (moduleType == null) {
            ElaroLogger.error('ModuleRegistryService.instantiateModule',
                'Class not found: ' + className, '');
            return null;
        }

        try {
            Object instance = moduleType.newInstance();
            moduleCache.put(className, instance);
            return instance;
        } catch (Exception e) {
            ElaroLogger.error('ModuleRegistryService.instantiateModule',
                'Failed to instantiate: ' + className + ' - ' + e.getMessage(),
                e.getStackTraceString());
            throw new AuraHandledException('Failed to load module: ' + className);
        }
    }

    /**
     * Loads all active modules and returns them as instantiated objects.
     * Skips modules that fail to load and logs errors.
     *
     * @return Map of framework identifier to instantiated module
     */
    public static Map<String, Object> loadAllModules() {
        Map<String, Object> modules = new Map<String, Object>();
        List<Elaro_Module_Registry__mdt> registrations = getActiveModules();

        for (Elaro_Module_Registry__mdt reg : registrations) {
            Object instance = instantiateModule(reg.Class_Name__c);
            if (instance != null) {
                modules.put(reg.Framework__c, instance);
            }
        }

        return modules;
    }

    /**
     * Gets a specific module for a given framework.
     *
     * @param framework The framework identifier
     * @return The module instance, or null if not registered
     */
    public static Object getModuleForFramework(String framework) {
        List<Elaro_Module_Registry__mdt> registrations = [
            SELECT Class_Name__c
            FROM Elaro_Module_Registry__mdt
            WHERE Framework__c = :framework
            AND Is_Active__c = true
            WITH USER_MODE
            LIMIT 1
        ];

        if (registrations.isEmpty()) {
            return null;
        }

        return instantiateModule(registrations[0].Class_Name__c);
    }

    /**
     * Returns the list of all registered framework identifiers.
     *
     * @return Set of framework names that have registered modules
     */
    public static Set<String> getRegisteredFrameworks() {
        Set<String> frameworks = new Set<String>();
        for (Elaro_Module_Registry__mdt reg : getActiveModules()) {
            frameworks.add(reg.Framework__c);
        }
        return frameworks;
    }

    /**
     * Clears the module instance cache. Useful for testing.
     */
    @TestVisible
    private static void clearCache() {
        moduleCache.clear();
    }
}
