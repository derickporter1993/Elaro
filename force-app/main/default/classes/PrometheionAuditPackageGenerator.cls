/**
 * PrometheionAuditPackageGenerator
 * 
 * Generates audit packages for compliance frameworks with evidence collection
 * 
 * @author Prometheion
 * @version 1.0
 */
public with sharing class PrometheionAuditPackageGenerator {
    
    /**
     * Generate audit package for a framework and date range
     * @param framework Framework name
     * @param packageName Package name
     * @param startDate Audit period start
     * @param endDate Audit period end
     * @return Created audit package ID
     */
    @AuraEnabled
    public static String generateAuditPackage(String framework, String packageName, Date startDate, Date endDate) {
        // Input validation
        if (String.isBlank(framework)) {
            throw new AuraHandledException('Framework cannot be blank');
        }
        if (String.isBlank(packageName)) {
            throw new AuraHandledException('Package name cannot be blank');
        }
        if (startDate == null || endDate == null) {
            throw new AuraHandledException('Start date and end date are required');
        }
        if (startDate > endDate) {
            throw new AuraHandledException('Start date must be before end date');
        }
        
        // Validate CRUD access
        PrometheionSecurityUtils.validateCRUDAccess('Prometheion_Audit_Package__c',
            PrometheionSecurityUtils.DmlOperation.DML_INSERT);
        
        // Create audit package
        Prometheion_Audit_Package__c auditPackage = new Prometheion_Audit_Package__c(
            Package_Name__c = packageName,
            Framework__c = framework,
            Status__c = 'DRAFT',
            Audit_Period_Start__c = startDate,
            Audit_Period_End__c = endDate,
            Created_By__c = UserInfo.getUserId(),
            Last_Modified_By__c = UserInfo.getUserId()
        );
        
        try {
            insert auditPackage;
            
            // Generate framework mappings
            generateFrameworkMappings(auditPackage.Id, framework);
            
            // Collect evidence items
            collectEvidenceItems(auditPackage.Id, framework, startDate, endDate);
            
            return auditPackage.Id;
        } catch (DmlException e) {
            throw new AuraHandledException('Error creating audit package: ' + PrometheionSecurityUtils.getSafeDmlMessage(e));
        }
    }
    
    /**
     * Generate framework mappings for the audit package
     */
    private static void generateFrameworkMappings(Id auditPackageId, String framework) {
        // Get framework requirements from PrometheionFrameworkEngine
        List<PrometheionFrameworkEngine.FrameworkRequirement> requirements = 
            PrometheionFrameworkEngine.getFrameworkRequirements(framework);
        
        if (requirements == null || requirements.isEmpty()) {
            return;
        }
        
        PrometheionSecurityUtils.validateCRUDAccess('Prometheion_Framework_Mapping__c',
            PrometheionSecurityUtils.DmlOperation.DML_INSERT);
        
        List<Prometheion_Framework_Mapping__c> mappings = new List<Prometheion_Framework_Mapping__c>();
        
        for (PrometheionFrameworkEngine.FrameworkRequirement req : requirements) {
            mappings.add(new Prometheion_Framework_Mapping__c(
                Audit_Package__c = auditPackageId,
                Framework__c = framework,
                Requirement_Code__c = req.code,
                Requirement_Description__c = req.description,
                Entity_Type__c = req.entityType,
                Is_Active__c = true,
                Mapping_Metadata__c = JSON.serialize(req.metadata)
            ));
        }
        
        if (!mappings.isEmpty()) {
            insert mappings;
        }
    }
    
    /**
     * Collect evidence items for the audit package
     */
    private static void collectEvidenceItems(Id auditPackageId, String framework, Date startDate, Date endDate) {
        // Use EvidenceCollectionService to collect evidence
        List<Compliance_Evidence__c> evidenceList = EvidenceCollectionService.collectEvidence(
            framework, startDate, endDate);
        
        if (evidenceList == null || evidenceList.isEmpty()) {
            return;
        }
        
        PrometheionSecurityUtils.validateCRUDAccess('Prometheion_Evidence_Item__c',
            PrometheionSecurityUtils.DmlOperation.DML_INSERT);
        
        List<Prometheion_Evidence_Item__c> evidenceItems = new List<Prometheion_Evidence_Item__c>();
        
        for (Compliance_Evidence__c evidence : evidenceList) {
            evidenceItems.add(new Prometheion_Evidence_Item__c(
                Audit_Package__c = auditPackageId,
                Evidence_Type__c = evidence.Evidence_Type__c,
                Evidence_Date__c = evidence.Evidence_Date__c,
                Description__c = evidence.Description__c,
                Evidence_Data__c = evidence.Evidence_Data__c,
                File_Reference__c = evidence.File_Reference__c,
                Status__c = 'COLLECTED'
            ));
        }
        
        if (!evidenceItems.isEmpty()) {
            insert evidenceItems;
        }
    }
}
