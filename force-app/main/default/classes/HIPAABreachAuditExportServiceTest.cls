/**
 * Unit tests for {@link HIPAABreachAuditExportService} (#214 gap-fill): regulator export of
 * HIPAA breaches as structured rows and CSV, with date-range filtering and the pack kill switch.
 *
 * @author Elaro Team
 * @since v3.2.0 (Spring '26)
 * @group HIPAA Pack
 * @see HIPAABreachAuditExportService
 */
@IsTest
private class HIPAABreachAuditExportServiceTest {

    @IsTest
    static void shouldExportBreachesAsRowsAndCsv() {
        HIPAA_Breach__c breach = new HIPAA_Breach__c(
            Discovery_Date__c = Date.today(),
            Status__c = 'Open',
            Records_Affected__c = 250,
            Notification_Required__c = true
        );
        insert breach;

        HIPAABreachAuditExportService service = new HIPAABreachAuditExportService();

        Test.startTest();
        List<HIPAABreachAuditExportService.BreachExportRow> rows = service.export(null, null);
        Blob csv = service.exportCsv(null, null);
        Test.stopTest();

        Assert.isFalse(rows.isEmpty(), 'Should export at least one breach');
        Boolean found = false;
        for (HIPAABreachAuditExportService.BreachExportRow row : rows) {
            if (row.breachId == breach.Id) {
                found = true;
                Assert.areEqual('Open', row.status, 'Status should match');
                Assert.isTrue(row.recordsAffected == 250, 'Records affected should match');
                Assert.isTrue(row.notificationRequired, 'Notification required should be true');
            }
        }
        Assert.isTrue(found, 'Exported rows should include the inserted breach');

        Assert.isNotNull(csv, 'CSV blob should not be null');
        String csvText = csv.toString();
        Assert.isTrue(csvText.contains('Breach Id'), 'CSV should contain a header row');
        Assert.isTrue(csvText.contains(breach.Id), 'CSV should include the breach id');
    }

    @IsTest
    static void shouldFilterByDateRange() {
        List<HIPAA_Breach__c> breaches = new List<HIPAA_Breach__c>{
            new HIPAA_Breach__c(Discovery_Date__c = Date.today().addDays(-400), Status__c = 'Open'),
            new HIPAA_Breach__c(Discovery_Date__c = Date.today(), Status__c = 'Open')
        };
        insert breaches;

        List<HIPAABreachAuditExportService.BreachExportRow> rows = new HIPAABreachAuditExportService()
            .export(Date.today().addDays(-30), Date.today());

        Set<Id> ids = new Set<Id>();
        for (HIPAABreachAuditExportService.BreachExportRow row : rows) {
            ids.add(row.breachId);
        }
        Assert.isTrue(ids.contains(breaches[1].Id), 'Recent breach should be within range');
        Assert.isFalse(ids.contains(breaches[0].Id), 'Old breach should be excluded by the date range');
    }

    @IsTest
    static void shouldRespectKillSwitch() {
        Elaro_Feature_Flags__c flags = Elaro_Feature_Flags__c.getOrgDefaults();
        flags.HIPAA_Pack_Enabled__c = false;
        upsert flags;

        try {
            new HIPAABreachAuditExportService().export(null, null);
            Assert.fail('Expected AuraHandledException when the HIPAA pack is disabled');
        } catch (AuraHandledException e) {
            Assert.isNotNull(e, 'Should throw when the HIPAA pack is disabled');
        }
    }
}
