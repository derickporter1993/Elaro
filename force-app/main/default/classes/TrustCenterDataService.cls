/**
 * Scheduled service for aggregating compliance data into Trust_Center_View__c.
 * Runs nightly to materialize public-safe compliance metrics.
 *
 * SECURITY NOTE: without sharing required because this is a scheduled system job
 * that aggregates data across all frameworks regardless of user context.
 * This class never exposes raw Compliance_Finding__c or Evidence__c data.
 * It only creates aggregated, anonymized metrics in Trust_Center_View__c.
 *
 * @author Elaro Team
 * @since v1.0.0 (Spring '26)
 * @group Trust Center
 * @see Trust_Center_View__c
 * @see TrustCenterLinkService
 */
public without sharing class TrustCenterDataService implements Schedulable {

    /**
     * Schedulable entry point. Executes daily aggregation.
     *
     * @param ctx SchedulableContext provided by platform
     */
    public void execute(SchedulableContext ctx) {
        try {
            aggregateComplianceData();
        } catch (Exception e) {
            ElaroLogger.error('TrustCenterDataService.execute',
                e.getMessage(), e.getStackTraceString());
        }
    }

    /**
     * Aggregates compliance data from all frameworks into materialized views.
     * Deletes existing views and rebuilds from current compliance state.
     * Uses 3 bulk aggregate queries instead of per-framework queries to avoid
     * SOQL-in-loop governor limit issues.
     *
     * @throws DmlException if aggregation or delete/insert operations fail
     */
    public void aggregateComplianceData() {
        // Delete existing views to rebuild fresh
        List<Trust_Center_View__c> existingViews = [
            SELECT Id FROM Trust_Center_View__c WITH USER_MODE LIMIT 10000
        ];
        if (!existingViews.isEmpty()) {
            delete as user existingViews;
        }

        // Define frameworks to aggregate
        List<String> frameworks = new List<String>{
            'SOC2', 'HIPAA', 'ISO27001', 'GDPR', 'PCI_DSS',
            'CCPA', 'CMMC', 'FedRAMP', 'NIST_CSF'
        };

        // Bulk query 1: Total controls per framework (replaces per-framework COUNT)
        Map<String, Integer> totalByFramework = new Map<String, Integer>();
        for (AggregateResult ar : [
            SELECT Framework__c fw, COUNT(Id) cnt
            FROM Compliance_Control__c
            GROUP BY Framework__c
            WITH USER_MODE
        ]) {
            totalByFramework.put((String) ar.get('fw'), (Integer) ar.get('cnt'));
        }

        // Bulk query 2: Compliant controls per framework (replaces per-framework COUNT)
        Map<String, Integer> compliantByFramework = new Map<String, Integer>();
        for (AggregateResult ar : [
            SELECT Framework__c fw, COUNT(Id) cnt
            FROM Compliance_Control__c
            WHERE Status__c = 'Compliant'
            GROUP BY Framework__c
            WITH USER_MODE
        ]) {
            compliantByFramework.put((String) ar.get('fw'), (Integer) ar.get('cnt'));
        }

        // Bulk query 3: Last audit date per framework (replaces per-framework MAX)
        Map<String, Date> auditDateByFramework = new Map<String, Date>();
        for (AggregateResult ar : [
            SELECT Framework__c fw, MAX(Assessment_Date__c) maxDate
            FROM Compliance_Assessment__c
            GROUP BY Framework__c
            WITH USER_MODE
        ]) {
            auditDateByFramework.put((String) ar.get('fw'), (Date) ar.get('maxDate'));
        }

        // Build views from pre-queried maps (no SOQL inside loop)
        List<Trust_Center_View__c> newViews = new List<Trust_Center_View__c>();
        for (String framework : frameworks) {
            Trust_Center_View__c view = buildFrameworkView(
                framework, totalByFramework, compliantByFramework, auditDateByFramework
            );
            if (view != null) {
                newViews.add(view);
            }
        }

        if (!newViews.isEmpty()) {
            insert as user newViews;
        }

        ElaroLogger.info('TrustCenterDataService.aggregateComplianceData',
            'Aggregated ' + newViews.size() + ' framework views');
    }

    /**
     * Builds a materialized view for a single framework using pre-queried
     * aggregate data maps. No SOQL is executed in this method.
     *
     * @param framework Framework identifier (e.g., 'SOC2', 'HIPAA')
     * @param totalByFramework Map of framework to total control count
     * @param compliantByFramework Map of framework to compliant control count
     * @param auditDateByFramework Map of framework to most recent audit date
     * @return Trust_Center_View__c record with aggregated metrics, or null if no data
     */
    @TestVisible
    private Trust_Center_View__c buildFrameworkView(
        String framework,
        Map<String, Integer> totalByFramework,
        Map<String, Integer> compliantByFramework,
        Map<String, Date> auditDateByFramework
    ) {
        Integer totalControls = totalByFramework.get(framework) ?? 0;

        if (totalControls == 0) {
            return null; // No controls for this framework
        }

        Integer compliantControls = compliantByFramework.get(framework) ?? 0;

        // Calculate percentage
        Decimal compliancePercentage = (Decimal.valueOf(compliantControls) / Decimal.valueOf(totalControls)) * 100;

        // Get most recent audit date from pre-queried map
        Date lastAudit = auditDateByFramework.get(framework);

        // Determine certification status
        String certStatus = determineCertificationStatus(
            compliancePercentage, lastAudit
        );

        Trust_Center_View__c view = new Trust_Center_View__c(
            Name = getFrameworkLabel(framework),
            Framework__c = framework,
            Compliance_Percentage__c = compliancePercentage.setScale(2),
            Controls_Total__c = totalControls,
            Controls_Compliant__c = compliantControls,
            Last_Audit_Date__c = lastAudit,
            Certification_Status__c = certStatus,
            Badge_Image_URL__c = getBadgeUrl(framework, certStatus),
            Is_Public__c = (compliancePercentage >= 80.0) // Only show if 80%+ compliant
        );

        return view;
    }

    /**
     * Determines certification status based on compliance percentage and audit date.
     *
     * @param compliancePercentage Overall compliance percentage (0-100)
     * @param lastAuditDate Most recent audit date, or null if never audited
     * @return Certification status: Certified, In_Progress, Renewal_Required, Not_Started
     */
    private String determineCertificationStatus(
        Decimal compliancePercentage, Date lastAuditDate
    ) {
        if (compliancePercentage >= 95.0 && lastAuditDate != null) {
            // Check if audit is within 1 year
            if (lastAuditDate.daysBetween(Date.today()) <= 365) {
                return 'Certified';
            } else {
                return 'Renewal_Required';
            }
        } else if (compliancePercentage >= 50.0) {
            return 'In_Progress';
        } else {
            return 'Not_Started';
        }
    }

    /**
     * Returns user-friendly label for framework code.
     *
     * @param framework Framework code (e.g., 'SOC2')
     * @return Human-readable label (e.g., 'SOC 2')
     */
    private String getFrameworkLabel(String framework) {
        Map<String, String> labels = new Map<String, String>{
            'SOC2' => 'SOC 2',
            'HIPAA' => 'HIPAA',
            'ISO27001' => 'ISO 27001',
            'GDPR' => 'GDPR',
            'PCI_DSS' => 'PCI-DSS',
            'CCPA' => 'CCPA',
            'CMMC' => 'CMMC 2.0',
            'FedRAMP' => 'FedRAMP',
            'NIST_CSF' => 'NIST CSF'
        };
        return labels.get(framework) ?? framework;
    }

    /**
     * Returns badge image URL from Static Resources based on framework and status.
     *
     * @param framework Framework code
     * @param status Certification status
     * @return Static Resource URL or empty string
     */
    private String getBadgeUrl(String framework, String status) {
        if (status == 'Certified') {
            return '/resource/Elaro_Badge_' + framework;
        }
        return '';
    }
}
