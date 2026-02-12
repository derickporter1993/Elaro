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
            Integer oversightCount = 0;

            for (AI_System_Registry__c system : registeredSystems) {
                if (String.isNotBlank(system.Risk_Level__c)) {
                    classifiedCount++;
                }
                // Check for oversight records (placeholder for actual oversight validation)
                if (system.Risk_Level__c == 'High' || system.Risk_Level__c == 'Unacceptable') {
                    // Would check AI_Human_Oversight_Record__c here
                    oversightCount++;
                }
            }

            // Calculate weighted score
            Decimal registrationScore = detectedCount > 0 ?
                (Decimal.valueOf(registeredCount) / Decimal.valueOf(detectedCount)) * 40 : 40;
            Decimal classificationScore = registeredCount > 0 ?
                (Decimal.valueOf(classifiedCount) / Decimal.valueOf(registeredCount)) * 30 : 0;
            Decimal oversightScore = oversightCount > 0 ? 20 : 0;
            Decimal transparencyScore = 10; // Placeholder

            return registrationScore + classificationScore + oversightScore + transparencyScore;

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
        // Placeholder - would generate comprehensive PDF report
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
                    result.status = result.passed ? 'COMPLIANT' : 'PARTIAL';
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
                    result.status = result.passed ? 'COMPLIANT' : 'PARTIAL';
                    result.finding = classified.size() + ' of ' + total.size() + ' systems risk-classified';
                }
                when else {
                    result.passed = false;
                    result.score = 0;
                    result.status = 'NOT_APPLICABLE';
                    result.finding = 'Control evaluation not implemented';
                }
            }
        } catch (Exception e) {
            ElaroLogger.error('AIGovernanceService.evaluateControl', e.getMessage(), e.getStackTraceString());
            result.passed = false;
            result.score = 0;
            result.status = 'NON_COMPLIANT';
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
