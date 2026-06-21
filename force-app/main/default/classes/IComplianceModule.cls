/**
 * Interface for compliance framework modules
 * Each framework (HIPAA, SOC2, GDPR, etc.) implements this interface
 * @group Interfaces
 * @author Elaro Team
 * @since v3.1.0 (Spring '26)
 */
public interface IComplianceModule {
    
    /**
     * Get the framework name
     * @return Framework name (e.g., 'HIPAA', 'SOC2')
     */
    String getFrameworkName();
    
    /**
     * Get the framework version
     * @return Version string (e.g., '2.0', '2023')
     */
    String getFrameworkVersion();
    
    /**
     * Get all controls for this framework
     * @return List of Control objects
     */
    List<ComplianceModuleTypes.Control> getControls();
    
    /**
     * Calculate compliance score for an audit package
     * @param auditPackageId The audit package ID
     * @return Decimal score (0-100)
     */
    Decimal calculateScore(Id auditPackageId);
    
    /**
     * Identify compliance gaps
     * @param auditPackageId The audit package ID
     * @return List of Gap objects
     */
    List<ComplianceModuleTypes.Gap> identifyGaps(Id auditPackageId);
    
    /**
     * Generate framework-specific report
     * @param auditPackageId The audit package ID
     * @return PDF content as Blob
     */
    Blob generateReport(Id auditPackageId);
    
    /**
     * Get control by ID
     * @param controlId The control ID
     * @return Control object or null
     */
    ComplianceModuleTypes.Control getControlById(String controlId);
    
    /**
     * Evaluate a specific control
     * @param controlId The control ID
     * @param context Evaluation context
     * @return ControlResult with evaluation outcome
     */
    ComplianceModuleTypes.ControlResult evaluateControl(String controlId, Map<String, Object> context);
}
