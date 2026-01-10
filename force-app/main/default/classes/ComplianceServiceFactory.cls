/**
 * Factory class for compliance service instantiation and registration
 * Provides centralized service lookup and creation following the Factory pattern
 * 
 * Services are registered by framework name and can be retrieved dynamically.
 * This enables framework-agnostic service access and simplifies integration.
 * 
 * @author Prometheion
 * @version 3.0
 */
public with sharing class ComplianceServiceFactory {
    
    // Service registry - maps framework name to service class type
    private static Map<String, Type> serviceRegistry = new Map<String, Type>();
    
    // Service cache - caches instantiated services per framework
    private static Map<String, ComplianceServiceBase> serviceCache = new Map<String, ComplianceServiceBase>();
    
    /**
     * Register a compliance service for a framework
     * @param frameworkName Framework identifier (e.g., 'GDPR', 'CCPA', 'PCI-DSS')
     * @param serviceType Service class type
     */
    public static void registerService(String frameworkName, Type serviceType) {
        if (String.isBlank(frameworkName)) {
            throw new IllegalArgumentException('Framework name cannot be blank');
        }
        if (serviceType == null) {
            throw new IllegalArgumentException('Service type cannot be null');
        }
        
        serviceRegistry.put(frameworkName.toUpperCase(), serviceType);
        // Clear cache for this framework to force re-instantiation
        serviceCache.remove(frameworkName.toUpperCase());
    }
    
    /**
     * Get service instance for a framework
     * @param frameworkName Framework identifier
     * @return ComplianceServiceBase instance or null if not registered
     */
    public static ComplianceServiceBase getService(String frameworkName) {
        if (String.isBlank(frameworkName)) {
            return null;
        }
        
        String frameworkKey = frameworkName.toUpperCase();
        
        // Check cache first
        if (serviceCache.containsKey(frameworkKey)) {
            return serviceCache.get(frameworkKey);
        }
        
        // Look up service type
        Type serviceType = serviceRegistry.get(frameworkKey);
        if (serviceType == null) {
            System.debug(LoggingLevel.WARN, 
                'ComplianceServiceFactory: No service registered for framework: ' + frameworkName);
            return null;
        }
        
        // Instantiate service
        try {
            ComplianceServiceBase service = (ComplianceServiceBase)serviceType.newInstance();
            serviceCache.put(frameworkKey, service);
            return service;
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 
                'ComplianceServiceFactory: Failed to instantiate service for ' + frameworkName + 
                ': ' + e.getMessage());
            return null;
        }
    }
    
    /**
     * Check if a service is registered for a framework
     * @param frameworkName Framework identifier
     * @return True if service is registered
     */
    public static Boolean isServiceRegistered(String frameworkName) {
        if (String.isBlank(frameworkName)) {
            return false;
        }
        return serviceRegistry.containsKey(frameworkName.toUpperCase());
    }
    
    /**
     * Get all registered framework names
     * @return Set of registered framework names
     */
    public static Set<String> getRegisteredFrameworks() {
        return new Set<String>(serviceRegistry.keySet());
    }
    
    /**
     * Clear service cache (useful for testing or when services need to be re-instantiated)
     */
    public static void clearCache() {
        serviceCache.clear();
    }
    
    /**
     * Initialize default service registrations
     * This method should be called during application startup or via a trigger
     * Services can also be registered dynamically at runtime
     */
    public static void initializeDefaultServices() {
        // GDPR Services - Register primary service for framework
        if (Type.forName('GDPRDataSubjectService') != null) {
            registerService('GDPR', Type.forName('GDPRDataSubjectService'));
        }
        
        // CCPA Services - Register primary service for framework
        if (Type.forName('CCPAConsumerRightsService') != null) {
            registerService('CCPA', Type.forName('CCPAConsumerRightsService'));
        }
        
        // PCI-DSS Services - Register primary service for framework
        if (Type.forName('PCIAccessControlService') != null) {
            registerService('PCI-DSS', Type.forName('PCIAccessControlService'));
            registerService('PCI_DSS', Type.forName('PCIAccessControlService')); // Also register with underscore
        }
        
        // Additional GDPR services can be accessed directly or via factory extension
        // GDPRConsentManagementService, GDPRDataInventoryService, GDPRBreachNotificationService
        
        // Additional CCPA services
        // CCPADataInventoryService, CCPAOptOutService
        
        // Additional PCI-DSS services
        // PCILoggingService, PCIDataProtectionService
        
        // Note: Additional services can be registered here as they are implemented
        // The factory pattern allows for dynamic registration without code changes
    }
}
