/**
 * Single source of truth for Elaro's "core platform vs. vertical pack" classification of
 * compliance frameworks (issue #211 — platform + vertical-pack architecture).
 *
 * Reads the classification fields (Layer__c, Pack__c, Is_Active__c) from
 * Framework_Config__mdt and exposes pack-aware lookups that also honor the per-pack kill
 * switches on {@link FeatureFlags}, so a framework that belongs to a disabled vertical pack
 * is reported as inactive.
 *
 * Classification values:
 * - Layer: "Core" (horizontal platform framework) or "Pack" (vertical-pack member)
 * - Pack:  "None" (Core), "HIPAA", "FinancialServices", or "AIGovernance"
 *
 * This is an additive, read-only registry: it does not alter ComplianceServiceFactory or
 * ElaroConstants behavior. Migrating those to derive their framework sets from this registry
 * is tracked as a follow-up (requires org validation against ElaroConstantsTest).
 *
 * @author Elaro Team
 * @since v3.2.0 (Spring '26)
 * @group Core Platform
 * @see FeatureFlags
 * @see Framework_Config__mdt
 */
public inherited sharing class PackRegistry {

    public static final String LAYER_CORE = 'Core';
    public static final String LAYER_PACK = 'Pack';

    public static final String PACK_NONE = 'None';
    public static final String PACK_HIPAA = 'HIPAA';
    public static final String PACK_FINANCIAL_SERVICES = 'FinancialServices';
    public static final String PACK_AI_GOVERNANCE = 'AIGovernance';

    /** Transaction-scoped cache keyed by upper-cased framework code. */
    private static Map<String, FrameworkClassification> classificationCache;

    /**
     * View of a framework's platform classification.
     */
    public class FrameworkClassification {
        @AuraEnabled public String frameworkCode;
        @AuraEnabled public String displayName;
        @AuraEnabled public String layer;
        @AuraEnabled public String pack;
        @AuraEnabled public Boolean isActive;

        public FrameworkClassification() {
        }

        public FrameworkClassification(
            String frameworkCode,
            String displayName,
            String layer,
            String pack,
            Boolean isActive
        ) {
            this.frameworkCode = frameworkCode;
            this.displayName = displayName;
            this.layer = layer;
            this.pack = pack;
            this.isActive = isActive;
        }
    }

    /**
     * Returns the classification for a framework code, or null if it is not classified.
     *
     * @param frameworkCode Framework code (e.g., 'HIPAA'); case-insensitive
     * @return FrameworkClassification or null
     */
    public static FrameworkClassification getClassification(String frameworkCode) {
        if (String.isBlank(frameworkCode)) {
            return null;
        }
        return load().get(frameworkCode.toUpperCase());
    }

    /**
     * Returns the architecture layer ('Core' or 'Pack') for a framework.
     *
     * @param frameworkCode Framework code; case-insensitive
     * @return 'Core', 'Pack', or null if unknown
     */
    public static String getLayer(String frameworkCode) {
        FrameworkClassification fc = getClassification(frameworkCode);
        return fc?.layer;
    }

    /**
     * Returns the vertical pack a framework belongs to.
     *
     * @param frameworkCode Framework code; case-insensitive
     * @return Pack name (e.g., 'HIPAA'), 'None' for Core, or null if unknown
     */
    public static String getPack(String frameworkCode) {
        FrameworkClassification fc = getClassification(frameworkCode);
        return fc?.pack;
    }

    /**
     * Indicates whether a framework is classified as Core (a horizontal platform framework).
     *
     * @param frameworkCode Framework code; case-insensitive
     * @return true if the framework's layer is Core
     */
    public static Boolean isCore(String frameworkCode) {
        return LAYER_CORE.equalsIgnoreCase(getLayer(frameworkCode));
    }

    /**
     * Returns all framework codes classified as Core, regardless of active state.
     *
     * @return Set of Core framework codes
     */
    public static Set<String> getCoreFrameworks() {
        Set<String> result = new Set<String>();
        for (FrameworkClassification fc : load().values()) {
            if (LAYER_CORE.equalsIgnoreCase(fc.layer)) {
                result.add(fc.frameworkCode);
            }
        }
        return result;
    }

    /**
     * Returns all framework codes belonging to the given vertical pack, regardless of active state.
     *
     * @param pack Pack name (e.g., 'HIPAA')
     * @return Set of framework codes (empty if none or blank pack)
     */
    public static Set<String> getFrameworksInPack(String pack) {
        Set<String> result = new Set<String>();
        if (String.isBlank(pack)) {
            return result;
        }
        for (FrameworkClassification fc : load().values()) {
            if (pack.equalsIgnoreCase(fc.pack)) {
                result.add(fc.frameworkCode);
            }
        }
        return result;
    }

    /**
     * Indicates whether a vertical pack is enabled via its FeatureFlags kill switch.
     * Core (or 'None') is always enabled; unknown packs default to enabled to avoid
     * silently hiding frameworks.
     *
     * @param pack Pack name
     * @return true if the pack is enabled
     */
    public static Boolean isPackEnabled(String pack) {
        if (String.isBlank(pack) || PACK_NONE.equalsIgnoreCase(pack) || LAYER_CORE.equalsIgnoreCase(pack)) {
            return true;
        }
        if (PACK_HIPAA.equalsIgnoreCase(pack)) {
            return FeatureFlags.isHipaaPackEnabled();
        }
        if (PACK_FINANCIAL_SERVICES.equalsIgnoreCase(pack)) {
            return FeatureFlags.isFinancialServicesPackEnabled();
        }
        if (PACK_AI_GOVERNANCE.equalsIgnoreCase(pack)) {
            return FeatureFlags.isAIGovernancePackEnabled();
        }
        return true;
    }

    /**
     * Determines whether a framework is effectively active: its Is_Active__c flag is true
     * AND (it is Core OR its vertical pack is enabled).
     *
     * @param frameworkCode Framework code; case-insensitive
     * @return true if active and its pack (if any) is enabled
     */
    public static Boolean isFrameworkActive(String frameworkCode) {
        FrameworkClassification fc = getClassification(frameworkCode);
        if (fc == null || fc.isActive != true) {
            return false;
        }
        return isPackEnabled(fc.pack);
    }

    /**
     * Returns all classified framework codes that are currently active and whose pack
     * (if any) is enabled.
     *
     * @return Set of active framework codes
     */
    public static Set<String> getActiveFrameworks() {
        Set<String> result = new Set<String>();
        for (FrameworkClassification fc : load().values()) {
            if (fc.isActive == true && isPackEnabled(fc.pack)) {
                result.add(fc.frameworkCode);
            }
        }
        return result;
    }

    /**
     * Loads (and caches for the transaction) the classification rows from Framework_Config__mdt.
     *
     * @return Map of upper-cased framework code to its classification
     */
    private static Map<String, FrameworkClassification> load() {
        if (classificationCache != null) {
            return classificationCache;
        }
        classificationCache = new Map<String, FrameworkClassification>();
        for (Framework_Config__mdt cfg : [
            SELECT Framework_Code__c, Display_Name__c, Layer__c, Pack__c, Is_Active__c
            FROM Framework_Config__mdt
            WHERE Layer__c != null
            WITH USER_MODE
        ]) {
            if (String.isBlank(cfg.Framework_Code__c)) {
                continue;
            }
            classificationCache.put(
                cfg.Framework_Code__c.toUpperCase(),
                new FrameworkClassification(
                    cfg.Framework_Code__c,
                    cfg.Display_Name__c,
                    cfg.Layer__c,
                    cfg.Pack__c,
                    cfg.Is_Active__c
                )
            );
        }
        return classificationCache;
    }

    /**
     * Test hook: seeds the classification cache so unit tests do not depend on deployed
     * Custom Metadata records.
     *
     * @param rows Classifications to seed the cache with
     */
    @TestVisible
    private static void setClassificationsForTest(List<FrameworkClassification> rows) {
        classificationCache = new Map<String, FrameworkClassification>();
        if (rows == null) {
            return;
        }
        for (FrameworkClassification fc : rows) {
            if (fc != null && String.isNotBlank(fc.frameworkCode)) {
                classificationCache.put(fc.frameworkCode.toUpperCase(), fc);
            }
        }
    }
}
