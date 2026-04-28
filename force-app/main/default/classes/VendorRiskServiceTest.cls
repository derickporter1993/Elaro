/**
 * Test class for VendorRiskService. Validates risk scoring, filtering,
 * summary analytics, and CRUD operations on Vendor_Compliance__c.
 *
 * @author Elaro Team
 * @since v3.1.0 (Spring '26)
 * @group Vendor Risk
 * @see VendorRiskService
 */
@IsTest(testFor=VendorRiskService.class)
private class VendorRiskServiceTest {

    @TestSetup
    static void makeData() {
        List<Vendor_Compliance__c> vendors = new List<Vendor_Compliance__c>();

        // High-risk vendor: no DPA, no certs, overdue, no assessment ever, missing critical frameworks
        Vendor_Compliance__c highRisk = new Vendor_Compliance__c();
        highRisk.Vendor_Name__c = 'High Risk Vendor';
        highRisk.Vendor_Type__c = 'CLOUD_SERVICE';
        highRisk.Status__c = 'ACTIVE';
        highRisk.Data_Processing_Agreement__c = false;
        highRisk.Security_Certifications__c = '';
        highRisk.Compliance_Frameworks__c = 'HIPAA';
        highRisk.Next_Assessment_Date__c = Date.today().addDays(-30);
        highRisk.Last_Assessment_Date__c = null;
        highRisk.Risk_Score__c = 0;
        vendors.add(highRisk);

        // Low-risk vendor: has DPA, certs, current assessment, has critical frameworks
        Vendor_Compliance__c lowRisk = new Vendor_Compliance__c();
        lowRisk.Vendor_Name__c = 'Low Risk Vendor';
        lowRisk.Vendor_Type__c = 'INTEGRATION';
        lowRisk.Status__c = 'ACTIVE';
        lowRisk.Data_Processing_Agreement__c = true;
        lowRisk.Security_Certifications__c = 'SOC2 Type II, ISO 27001';
        lowRisk.Compliance_Frameworks__c = 'SOC2;ISO27001;HIPAA';
        lowRisk.Next_Assessment_Date__c = Date.today().addDays(60);
        lowRisk.Last_Assessment_Date__c = Date.today().addDays(-30);
        lowRisk.Risk_Score__c = 0;
        vendors.add(lowRisk);

        // Suspended vendor
        Vendor_Compliance__c suspended = new Vendor_Compliance__c();
        suspended.Vendor_Name__c = 'Suspended Vendor';
        suspended.Vendor_Type__c = 'DATA_PROCESSOR';
        suspended.Status__c = 'SUSPENDED';
        suspended.Data_Processing_Agreement__c = false;
        suspended.Security_Certifications__c = '';
        suspended.Compliance_Frameworks__c = '';
        suspended.Next_Assessment_Date__c = Date.today().addDays(-90);
        suspended.Last_Assessment_Date__c = null;
        suspended.Risk_Score__c = 0;
        vendors.add(suspended);

        // Under review vendor
        Vendor_Compliance__c underReview = new Vendor_Compliance__c();
        underReview.Vendor_Name__c = 'Under Review Vendor';
        underReview.Vendor_Type__c = 'CONSULTING';
        underReview.Status__c = 'UNDER_REVIEW';
        underReview.Data_Processing_Agreement__c = true;
        underReview.Security_Certifications__c = 'ISO 27001';
        underReview.Compliance_Frameworks__c = 'SOC2;ISO27001';
        underReview.Next_Assessment_Date__c = Date.today().addDays(30);
        underReview.Last_Assessment_Date__c = Date.today().addDays(-60);
        underReview.Risk_Score__c = 2;
        vendors.add(underReview);

        insert as user vendors;
    }

    @IsTest
    static void shouldGetAllVendors() {
        VendorRiskService service = new VendorRiskService();

        Test.startTest();
        List<Vendor_Compliance__c> results = service.getVendors(null, null);
        Test.stopTest();

        Assert.areEqual(4, results.size(), 'Should return all 4 test vendors');
    }

    @IsTest
    static void shouldFilterVendorsByStatus() {
        VendorRiskService service = new VendorRiskService();

        Test.startTest();
        List<Vendor_Compliance__c> results = service.getVendors('ACTIVE', null);
        Test.stopTest();

        Assert.areEqual(2, results.size(), 'Should return 2 active vendors');
        for (Vendor_Compliance__c v : results) {
            Assert.areEqual('ACTIVE', v.Status__c, 'All results should have ACTIVE status');
        }
    }

    @IsTest
    static void shouldFilterVendorsByType() {
        VendorRiskService service = new VendorRiskService();

        Test.startTest();
        List<Vendor_Compliance__c> results = service.getVendors(null, 'CLOUD_SERVICE');
        Test.stopTest();

        Assert.areEqual(1, results.size(), 'Should return 1 cloud service vendor');
        Assert.areEqual('CLOUD_SERVICE', results[0].Vendor_Type__c, 'Result should be CLOUD_SERVICE type');
    }

    @IsTest
    static void shouldGetVendorById() {
        Vendor_Compliance__c existing = [
            SELECT Id FROM Vendor_Compliance__c WHERE Vendor_Name__c = 'Low Risk Vendor' WITH USER_MODE LIMIT 1
        ];
        VendorRiskService service = new VendorRiskService();

        Test.startTest();
        Vendor_Compliance__c result = service.getVendorById(existing.Id);
        Test.stopTest();

        Assert.isNotNull(result, 'Should return the vendor record');
        Assert.areEqual('Low Risk Vendor', result.Vendor_Name__c, 'Should return correct vendor');
    }

