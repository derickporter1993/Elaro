/**
 * Implements IComplianceModule for AI Governance frameworks (EU AI Act and NIST AI RMF).
 * Provides automated discovery, risk classification, and compliance assessment
 * of AI systems deployed in Salesforce.
 *
 * @author Elaro Team
 * @since v1.0.0 (Spring '26)
 * @group AI Governance
 * @see IComplianceModule
 * @see AIDetectionEngine
 * @see AIRiskClassificationEngine
 */
public inherited sharing class AIGovernanceService implements IComplianceModule {

    private static final String FRAMEWORK_NAME = 'AI Governance';
    private static final String FRAMEWORK_VERSION = '1.0 (EU AI Act + NIST AI RMF)';

    /**
     * Gets the framework name.
     *
     * @return Framework name
     */
    public String getFrameworkName() {
        return FRAMEWORK_NAME;
    }

    /**
     * Gets the framework version.
     *
     * @return Framework version string
     */
    public String getFrameworkVersion() {
        return FRAMEWORK_VERSION;
    }

    /**
     * Gets all AI governance controls.
     *
     * @return List of Control objects for AI governance
     */
    public List<IComplianceModule.Control> getControls() {
        List<IComplianceModule.Control> controls = new List<IComplianceModule.Control>();

        // EU AI Act Controls
        controls.add(createControl('AI-001', 'AI System Registry', 'All AI systems must be registered and classified',
            'CRITICAL', 'EU AI Act', true));
        controls.add(createControl('AI-002', 'Risk Classification', 'AI systems must be risk-classified per Annex III',
            'CRITICAL', 'EU AI Act', true));
        controls.add(createControl('AI-003', 'Prohibited Uses', 'Unacceptable risk AI systems must be prohibited',
            'CRITICAL', 'EU AI Act', true));
        controls.add(createControl('AI-004', 'Human Oversight', 'High-risk AI requires human oversight mechanisms',
            'HIGH', 'EU AI Act', true));
        controls.add(createControl('AI-005', 'Transparency Obligations', 'Users must be informed of AI interaction',
            'MEDIUM', 'EU AI Act', true));

        // NIST AI RMF Controls
        controls.add(createControl('RMF-GOV-01', 'AI Governance Structure', 'Establish AI governance framework',
            'HIGH', 'NIST AI RMF', true));
        controls.add(createControl('RMF-MAP-01', 'AI Risk Mapping', 'Map AI risks and impacts',
            'HIGH', 'NIST AI RMF', true));
        controls.add(createControl('RMF-MEA-01', 'AI Performance Metrics', 'Measure AI system performance and accuracy',
            'MEDIUM', 'NIST AI RMF', true));
        controls.add(createControl('RMF-MAN-01', 'AI Risk Management', 'Manage identified AI risks',
            'HIGH', 'NIST AI RMF', true));

        return controls;
    }

    /**
     * Calculates AI governance compliance score.
     *
     * @param auditPackageId Not used (AI governance operates on detected systems)
     * @return Decimal compliance score 0-100
     */
    public Decimal calculateScore(Id auditPackageId) {
        try {
            // Discover AI systems
            List<AIDetectionEngine.AISystemMetadata> systems = AIDetectionEngine.discoverAISystems();

            if (systems.isEmpty()) {
                return 100.0; // No AI systems = full compliance
            }

            // Query existing registry entries
            List<AI_System_Registry__c> registeredSystems = [
                SELECT Id, Name, System_Type__c, Risk_Level__c, Status__c
                FROM AI_System_Registry__c
                WITH USER_MODE
            ];

            Integer registeredCount = registeredSystems.size();
            Integer detectedCount = systems.size();
            Integer classifiedCount = 0;

            for (AI_System_Registry__c system : registeredSystems) {
                if (String.isNotBlank(system.Risk_Level__c)) {
                    classifiedCount++;
                }
            }

            // Human oversight (AI-004) is verified against real AI_Human_Oversight_Record__c
            // data: count high-risk systems that actually have at least one oversight record,
            // rather than assuming oversight exists for any high-risk system.
            Integer highRiskCount = 0;
            Integer highRiskWithOversight = 0;
            for (AI_System_Registry__c system : [
                SELECT Id, Risk_Level__c,
                    (SELECT Id FROM Human_Oversight_Records__r LIMIT 1)
                FROM AI_System_Registry__c
                WHERE Risk_Level__c IN ('High', 'Unacceptable')
                WITH USER_MODE
            ]) {
                highRiskCount++;
                if (!system.Human_Oversight_Records__r.isEmpty()) {
                    highRiskWithOversight++;
                }
            }

            // Weighted score over dimensions Elaro can actually verify from org data:
            //   Registration (AI-001) = 40, Classification (AI-002) = 30, Oversight (AI-004) = 30.
            // Transparency (AI-005 — informing users of AI interaction) has NO programmatic
            // signal in this org model, so it is NOT fabricated and is EXCLUDED from the
            // denominator (flagged NOT_EVALUATED in identifyGaps / evaluateControl) instead of
            // silently adding a +10 that was never verified.
            Decimal registrationScore = detectedCount > 0 ?
                (Decimal.valueOf(registeredCount) / Decimal.valueOf(detectedCount)) * 40 : 40;
            Decimal classificationScore = registeredCount > 0 ?
                (Decimal.valueOf(classifiedCount) / Decimal.valueOf(registeredCount)) * 30 : 0;
            // No high-risk systems = oversight requirement not triggered, full credit for the
            // dimension; otherwise credit is proportional to high-risk systems with real records.
            Decimal oversightScore = highRiskCount > 0 ?
                (Decimal.valueOf(highRiskWithOversight) / Decimal.valueOf(highRiskCount)) * 30 : 30;

            // Denominator is 100 (40 + 30 + 30); transparency's 10 points are excluded.
            return registrationScore + classificationScore + oversightScore;

        } catch (Exception e) {
            ElaroLogger.error('AIGovernanceService.calculateScore', e.getMessage(), e.getStackTraceString());
            return 0.0;
        }
    }

    /**
     * Identifies AI governance gaps.
     *
     * @param auditPackageId Not used (AI governance operates on detected systems)
     * @return List of Gap objects
     */
    public List<IComplianceModule.Gap> identifyGaps(Id auditPackageId) {
        List<IComplianceModule.Gap> gaps = new List<IComplianceModule.Gap>();

        try {
            // Discover AI systems
            List<AIDetectionEngine.AISystemMetadata> systems = AIDetectionEngine.discoverAISystems();

            // Query registered systems
            Set<String> registeredSystemNames = new Set<String>();
            for (AI_System_Registry__c reg : [SELECT Name FROM AI_System_Registry__c WITH USER_MODE]) {
                registeredSystemNames.add(reg.Name);
            }

            // Find unregistered systems
            for (AIDetectionEngine.AISystemMetadata system : systems) {
                if (!registeredSystemNames.contains(system.systemName)) {
                    IComplianceModule.Gap gap = new IComplianceModule.Gap();
                    gap.id = 'GAP-' + system.systemName;
                    gap.controlId = 'AI-001';
                    gap.controlCode = 'AI-001';
                    gap.controlName = 'AI System Registry';
                    gap.description = 'AI system "' + system.systemName + '" detected but not registered';
                    gap.severity = 'HIGH';
                    gap.recommendation = 'Register this AI system in AI_System_Registry__c and complete risk classification';
                    gap.dueDate = Date.today().addDays(30);
                    gap.riskScore = 85.0;
                    gaps.add(gap);
                }
            }

            // Find systems missing risk classification
            for (AI_System_Registry__c system : [
                SELECT Id, Name, Risk_Level__c, System_Type__c
                FROM AI_System_Registry__c
                WHERE Risk_Level__c = null
                WITH USER_MODE
            ]) {
                IComplianceModule.Gap gap = new IComplianceModule.Gap();
                gap.id = 'GAP-RISK-' + system.Id;
                gap.controlId = 'AI-002';
                gap.controlCode = 'AI-002';
                gap.controlName = 'Risk Classification';
                gap.description = 'AI system "' + system.Name + '" missing EU AI Act risk classification';
                gap.severity = 'CRITICAL';
                gap.recommendation = 'Complete risk classification using AIRiskClassificationEngine';
                gap.dueDate = Date.today().addDays(14);
                gap.riskScore = 95.0;
                gaps.add(gap);
            }

            // Find high-risk systems without oversight
            for (AI_System_Registry__c system : [
                SELECT Id, Name, Risk_Level__c,
                    (SELECT Id FROM Human_Oversight_Records__r LIMIT 1)
                FROM AI_System_Registry__c
                WHERE Risk_Level__c IN ('High', 'Unacceptable')
                WITH USER_MODE
            ]) {
                if (system.Human_Oversight_Records__r.isEmpty()) {
                    IComplianceModule.Gap gap = new IComplianceModule.Gap();
                    gap.id = 'GAP-OVERSIGHT-' + system.Id;
                    gap.controlId = 'AI-004';
                    gap.controlCode = 'AI-004';
                    gap.controlName = 'Human Oversight';
                    gap.description = 'High-risk AI system "' + system.Name + '" lacks human oversight records';
                    gap.severity = 'CRITICAL';
                    gap.recommendation = 'Implement human oversight mechanism and log oversight decisions';
                    gap.dueDate = Date.today().addDays(7);
                    gap.riskScore = 90.0;
                    gaps.add(gap);
                }
            }

            // Transparency (AI-005) cannot be programmatically verified — surface it as a
            // manual-attestation item instead of silently scoring it as compliant.
            IComplianceModule.Gap transparencyGap = new IComplianceModule.Gap();
            transparencyGap.id = 'GAP-AI-005-TRANSPARENCY';
            transparencyGap.controlId = 'AI-005';
            transparencyGap.controlCode = 'AI-005';
            transparencyGap.controlName = 'Transparency Obligations';
            transparencyGap.description = 'Transparency obligation (informing users they are '
                + 'interacting with AI) could not be automatically verified. Requires manual '
                + 'attestation that AI disclosure notices are presented to end users.';
            transparencyGap.severity = 'MEDIUM';
            transparencyGap.recommendation = 'Document and attest the AI interaction disclosures '
                + 'shown to users; attach evidence to satisfy EU AI Act Article 50 transparency.';
            transparencyGap.status = 'Manual Review Required';
            transparencyGap.dueDate = Date.today().addDays(30);
            transparencyGap.riskScore = 50.0;
            gaps.add(transparencyGap);

        } catch (Exception e) {
            ElaroLogger.error('AIGovernanceService.identifyGaps', e.getMessage(), e.getStackTraceString());
        }

        return gaps;
    }

    /**
     * Generates AI governance compliance report.
     *
     * @param auditPackageId Not used
     * @return PDF report as Blob
     */
    public Blob generateReport(Id auditPackageId) {
        // Text summary report built from the real computed score and gaps. (A richer PDF
        // layout can be added later; the figures below are not fabricated.)
        String reportContent = 'AI Governance Compliance Report\n\n';
        reportContent += 'Framework: ' + FRAMEWORK_NAME + '\n';
        reportContent += 'Version: ' + FRAMEWORK_VERSION + '\n';
        reportContent += 'Generated: ' + Datetime.now().format() + '\n\n';

        Decimal score = calculateScore(auditPackageId);
        reportContent += 'Overall Compliance Score: ' + score.setScale(2) + '%\n\n';

        List<IComplianceModule.Gap> gaps = identifyGaps(auditPackageId);
        reportContent += 'Identified Gaps: ' + gaps.size() + '\n';

        return Blob.valueOf(reportContent);
    }

    /**
     * Gets a control by ID.
     *
     * @param controlId The control ID
     * @return Control object or null
     */
    public IComplianceModule.Control getControlById(String controlId) {
        List<IComplianceModule.Control> allControls = getControls();
        for (IComplianceModule.Control ctrl : allControls) {
            if (ctrl.id == controlId) {
                return ctrl;
            }
        }
        return null;
    }

    /**
     * Evaluates a specific AI governance control.
     *
     * @param controlId The control ID
     * @param context Evaluation context (may contain systemId, etc.)
     * @return ControlResult with evaluation outcome
     */
    public IComplianceModule.ControlResult evaluateControl(String controlId, Map<String, Object> context) {
        IComplianceModule.ControlResult result = new IComplianceModule.ControlResult();
        result.controlId = controlId;

        try {
            switch on controlId {
                when 'AI-001' { // AI System Registry
                    List<AIDetectionEngine.AISystemMetadata> detected = AIDetectionEngine.discoverAISystems();
                    List<AI_System_Registry__c> registered = [SELECT Id FROM AI_System_Registry__c WITH USER_MODE];
                    result.passed = (detected.size() == registered.size());
                    result.score = detected.size() > 0 ?
                        (Decimal.valueOf(registered.size()) / Decimal.valueOf(detected.size())) * 100 : 100;
                    result.status = result.passed
                        ? ElaroConstants.STATUS_COMPLIANT
                        : ElaroConstants.STATUS_PARTIAL;
                    result.finding = registered.size() + ' of ' + detected.size() + ' AI systems registered';
                }
                when 'AI-002' { // Risk Classification
                    List<AI_System_Registry__c> classified = [
                        SELECT Id FROM AI_System_Registry__c
                        WHERE Risk_Level__c != null WITH USER_MODE
                    ];
                    List<AI_System_Registry__c> total = [SELECT Id FROM AI_System_Registry__c WITH USER_MODE];
                    result.passed = (classified.size() == total.size());
                    result.score = total.size() > 0 ?
                        (Decimal.valueOf(classified.size()) / Decimal.valueOf(total.size())) * 100 : 0;
                    result.status = result.passed
                        ? ElaroConstants.STATUS_COMPLIANT
                        : ElaroConstants.STATUS_PARTIAL;
                    result.finding = classified.size() + ' of ' + total.size() + ' systems risk-classified';
                }
                when 'AI-004' { // Human Oversight — verified against real oversight records
                    Integer highRiskCount = 0;
                    Integer highRiskWithOversight = 0;
                    for (AI_System_Registry__c system : [
                        SELECT Id,
                            (SELECT Id FROM Human_Oversight_Records__r LIMIT 1)
                        FROM AI_System_Registry__c
                        WHERE Risk_Level__c IN ('High', 'Unacceptable')
                        WITH USER_MODE
                    ]) {
                        highRiskCount++;
                        if (!system.Human_Oversight_Records__r.isEmpty()) {
                            highRiskWithOversight++;
                        }
                    }
                    result.passed = (highRiskWithOversight == highRiskCount);
                    result.score = highRiskCount > 0 ?
                        (Decimal.valueOf(highRiskWithOversight) / Decimal.valueOf(highRiskCount)) * 100 : 100;
                    result.status = result.passed
                        ? ElaroConstants.STATUS_COMPLIANT
                        : ElaroConstants.STATUS_PARTIAL;
                    result.finding = highRiskWithOversight + ' of ' + highRiskCount
                        + ' high-risk AI systems have human oversight records';
                }
                when 'AI-005' { // Transparency Obligations — no programmatic signal available
                    // Informing users they are interacting with AI is a process/UX control
                    // that cannot be verified from org data. Report NOT_EVALUATED so it is
                    // excluded from scoring rather than fabricating a pass.
                    result.passed = false;
                    result.score = 0;
                    result.status = ElaroConstants.STATUS_NOT_EVALUATED;
                    result.finding = 'Transparency obligation requires manual attestation that '
                        + 'AI interaction disclosures are shown to users; cannot be verified '
                        + 'programmatically.';
                }
                when else {
                    // Controls without an automated check are reported NOT_EVALUATED (requires
                    // manual review), never NOT_APPLICABLE / passed, so they are excluded from
                    // scoring rather than silently treated as compliant.
                    result.passed = false;
                    result.score = 0;
                    result.status = ElaroConstants.STATUS_NOT_EVALUATED;
                    result.finding = 'No automated evaluation available for this control; '
                        + 'requires manual review and evidence.';
                }
            }
        } catch (Exception e) {
            ElaroLogger.error('AIGovernanceService.evaluateControl', e.getMessage(), e.getStackTraceString());
            result.passed = false;
            result.score = 0;
            result.status = ElaroConstants.STATUS_NON_COMPLIANT;
            result.finding = 'Evaluation failed: ' + e.getMessage();
        }

        return result;
    }

    /**
     * Helper method to create a control object.
     */
    private IComplianceModule.Control createControl(String id, String name, String description,
                                                      String severity, String category, Boolean required) {
        IComplianceModule.Control ctrl = new IComplianceModule.Control();
        ctrl.id = id;
        ctrl.code = id;
        ctrl.name = name;
        ctrl.description = description;
        ctrl.severity = severity;
        ctrl.category = category;
        ctrl.family = 'AI Governance';
        ctrl.isRequired = required;
        return ctrl;
    }
}
