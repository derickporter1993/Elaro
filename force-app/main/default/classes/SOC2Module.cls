/**
 * SOC 2 Type II compliance module implementation
 * Covers Trust Service Criteria (CC6, CC7, CC8, CC9)
 * @group Compliance Framework
 * @author Elaro Team
 * @since v3.1.0 (Spring '26)
 */
public with sharing class SOC2Module implements IComplianceModule {
    
    private static final String FRAMEWORK_NAME = 'SOC2';
    private static final String FRAMEWORK_VERSION = '2017';
    
    private static final List<IComplianceModule.Control> SOC2_CONTROLS;
    
    static {
        SOC2_CONTROLS = new List<IComplianceModule.Control>();
        
        // CC6 - Logical and Physical Access Controls
        SOC2_CONTROLS.add(createControl('CC6.1', 'Logical Access Security', 
            'The entity implements logical access security software and infrastructure', 
            'CC6', 'CRITICAL'));
        SOC2_CONTROLS.add(createControl('CC6.2', 'User Registration and Authorization', 
            'New internal and external users are registered and authorized', 
            'CC6', 'HIGH'));
        SOC2_CONTROLS.add(createControl('CC6.3', 'Credential Lifecycle Management', 
            'The entity grants credentials in accordance with authorization', 
            'CC6', 'HIGH'));
        SOC2_CONTROLS.add(createControl('CC6.6', 'System Boundary Protection', 
            'The entity restricts logical access to the system boundary', 
            'CC6', 'CRITICAL'));
        SOC2_CONTROLS.add(createControl('CC6.7', 'Change Management for Access', 
            'The entity restricts modification of configuration, management functionality', 
            'CC6', 'HIGH'));
        
        // CC7 - System Operations
        SOC2_CONTROLS.add(createControl('CC7.1', 'Detection of New Vulnerabilities', 
            'To meet its objectives, the entity uses detection and monitoring procedures', 
            'CC7', 'HIGH'));
        SOC2_CONTROLS.add(createControl('CC7.2', 'Monitoring System Components', 
            'The entity monitors system components and the operation of those components', 
            'CC7', 'CRITICAL'));
        SOC2_CONTROLS.add(createControl('CC7.3', 'Evaluation of Security Events', 
            'The entity evaluates security events to determine impact', 
            'CC7', 'HIGH'));
        SOC2_CONTROLS.add(createControl('CC7.4', 'Response to Security Incidents', 
            'The entity responds to identified security incidents', 
            'CC7', 'CRITICAL'));
        
        // CC8 - Change Management
        SOC2_CONTROLS.add(createControl('CC8.1', 'Change Authorization', 
            'The entity authorizes, designs, develops, implements changes', 
            'CC8', 'HIGH'));
        
        // CC9 - Risk Mitigation
        SOC2_CONTROLS.add(createControl('CC9.1', 'Risk Assessment and Analysis', 
            'The entity identifies, selects, and develops risk mitigation activities', 
            'CC9', 'HIGH'));
        SOC2_CONTROLS.add(createControl('CC9.2', 'Vendor Risk Management', 
            'The entity assesses and manages risks from vendors', 
            'CC9', 'MEDIUM'));
    }
    
    public String getFrameworkName() { return FRAMEWORK_NAME; }
    public String getFrameworkVersion() { return FRAMEWORK_VERSION; }
    public List<IComplianceModule.Control> getControls() { return SOC2_CONTROLS; }
    
    public Decimal calculateScore(Id auditPackageId) {
        if (auditPackageId == null) {
            return 0;
        }
        
        Decimal totalScore = 0;
        Decimal totalWeight = 0;

        for (IComplianceModule.Control ctrl : SOC2_CONTROLS) {
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
        
        for (IComplianceModule.Control ctrl : SOC2_CONTROLS) {
            IComplianceModule.ControlResult result = evaluateControl(ctrl.code, 
                new Map<String, Object>{ 'auditPackageId' => auditPackageId });
            
            if (!result.passed || result.status != ElaroConstants.STATUS_COMPLIANT) {
                IComplianceModule.Gap gap = new IComplianceModule.Gap();
                gap.id = 'GAP-SOC2-' + ctrl.code;
                gap.controlId = ctrl.id;
                gap.controlCode = ctrl.code;
                gap.controlName = ctrl.name;
                gap.description = result.finding;
                gap.severity = ctrl.severity;
                // Distinguish a real failure from a control we simply could not verify.
                gap.status = (result.status == ElaroConstants.STATUS_NOT_EVALUATED)
                    ? 'Manual Review Required'
                    : 'Open';
                gap.recommendation = getSOC2Recommendation(ctrl.code);
                gaps.add(gap);
            }
        }
        
        return gaps;
    }
    
    public Blob generateReport(Id auditPackageId) {
        PageReference pdfPage = Page.ElaroAuditPackagePDF;
        pdfPage.getParameters().put('id', auditPackageId);
        pdfPage.getParameters().put('framework', 'SOC2');
        return Test.isRunningTest() ? Blob.valueOf('SOC2 Report') : pdfPage.getContentAsPDF();
    }
    
    public IComplianceModule.Control getControlById(String controlId) {
        for (IComplianceModule.Control ctrl : SOC2_CONTROLS) {
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
            when 'CC6.1' { result = evaluateLogicalAccess(auditPackageId); }
            when 'CC7.2' { result = evaluateSystemMonitoring(auditPackageId); }
            when 'CC7.4' { result = evaluateIncidentResponse(auditPackageId); }
            when 'CC8.1' { result = evaluateChangeManagement(auditPackageId); }
            when else { result = defaultEvaluation(controlId, auditPackageId); }
        }
        
        return result;
    }
    
    private IComplianceModule.ControlResult evaluateLogicalAccess(Id pkgId) {
        IComplianceModule.ControlResult r = new IComplianceModule.ControlResult();
        r.controlId = 'CC6.1';
        
        Integer psaCount = [SELECT COUNT() FROM PermissionSetAssignment WITH USER_MODE LIMIT 1000];
        r.passed = psaCount > 0;
        r.score = r.passed ? 85 : 40;
        r.status = r.passed ? ElaroConstants.STATUS_COMPLIANT : ElaroConstants.STATUS_PARTIAL;
        r.finding = 'Permission set architecture in place';
        return r;
    }
    
    private IComplianceModule.ControlResult evaluateSystemMonitoring(Id pkgId) {
        IComplianceModule.ControlResult r = new IComplianceModule.ControlResult();
        r.controlId = 'CC7.2';
        
        Integer auditCount = [SELECT COUNT() FROM SetupAuditTrail WHERE CreatedDate >= LAST_N_DAYS:7 WITH USER_MODE LIMIT 1000];
        r.passed = auditCount > 100;
        r.score = Math.min(auditCount / 10, 100);
        r.status = r.passed ? ElaroConstants.STATUS_COMPLIANT : ElaroConstants.STATUS_PARTIAL;
        r.finding = auditCount + ' monitoring events in last 7 days';
        return r;
    }
    
    private IComplianceModule.ControlResult evaluateIncidentResponse(Id pkgId) {
        IComplianceModule.ControlResult r = new IComplianceModule.ControlResult();
        r.controlId = 'CC7.4';

        // CC7.4 (response to security incidents) cannot be confirmed from org config.
        // Base the verdict on collected incident-response evidence; if none exists, do
        // NOT assume procedures are in place — report NOT_EVALUATED.
        Integer incidentEvidence = [
            SELECT COUNT() FROM Elaro_Evidence_Item__c
            WHERE Audit_Package__c = :pkgId
            AND Evidence_Type__c IN ('Incident', 'SecurityIncident', 'IncidentResponse', 'Alert')
            WITH USER_MODE
            LIMIT 100
        ];

        if (incidentEvidence > 0) {
            r.passed = true;
            r.score = 85;
            r.status = ElaroConstants.STATUS_COMPLIANT;
            r.finding = 'Incident response documented with ' + incidentEvidence
                + ' evidence item(s).';
        } else {
            r.passed = false;
            r.score = 0;
            r.status = ElaroConstants.STATUS_NOT_EVALUATED;
            r.finding = 'No incident-response evidence found for this audit package. Attach '
                + 'documented incident response procedures and records to evaluate CC7.4.';
        }
        return r;
    }
    
    private IComplianceModule.ControlResult evaluateChangeManagement(Id pkgId) {
        IComplianceModule.ControlResult r = new IComplianceModule.ControlResult();
        r.controlId = 'CC8.1';

        // SetupAuditTrail records configuration changes/deployments. We can verify that
        // changes are being tracked, but the audit trail alone does not prove change
        // *authorization* (CC8.1 requires authorized, designed, tested changes). Treat the
        // presence of tracked changes as evidence of change management; absence means we
        // cannot attest to it, so report NOT_EVALUATED rather than fabricating a pass.
        Integer changeCount = [
            SELECT COUNT() FROM SetupAuditTrail
            WHERE CreatedDate >= LAST_N_DAYS:30
            WITH USER_MODE
            LIMIT 1000
        ];

        if (changeCount > 0) {
            r.passed = true;
            r.score = 80;
            r.status = ElaroConstants.STATUS_COMPLIANT;
            r.finding = changeCount + ' configuration change(s) recorded in the Setup Audit '
                + 'Trail in the last 30 days, evidencing tracked change management. Verify '
                + 'that change authorization/approval records support these changes.';
        } else {
            r.passed = false;
            r.score = 0;
            r.status = ElaroConstants.STATUS_NOT_EVALUATED;
            r.finding = 'No configuration changes were recorded in the Setup Audit Trail for '
                + 'the last 30 days, so change-management rigor (authorization, design, '
                + 'testing) could not be verified. Provide change-approval evidence to '
                + 'evaluate CC8.1.';
        }
        return r;
    }
    
    private IComplianceModule.ControlResult defaultEvaluation(String controlId, Id pkgId) {
        IComplianceModule.ControlResult r = new IComplianceModule.ControlResult();
        r.controlId = controlId;
        // No automated check exists for this control. Never default an unverified control
        // to a pass — report NOT_EVALUATED so it is excluded from the score denominator
        // and surfaced as a manual-review gap.
        r.passed = false;
        r.score = 0;
        r.status = ElaroConstants.STATUS_NOT_EVALUATED;
        r.finding = 'No automated evaluation is available for control ' + controlId
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
        c.category = 'Trust Service Criteria';
        return c;
    }
    
    private String getSOC2Recommendation(String code) {
        Map<String, String> recs = new Map<String, String>{
            'CC6.1' => 'Implement role-based access control and regular access reviews',
            'CC7.2' => 'Enable comprehensive logging and real-time monitoring alerts',
            'CC7.4' => 'Document incident response procedures and conduct tabletop exercises',
            'CC8.1' => 'Implement change approval workflows and deployment tracking'
        };
        return recs.containsKey(code) ? recs.get(code) : 'Review SOC 2 requirements and implement controls';
    }
}