    @IsTest
    static void shouldReturnNullForInvalidId() {
        VendorRiskService service = new VendorRiskService();

        Test.startTest();
        Vendor_Compliance__c result = service.getVendorById(UserInfo.getUserId());
        Test.stopTest();

        Assert.isNull(result, 'Should return null for non-existent vendor Id');
    }

    @IsTest
    static void shouldCalculateRiskScoreForHighRisk() {
        Vendor_Compliance__c highRisk = [
            SELECT Id FROM Vendor_Compliance__c WHERE Vendor_Name__c = 'High Risk Vendor' WITH USER_MODE LIMIT 1
        ];
        VendorRiskService service = new VendorRiskService();

        Test.startTest();
        Vendor_Compliance__c result = service.calculateRiskScore(highRisk.Id);
        Test.stopTest();

        // no DPA (+2) + no certs (+2) + overdue (+1) + no assessment (+1) + missing SOC2 (+1) + missing ISO27001 (+1) = 8
        Assert.areEqual(8, result.Risk_Score__c, 'High risk vendor should score 8');
    }

    @IsTest
    static void shouldCalculateRiskScoreForLowRisk() {
        Vendor_Compliance__c lowRisk = [
            SELECT Id FROM Vendor_Compliance__c WHERE Vendor_Name__c = 'Low Risk Vendor' WITH USER_MODE LIMIT 1
        ];
        VendorRiskService service = new VendorRiskService();

        Test.startTest();
        Vendor_Compliance__c result = service.calculateRiskScore(lowRisk.Id);
        Test.stopTest();

        // has DPA (0) + has certs (0) + not overdue (0) + has assessment (0) + has SOC2 (0) + has ISO27001 (0) = 0
        Assert.areEqual(0, result.Risk_Score__c, 'Low risk vendor should score 0');
    }

    @IsTest
    static void shouldCapRiskScoreAtTen() {
        Vendor_Compliance__c suspended = [
            SELECT Id FROM Vendor_Compliance__c WHERE Vendor_Name__c = 'Suspended Vendor' WITH USER_MODE LIMIT 1
        ];
        VendorRiskService service = new VendorRiskService();

        Test.startTest();
        Vendor_Compliance__c result = service.calculateRiskScore(suspended.Id);
        Test.stopTest();

        // no DPA (+2) + no certs (+2) + overdue (+1) + no assessment (+1) + SUSPENDED (+2) + missing SOC2 (+1) + missing ISO27001 (+1) = 10 (capped)
        Assert.areEqual(10, result.Risk_Score__c, 'Risk score should be capped at 10');
        Assert.isTrue(result.Risk_Score__c <= 10, 'Risk score should never exceed 10');
    }

    @IsTest
    static void shouldGetOverdueAssessments() {
        VendorRiskService service = new VendorRiskService();

        Test.startTest();
        List<Vendor_Compliance__c> results = service.getOverdueAssessments();
        Test.stopTest();

        // Only ACTIVE vendors with overdue assessments: High Risk Vendor
        Assert.areEqual(1, results.size(), 'Should return 1 active vendor with overdue assessment');
        Assert.areEqual('High Risk Vendor', results[0].Vendor_Name__c, 'Overdue vendor should be High Risk Vendor');
    }

    @IsTest
    static void shouldGetVendorComplianceSummary() {
        VendorRiskService service = new VendorRiskService();

        Test.startTest();
        VendorRiskService.VendorSummary summary = service.getVendorComplianceSummary();
        Test.stopTest();

        Assert.areEqual(4, summary.totalVendors, 'Should count all 4 vendors');
        Assert.areEqual(2, summary.activeVendors, 'Should count 2 active vendors');
        Assert.isNotNull(summary.averageRiskScore, 'Average risk score should not be null');
        Assert.areEqual(1, summary.overdueCount, 'Should count 1 overdue active vendor');
    }

    @IsTest
    static void shouldSaveNewVendor() {
        VendorRiskService service = new VendorRiskService();

        Vendor_Compliance__c newVendor = new Vendor_Compliance__c();
        newVendor.Vendor_Name__c = 'Brand New Vendor';
        newVendor.Vendor_Type__c = 'OTHER';
        newVendor.Status__c = 'ACTIVE';
        newVendor.Data_Processing_Agreement__c = true;
        newVendor.Risk_Score__c = 3;

        Test.startTest();
        Vendor_Compliance__c result = service.saveVendor(newVendor);
        Test.stopTest();

        Assert.isNotNull(result.Id, 'Saved vendor should have an Id');
        List<Vendor_Compliance__c> verification = [
            SELECT Vendor_Name__c FROM Vendor_Compliance__c WHERE Id = :result.Id WITH USER_MODE
        ];
        Assert.areEqual(1, verification.size(), 'Vendor should exist in database');
        Assert.areEqual('Brand New Vendor', verification[0].Vendor_Name__c, 'Vendor name should match');
    }

    @IsTest
    static void shouldThrowOnBlankVendorName() {
        VendorRiskService service = new VendorRiskService();

        Vendor_Compliance__c vendor = new Vendor_Compliance__c();
        vendor.Vendor_Name__c = '';
        vendor.Vendor_Type__c = 'OTHER';
        vendor.Status__c = 'ACTIVE';

        Test.startTest();
        try {
            service.saveVendor(vendor);
            Assert.fail('Should have thrown AuraHandledException for blank vendor name');
        } catch (AuraHandledException e) {
            Assert.isTrue(e.getMessage().contains('Vendor name is required'),
                'Error message should mention vendor name requirement');
        }
        Test.stopTest();
    }
}
