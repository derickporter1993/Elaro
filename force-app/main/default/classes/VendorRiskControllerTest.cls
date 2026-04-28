/**
 * Test class for VendorRiskController. Validates AuraEnabled endpoint behavior
 * including success paths, error handling, and delegation to VendorRiskService.
 *
 * @author Elaro Team
 * @since v3.1.0 (Spring '26)
 * @group Vendor Risk
 * @see VendorRiskController
 */
@IsTest(testFor=VendorRiskController.class)
private class VendorRiskControllerTest {

    @TestSetup
    static void makeData() {
        List<Vendor_Compliance__c> vendors = new List<Vendor_Compliance__c>();

        Vendor_Compliance__c activeVendor = new Vendor_Compliance__c();
        activeVendor.Vendor_Name__c = 'Controller Test Vendor Active';
        activeVendor.Vendor_Type__c = 'CLOUD_SERVICE';
        activeVendor.Status__c = 'ACTIVE';
        activeVendor.Data_Processing_Agreement__c = true;
        activeVendor.Security_Certifications__c = 'SOC2 Type II';
        activeVendor.Compliance_Frameworks__c = 'SOC2;ISO27001';
        activeVendor.Next_Assessment_Date__c = Date.today().addDays(30);
        activeVendor.Last_Assessment_Date__c = Date.today().addDays(-60);
        activeVendor.Risk_Score__c = 2;
        vendors.add(activeVendor);

        Vendor_Compliance__c overdueVendor = new Vendor_Compliance__c();
        overdueVendor.Vendor_Name__c = 'Controller Test Vendor Overdue';
        overdueVendor.Vendor_Type__c = 'INTEGRATION';
        overdueVendor.Status__c = 'ACTIVE';
        overdueVendor.Data_Processing_Agreement__c = false;
        overdueVendor.Security_Certifications__c = '';
        overdueVendor.Compliance_Frameworks__c = 'HIPAA';
        overdueVendor.Next_Assessment_Date__c = Date.today().addDays(-15);
        overdueVendor.Last_Assessment_Date__c = null;
        overdueVendor.Risk_Score__c = 6;
        vendors.add(overdueVendor);

        Vendor_Compliance__c suspendedVendor = new Vendor_Compliance__c();
        suspendedVendor.Vendor_Name__c = 'Controller Test Vendor Suspended';
        suspendedVendor.Vendor_Type__c = 'DATA_PROCESSOR';
        suspendedVendor.Status__c = 'SUSPENDED';
        suspendedVendor.Data_Processing_Agreement__c = false;
        suspendedVendor.Security_Certifications__c = '';
        suspendedVendor.Compliance_Frameworks__c = '';
        suspendedVendor.Next_Assessment_Date__c = Date.today().addDays(-60);
        suspendedVendor.Last_Assessment_Date__c = null;
        suspendedVendor.Risk_Score__c = 9;
        vendors.add(suspendedVendor);

        insert as user vendors;
    }

    @IsTest
    static void shouldGetDashboardData() {
        Test.startTest();
        VendorRiskController.VendorDashboardData data = VendorRiskController.getDashboardData();
        Test.stopTest();

        Assert.isNotNull(data, 'Dashboard data should not be null');
        Assert.isNotNull(data.vendors, 'Vendors list should not be null');
        Assert.areEqual(3, data.vendors.size(), 'Should return all 3 test vendors');
        Assert.isNotNull(data.summary, 'Summary should not be null');
        Assert.areEqual(3, data.summary.totalVendors, 'Summary should count all vendors');
        Assert.areEqual(2, data.summary.activeVendors, 'Summary should count active vendors');
    }

    @IsTest
    static void shouldGetFilteredVendorsByStatus() {
        Test.startTest();
        List<Vendor_Compliance__c> results = VendorRiskController.getFilteredVendors('SUSPENDED', null);
        Test.stopTest();

        Assert.areEqual(1, results.size(), 'Should return 1 suspended vendor');
        Assert.areEqual('SUSPENDED', results[0].Status__c, 'Status should be SUSPENDED');
    }

    @IsTest
    static void shouldGetFilteredVendorsByType() {
        Test.startTest();
        List<Vendor_Compliance__c> results = VendorRiskController.getFilteredVendors(null, 'INTEGRATION');
        Test.stopTest();

        Assert.areEqual(1, results.size(), 'Should return 1 integration vendor');
        Assert.areEqual('INTEGRATION', results[0].Vendor_Type__c, 'Type should be INTEGRATION');
    }

    @IsTest
    static void shouldSaveVendor() {
        Vendor_Compliance__c newVendor = new Vendor_Compliance__c();
        newVendor.Vendor_Name__c = 'Controller Save Test Vendor';
        newVendor.Vendor_Type__c = 'CONSULTING';
        newVendor.Status__c = 'ACTIVE';
        newVendor.Data_Processing_Agreement__c = true;

        Test.startTest();
        Vendor_Compliance__c result = VendorRiskController.saveVendor(newVendor);
        Test.stopTest();

        Assert.isNotNull(result.Id, 'Saved vendor should have an Id');
    }

    @IsTest
    static void shouldThrowOnSaveWithBlankName() {
        Vendor_Compliance__c vendor = new Vendor_Compliance__c();
        vendor.Vendor_Name__c = '';
        vendor.Vendor_Type__c = 'OTHER';
        vendor.Status__c = 'ACTIVE';

        Test.startTest();
        try {
            VendorRiskController.saveVendor(vendor);
            Assert.fail('Should have thrown AuraHandledException');
        } catch (AuraHandledException e) {
            Assert.isTrue(e.getMessage().contains('Vendor name is required'),
                'Error should mention vendor name requirement');
        }
        Test.stopTest();
    }

    @IsTest
    static void shouldRefreshRiskScore() {
        Vendor_Compliance__c vendor = [
            SELECT Id FROM Vendor_Compliance__c
            WHERE Vendor_Name__c = 'Controller Test Vendor Overdue' WITH USER_MODE LIMIT 1
        ];

        Test.startTest();
        Vendor_Compliance__c result = VendorRiskController.refreshRiskScore(vendor.Id);
        Test.stopTest();

        Assert.isNotNull(result, 'Result should not be null');
        Assert.isNotNull(result.Risk_Score__c, 'Risk score should be populated');
        Assert.isTrue(result.Risk_Score__c > 0, 'Risk score should be positive for this vendor');
    }

    @IsTest
    static void shouldGetOverdueVendors() {
        Test.startTest();
        List<Vendor_Compliance__c> results = VendorRiskController.getOverdueVendors();
        Test.stopTest();

        // Only ACTIVE vendors with overdue assessments
        Assert.areEqual(1, results.size(), 'Should return 1 overdue active vendor');
        Assert.areEqual('Controller Test Vendor Overdue', results[0].Vendor_Name__c,
            'Overdue vendor should be the one with past due assessment');
    }

    @IsTest
    static void shouldHandleRefreshRiskScoreWithInvalidId() {
        Test.startTest();
        try {
            VendorRiskController.refreshRiskScore(UserInfo.getUserId());
            Assert.fail('Should have thrown AuraHandledException for invalid vendor Id');
        } catch (AuraHandledException e) {
            Assert.isNotNull(e.getMessage(), 'Error message should not be null');
        }
        Test.stopTest();
    }
}
