/**
 * Test class for AIGovernanceService.
 *
 * @author Elaro Team
 * @since v1.0.0 (Spring '26)
 * @group AI Governance
 */
@IsTest(testFor=AIGovernanceService.class)
private class AIGovernanceServiceTest {

    @TestSetup
    static void makeData() {
        // Create test AI system registrations
        List<AI_System_Registry__c> systems = new List<AI_System_Registry__c>();

        AI_System_Registry__c system1 = new AI_System_Registry__c();
        system1.Name = 'Test Einstein Prediction';
        system1.System_Type__c = 'Einstein Prediction';
        system1.Detection_Method__c = 'Metadata API Scan';
        system1.Risk_Level__c = 'High';
        system1.Status__c = 'Active';
        system1.Use_Case_Description__c = 'Test prediction system';
        systems.add(system1);

        AI_System_Registry__c system2 = new AI_System_Registry__c();
        system2.Name = 'Test Einstein Bot';
        system2.System_Type__c = 'Einstein Bot';
        system2.Detection_Method__c = 'License Detection';
        system2.Risk_Level__c = 'Limited';
        system2.Status__c = 'Active';
        system2.Use_Case_Description__c = 'Customer service bot';
        systems.add(system2);

        insert as user systems;
    }

    @IsTest
    static void shouldReturnFrameworkName() {
        AIGovernanceService service = new AIGovernanceService();

        Test.startTest();
        String name = service.getFrameworkName();
        Test.stopTest();

        Assert.areEqual('AI Governance', name, 'Framework name should be AI Governance');
    }

    @IsTest
    static void shouldReturnFrameworkVersion() {
        AIGovernanceService service = new AIGovernanceService();

        Test.startTest();
        String version = service.getFrameworkVersion();
        Test.stopTest();

        Assert.isTrue(version.contains('EU AI Act'), 'Version should reference EU AI Act');
        Assert.isTrue(version.contains('NIST AI RMF'), 'Version should reference NIST AI RMF');
    }

    @IsTest
    static void shouldReturnControls() {
        AIGovernanceService service = new AIGovernanceService();

        Test.startTest();
        List<IComplianceModule.Control> controls = service.getControls();
        Test.stopTest();

        Assert.isTrue(controls.size() > 0, 'Should return multiple controls');

        Boolean hasEUControls = false;
        Boolean hasRMFControls = false;

        for (IComplianceModule.Control ctrl : controls) {
            if (ctrl.category == 'EU AI Act') {
                hasEUControls = true;
            }
            if (ctrl.category == 'NIST AI RMF') {
                hasRMFControls = true;
            }
        }

        Assert.isTrue(hasEUControls, 'Should include EU AI Act controls');
        Assert.isTrue(hasRMFControls, 'Should include NIST AI RMF controls');
    }

    @IsTest
    static void shouldCalculateComplianceScore() {
        AIGovernanceService service = new AIGovernanceService();

        Test.setMock(HttpCalloutMock.class, new ToolingApiMock());

        Test.startTest();
        Decimal score = service.calculateScore(null);
        Test.stopTest();

        Assert.isTrue(score >= 0 && score <= 100, 'Score should be between 0 and 100');
    }

    @IsTest
    static void shouldIdentifyGaps() {
        AIGovernanceService service = new AIGovernanceService();

        Test.setMock(HttpCalloutMock.class, new ToolingApiMock());

        Test.startTest();
        List<IComplianceModule.Gap> gaps = service.identifyGaps(null);
        Test.stopTest();

        Assert.isNotNull(gaps, 'Should return list of gaps');
    }

    @IsTest
    static void shouldGenerateReport() {
        AIGovernanceService service = new AIGovernanceService();

        Test.startTest();
        Blob reportBlob = service.generateReport(null);
        Test.stopTest();

        Assert.isNotNull(reportBlob, 'Should generate report');
        String reportContent = reportBlob.toString();
        Assert.isTrue(reportContent.contains('AI Governance'), 'Report should contain framework name');
    }

    @IsTest
    static void shouldGetControlById() {
        AIGovernanceService service = new AIGovernanceService();

        Test.startTest();
        IComplianceModule.Control ctrl = service.getControlById('AI-001');
        Test.stopTest();

        Assert.isNotNull(ctrl, 'Should return control AI-001');
        Assert.areEqual('AI-001', ctrl.id, 'Control ID should match');
    }

    @IsTest
    static void shouldReturnNullForInvalidControlId() {
        AIGovernanceService service = new AIGovernanceService();

        Test.startTest();
        IComplianceModule.Control ctrl = service.getControlById('INVALID-999');
        Test.stopTest();

        Assert.isNull(ctrl, 'Should return null for invalid control ID');
    }

    @IsTest
    static void shouldEvaluateRegistryControl() {
        AIGovernanceService service = new AIGovernanceService();

        Test.setMock(HttpCalloutMock.class, new ToolingApiMock());

        Test.startTest();
        IComplianceModule.ControlResult result = service.evaluateControl('AI-001', new Map<String, Object>());
        Test.stopTest();

        Assert.isNotNull(result, 'Should return control result');
        Assert.areEqual('AI-001', result.controlId, 'Control ID should match');
        Assert.isNotNull(result.status, 'Status should be set');
    }

    @IsTest
    static void shouldEvaluateClassificationControl() {
        AIGovernanceService service = new AIGovernanceService();

        Test.startTest();
        IComplianceModule.ControlResult result = service.evaluateControl('AI-002', new Map<String, Object>());
        Test.stopTest();

        Assert.isNotNull(result, 'Should return control result');
        Assert.areEqual('AI-002', result.controlId, 'Control ID should match');
        Assert.isTrue(result.score >= 0 && result.score <= 100, 'Score should be valid');
    }

