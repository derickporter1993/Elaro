/**
 * Shared DTOs for compliance framework modules.
 */
public inherited sharing class ComplianceModuleTypes {
    /**
     * Represents a compliance control.
     */
    public class Control {
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
     * Represents a compliance gap.
     */
    public class Gap {
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
     * Result of control evaluation.
     */
    public class ControlResult {
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
