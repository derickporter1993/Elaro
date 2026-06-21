/**
 * FINRA compliance module implementation
 * Covers Rule 3110 (Supervision), Rule 4511 (Books/Records), Rule 4370 (BCP)
 * @group Compliance Framework
 * @author Elaro Team
 * @since v3.1.0 (Spring '26)
 */
public with sharing class FINRAModule implements IComplianceModule {
    
    private static final String FRAMEWORK_NAME = 'FINRA';
    private static final String FRAMEWORK_VERSION = '2024';
    
    private static final List<IComplianceModule.Control> FINRA_CONTROLS;
    
    static {
        FINRA_CONTROLS = new List<IComplianceModule.Control>();
        
        // Rule 3110 - Supervision
        FINRA_CONTROLS.add(createControl('3110(a)', 'Supervisory System', 
            'Establish and maintain a supervisory system reasonably designed to achieve compliance', 
            'Supervision', 'CRITICAL'));
        FINRA_CONTROLS.add(createControl('3110(b)', 'Written Supervisory Procedures', 
            'Establish written procedures for supervision of business activities', 
            'Supervision', 'CRITICAL'));
        FINRA_CONTROLS.add(createControl('3110(c)', 'Internal Inspections', 
            'Conduct regular and periodic internal inspections', 
            'Supervision', 'HIGH'));
        FINRA_CONTROLS.add(createControl('3110(d)', 'Review of Correspondence', 
            'Review of customer correspondence and communications', 
            'Supervision', 'HIGH'));
        
        // Rule 4511 - Books and Records
        FINRA_CONTROLS.add(createControl('4511(a)', 'Record Keeping', 
            'Make and preserve books, accounts, records, memoranda as required by Rule 17a-4', 
            'Records', 'CRITICAL'));
        FINRA_CONTROLS.add(createControl('4511(b)', 'Record Retention', 
            'Preserve records for required time periods', 
            'Records', 'CRITICAL'));
        FINRA_CONTROLS.add(createControl('4511(c)', 'Record Accessibility', 
            'Records must be readily accessible for examination', 
            'Records', 'HIGH'));
        
        // Rule 4370 - Business Continuity
        FINRA_CONTROLS.add(createControl('4370(a)', 'Business Continuity Plan', 
            'Create and maintain a written business continuity plan', 
            'BCP', 'CRITICAL'));
        FINRA_CONTROLS.add(createControl('4370(b)', 'Annual Review', 
            'Conduct annual review of business continuity plan', 
            'BCP', 'HIGH'));
        FINRA_CONTROLS.add(createControl('4370(c)', 'Emergency Contact Information', 
            'Maintain emergency contact information', 
            'BCP', 'MEDIUM'));
    }
    
    public String getFrameworkName() { return FRAMEWORK_NAME; }
    public String getFrameworkVersion() { return FRAMEWORK_VERSION; }
    public List<IComplianceModule.Control> getControls() { return FINRA_CONTROLS; }
    
    public Decimal calculateScore(Id auditPackageId) {
        if (auditPackageId == null) {
            return 0;
        }
        
        Decimal totalScore = 0;
        Decimal totalWeight = 0;

        for (IComplianceModule.Control ctrl : FINRA_CONTROLS) {
            IComplianceModule.ControlResult result = evaluateControl(ctrl.code,
                new Map<String, Object>{ 'auditPackageId' => auditPackageId });

            // Controls that could not be evaluated are excluded from the denominator so
            // they neither inflate nor deflate the score (never counted as a silent pass).
            if (result.status == ElaroConstants.STATUS_NOT_EVALUATED) {
                continue;
            }

            Decimal weight = ctrl.severity == 'CRITICAL' ? 3 : ctrl.severity == 'HIGH' ? 2 : 1;
            totalWeight += weight;
            totalScore += weight * result.score / 100;
        }

        return totalWeight > 0 ? (totalScore / totalWeight) * 100 : 0;
    }
    
    public List<IComplianceModule.Gap> identifyGaps(Id auditPackageId) {
        List<IComplianceModule.Gap> gaps = new List<IComplianceModule.Gap>();
        
        for (IComplianceModule.Control ctrl : FINRA_CONTROLS) {
            IComplianceModule.ControlResult result = evaluateControl(ctrl.code, 
                new Map<String, Object>{ 'auditPackageId' => auditPackageId });
            
            if (!result.passed) {
                IComplianceModule.Gap gap = new IComplianceModule.Gap();
                gap.id = 'GAP-FINRA-' + ctrl.code;
                gap.controlId = ctrl.id;
                gap.controlCode = ctrl.code;
                gap.controlName = ctrl.name;
                gap.description = result.finding;
                gap.severity = ctrl.severity;
                // Distinguish a real failure from a control we simply could not verify.
                gap.status = (result.status == ElaroConstants.STATUS_NOT_EVALUATED)
                    ? 'Manual Review Required'
                    : 'Open';
                gap.recommendation = getFINRARecommendation(ctrl.code);
                gaps.add(gap);
            }
        }
        
        return gaps;
    }
    
    public Blob generateReport(Id auditPackageId) {
        PageReference pdfPage = Page.ElaroAuditPackagePDF;
        pdfPage.getParameters().put('id', auditPackageId);
        pdfPage.getParameters().put('framework', 'FINRA');
        return Test.isRunningTest() ? Blob.valueOf('FINRA Report') : pdfPage.getContentAsPDF();
    }
    
    public IComplianceModule.Control getControlById(String controlId) {
        for (IComplianceModule.Control ctrl : FINRA_CONTROLS) {
            if (ctrl.code == controlId) {
                return ctrl;
            }
        }
        return null;
    }
    
    public IComplianceModule.ControlResult evaluateControl(String controlId, Map<String, Object> context) {
        IComplianceModule.ControlResult result = new IComplianceModule.ControlResult();
        result.controlId = controlId;
        Id auditPackageId = (Id)context.get('auditPackageId');
        
        switch on controlId {
            when '3110(a)', '3110(b)' { result = evaluateSupervision(controlId, auditPackageId); }
            when '3110(d)' { result = evaluateCommunicationsReview(auditPackageId); }
            when '4511(a)', '4511(b)' { result = evaluateRecordKeeping(controlId, auditPackageId); }
            when '4370(a)', '4370(b)' { result = evaluateBCP(controlId, auditPackageId); }
            when else { result = defaultEvaluation(controlId, auditPackageId); }
        }
        
        return result;
    }
    
    private IComplianceModule.ControlResult evaluateSupervision(String ctrlId, Id pkgId) {
        IComplianceModule.ControlResult r = new IComplianceModule.ControlResult();
        r.controlId = ctrlId;
        
        // Check for supervision-related evidence
        Integer supervisoryEvidence = [
            SELECT COUNT() FROM Elaro_Evidence_Item__c
            WHERE Audit_Package__c = :pkgId
            AND (Evidence_Type__c = 'Supervision' OR Description__c LIKE '%supervis%')
            WITH USER_MODE
            LIMIT 100
        ];
        
        r.passed = supervisoryEvidence > 0;
        r.score = supervisoryEvidence > 0 ? 85 : 40;
        r.status = r.passed ? ElaroConstants.STATUS_COMPLIANT : ElaroConstants.STATUS_PARTIAL;
        r.finding = r.passed
            ? 'Supervisory procedures documented'
            : 'Written supervisory procedures should be documented';
        return r;
    }
    
    private IComplianceModule.ControlResult evaluateCommunicationsReview(Id pkgId) {
        IComplianceModule.ControlResult r = new IComplianceModule.ControlResult();
        r.controlId = '3110(d)';
        
        // Check the Setup Audit Trail for evidence of communication-review configuration
        // activity. The audit trail cannot prove correspondence was actually reviewed, so
        // a partial/positive signal is only justified when such activity exists; otherwise
        // we cannot attest to 3110(d) and report NOT_EVALUATED.
        Integer commReviews = [
            SELECT COUNT() FROM SetupAuditTrail
            WHERE CreatedDate >= LAST_N_DAYS:30
            AND (Action LIKE '%email%' OR Action LIKE '%message%')
            WITH USER_MODE
            LIMIT 100
        ];

        if (commReviews > 0) {
            r.passed = false;
            r.score = 50;
            r.status = ElaroConstants.STATUS_PARTIAL;
            r.finding = commReviews + ' communication-related configuration change(s) found '
                + 'in the last 30 days. Formal correspondence-review records are still '
                + 'required to fully satisfy 3110(d).';
        } else {
            r.passed = false;
            r.score = 0;
            r.status = ElaroConstants.STATUS_NOT_EVALUATED;
            r.finding = 'No communication-review activity could be detected. Provide '
                + 'correspondence-review records to evaluate 3110(d).';
        }
        return r;
    }
    
    private IComplianceModule.ControlResult evaluateRecordKeeping(String ctrlId, Id pkgId) {
        IComplianceModule.ControlResult r = new IComplianceModule.ControlResult();
        r.controlId = ctrlId;

        // FINRA 4511 / SEC Rule 17a-4 require specific retention periods and WORM-style
        // preservation. The Salesforce platform stores records, but it cannot prove from
        // Apex that retention policies, immutability, and required preservation periods are
        // configured. Base the verdict on collected record-keeping evidence; otherwise
        // report NOT_EVALUATED instead of asserting platform-provided compliance.
        Integer recordKeepingEvidence = [
            SELECT COUNT() FROM Elaro_Evidence_Item__c
            WHERE Audit_Package__c = :pkgId
            AND (Evidence_Type__c IN ('RecordRetention', 'BooksAndRecords', 'Retention')
                 OR Description__c LIKE '%retention%' OR Description__c LIKE '%17a-4%')
            WITH USER_MODE
            LIMIT 100
        ];

        if (recordKeepingEvidence > 0) {
            r.passed = true;
            r.score = 85;
            r.status = ElaroConstants.STATUS_COMPLIANT;
            r.finding = 'Record-keeping/retention evidence found (' + recordKeepingEvidence
                + ' item(s)) supporting books-and-records requirements.';
        } else {
            r.passed = false;
            r.score = 0;
            r.status = ElaroConstants.STATUS_NOT_EVALUATED;
            r.finding = 'Record-keeping compliance (retention periods and immutable '
                + 'preservation under FINRA 4511 / SEC Rule 17a-4) could not be verified '
                + 'from Apex. Attach retention-policy and preservation evidence to evaluate '
                + ctrlId + '.';
        }
        return r;
    }
    
    private IComplianceModule.ControlResult evaluateBCP(String ctrlId, Id pkgId) {
        IComplianceModule.ControlResult r = new IComplianceModule.ControlResult();
        r.controlId = ctrlId;
        
        Integer bcpEvidence = [
            SELECT COUNT() FROM Elaro_Evidence_Item__c
            WHERE Audit_Package__c = :pkgId
            AND (Evidence_Type__c = 'BCP' OR Description__c LIKE '%continuity%' OR Description__c LIKE '%disaster%')
            WITH USER_MODE
            LIMIT 100
        ];
        
        // A business continuity plan is a documented artifact; it can only be attested to
        // when BCP evidence has been collected. With no evidence, do NOT assume a partial
        // pass — report NOT_EVALUATED so the control is excluded from scoring and surfaced
        // for manual review.
        if (bcpEvidence > 0) {
            r.passed = true;
            r.score = 80;
            r.status = ElaroConstants.STATUS_COMPLIANT;
            r.finding = 'BCP documentation found (' + bcpEvidence + ' evidence item(s)).';
        } else {
            r.passed = false;
            r.score = 0;
            r.status = ElaroConstants.STATUS_NOT_EVALUATED;
            r.finding = 'No business continuity / disaster recovery evidence found for this '
                + 'audit package. Attach a documented BCP to evaluate ' + ctrlId + '.';
        }
        return r;
    }
    
    private IComplianceModule.ControlResult defaultEvaluation(String ctrlId, Id pkgId) {
        IComplianceModule.ControlResult r = new IComplianceModule.ControlResult();
        r.controlId = ctrlId;
        // No automated check exists for this control. Never default an unverified control
        // to a pass — report NOT_EVALUATED so it is excluded from the score denominator
        // and surfaced as a manual-review gap.
        r.passed = false;
        r.score = 0;
        r.status = ElaroConstants.STATUS_NOT_EVALUATED;
        r.finding = 'No automated evaluation is available for control ' + ctrlId
            + '. Manual review and supporting evidence are required to determine compliance.';
        return r;
    }
    
    private static IComplianceModule.Control createControl(String code, String name, String desc, String family, String sev) {
        IComplianceModule.Control c = new IComplianceModule.Control();
        c.id = code;
        c.code = code;
        c.name = name;
        c.description = desc;
        c.family = 'Rule ' + family;
        c.severity = sev;
        c.category = family;
        return c;
    }
    
    private String getFINRARecommendation(String code) {
        Map<String, String> recs = new Map<String, String>{
            '3110(a)' => 'Document supervisory system and responsibilities',
            '3110(b)' => 'Create written supervisory procedures manual',
            '3110(d)' => 'Implement communication review process',
            '4511(a)' => 'Ensure all required records are maintained',
            '4370(a)' => 'Develop comprehensive business continuity plan'
        };
        return recs.containsKey(code) ? recs.get(code) : 'Review FINRA rule requirements';
    }
}