    @IsTest
    static void shouldHandleUnknownControlEvaluation() {
        AIGovernanceService service = new AIGovernanceService();

        Test.startTest();
        IComplianceModule.ControlResult result = service.evaluateControl('UNKNOWN-999', new Map<String, Object>());
        Test.stopTest();

        // A control with no automated check must NOT be silently passed or marked
        // NOT_APPLICABLE — it is NOT_EVALUATED so it is excluded from scoring.
        Assert.areEqual(ElaroConstants.STATUS_NOT_EVALUATED, result.status,
            'Unknown control should be NOT_EVALUATED, not a fabricated verdict');
        Assert.isFalse(result.passed, 'Unevaluated control must not be marked passed');
        Assert.isTrue(result.score == 0, 'Unevaluated control must not contribute score');
    }

    @IsTest
    static void shouldFlagTransparencyAsNotEvaluated() {
        AIGovernanceService service = new AIGovernanceService();

        Test.setMock(HttpCalloutMock.class, new ToolingApiMock());

        Test.startTest();
        IComplianceModule.ControlResult result = service.evaluateControl('AI-005', new Map<String, Object>());
        Test.stopTest();

        // Transparency has no programmatic signal — it must be NOT_EVALUATED, never a
        // fabricated +10 / pass.
        Assert.areEqual(ElaroConstants.STATUS_NOT_EVALUATED, result.status,
            'Transparency (AI-005) must be NOT_EVALUATED, not fabricated as compliant');
        Assert.isFalse(result.passed, 'Transparency must not be marked passed without evidence');
        Assert.isTrue(result.score == 0, 'Transparency must not contribute a placeholder score');
    }

    @IsTest
    static void shouldSurfaceTransparencyAsManualReviewGap() {
        AIGovernanceService service = new AIGovernanceService();

        Test.setMock(HttpCalloutMock.class, new ToolingApiMock());

        Test.startTest();
        List<IComplianceModule.Gap> gaps = service.identifyGaps(null);
        Test.stopTest();

        Boolean foundTransparencyGap = false;
        for (IComplianceModule.Gap gap : gaps) {
            if (gap.controlCode == 'AI-005') {
                foundTransparencyGap = true;
                Assert.areEqual('Manual Review Required', gap.status,
                    'Transparency gap should require manual review, not be auto-closed');
            }
        }
        Assert.isTrue(foundTransparencyGap,
            'Transparency obligation must be surfaced as a manual-attestation gap');
    }

    @IsTest
    static void shouldExcludeTransparencyFromScoreDenominator() {
        AIGovernanceService service = new AIGovernanceService();

        // Mock returns one detected AI system so the scorer runs the weighted path
        // (instead of the "no AI systems = 100" early return).
        Test.setMock(HttpCalloutMock.class, new DetectedSystemMock());

        Test.startTest();
        Decimal score = service.calculateScore(null);
        Test.stopTest();

        // The mock returns 1 detected system for each of the 5 AI metadata types => 5
        // detected. Registry has 2 systems, both risk-classified; one is High-risk with NO
        // oversight record. Verifiable dimensions only:
        //   registration  = (2/5) * 40 = 16
        //   classification = (2/2) * 30 = 30
        //   oversight     = (0/1) * 30 =  0   (no real oversight records)
        //   transparency  = EXCLUDED (no programmatic signal — no fabricated +10)
        // => 46. Under the old placeholder logic this would have been 16 + 30 + 20 + 10 = 76.
        Assert.isTrue(score == 46,
            'Score must reflect only verifiable dimensions (expected 46), got: ' + score);
        Assert.isTrue(score <= 70.0,
            'Score must not include fabricated oversight/transparency credit, got: ' + score);
    }

    @IsTest
    static void shouldEvaluateOversightFromRealRecords() {
        AIGovernanceService service = new AIGovernanceService();

        // Attach a real oversight record to the seeded High-risk system.
        AI_System_Registry__c highRisk = [
            SELECT Id FROM AI_System_Registry__c WHERE Risk_Level__c = 'High' LIMIT 1
        ];
        insert as user new AI_Human_Oversight_Record__c(
            AI_System__c = highRisk.Id,
            Human_Decision__c = 'Approved',
            Justification__c = 'Reviewed model output and confirmed accuracy'
        );

        Test.startTest();
        IComplianceModule.ControlResult result = service.evaluateControl('AI-004', new Map<String, Object>());
        Test.stopTest();

        Assert.areEqual('AI-004', result.controlId, 'Control ID should match');
        // The single High-risk system now has an oversight record, so the dimension is met.
        Assert.areEqual(ElaroConstants.STATUS_COMPLIANT, result.status,
            'Oversight should be COMPLIANT when high-risk systems have real oversight records');
        Assert.isTrue(result.passed, 'Oversight control should pass with real records present');
    }

    /**
     * Mock HTTP callout for Tooling API (no AI systems detected).
     */
    private class ToolingApiMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);

            Map<String, Object> response = new Map<String, Object>();
            response.put('records', new List<Map<String, Object>>());
            res.setBody(JSON.serialize(response));

            return res;
        }
    }

    /**
     * Mock that reports one detected AI system per Tooling metadata-type query, so the
     * scorer exercises the weighted path instead of the "no AI systems" early return.
     */
    private class DetectedSystemMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);

            Map<String, Object> record = new Map<String, Object>{
                'DeveloperName' => 'Detected_System',
                'Id' => '0Ai000000000001AAA',
                'NamespacePrefix' => null
            };
            Map<String, Object> response = new Map<String, Object>{
                'records' => new List<Map<String, Object>>{ record }
            };
            res.setBody(JSON.serialize(response));

            return res;
        }
    }
}
