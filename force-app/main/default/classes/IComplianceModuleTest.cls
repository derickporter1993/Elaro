/**
 * Integration tests for {@link IComplianceModule} verifying that concrete module
 * implementations fulfill the interface contract. Uses dynamic Type.forName()
 * to remain decoupled from vertical packages.
 *
 * @author Elaro Team
 * @since v3.1.0 (Spring '26)
 * @group Compliance Framework
 * @see IComplianceModule
 * @see ComplianceServiceFactory
 */
@IsTest(testFor=IComplianceModule.class)
private class IComplianceModuleTest {

    private static IComplianceModule createModule(String className) {
        Type t = Type.forName(className);
        if (t == null) {
            return null;
        }
        return (IComplianceModule)t.newInstance();
    }

    @IsTest
    static void shouldReturnFrameworkNameAndVersionForAvailableModules() {
        Map<String, String> moduleMap = new Map<String, String>{
            'HIPAAModule' => 'HIPAA',
            'SOC2Module' => 'SOC2',
            'GDPRModule' => 'GDPR'
        };

        Test.startTest();
        for (String className : moduleMap.keySet()) {
            IComplianceModule mod = createModule(className);
            if (mod == null) {
                continue;
            }
            String expectedName = moduleMap.get(className);
            Assert.areEqual(expectedName, mod.getFrameworkName(),
                className + ' should return ' + expectedName + ' as framework name');
            Assert.isNotNull(mod.getFrameworkVersion(),
                className + ' should return a non-null version');
        }
        Test.stopTest();
    }

    @IsTest
    static void shouldReturnNonEmptyControlsForAvailableModules() {
        List<String> moduleClasses = new List<String>{'HIPAAModule', 'SOC2Module', 'GDPRModule'};

        Test.startTest();
        for (String className : moduleClasses) {
            IComplianceModule mod = createModule(className);
            if (mod == null) {
                continue;
            }
            List<ComplianceModuleTypes.Control> controls = mod.getControls();
            Assert.isNotNull(controls, className + ' controls should not be null');
            Assert.isFalse(controls.isEmpty(), className + ' should have at least one control');

            for (ComplianceModuleTypes.Control ctrl : controls) {
                Assert.isNotNull(ctrl.code, className + ' control code should not be null');
                Assert.isNotNull(ctrl.name, className + ' control name should not be null');
                Assert.isNotNull(ctrl.severity, className + ' control severity should not be null');
            }
        }
        Test.stopTest();
    }

    @IsTest
    static void shouldReturnControlByIdAndNullForInvalidId() {
        IComplianceModule hipaa = createModule('HIPAAModule');
        IComplianceModule soc2 = createModule('SOC2Module');

        Test.startTest();
        if (hipaa != null) {
            ComplianceModuleTypes.Control hipaaCtrl = hipaa.getControlById('164.312(a)');
            ComplianceModuleTypes.Control hipaaNull = hipaa.getControlById('INVALID_CONTROL_ID');
            Assert.isNotNull(hipaaCtrl, 'Should find HIPAA control 164.312(a)');
            Assert.areEqual('164.312(a)', hipaaCtrl.code, 'Control code should match 164.312(a)');
            Assert.isNull(hipaaNull, 'Should return null for invalid HIPAA control ID');
        }
        if (soc2 != null) {
            ComplianceModuleTypes.Control soc2Ctrl = soc2.getControlById('CC6.1');
            ComplianceModuleTypes.Control soc2Null = soc2.getControlById('NONEXISTENT');
            Assert.isNotNull(soc2Ctrl, 'Should find SOC2 control CC6.1');
            Assert.areEqual('CC6.1', soc2Ctrl.code, 'Control code should match CC6.1');
            Assert.isNull(soc2Null, 'Should return null for invalid SOC2 control ID');
        }
        Test.stopTest();
    }

    @IsTest
    static void shouldCalculateScoreAsZeroForNullAuditPackageId() {
        List<String> moduleClasses = new List<String>{'HIPAAModule', 'SOC2Module', 'GDPRModule'};

        Test.startTest();
        for (String className : moduleClasses) {
            IComplianceModule mod = createModule(className);
            if (mod == null) {
                continue;
            }
            Decimal score = mod.calculateScore(null);
            Assert.areEqual(0, score, className + ' score should be 0 for null audit package');
        }
        Test.stopTest();
    }

