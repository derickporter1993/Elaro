/**
 * Lightning Web Component controller for the Vendor Risk Management dashboard.
 * Provides AuraEnabled endpoints for vendor CRUD, risk scoring, filtering,
 * and summary analytics. Delegates all business logic to {@link VendorRiskService}.
 *
 * @author Elaro Team
 * @since v3.1.0 (Spring '26)
 * @group Vendor Risk
 * @see VendorRiskService
 */
public with sharing class VendorRiskController {

    /**
     * Wrapper class combining vendor list and summary analytics for the dashboard.
     */
    public class VendorDashboardData {
        /** All vendor compliance records. */
        @AuraEnabled public List<Vendor_Compliance__c> vendors { get; set; }
        /** Aggregated compliance summary metrics. */
        @AuraEnabled public VendorRiskService.VendorSummary summary { get; set; }
    }

    /**
     * Retrieves all vendor records and summary analytics for the dashboard.
     *
     * @return VendorDashboardData containing vendors and summary
     * @throws AuraHandledException if data retrieval fails
     */
    @AuraEnabled(cacheable=true)
    public static VendorDashboardData getDashboardData() {
        try {
            VendorRiskService service = new VendorRiskService();
            VendorDashboardData data = new VendorDashboardData();
            data.vendors = service.getVendors(null, null);
            data.summary = service.getVendorComplianceSummary();
            return data;
        } catch (Exception e) {
            ElaroLogger.error('VendorRiskController.getDashboardData', e.getMessage(), e.getStackTraceString());
            throw new AuraHandledException('Unable to load vendor dashboard data. Please verify you have the required permissions and try again.');
        }
    }

    /**
     * Retrieves vendor records filtered by status and/or type.
     *
     * @param statusFilter Optional status picklist value (e.g. 'ACTIVE')
     * @param typeFilter Optional vendor type picklist value (e.g. 'CLOUD_SERVICE')
     * @return List of matching Vendor_Compliance__c records
     * @throws AuraHandledException if query fails
     */
    @AuraEnabled
    public static List<Vendor_Compliance__c> getFilteredVendors(String statusFilter, String typeFilter) {
        try {
            VendorRiskService service = new VendorRiskService();
            return service.getVendors(statusFilter, typeFilter);
        } catch (Exception e) {
            ElaroLogger.error('VendorRiskController.getFilteredVendors', e.getMessage(), e.getStackTraceString());
            throw new AuraHandledException('Unable to retrieve filtered vendors. Please try again.');
        }
    }

    /**
     * Saves (inserts or updates) a vendor compliance record.
     *
     * @param vendor The Vendor_Compliance__c record to save
     * @return The saved Vendor_Compliance__c record
     * @throws AuraHandledException if validation or DML fails
     */
    @AuraEnabled
    public static Vendor_Compliance__c saveVendor(Vendor_Compliance__c vendor) {
        try {
            VendorRiskService service = new VendorRiskService();
            return service.saveVendor(vendor);
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            ElaroLogger.error('VendorRiskController.saveVendor', e.getMessage(), e.getStackTraceString());
            throw new AuraHandledException('Unable to save vendor record. Please verify your input and try again.');
        }
    }

    /**
     * Recalculates and persists the risk score for a specific vendor, then returns the updated record.
     *
     * @param vendorId The Id of the Vendor_Compliance__c record
     * @return The updated Vendor_Compliance__c record with recalculated Risk_Score__c
     * @throws AuraHandledException if scoring or DML fails
     */
    @AuraEnabled
    public static Vendor_Compliance__c refreshRiskScore(Id vendorId) {
        try {
            VendorRiskService service = new VendorRiskService();
            return service.calculateRiskScore(vendorId);
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            ElaroLogger.error('VendorRiskController.refreshRiskScore', e.getMessage(), e.getStackTraceString());
            throw new AuraHandledException('Unable to refresh the risk score. Please try again.');
        }
    }

    /**
     * Retrieves active vendors with overdue assessment dates.
     *
     * @return List of Vendor_Compliance__c records with overdue assessments
     * @throws AuraHandledException if query fails
     */
    @AuraEnabled
    public static List<Vendor_Compliance__c> getOverdueVendors() {
        try {
            VendorRiskService service = new VendorRiskService();
            return service.getOverdueAssessments();
        } catch (Exception e) {
            ElaroLogger.error('VendorRiskController.getOverdueVendors', e.getMessage(), e.getStackTraceString());
            throw new AuraHandledException('Unable to retrieve overdue vendor assessments. Please try again.');
        }
    }
}
