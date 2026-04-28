/**
 * Service class for Vendor Risk Management operations. Provides CRUD, risk scoring,
 * filtering, and summary analytics for Vendor_Compliance__c records.
 *
 * @author Elaro Team
 * @since v3.1.0 (Spring '26)
 * @group Vendor Risk
 * @see VendorRiskController
 * @see Vendor_Compliance__c
 */
public inherited sharing class VendorRiskService {

    private static final Decimal MAX_RISK_SCORE = 10.0;
    private static final Decimal HIGH_RISK_THRESHOLD = 7.0;
    private static final Set<String> CRITICAL_FRAMEWORKS = new Set<String>{ 'SOC2', 'ISO27001' };

    /**
     * Wrapper class containing vendor compliance summary analytics.
     */
    public class VendorSummary {
        /** Total number of vendor records. */
        @AuraEnabled public Integer totalVendors { get; set; }
        /** Number of vendors with ACTIVE status. */
        @AuraEnabled public Integer activeVendors { get; set; }
        /** Mean risk score across all vendors. */
        @AuraEnabled public Decimal averageRiskScore { get; set; }
        /** Number of active vendors with overdue next assessment date. */
        @AuraEnabled public Integer overdueCount { get; set; }
        /** Number of vendors with risk score >= 7. */
        @AuraEnabled public Integer highRiskCount { get; set; }
    }

    /**
     * Retrieves vendor compliance records with optional status and type filters.
     *
     * @param statusFilter Optional status picklist value to filter by (e.g. 'ACTIVE')
     * @param typeFilter Optional vendor type picklist value to filter by (e.g. 'CLOUD_SERVICE')
     * @return List of Vendor_Compliance__c records matching the filters
     */
    public List<Vendor_Compliance__c> getVendors(String statusFilter, String typeFilter) {
        String query = 'SELECT Id, Name, Vendor_Name__c, Vendor_Type__c, Compliance_Frameworks__c, '
            + 'Risk_Score__c, Status__c, Last_Assessment_Date__c, Next_Assessment_Date__c, '
            + 'Assessment_Notes__c, Contract_Reference__c, Data_Processing_Agreement__c, '
            + 'Security_Certifications__c, Owner__c '
            + 'FROM Vendor_Compliance__c';

        List<String> conditions = new List<String>();
        Map<String, Object> binds = new Map<String, Object>();

        if (String.isNotBlank(statusFilter)) {
            conditions.add('Status__c = :statusFilter');
            binds.put('statusFilter', statusFilter);
        }
        if (String.isNotBlank(typeFilter)) {
            conditions.add('Vendor_Type__c = :typeFilter');
            binds.put('typeFilter', typeFilter);
        }

        if (!conditions.isEmpty()) {
            query += ' WHERE ' + String.join(conditions, ' AND ');
        }

        query += ' WITH USER_MODE ORDER BY Risk_Score__c DESC NULLS LAST, Vendor_Name__c ASC LIMIT 1000';

        return Database.queryWithBinds(query, binds, AccessLevel.USER_MODE);
    }

    /**
     * Retrieves a single vendor compliance record by Id.
     *
     * @param vendorId The Id of the Vendor_Compliance__c record
     * @return The vendor record, or null if not found
     */
    public Vendor_Compliance__c getVendorById(Id vendorId) {
        List<Vendor_Compliance__c> vendors = [
            SELECT Id, Name, Vendor_Name__c, Vendor_Type__c, Compliance_Frameworks__c,
                Risk_Score__c, Status__c, Last_Assessment_Date__c, Next_Assessment_Date__c,
                Assessment_Notes__c, Contract_Reference__c, Data_Processing_Agreement__c,
                Security_Certifications__c, Owner__c
            FROM Vendor_Compliance__c
            WHERE Id = :vendorId
            WITH USER_MODE
            LIMIT 1
        ];
        return vendors.isEmpty() ? null : vendors[0];
    }

    /**
     * Calculates and persists a risk score (0-10) for the specified vendor based on
     * multiple compliance factors: DPA status, certifications, assessment cadence,
     * suspension status, and critical framework coverage.
     *
     * @param vendorId The Id of the Vendor_Compliance__c record to score
     * @return The updated Vendor_Compliance__c record with new Risk_Score__c
     * @throws AuraHandledException if the vendor is not found
     */
    public Vendor_Compliance__c calculateRiskScore(Id vendorId) {
        Vendor_Compliance__c vendor = getVendorById(vendorId);
        if (vendor == null) {
            throw new AuraHandledException('Vendor not found for Id: ' + vendorId);
        }

        Decimal score = 0;

        // +2 if no DPA
        if (vendor.Data_Processing_Agreement__c == false) {
            score += 2;
        }

        // +2 if no certifications
        if (String.isBlank(vendor.Security_Certifications__c)) {
            score += 2;
        }

        // +1 if assessment overdue
        if (vendor.Next_Assessment_Date__c != null && vendor.Next_Assessment_Date__c < Date.today()) {
            score += 1;
        }

        // +1 if no assessment ever
        if (vendor.Last_Assessment_Date__c == null) {
            score += 1;
        }

        // +2 if status is SUSPENDED
        if (vendor.Status__c == 'SUSPENDED') {
            score += 2;
        }

        // +1 per missing critical framework (SOC2, ISO27001)
        String frameworks = vendor.Compliance_Frameworks__c ?? '';
        for (String critical : CRITICAL_FRAMEWORKS) {
            if (!frameworks.contains(critical)) {
                score += 1;
            }
        }

        // Cap at 10
        score = Math.min(score, MAX_RISK_SCORE);

        vendor.Risk_Score__c = score;
        update as user vendor;

        return vendor;
    }

    /**
     * Retrieves active vendors whose next assessment date has passed.
     *
     * @return List of Vendor_Compliance__c records with overdue assessments
     */
    public List<Vendor_Compliance__c> getOverdueAssessments() {
        return [
            SELECT Id, Name, Vendor_Name__c, Vendor_Type__c, Risk_Score__c, Status__c,
                Last_Assessment_Date__c, Next_Assessment_Date__c, Data_Processing_Agreement__c
            FROM Vendor_Compliance__c
            WHERE Next_Assessment_Date__c < TODAY
                AND Status__c = 'ACTIVE'
            WITH USER_MODE
            ORDER BY Next_Assessment_Date__c ASC
        ];
    }

    /**
     * Generates a summary of vendor compliance analytics including totals,
     * averages, and risk distribution.
     *
     * @return VendorSummary with aggregated metrics
     */
    public VendorSummary getVendorComplianceSummary() {
        VendorSummary summary = new VendorSummary();

        List<Vendor_Compliance__c> allVendors = [
            SELECT Id, Status__c, Risk_Score__c, Next_Assessment_Date__c
            FROM Vendor_Compliance__c
            WITH USER_MODE
        ];

        summary.totalVendors = allVendors.size();
        summary.activeVendors = 0;
        summary.overdueCount = 0;
        summary.highRiskCount = 0;
        Decimal totalScore = 0;
        Integer scoredCount = 0;

        for (Vendor_Compliance__c v : allVendors) {
            if (v.Status__c == 'ACTIVE') {
                summary.activeVendors++;
            }
            if (v.Risk_Score__c != null) {
                totalScore += v.Risk_Score__c;
                scoredCount++;
                if (v.Risk_Score__c >= HIGH_RISK_THRESHOLD) {
                    summary.highRiskCount++;
                }
            }
            if (v.Next_Assessment_Date__c != null
                && v.Next_Assessment_Date__c < Date.today()
                && v.Status__c == 'ACTIVE') {
                summary.overdueCount++;
            }
        }

        summary.averageRiskScore = scoredCount > 0
            ? (totalScore / scoredCount).setScale(1, RoundingMode.HALF_UP)
            : 0;

        return summary;
    }

    /**
     * Upserts a vendor compliance record after validation.
     *
     * @param vendor The Vendor_Compliance__c record to save
     * @return The saved Vendor_Compliance__c record
     * @throws AuraHandledException if validation fails (blank vendor name or invalid score)
     */
    public Vendor_Compliance__c saveVendor(Vendor_Compliance__c vendor) {
        if (String.isBlank(vendor.Vendor_Name__c)) {
            throw new AuraHandledException('Vendor name is required.');
        }

        if (vendor.Risk_Score__c != null && (vendor.Risk_Score__c < 0 || vendor.Risk_Score__c > 10)) {
            throw new AuraHandledException('Risk score must be between 0 and 10.');
        }

        upsert as user vendor;
        return vendor;
    }
}
