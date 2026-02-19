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
    List<Control> getControls();
    
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
    List<Gap> identifyGaps(Id auditPackageId);
    
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
    Control getControlById(String controlId);
    
    /**
     * Evaluate a specific control
     * @param controlId The control ID
     * @param context Evaluation context
     * @return ControlResult with evaluation outcome
     */
    ControlResult evaluateControl(String controlId, Map<String, Object> context);
    
    // ═══════════════════════════════════════════════════════════════
    // INNER CLASSES
    // ═══════════════════════════════════════════════════════════════
    
    /**
     * Represents a compliance control
     */
    class Control {
        public String id;
        public String code;
        public String name;
        public String description;
        public String category;
        public String family;
        public String severity; // CRITICAL, HIGH, MEDIUM, LOW
        public Boolean isRequired;
        public List<String> relatedControls;
        public Map<String, Object> metadata;
        
        public Control() {
            this.relatedControls = new List<String>();
            this.metadata = new Map<String, Object>();
            this.isRequired = true;
        }
    }
    
    /**
     * Represents a compliance gap
     */
    class Gap {
        public String id;
        public String controlId;
        public String controlCode;
        public String controlName;
        public String description;
        public String severity;
        public String status;
        public String recommendation;
        public Date dueDate;
        public Decimal riskScore;
        
        public Gap() {
            this.status = 'Open';
        }
    }
    
    /**
     * Result of control evaluation
     */
    class ControlResult {
        public String controlId;
        public Boolean passed;
        public Decimal score;
        public String status; // COMPLIANT, NON_COMPLIANT, PARTIAL, NOT_APPLICABLE
        public String finding;
        public List<String> evidenceIds;
        public Datetime evaluatedAt;
        
        public ControlResult() {
            this.evidenceIds = new List<String>();
            this.evaluatedAt = Datetime.now();
        }
    }
}
