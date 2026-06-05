/**
 * HIPAA breach audit export for regulators (issue #214 gap-fill, HIPAA pack).
 *
 * Produces a regulator-ready export of HIPAA_Breach__c records — structured rows for
 * programmatic/UI use and a CSV Blob for download/submission to HHS OCR — complementing the
 * existing breach detection (BreachPatternMatcher), deadline monitoring (BreachDeadlineMonitor),
 * and notification (HIPAABreachNotificationService) capabilities.
 *
 * Read-only, WITH USER_MODE. Gated by the HIPAA vertical-pack kill switch
 * ({@link FeatureFlags#isHipaaPackEnabled}).
 *
 * @author Elaro Team
 * @since v3.2.0 (Spring '26)
 * @group HIPAA Pack
 * @see HIPAABreachNotificationService
 * @see HIPAA_Breach__c
 */
public inherited sharing class HIPAABreachAuditExportService {

    /**
     * A single breach record in regulator-export form.
     */
    public class BreachExportRow {
        @AuraEnabled
        public Id breachId;
        @AuraEnabled
        public String breachType;
        @AuraEnabled
        public Date discoveryDate;
        @AuraEnabled
        public Decimal recordsAffected;
        @AuraEnabled
        public String riskLevel;
        @AuraEnabled
        public String status;
        @AuraEnabled
        public Boolean notificationRequired;
        @AuraEnabled
        public Date notificationDeadline;
        @AuraEnabled
        public Boolean individualsNotified;
        @AuraEnabled
        public Date individualNotificationDate;
        @AuraEnabled
        public Boolean hhsNotified;
        @AuraEnabled
        public Date hhsNotificationDate;
        @AuraEnabled
        public String hhsConfirmationNumber;
        @AuraEnabled
        public Boolean mediaNotified;
        @AuraEnabled
        public Date mediaNotificationDate;
    }

    /**
     * Exports breaches discovered within an optional date range as structured rows.
     *
     * @param startDate Inclusive lower bound on Discovery Date (null for no lower bound)
     * @param endDate Inclusive upper bound on Discovery Date (null for no upper bound)
     * @return Export rows ordered by discovery date (newest first)
     * @throws AuraHandledException if the HIPAA pack is disabled or the query fails
     */
    public List<BreachExportRow> export(Date startDate, Date endDate) {
        if (!FeatureFlags.isHipaaPackEnabled()) {
            throw new AuraHandledException('The HIPAA pack is disabled for this org.');
        }
        try {
            List<BreachExportRow> rows = new List<BreachExportRow>();
            for (HIPAA_Breach__c breach : queryBreaches(startDate, endDate)) {
                BreachExportRow row = new BreachExportRow();
                row.breachId = breach.Id;
                row.breachType = breach.Breach_Type__c;
                row.discoveryDate = breach.Discovery_Date__c;
                row.recordsAffected = breach.Records_Affected__c;
                row.riskLevel = breach.Risk_Level__c;
                row.status = breach.Status__c;
                row.notificationRequired = breach.Notification_Required__c;
                row.notificationDeadline = breach.Notification_Deadline__c;
                row.individualsNotified = breach.Individuals_Notified__c;
                row.individualNotificationDate = breach.Individual_Notification_Date__c;
                row.hhsNotified = breach.HHS_Notified__c;
                row.hhsNotificationDate = breach.HHS_Notification_Date__c;
                row.hhsConfirmationNumber = breach.HHS_Confirmation_Number__c;
                row.mediaNotified = breach.Media_Notified__c;
                row.mediaNotificationDate = breach.Media_Notification_Date__c;
                rows.add(row);
            }
            ElaroLogger.info('HIPAABreachAuditExportService.export', 'Exported ' + rows.size() + ' breach record(s)');
            return rows;
        } catch (Exception e) {
            ElaroLogger.error('HIPAABreachAuditExportService.export', e.getMessage(), e.getStackTraceString());
            throw new AuraHandledException('Unable to export breach audit data. ' + e.getMessage());
        }
    }

    /**
     * Exports breaches as a CSV Blob suitable for download and regulator submission.
     *
     * @param startDate Inclusive lower bound on Discovery Date (null for no lower bound)
     * @param endDate Inclusive upper bound on Discovery Date (null for no upper bound)
     * @return CSV content as a Blob
     * @throws AuraHandledException if the HIPAA pack is disabled or the query fails
     */
    public Blob exportCsv(Date startDate, Date endDate) {
        List<BreachExportRow> rows = export(startDate, endDate);
        List<String> lines = new List<String>();
        lines.add(
            'Breach Id,Breach Type,Discovery Date,Records Affected,Risk Level,Status,' +
            'Notification Required,Notification Deadline,Individuals Notified,Individual Notification Date,' +
            'HHS Notified,HHS Notification Date,HHS Confirmation Number,Media Notified,Media Notification Date'
        );
        for (BreachExportRow row : rows) {
            lines.add(
                String.join(
                    new List<String>{
                        csvCell(row.breachId),
                        csvCell(row.breachType),
                        csvCell(row.discoveryDate),
                        csvCell(row.recordsAffected),
                        csvCell(row.riskLevel),
                        csvCell(row.status),
                        csvCell(row.notificationRequired),
                        csvCell(row.notificationDeadline),
                        csvCell(row.individualsNotified),
                        csvCell(row.individualNotificationDate),
                        csvCell(row.hhsNotified),
                        csvCell(row.hhsNotificationDate),
                        csvCell(row.hhsConfirmationNumber),
                        csvCell(row.mediaNotified),
                        csvCell(row.mediaNotificationDate)
                    },
                    ','
                )
            );
        }
        return Blob.valueOf(String.join(lines, '\n'));
    }

    /**
     * Renders a value as a CSV cell, quoting and escaping when needed.
     *
     * @param value Any value (null becomes empty)
     * @return CSV-safe cell string
     */
    private String csvCell(Object value) {
        if (value == null) {
            return '';
        }
        String text = String.valueOf(value);
        if (text.contains(',') || text.contains('"') || text.contains('\n')) {
            text = '"' + text.replace('"', '""') + '"';
        }
        return text;
    }

    /**
     * Queries breaches, optionally constrained to a discovery-date range.
     *
     * @param startDate Inclusive lower bound (nullable)
     * @param endDate Inclusive upper bound (nullable)
     * @return Matching HIPAA_Breach__c records
     */
    private List<HIPAA_Breach__c> queryBreaches(Date startDate, Date endDate) {
        if (startDate != null && endDate != null) {
            return [
                SELECT Id, Breach_Type__c, Discovery_Date__c, Records_Affected__c, Risk_Level__c, Status__c,
                    Notification_Required__c, Notification_Deadline__c, Individuals_Notified__c,
                    Individual_Notification_Date__c, HHS_Notified__c, HHS_Notification_Date__c,
                    HHS_Confirmation_Number__c, Media_Notified__c, Media_Notification_Date__c
                FROM HIPAA_Breach__c
                WHERE Discovery_Date__c >= :startDate
                AND Discovery_Date__c <= :endDate
                WITH USER_MODE
                ORDER BY Discovery_Date__c DESC
            ];
        }
        return [
            SELECT Id, Breach_Type__c, Discovery_Date__c, Records_Affected__c, Risk_Level__c, Status__c,
                Notification_Required__c, Notification_Deadline__c, Individuals_Notified__c,
                Individual_Notification_Date__c, HHS_Notified__c, HHS_Notification_Date__c,
                HHS_Confirmation_Number__c, Media_Notified__c, Media_Notification_Date__c
            FROM HIPAA_Breach__c
            WITH USER_MODE
            ORDER BY Discovery_Date__c DESC
        ];
    }
}
