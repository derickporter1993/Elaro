/**
 * Manages board governance reports for SEC 10-K annual cybersecurity
 * disclosure requirements. Under SEC Regulation S-K Item 106, public
 * companies must describe board oversight of cybersecurity risk,
 * management roles, and risk management strategy in annual filings.
 *
 * @author Elaro Team
 * @since v3.1.0 (Spring '26)
 * @group SEC Module
 * @see Board_Governance_Report__c
 * @see DisclosureWorkflowService
 */
public inherited sharing class BoardGovernanceService {

    /**
     * Section key constants for the updateReportContent sections map.
     */
    public static final String SECTION_GOVERNANCE = 'governance';
    public static final String SECTION_RISK_MANAGEMENT = 'riskManagement';
    public static final String SECTION_STRATEGY = 'strategy';
    public static final String SECTION_BOARD_OVERSIGHT = 'boardOversight';
    public static final String SECTION_MANAGEMENT_ROLE = 'managementRole';

    /**
     * Creates a new board governance report with Draft status.
     *
     * @param reportPeriod The reporting period (e.g., 'FY2025', 'Q4-2025')
     * @param reportType The type of report (e.g., '10-K', 'Annual')
     * @return The newly inserted Board_Governance_Report__c record
     * @throws AuraHandledException if creation fails
     */
    public static Board_Governance_Report__c createReport(String reportPeriod, String reportType) {
        Board_Governance_Report__c report = new Board_Governance_Report__c(
            Report_Period__c = reportPeriod,
            Report_Type__c = reportType,
            Status__c = 'Draft'
        );

        try {
            insert as user report;
            ElaroLogger.info(
                'BoardGovernanceService.createReport',
                'Created governance report ' + report.Id
                    + ' for period ' + reportPeriod
                    + ' (Type: ' + reportType + ')'
            );
        } catch (Exception e) {
            ElaroLogger.error(
                'BoardGovernanceService.createReport',
                e.getMessage(),
                e.getStackTraceString()
            );
            throw new AuraHandledException('Failed to create governance report. Please verify permissions and try again.');
        }

        return report;
    }

    /**
     * Updates the content sections of a governance report. Accepts a map
     * with keys matching the section constants (governance, riskManagement,
     * strategy, boardOversight, managementRole).
     *
     * @param reportId The Board_Governance_Report__c record Id
     * @param sections Map of section keys to content strings
     * @throws AuraHandledException if report not found or update fails
     */
    public static void updateReportContent(Id reportId, Map<String, String> sections) {
        List<Board_Governance_Report__c> reports = [
            SELECT Id, Status__c
            FROM Board_Governance_Report__c
            WHERE Id = :reportId
            WITH USER_MODE
            LIMIT 1
        ];

        if (reports.isEmpty()) {
            throw new AuraHandledException('Governance report not found.');
        }

        Board_Governance_Report__c report = reports[0];

        if (report.Status__c == 'Approved') {
            throw new AuraHandledException('Cannot modify an approved governance report. Create a new version instead.');
        }

        if (sections.containsKey(SECTION_GOVERNANCE)) {
            report.Governance_Description__c = sections.get(SECTION_GOVERNANCE);
        }
        if (sections.containsKey(SECTION_RISK_MANAGEMENT)) {
            report.Risk_Management_Description__c = sections.get(SECTION_RISK_MANAGEMENT);
        }
        if (sections.containsKey(SECTION_STRATEGY)) {
            report.Strategy_Description__c = sections.get(SECTION_STRATEGY);
        }
        if (sections.containsKey(SECTION_BOARD_OVERSIGHT)) {
            report.Board_Oversight_Description__c = sections.get(SECTION_BOARD_OVERSIGHT);
        }
        if (sections.containsKey(SECTION_MANAGEMENT_ROLE)) {
            report.Management_Role_Description__c = sections.get(SECTION_MANAGEMENT_ROLE);
        }

        try {
            update as user report;
            ElaroLogger.info(
                'BoardGovernanceService.updateReportContent',
                'Updated ' + sections.keySet().size() + ' sections for report ' + reportId
            );
        } catch (Exception e) {
            ElaroLogger.error(
                'BoardGovernanceService.updateReportContent',
                e.getMessage(),
                e.getStackTraceString()
            );
            throw new AuraHandledException('Failed to update report content. Please try again.');
        }
    }

    /**
     * Approves a governance report, setting the approval metadata.
     *
     * @param reportId The Board_Governance_Report__c record Id
     * @throws AuraHandledException if report not found, already approved, or update fails
     */
    public static void approveReport(Id reportId) {
        List<Board_Governance_Report__c> reports = [
            SELECT Id, Status__c
            FROM Board_Governance_Report__c
            WHERE Id = :reportId
            WITH USER_MODE
            LIMIT 1
        ];

        if (reports.isEmpty()) {
            throw new AuraHandledException('Governance report not found.');
        }

        Board_Governance_Report__c report = reports[0];

        if (report.Status__c == 'Approved') {
            throw new AuraHandledException('Governance report is already approved.');
        }

        report.Status__c = 'Approved';
        report.Approved_Date__c = Date.today();
        report.Approved_By__c = UserInfo.getUserId();

        try {
            update as user report;
            ElaroLogger.info(
                'BoardGovernanceService.approveReport',
                'Report ' + reportId + ' approved by ' + UserInfo.getUserId()
            );
        } catch (Exception e) {
            ElaroLogger.error(
                'BoardGovernanceService.approveReport',
                e.getMessage(),
                e.getStackTraceString()
            );
            throw new AuraHandledException('Failed to approve report. Please try again.');
        }
    }

    /**
     * Retrieves all governance reports for a given reporting period.
     *
     * @param reportPeriod The reporting period to filter by
     * @return List of governance reports ordered by creation date
     */
    public static List<Board_Governance_Report__c> getReportsByPeriod(String reportPeriod) {
        return [
            SELECT Id, Report_Period__c, Report_Type__c, Governance_Description__c,
                Risk_Management_Description__c, Strategy_Description__c,
                Board_Oversight_Description__c, Management_Role_Description__c,
                Status__c, Approved_Date__c, Approved_By__c, CreatedDate
            FROM Board_Governance_Report__c
            WHERE Report_Period__c = :reportPeriod
            WITH USER_MODE
            ORDER BY CreatedDate DESC
        ];
    }
}
