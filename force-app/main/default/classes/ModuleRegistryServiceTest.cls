/**
 * Tests for ModuleRegistryService covering module loading, instantiation,
 * caching, and error handling.
 *
 * @author Elaro Team
 * @since v3.1.0 (Spring '26)
 * @group Architecture
 * @see ModuleRegistryService
 */
@IsTest(testFor=ModuleRegistryService.class)
private class ModuleRegistryServiceTest {

    @IsTest
    static void shouldGetActiveModules() {
        Test.startTest();
        List<Elaro_Module_Registry__mdt> modules = ModuleRegistryService.getActiveModules();
        Test.stopTest();

        Assert.isNotNull(modules, 'Should return a list (may be empty in test context)');
    }

    @IsTest
    static void shouldInstantiateKnownClass() {
        Test.startTest();
        Object instance = ModuleRegistryService.instantiateModule('ModuleRegistryService');
        Test.stopTest();

        Assert.isNotNull(instance, 'Should instantiate a known Apex class');
    }

    @IsTest
    static void shouldReturnNullForUnknownClass() {
        Test.startTest();
        Object instance = ModuleRegistryService.instantiateModule('NonExistentClass_XYZ_999');
        Test.stopTest();

        Assert.isNull(instance, 'Should return null for unknown class');
    }

    @IsTest
    static void shouldThrowForBlankClassName() {
        Test.startTest();
        try {
            ModuleRegistryService.instantiateModule('');
            Assert.fail('Should throw for blank class name');
        } catch (AuraHandledException e) {
            Assert.isTrue(e.getMessage().contains('cannot be blank'),
                'Error should mention blank class name');
        }
        Test.stopTest();
    }

    @IsTest
    static void shouldCacheInstances() {
        Test.startTest();
        Object first = ModuleRegistryService.instantiateModule('ModuleRegistryService');
        Object second = ModuleRegistryService.instantiateModule('ModuleRegistryService');
        Test.stopTest();

        Assert.areEqual(first, second, 'Cached instances should be the same object');
    }

    @IsTest
    static void shouldClearCache() {
        ModuleRegistryService.instantiateModule('ModuleRegistryService');

        Test.startTest();
        ModuleRegistryService.clearCache();
        Test.stopTest();

        Object afterClear = ModuleRegistryService.instantiateModule('ModuleRegistryService');
        Assert.isNotNull(afterClear, 'Should create new instance after cache clear');
    }

    @IsTest
    static void shouldLoadAllModules() {
        Test.startTest();
        Map<String, Object> modules = ModuleRegistryService.loadAllModules();
        Test.stopTest();

        Assert.isNotNull(modules, 'Should return map (may be empty in test context)');
    }

    @IsTest
    static void shouldGetRegisteredFrameworks() {
        Test.startTest();
        Set<String> frameworks = ModuleRegistryService.getRegisteredFrameworks();
        Test.stopTest();

        Assert.isNotNull(frameworks, 'Should return set (may be empty in test context)');
    }

    @IsTest
    static void shouldGetModuleForFramework() {
        Test.startTest();
        Object module = ModuleRegistryService.getModuleForFramework('NONEXISTENT_FRAMEWORK');
        Test.stopTest();

        Assert.isNull(module, 'Should return null for unregistered framework');
    }
}
