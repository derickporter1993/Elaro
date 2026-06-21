/**
 * GDPR compliance module implementation
 * Covers DSR tracking (Articles 15-22), ROPA (Article 30), Breach Notification (Article 33)
 * @group Compliance Framework
 * @author Elaro Team
 * @since v3.1.0 (Spring '26)
 */
public with sharing class GDPRModule implements IComplianceModule {
    
    private static final String FRAMEWORK_NAME = 'GDPR';
    private static final String FRAMEWORK_VERSION = '2018';
    
    private static final List<IComplianceModule.Control> GDPR_CONTROLS;
    
    static {
        GDPR_CONTROLS = new List<IComplianceModule.Control>();
        
        // Lawfulness of Processing
        GDPR_CONTROLS.add(createControl('Art.5', 'Data Processing Principles', 
            'Personal data must be processed lawfully, fairly, and transparently', 
            'Principles', 'CRITICAL'));
        GDPR_CONTROLS.add(createControl('Art.6', 'Lawfulness of Processing', 
            'Processing shall be lawful with valid legal basis', 
            'Lawfulness', 'CRITICAL'));
        GDPR_CONTROLS.add(createControl('Art.7', 'Conditions for Consent', 
            'Controller must demonstrate consent was given', 
            'Consent', 'HIGH'));
        
        // Data Subject Rights (Articles 15-22)
        GDPR_CONTROLS.add(createControl('Art.15', 'Right of Access', 
            'Data subject has right to obtain confirmation and access to personal data', 
            'DSR', 'HIGH'));
        GDPR_CONTROLS.add(createControl('Art.16', 'Right to Rectification', 
            'Data subject has right to rectification of inaccurate data', 
            'DSR', 'MEDIUM'));
        GDPR_CONTROLS.add(createControl('Art.17', 'Right to Erasure', 
            'Data subject has right to erasure (right to be forgotten)', 
            'DSR', 'CRITICAL'));
        GDPR_CONTROLS.add(createControl('Art.18', 'Right to Restriction', 
            'Data subject has right to restrict processing', 
            'DSR', 'MEDIUM'));
        GDPR_CONTROLS.add(createControl('Art.20', 'Right to Data Portability', 
            'Data subject has right to receive their data in portable format', 
            'DSR', 'MEDIUM'));
        GDPR_CONTROLS.add(createControl('Art.21', 'Right to Object', 
            'Data subject has right to object to processing', 
            'DSR', 'HIGH'));
        
        // Security and Breach Notification
        GDPR_CONTROLS.add(createControl('Art.25', 'Data Protection by Design', 
            'Implement appropriate technical and organizational measures', 
            'Security', 'CRITICAL'));
        GDPR_CONTROLS.add(createControl('Art.30', 'Records of Processing (ROPA)', 
            'Maintain records of processing activities', 
            'Documentation', 'CRITICAL'));
        GDPR_CONTROLS.add(createControl('Art.32', 'Security of Processing', 
            'Implement appropriate security measures', 
            'Security', 'CRITICAL'));
        GDPR_CONTROLS.add(createControl('Art.33', 'Breach Notification to Authority', 
            'Notify supervisory authority within 72 hours of breach', 
            'Breach', 'CRITICAL'));
        GDPR_CONTROLS.add(createControl('Art.34', 'Breach Notification to Data Subject', 
            'Communicate breach to data subject when high risk', 
            'Breach', 'HIGH'));
        
        // DPO and Impact Assessments
        GDPR_CONTROLS.add(createControl('Art.35', 'Data Protection Impact Assessment', 
            'Carry out DPIA for high-risk processing', 
            'Assessment', 'HIGH'));
        GDPR_CONTROLS.add(createControl('Art.37', 'Designation of DPO', 
            'Designate a Data Protection Officer where required', 
            'Governance', 'HIGH'));
    }
    
    public String getFrameworkName() { return FRAMEWORK_NAME; }
    public String getFrameworkVersion() { return FRAMEWORK_VERSION; }
    public List<IComplianceModule.Control> getControls() { return GDPR_CONTROLS; }
    
    public Decimal calculateScore(Id auditPackageId) {
        if (auditPackageId == null) {
            return 0;
        }
        
        Decimal totalScore = 0;
        Decimal totalWeight = 0;

        for (IComplianceModule.Control ctrl : GDPR_CONTROLS) {
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
        
        for (IComplianceModule.Control ctrl : GDPR_CONTROLS) {
            IComplianceModule.ControlResult result = evaluateControl(ctrl.code, 
                new Map<String, Object>{ 'auditPackageId' => auditPackageId });
            
            if (!result.passed) {
                IComplianceModule.Gap gap = new IComplianceModule.Gap();
                gap.id = 'GAP-GDPR-' + ctrl.code;
                gap.controlId = ctrl.id;
                gap.controlCode = ctrl.code;
                gap.controlName = ctrl.name;
                gap.description = result.finding;
                gap.severity = ctrl.severity;
                // Distinguish a real failure from a control we simply could not verify.
                gap.status = (result.status == ElaroConstants.STATUS_NOT_EVALUATED)
                    ? 'Manual Review Required'
                    : 'Open';
                gap.recommendation = getGDPRRecommendation(ctrl.code);
                gaps.add(gap);
            }
        }
        
        return gaps;
    }
    
    public Blob generateReport(Id auditPackageId) {
        PageReference pdfPage = Page.ElaroAuditPackagePDF;
        pdfPage.getParameters().put('id', auditPackageId);
        pdfPage.getParameters().put('framework', 'GDPR');
        return Test.isRunningTest() ? Blob.valueOf('GDPR Report') : pdfPage.getContentAsPDF();
    }
    
    public IComplianceModule.Control getControlById(String controlId) {
        for (IComplianceModule.Control ctrl : GDPR_CONTROLS) {
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
            when 'Art.17' { result = evaluateRightToErasure(auditPackageId); }
            when 'Art.30' { result = evaluateROPA(auditPackageId); }
            when 'Art.32' { result = evaluateSecurityMeasures(auditPackageId); }
            when 'Art.33' { result = evaluateBreachNotification(auditPackageId); }
            when else { result = defaultEvaluation(controlId, auditPackageId); }
        }
        
        return result;
    }
    
    private IComplianceModule.ControlResult evaluateRightToErasure(Id pkgId) {
        IComplianceModule.ControlResult r = new IComplianceModule.ControlResult();
        r.controlId = 'Art.17';
        
        // Check for DSR handling capabilities
        Integer dsrEvidence = [
            SELECT COUNT() FROM Elaro_Evidence_Item__c
            WHERE Audit_Package__c = :pkgId
            AND (Evidence_Type__c = 'DSR' OR Evidence_Type__c = 'Erasure' OR Description__c LIKE '%deletion%')
            WITH USER_MODE
            LIMIT 100
        ];
        
        r.passed = dsrEvidence > 0;
        r.score = dsrEvidence > 0 ? 80 : 40;
        r.status = dsrEvidence > 0 ? ElaroConstants.STATUS_COMPLIANT : ElaroConstants.STATUS_PARTIAL;
        r.finding = dsrEvidence > 0
            ? 'Data erasure procedures documented'
            : 'Implement data erasure request handling process';
        return r;
    }
    
    private IComplianceModule.ControlResult evaluateROPA(Id pkgId) {
        IComplianceModule.ControlResult r = new IComplianceModule.ControlResult();
        r.controlId = 'Art.30';
        
        Integer ropaEvidence = [
            SELECT COUNT() FROM Elaro_Evidence_Item__c
            WHERE Audit_Package__c = :pkgId
            AND (Evidence_Type__c = 'ROPA' OR Description__c LIKE '%record of processing%')
            WITH USER_MODE
            LIMIT 100
        ];
        
        r.passed = ropaEvidence > 0;
        r.score = ropaEvidence > 0 ? 85 : 30;
        r.status = ropaEvidence > 0 ? ElaroConstants.STATUS_COMPLIANT : ElaroConstants.STATUS_NON_COMPLIANT;
        r.finding = ropaEvidence > 0
            ? 'ROPA documentation maintained'
            : 'Records of Processing Activities must be documented';
        return r;
    }
    
    private IComplianceModule.ControlResult evaluateSecurityMeasures(Id pkgId) {
        IComplianceModule.ControlResult r = new IComplianceModule.ControlResult();
        r.controlId = 'Art.32';

        // GDPR Art. 32 requires "appropriate technical and organisational measures"
        // (encryption, confidentiality, integrity, resilience, regular testing). The
        // Salesforce platform supplies a baseline, but Apex cannot confirm that the
        // org-specific configuration and organizational measures are appropriate. Base the
        // verdict on collected security evidence; otherwise report NOT_EVALUATED rather
        // than asserting platform-provided compliance.
        Integer securityEvidence = [
            SELECT COUNT() FROM Elaro_Evidence_Item__c
            WHERE Audit_Package__c = :pkgId
            AND (Evidence_Type__c IN ('Security', 'Encryption', 'AccessReview',
                                      'SecurityMeasure', 'PenTest')
                 OR Description__c LIKE '%encryption%' OR Description__c LIKE '%security measure%')
            WITH USER_MODE
            LIMIT 100
        ];

        if (securityEvidence > 0) {
            r.passed = true;
            r.score = 85;
            r.status = ElaroConstants.STATUS_COMPLIANT;
            r.finding = 'Security-measure evidence found (' + securityEvidence + ' item(s)) '
                + 'supporting Art. 32 technical and organizational measures.';
        } else {
            r.passed = false;
            r.score = 0;
            r.status = ElaroConstants.STATUS_NOT_EVALUATED;
            r.finding = 'Appropriateness of technical and organizational security measures '
                + '(Art. 32) could not be verified from Apex. The Salesforce platform '
                + 'provides a baseline, but documented evidence of encryption, access '
                + 'controls, resilience, and testing is required to evaluate this control.';
        }
        return r;
    }
    
    private IComplianceModule.ControlResult evaluateBreachNotification(Id pkgId) {
        IComplianceModule.ControlResult r = new IComplianceModule.ControlResult();
        r.controlId = 'Art.33';
        
        Integer breachProcEvidence = [
            SELECT COUNT() FROM Elaro_Evidence_Item__c
            WHERE Audit_Package__c = :pkgId
            AND (Evidence_Type__c = 'BreachProcedure' OR Description__c LIKE '%breach notification%')
            WITH USER_MODE
            LIMIT 100
        ];
        
        // Breach-notification readiness (Art. 33, 72-hour reporting) is a documented
        // procedure; it can only be attested to when evidence exists. Do NOT assume
        // procedures are in place — base the verdict on collected evidence and otherwise
        // report NOT_EVALUATED.
        if (breachProcEvidence > 0) {
            r.passed = true;
            r.score = 85;
            r.status = ElaroConstants.STATUS_COMPLIANT;
            r.finding = 'Breach-notification procedure evidence found ('
                + breachProcEvidence + ' item(s)) supporting Art. 33 72-hour reporting.';
        } else {
            r.passed = false;
            r.score = 0;
            r.status = ElaroConstants.STATUS_NOT_EVALUATED;
            r.finding = 'No breach-notification procedure evidence found for this audit '
                + 'package. Attach documented and tested 72-hour breach notification '
                + 'procedures to evaluate Art. 33.';
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
        c.family = family;
        c.severity = sev;
        c.category = 'GDPR ' + family;
        return c;
    }
    
    private String getGDPRRecommendation(String code) {
        Map<String, String> recs = new Map<String, String>{
            'Art.17' => 'Implement automated data deletion workflows and verification',
            'Art.30' => 'Create and maintain comprehensive Records of Processing Activities',
            'Art.32' => 'Document security measures and conduct regular security assessments',
            'Art.33' => 'Establish 72-hour breach notification procedures and test annually'
        };
        return recs.containsKey(code) ? recs.get(code) : 'Review GDPR requirements and document compliance';
    }
}