    @IsTest
    static void shouldEvaluateControlAndReturnValidResult() {
        IComplianceModule hipaa = createModule('HIPAAModule');
        if (hipaa == null) {
            return;
        }

        Map<String, Object> context = new Map<String, Object>{
            'auditPackageId' => null
        };

        Test.startTest();
        ComplianceModuleTypes.ControlResult result = hipaa.evaluateControl(
            '164.312(e)', context
        );
        Test.stopTest();

        Assert.isNotNull(result, 'Control evaluation result should not be null');
        Assert.areEqual('164.312(e)', result.controlId, 'Result controlId should match requested control');
        Assert.isNotNull(result.status, 'Result status should not be null');
        Assert.isNotNull(result.finding, 'Result finding should not be null');
        Assert.isNotNull(result.evaluatedAt, 'Result evaluatedAt should be set');
    }

    @IsTest
    static void shouldGenerateReportBlobInTestContext() {
        List<String> moduleClasses = new List<String>{'HIPAAModule', 'SOC2Module', 'GDPRModule'};
        Id fakeId = '001000000000001AAA';

        Test.startTest();
        for (String className : moduleClasses) {
            IComplianceModule mod = createModule(className);
            if (mod == null) {
                continue;
            }
            Blob report = mod.generateReport(fakeId);
            Assert.isNotNull(report, className + ' report blob should not be null');
            Assert.isTrue(report.size() > 0, className + ' report blob should have content');
        }
        Test.stopTest();
    }

    @IsTest
    static void shouldVerifyFactoryReturnsServicesForSupportedFrameworks() {
        Test.startTest();
        Set<String> supportedFrameworks = ComplianceServiceFactory.getSupportedFrameworks();
        Boolean hipaaSupported = ComplianceServiceFactory.isFrameworkSupported('HIPAA');
        Boolean soc2Supported = ComplianceServiceFactory.isFrameworkSupported('SOC2');
        Boolean gdprSupported = ComplianceServiceFactory.isFrameworkSupported('GDPR');
        Boolean invalidSupported = ComplianceServiceFactory.isFrameworkSupported('INVALID');
        Boolean nullSupported = ComplianceServiceFactory.isFrameworkSupported(null);
        Test.stopTest();

        Assert.isNotNull(supportedFrameworks, 'Supported frameworks set should not be null');
        Assert.isFalse(supportedFrameworks.isEmpty(), 'Supported frameworks should not be empty');
        Assert.isTrue(hipaaSupported, 'HIPAA should be a supported framework');
        Assert.isTrue(soc2Supported, 'SOC2 should be a supported framework');
        Assert.isTrue(gdprSupported, 'GDPR should be a supported framework');
        Assert.isFalse(invalidSupported, 'INVALID should not be a supported framework');
        Assert.isFalse(nullSupported, 'null should not be a supported framework');
    }

    @IsTest
    static void shouldThrowWhenFactoryReceivesBlankFramework() {
        Test.startTest();
        try {
            ComplianceServiceFactory.getService('');
            Assert.fail('Should have thrown ComplianceServiceException for blank framework');
        } catch (ComplianceServiceFactory.ComplianceServiceException e) {
            Assert.isTrue(
                e.getMessage().contains('blank'),
                'Error should mention blank: ' + e.getMessage()
            );
        }
        Test.stopTest();
    }

    @IsTest
    static void shouldVerifyInnerClassDefaults() {
        Test.startTest();
        ComplianceModuleTypes.Control control = new ComplianceModuleTypes.Control();
        ComplianceModuleTypes.Gap gap = new ComplianceModuleTypes.Gap();
        ComplianceModuleTypes.ControlResult result = new ComplianceModuleTypes.ControlResult();
        Test.stopTest();

        Assert.isNotNull(control.relatedControls, 'Control relatedControls should be initialized');
        Assert.isNotNull(control.metadata, 'Control metadata should be initialized');
        Assert.isTrue(control.isRequired, 'Control isRequired should default to true');
        Assert.areEqual('Open', gap.status, 'Gap status should default to Open');
        Assert.isNotNull(result.evidenceIds, 'ControlResult evidenceIds should be initialized');
        Assert.isNotNull(result.evaluatedAt, 'ControlResult evaluatedAt should be initialized');
    }
}
