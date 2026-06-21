/**
 * ComplianceDashboardControllerTest
 * 
 * Test class for ComplianceDashboardController
 * 
 * @author Elaro
 * @version 1.0
 */
@IsTest(testFor=ComplianceDashboardController.class)
private class ComplianceDashboardControllerTest {
    
    @TestSetup
    static void setupTestData() {
        // Create test gaps and evidence
        List<Compliance_Gap__c> gaps = ComplianceTestDataFactory.createComplianceGaps('SOX', 3);
        List<Compliance_Evidence__c> evidence = ComplianceTestDataFactory.createComplianceEvidence('SOX', 3);
        insert gaps;
        insert evidence;
    }
    
    @IsTest
    static void testGetDashboardSummary() {
        Test.startTest();
        ComplianceDashboardController.DashboardSummary summary = 
            ComplianceDashboardController.getDashboardSummary();
        Test.stopTest();
        
        Assert.areNotEqual(null, summary, 'Summary should not be null');
        Assert.areNotEqual(null, summary.lastUpdated, 'Last updated should not be null');
        Assert.areNotEqual(null, summary.frameworks, 'Frameworks should not be null');
    }
    
    @IsTest
    static void testGetFrameworkDashboard_Success() {
        Test.startTest();
        ComplianceDashboardController.FrameworkDashboardData data = 
            ComplianceDashboardController.getFrameworkDashboard('SOX');
        Test.stopTest();
        
        Assert.areNotEqual(null, data, 'Data should not be null');
        Assert.areEqual('SOX', data.framework, 'Framework should match');
        Assert.areNotEqual(null, data.evaluation, 'Evaluation should not be null');
        Assert.areNotEqual(null, data.gaps, 'Gaps should not be null');
        Assert.areNotEqual(null, data.evidence, 'Evidence should not be null');
    }
    
    @IsTest
    static void testGetFrameworkDashboard_BlankFramework() {
        Test.startTest();
        try {
            ComplianceDashboardController.getFrameworkDashboard('');
            Assert.fail( 'Should have thrown IllegalArgumentException');
        } catch (IllegalArgumentException e) {
            Assert.isTrue(e.getMessage().contains('blank'), 'Exception should mention blank framework');
        }
        Test.stopTest();
    }

    // ─── Permission Context Tests (System.runAs) ────────────────────────

    /**
     * getFrameworkDashboard queries Compliance_Gap__c / Compliance_Evidence__c
     * WITH USER_MODE. A Standard User without the Elaro User permission set has
     * no read access to those objects, so the call must raise an
     * AuraHandledException rather than return compliance data.
     */
    @IsTest
    static void testGetFrameworkDashboard_unauthorizedUserDenied() {
        User minimal = ComplianceTestDataFactory.createTestUser();
        insert minimal;

        Test.startTest();
        System.runAs(minimal) {
            try {
                ComplianceDashboardController.getFrameworkDashboard('SOX');
                Assert.fail('Unauthorized user should not read the framework dashboard');
            } catch (AuraHandledException e) {
                Assert.isNotNull(e.getMessage(), 'Should surface an authorization error');
            }
        }
        Test.stopTest();
    }

    /**
     * getDashboardSummary also queries the compliance objects WITH USER_MODE and
     * must deny an unauthorized user.
     */
    @IsTest
    static void testGetDashboardSummary_unauthorizedUserDenied() {
        User minimal = ComplianceTestDataFactory.createTestUser();
        insert minimal;

        Test.startTest();
        System.runAs(minimal) {
            try {
                ComplianceDashboardController.getDashboardSummary();
                Assert.fail('Unauthorized user should not read the dashboard summary');
            } catch (AuraHandledException e) {
                Assert.isNotNull(e.getMessage(), 'Should surface an authorization error');
            }
        }
        Test.stopTest();
    }

    /**
     * With the Elaro User permission set (read on the compliance objects) the
     * same otherwise-minimal user can load the framework dashboard.
     */
    @IsTest
    static void testGetFrameworkDashboard_authorizedUserSucceeds() {
        User authorized = ComplianceTestDataFactory.createTestUser();
        insert authorized;

        PermissionSet ps = [
            SELECT Id FROM PermissionSet WHERE Name = 'Elaro_User' LIMIT 1
        ];
        insert new PermissionSetAssignment(
            AssigneeId = authorized.Id, PermissionSetId = ps.Id
        );

        Test.startTest();
        System.runAs(authorized) {
            ComplianceDashboardController.FrameworkDashboardData data =
                ComplianceDashboardController.getFrameworkDashboard('SOX');
            Assert.isNotNull(data, 'Authorized user should receive framework data');
            Assert.areEqual('SOX', data.framework, 'Framework should match');
        }
        Test.stopTest();
    }
}
