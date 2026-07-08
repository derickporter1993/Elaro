/**
 * ComplianceServiceFactory
 *
 * Factory class for instantiating compliance framework services.
 * Provides centralized service resolution based on framework identifier.
 * Uses dynamic Type.forName() to decouple from vertical packages.
 *
 * @author Elaro
 * @version 2.0
 * @since v3.1.0 (Spring '26)
 * @group Compliance Framework
 */
public with sharing class ComplianceServiceFactory {

    // Singleton instances cache
    private static Map<String, IRiskScoringService> serviceCache = new Map<String, IRiskScoringService>();
    private static Map<String, IAccessControlService> accessServiceCache = new Map<String, IAccessControlService>();
    private static Map<String, IBreachNotificationService> breachServiceCache = new Map<String, IBreachNotificationService>();

    // Framework constants
    public static final String FRAMEWORK_HIPAA = 'HIPAA';
    public static final String FRAMEWORK_SOC2 = 'SOC2';
    public static final String FRAMEWORK_GDPR = 'GDPR';
    public static final String FRAMEWORK_CCPA = 'CCPA';
    public static final String FRAMEWORK_PCI_DSS = 'PCI_DSS';
    public static final String FRAMEWORK_NIST = 'NIST';
    public static final String FRAMEWORK_FEDRAMP = 'FEDRAMP';
    public static final String FRAMEWORK_SOX = 'SOX';
    public static final String FRAMEWORK_GLBA = 'GLBA';
    public static final String FRAMEWORK_ISO27001 = 'ISO27001';

    // Supported frameworks set
    private static final Set<String> SUPPORTED_FRAMEWORKS = new Set<String>{
        FRAMEWORK_HIPAA, FRAMEWORK_SOC2, FRAMEWORK_GDPR, FRAMEWORK_CCPA,
        FRAMEWORK_PCI_DSS, FRAMEWORK_NIST, FRAMEWORK_FEDRAMP, FRAMEWORK_SOX,
        FRAMEWORK_GLBA, FRAMEWORK_ISO27001
    };

    // Service class mappings (decoupled from direct imports)
    private static final Map<String, String> RISK_SERVICE_MAP = new Map<String, String>{
        'HIPAA' => 'ElaroHIPAAComplianceService',
        'SOC2' => 'ElaroSOC2ComplianceService',
        'GDPR' => 'ElaroGDPRComplianceService',
        'CCPA' => 'ElaroCCPAComplianceService',
        'PCI_DSS' => 'ElaroPCIDSSComplianceService'
    };

    private static final Map<String, String> ACCESS_SERVICE_MAP = new Map<String, String>{
        'SOC2' => 'SOC2AccessReviewService',
        'HIPAA' => 'SOC2AccessReviewService'
    };

    private static final Map<String, String> BREACH_SERVICE_MAP = new Map<String, String>{
        'HIPAA' => 'HIPAABreachNotificationService',
        'SOC2' => 'SOC2IncidentResponseService'
    };

    /**
     * Get the main compliance service for a framework
     * @param framework Framework identifier
     * @return IRiskScoringService implementation for the framework
     */
    public static IRiskScoringService getService(String framework) {
        validateFramework(framework);

        if (serviceCache.containsKey(framework)) {
            return serviceCache.get(framework);
        }

        IRiskScoringService service = createService(framework);
        serviceCache.put(framework, service);
        return service;
    }

    /**
     * Get access control service for a framework
     * @param framework Framework identifier
     * @return IAccessControlService implementation for the framework
     */
    public static IAccessControlService getAccessService(String framework) {
        validateFramework(framework);

        if (accessServiceCache.containsKey(framework)) {
            return accessServiceCache.get(framework);
        }

        IAccessControlService service = createAccessService(framework);
        if (service != null) {
            accessServiceCache.put(framework, service);
        }
        return service;
    }

    /**
     * Get breach notification service for a framework
     * @param framework Framework identifier
     * @return IBreachNotificationService implementation for the framework
     */
    public static IBreachNotificationService getBreachService(String framework) {
        validateFramework(framework);

        if (breachServiceCache.containsKey(framework)) {
            return breachServiceCache.get(framework);
        }

        IBreachNotificationService service = createBreachService(framework);
        if (service != null) {
            breachServiceCache.put(framework, service);
        }
        return service;
    }

    /**
     * Get all supported frameworks
     * @return Set of supported framework identifiers
     */
    public static Set<String> getSupportedFrameworks() {
        return SUPPORTED_FRAMEWORKS.clone();
    }

    /**
     * Check if a framework is supported
     * @param framework Framework identifier to check
     * @return true if supported
     */
    public static Boolean isFrameworkSupported(String framework) {
        return framework != null && SUPPORTED_FRAMEWORKS.contains(framework.toUpperCase());
    }

    /**
     * Get framework configuration from custom metadata
     * @param framework Framework identifier
     * @return Framework configuration or null if not found
     */
    public static FrameworkConfig getFrameworkConfig(String framework) {
        validateFramework(framework);

        List<Framework_Config__mdt> configs = [
            SELECT DeveloperName, Framework_Code__c, Display_Name__c,
                   Score_Multiplier__c, Response_Deadline_Days__c,
                   Evidence_Retention_Days__c, Service_Class__c
            FROM Framework_Config__mdt
            WHERE Framework_Code__c = :framework
            WITH USER_MODE
            LIMIT 1
        ];

        if (configs.isEmpty()) {
            return new FrameworkConfig(framework);
        }

        return new FrameworkConfig(configs[0]);
    }

    /**
     * Clear service caches (useful for testing)
     */
    @TestVisible
    private static void clearCache() {
        serviceCache.clear();
        accessServiceCache.clear();
        breachServiceCache.clear();
    }

    private static IRiskScoringService createService(String framework) {
        String className = RISK_SERVICE_MAP.get(framework.toUpperCase());
        if (className == null) {
            FrameworkConfig config = getFrameworkConfig(framework);
            if (String.isNotBlank(config.serviceClass)) {
                className = config.serviceClass;
            }
        }
        if (className == null) {
            throw new ComplianceServiceException('No service implementation found for framework: ' + framework);
        }
        return (IRiskScoringService)createInstanceOf(className, 'IRiskScoringService');
    }

    private static IAccessControlService createAccessService(String framework) {
        String className = ACCESS_SERVICE_MAP.get(framework.toUpperCase());
        if (className == null) {
            return null;
        }
        return (IAccessControlService)createInstanceOf(className, 'IAccessControlService');
    }

    private static IBreachNotificationService createBreachService(String framework) {
        String className = BREACH_SERVICE_MAP.get(framework.toUpperCase());
        if (className == null) {
            return null;
        }
        return (IBreachNotificationService)createInstanceOf(className, 'IBreachNotificationService');
    }

    private static Object createInstanceOf(String className, String expectedInterface) {
        try {
            Type serviceType = Type.forName(className);
            if (serviceType == null) {
                throw new ComplianceServiceException('Class not found: ' + className + '. Ensure the vertical package is deployed.');
            }
            return serviceType.newInstance();
        } catch (ComplianceServiceException e) {
            throw e;
        } catch (Exception e) {
            throw new ComplianceServiceException('Failed to create ' + expectedInterface + ' from ' + className + ': ' + e.getMessage());
        }
    }

    /**
     * Validate framework identifier
     */
    private static void validateFramework(String framework) {
        if (String.isBlank(framework)) {
            throw new ComplianceServiceException('Framework identifier cannot be blank');
        }
    }

    /**
     * Framework configuration wrapper
     */
    public class FrameworkConfig {
        @AuraEnabled public String frameworkCode;
        @AuraEnabled public String displayName;
        @AuraEnabled public Decimal scoreMultiplier;
        @AuraEnabled public Integer responseDeadlineDays;
        @AuraEnabled public Integer evidenceRetentionDays;
        @AuraEnabled public String serviceClass;

        public FrameworkConfig(String framework) {
            this.frameworkCode = framework;
            this.displayName = framework;
            this.scoreMultiplier = 1.0;
            this.responseDeadlineDays = 30;
            this.evidenceRetentionDays = 365;
            this.serviceClass = null;
        }

        public FrameworkConfig(Framework_Config__mdt config) {
            this.frameworkCode = config.Framework_Code__c;
            this.displayName = config.Display_Name__c;
            this.scoreMultiplier = config.Score_Multiplier__c != null ? config.Score_Multiplier__c : 1.0;
            this.responseDeadlineDays = config.Response_Deadline_Days__c != null ?
                                        config.Response_Deadline_Days__c.intValue() : 30;
            this.evidenceRetentionDays = config.Evidence_Retention_Days__c != null ?
                                         config.Evidence_Retention_Days__c.intValue() : 365;
            this.serviceClass = config.Service_Class__c;
        }
    }

    /**
     * Custom exception for factory errors
     */
    public class ComplianceServiceException extends Exception {}
}
