/**
 * Unit tests for {@link PackRegistry}. Uses the @TestVisible injection hook for deterministic
 * logic coverage (independent of deployed Custom Metadata) plus one smoke test of the real
 * metadata-backed load path.
 *
 * @author Elaro Team
 * @since v3.2.0 (Spring '26)
 * @group Core Platform
 * @see PackRegistry
 */
@IsTest
private class PackRegistryTest {

    private static List<PackRegistry.FrameworkClassification> sampleRows() {
        return new List<PackRegistry.FrameworkClassification>{
            new PackRegistry.FrameworkClassification('HIPAA', 'HIPAA', 'Pack', 'HIPAA', true),
            new PackRegistry.FrameworkClassification('SOC2', 'SOC2', 'Core', 'None', true),
            new PackRegistry.FrameworkClassification('PCI_DSS', 'PCI_DSS', 'Core', 'None', true),
            new PackRegistry.FrameworkClassification('GLBA', 'GLBA', 'Pack', 'FinancialServices', true),
            new PackRegistry.FrameworkClassification('AI_GOVERNANCE', 'AI_GOVERNANCE', 'Pack', 'AIGovernance', false)
        };
    }

    @IsTest
    static void shouldClassifyCoreAndPackFrameworks() {
        PackRegistry.setClassificationsForTest(sampleRows());

        Test.startTest();
        Assert.areEqual('Core', PackRegistry.getLayer('SOC2'), 'SOC2 should be Core');
        Assert.areEqual('Pack', PackRegistry.getLayer('HIPAA'), 'HIPAA should be a Pack');
        Assert.areEqual('HIPAA', PackRegistry.getPack('hipaa'), 'getPack should be case-insensitive');
        Assert.isTrue(PackRegistry.isCore('PCI_DSS'), 'PCI-DSS should be Core per the #211 decision');
        Assert.isFalse(PackRegistry.isCore('HIPAA'), 'HIPAA is not Core');
        Test.stopTest();
    }

    @IsTest
    static void shouldReturnCoreAndPackSets() {
        PackRegistry.setClassificationsForTest(sampleRows());

        Set<String> core = PackRegistry.getCoreFrameworks();
        Assert.isTrue(core.contains('SOC2'), 'Core set should include SOC2');
        Assert.isTrue(core.contains('PCI_DSS'), 'Core set should include PCI_DSS');
        Assert.isFalse(core.contains('HIPAA'), 'Core set should not include HIPAA');

        Set<String> finServ = PackRegistry.getFrameworksInPack('FinancialServices');
        Assert.isTrue(finServ.contains('GLBA'), 'Financial Services pack should include GLBA');
        Assert.areEqual(0, PackRegistry.getFrameworksInPack('').size(), 'Blank pack should yield an empty set');
    }

    @IsTest
    static void shouldGateActiveFrameworksByPackFlag() {
        PackRegistry.setClassificationsForTest(sampleRows());

        // Disable the HIPAA pack via the hierarchy custom setting org default.
        Elaro_Feature_Flags__c flags = Elaro_Feature_Flags__c.getOrgDefaults();
        flags.HIPAA_Pack_Enabled__c = false;
        upsert flags;

        Test.startTest();
        Assert.isFalse(PackRegistry.isPackEnabled('HIPAA'), 'HIPAA pack should be disabled');
        Assert.isTrue(PackRegistry.isPackEnabled('FinancialServices'), 'Financial Services pack should default enabled');
        Assert.isTrue(PackRegistry.isPackEnabled('None'), 'Core (None) is always enabled');

        Assert.isFalse(PackRegistry.isFrameworkActive('HIPAA'), 'HIPAA inactive because its pack is disabled');
        Assert.isTrue(PackRegistry.isFrameworkActive('SOC2'), 'SOC2 active (Core)');
        Assert.isFalse(
            PackRegistry.isFrameworkActive('AI_GOVERNANCE'),
            'AI Governance row is inactive (Is_Active false)'
        );

        Set<String> active = PackRegistry.getActiveFrameworks();
        Assert.isTrue(active.contains('SOC2'), 'SOC2 should be active');
        Assert.isFalse(active.contains('HIPAA'), 'HIPAA excluded (pack disabled)');
        Assert.isFalse(active.contains('AI_GOVERNANCE'), 'AI Governance excluded (inactive)');
        Test.stopTest();
    }

    @IsTest
    static void shouldHandleUnknownAndBlankCodes() {
        PackRegistry.setClassificationsForTest(sampleRows());
        Assert.isNull(PackRegistry.getClassification('NOPE'), 'Unknown framework returns null classification');
        Assert.isNull(PackRegistry.getLayer(''), 'Blank code returns null layer');
        Assert.isFalse(PackRegistry.isFrameworkActive('NOPE'), 'Unknown framework is not active');
        Assert.isTrue(PackRegistry.isPackEnabled('SomeUnknownPack'), 'Unknown packs default to enabled');
    }

    @IsTest
    static void shouldLoadFromDeployedMetadata() {
        // Smoke test of the real Framework_Config__mdt-backed load path (records ship with the package).
        Test.startTest();
        Set<String> core = PackRegistry.getCoreFrameworks();
        Set<String> active = PackRegistry.getActiveFrameworks();
        Test.stopTest();

        Assert.isNotNull(core, 'getCoreFrameworks should never return null');
        Assert.isNotNull(active, 'getActiveFrameworks should never return null');
    }
}
