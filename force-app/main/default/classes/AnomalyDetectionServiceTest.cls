/**
 * AnomalyDetectionServiceTest
 * 
 * Test class for AnomalyDetectionService
 * 
 * @author Elaro
 * @version 1.0
 */
@IsTest(testFor=AnomalyDetectionService.class)
private class AnomalyDetectionServiceTest {

    @TestSetup
    static void setupTestData() {
        // Create test metadata changes with varying risk levels
        List<Metadata_Change__c> changes = new List<Metadata_Change__c>();

        // Create CRITICAL risk changes to trigger anomaly detection
        for (Integer i = 0; i < 5; i++) {
            changes.add(new Metadata_Change__c(
                Metadata_Type__c = 'ApexClass',
                Metadata_Name__c = 'CriticalClass' + i,
                Change_Type__c = 'Modified',
                Risk_Level__c = 'CRITICAL',
                Change_Date__c = Date.today()
            ));
        }

        // Create non-critical changes
        for (Integer i = 0; i < 5; i++) {
            changes.add(new Metadata_Change__c(
                Metadata_Type__c = 'CustomField',
                Metadata_Name__c = 'Field' + i,
                Change_Type__c = 'Created',
                Risk_Level__c = 'LOW',
                Change_Date__c = Date.today()
            ));
        }

        insert changes;
    }

    @IsTest
    static void testDetectAnomalies_Success() {
        Test.startTest();
        List<AnomalyDetectionService.Anomaly> anomalies =
            AnomalyDetectionService.detectAnomalies('SOX', 30);
        Test.stopTest();

        Assert.areNotEqual(null, anomalies, 'Anomalies list should not be null');
    }

    @IsTest
    static void testDetectAnomalies_BlankFramework() {
        Test.startTest();
        try {
            AnomalyDetectionService.detectAnomalies('', 30);
            Assert.fail( 'Should have thrown IllegalArgumentException');
        } catch (IllegalArgumentException e) {
            Assert.isNotNull(e.getMessage(), 'Exception should have a message');
        }
        Test.stopTest();
    }

    @IsTest
    static void testDetectAnomalies_NullFramework() {
        Test.startTest();
        try {
            AnomalyDetectionService.detectAnomalies(null, 30);
            Assert.fail( 'Should have thrown IllegalArgumentException');
        } catch (IllegalArgumentException e) {
            Assert.isTrue(e.getMessage().contains('Framework is required'),
                'Exception should mention framework');
        }
        Test.stopTest();
    }

    @IsTest
    static void testDetectAnomalies_DefaultDaysBack() {
        Test.startTest();
        List<AnomalyDetectionService.Anomaly> anomalies =
            AnomalyDetectionService.detectAnomalies('SOX', null);
        Test.stopTest();

        Assert.areNotEqual(null, anomalies, 'Anomalies list should not be null');
    }

    @IsTest
    static void testDetectAnomalies_NegativeDaysBack() {
        Test.startTest();
        List<AnomalyDetectionService.Anomaly> anomalies =
            AnomalyDetectionService.detectAnomalies('SOX', -5);
        Test.stopTest();

        // Should default to 30 days when negative
        Assert.areNotEqual(null, anomalies, 'Anomalies list should not be null');
    }

    @IsTest
    static void testDetectAnomalies_ZeroDaysBack() {
        Test.startTest();
        List<AnomalyDetectionService.Anomaly> anomalies =
            AnomalyDetectionService.detectAnomalies('SOX', 0);
        Test.stopTest();

        // Should default to 30 days when zero
        Assert.areNotEqual(null, anomalies, 'Anomalies list should not be null');
    }

    @IsTest
    static void testDetectAnomalies_CriticalChangesDetected() {
        Test.startTest();
        List<AnomalyDetectionService.Anomaly> anomalies =
            AnomalyDetectionService.detectAnomalies('SOX', 30);
        Test.stopTest();

        // Should detect the CRITICAL metadata changes
        Boolean foundCritical = false;
        for (AnomalyDetectionService.Anomaly a : anomalies) {
            if (a.type == 'HIGH_RISK_CHANGE' && a.severity == 'CRITICAL') {
                foundCritical = true;
                break;
            }
        }
        Assert.areEqual(true, foundCritical, 'Should detect critical metadata changes');
    }

    @IsTest
    static void testDetectAnomalies_DifferentFrameworks() {
        Test.startTest();
        List<AnomalyDetectionService.Anomaly> soxAnomalies =
            AnomalyDetectionService.detectAnomalies('SOX', 30);
        List<AnomalyDetectionService.Anomaly> gdprAnomalies =
            AnomalyDetectionService.detectAnomalies('GDPR', 30);
        List<AnomalyDetectionService.Anomaly> hipaaAnomalies =
            AnomalyDetectionService.detectAnomalies('HIPAA', 30);
        Test.stopTest();

        Assert.areNotEqual(null, soxAnomalies, 'SOX anomalies should not be null');
        Assert.areNotEqual(null, gdprAnomalies, 'GDPR anomalies should not be null');
        Assert.areNotEqual(null, hipaaAnomalies, 'HIPAA anomalies should not be null');
    }

    @IsTest
    static void testDetectAnomalies_LargeDaysBack() {
        Test.startTest();
        List<AnomalyDetectionService.Anomaly> anomalies =
            AnomalyDetectionService.detectAnomalies('SOX', 365);
        Test.stopTest();

        Assert.areNotEqual(null, anomalies, 'Anomalies list should not be null');
    }

    /**
     * Builds a synthetic LoginHistory record. LoginHistory and its fields are read-only,
     * so we deserialize from JSON to populate them in memory for unit testing.
     */
    private static LoginHistory makeLogin(Id userId, Datetime loginTime, String sourceIp, String status) {
        Map<String, Object> fields = new Map<String, Object>{
            'attributes' => new Map<String, Object>{ 'type' => 'LoginHistory' },
            'UserId' => userId,
            'LoginTime' => loginTime.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss.SSSZ'),
            'SourceIp' => sourceIp,
            'Status' => status
        };
        return (LoginHistory) JSON.deserialize(JSON.serialize(fields), LoginHistory.class);
    }

    @IsTest
    static void testAnalyzeLoginHistory_DetectsRepeatedFailures() {
        // Build synthetic LoginHistory records in memory (LoginHistory is read-only / not insertable).
        Id userId = UserInfo.getUserId();
        List<LoginHistory> logins = new List<LoginHistory>();
        for (Integer i = 0; i < 6; i++) {
            logins.add(makeLogin(
                userId,
                Datetime.newInstanceGmt(2026, 6, 1, 12, 0, 0), // noon GMT = in-hours
                '203.0.113.' + i,
                'Invalid Password'
            ));
        }

        Test.startTest();
        List<AnomalyDetectionService.Anomaly> anomalies =
            AnomalyDetectionService.analyzeLoginHistory(logins);
        Test.stopTest();

        Boolean foundFailureAnomaly = false;
        for (AnomalyDetectionService.Anomaly a : anomalies) {
            if (a.type == 'REPEATED_LOGIN_FAILURES') {
                foundFailureAnomaly = true;
                Assert.areEqual('HIGH', a.severity, 'Repeated failures should be HIGH severity');
                Assert.areEqual(String.valueOf(userId), a.entityId, 'Anomaly should reference the failing user');
            }
        }
        Assert.isTrue(foundFailureAnomaly,
            'Detector must flag repeated failed logins as a real anomaly');
    }

    @IsTest
    static void testAnalyzeLoginHistory_DetectsOffHoursAccess() {
        Id userId = UserInfo.getUserId();
        List<LoginHistory> logins = new List<LoginHistory>{
            makeLogin(
                userId,
                Datetime.newInstanceGmt(2026, 6, 1, 3, 0, 0), // 3 AM GMT = off-hours
                '198.51.100.7',
                'Success'
            )
        };

        Test.startTest();
        List<AnomalyDetectionService.Anomaly> anomalies =
            AnomalyDetectionService.analyzeLoginHistory(logins);
        Test.stopTest();

        Boolean foundOffHours = false;
        for (AnomalyDetectionService.Anomaly a : anomalies) {
            if (a.type == 'OFF_HOURS_ACCESS') {
                foundOffHours = true;
                Assert.areEqual('MEDIUM', a.severity, 'Off-hours access should be MEDIUM severity');
            }
        }
        Assert.isTrue(foundOffHours,
            'Detector must flag off-hours successful logins as a real anomaly');
    }

    @IsTest
    static void testAnalyzeLoginHistory_NormalAccessNoAnomalies() {
        Id userId = UserInfo.getUserId();
        List<LoginHistory> logins = new List<LoginHistory>{
            makeLogin(
                userId,
                Datetime.newInstanceGmt(2026, 6, 1, 14, 0, 0), // 2 PM GMT = in-hours
                '198.51.100.10',
                'Success'
            )
        };

        Test.startTest();
        List<AnomalyDetectionService.Anomaly> anomalies =
            AnomalyDetectionService.analyzeLoginHistory(logins);
        Test.stopTest();

        // A single in-hours successful login is genuinely benign — empty here reflects a
        // real evaluation, not a fabricated all-clear (the detector did run over the data).
        Assert.areEqual(0, anomalies.size(),
            'In-hours successful login should produce no anomalies');
    }

    @IsTest
    static void testAnalyzeLoginHistory_BelowFailureThreshold() {
        Id userId = UserInfo.getUserId();
        List<LoginHistory> logins = new List<LoginHistory>();
        for (Integer i = 0; i < 3; i++) { // below the >= 5 threshold
            logins.add(makeLogin(
                userId,
                Datetime.newInstanceGmt(2026, 6, 1, 12, 0, 0),
                '203.0.113.' + i,
                'Invalid Password'
            ));
        }

        Test.startTest();
        List<AnomalyDetectionService.Anomaly> anomalies =
            AnomalyDetectionService.analyzeLoginHistory(logins);
        Test.stopTest();

        for (AnomalyDetectionService.Anomaly a : anomalies) {
            Assert.areNotEqual('REPEATED_LOGIN_FAILURES', a.type,
                'Failures below threshold should not raise a repeated-failure anomaly');
        }
    }

    @IsTest
    static void testAnomalyClass_Properties() {
        Test.startTest();
        AnomalyDetectionService.Anomaly anomaly = new AnomalyDetectionService.Anomaly();
        anomaly.type = 'TEST_TYPE';
        anomaly.severity = 'HIGH';
        anomaly.description = 'Test description';
        anomaly.entityId = '001000000000000AAA';
        Test.stopTest();

        Assert.areEqual('TEST_TYPE', anomaly.type, 'Type should match');
        Assert.areEqual('HIGH', anomaly.severity, 'Severity should match');
        Assert.areEqual('Test description', anomaly.description, 'Description should match');
        Assert.areEqual('001000000000000AAA', anomaly.entityId, 'EntityId should match');
        Assert.areNotEqual(null, anomaly.detectedDate, 'DetectedDate should be set');
    }

    @IsTest
    static void testAnomalyClass_DefaultDetectedDate() {
        Test.startTest();
        Datetime beforeCreate = System.now();
        AnomalyDetectionService.Anomaly anomaly = new AnomalyDetectionService.Anomaly();
        Datetime afterCreate = System.now();
        Test.stopTest();

        Assert.isTrue(anomaly.detectedDate >= beforeCreate, 'DetectedDate should be at or after test start');
        Assert.isTrue(anomaly.detectedDate <= afterCreate, 'DetectedDate should be at or before test end');
    }

    @IsTest
    static void testDetectAnomalies_SmallDaysBack() {
        Test.startTest();
        List<AnomalyDetectionService.Anomaly> anomalies =
            AnomalyDetectionService.detectAnomalies('SOX', 1);
        Test.stopTest();

        Assert.areNotEqual(null, anomalies, 'Anomalies list should not be null');
    }

    @IsTest
    static void testDetectAnomalies_VerifyAnomalyDetails() {
        Test.startTest();
        List<AnomalyDetectionService.Anomaly> anomalies =
            AnomalyDetectionService.detectAnomalies('SOX', 30);
        Test.stopTest();

        for (AnomalyDetectionService.Anomaly anomaly : anomalies) {
            if (anomaly.type == 'HIGH_RISK_CHANGE') {
                Assert.areNotEqual(null, anomaly.description, 'Description should not be null');
                Assert.areNotEqual(null, anomaly.entityId, 'EntityId should not be null');
                Assert.areEqual('CRITICAL', anomaly.severity, 'Severity should be CRITICAL');
            }
        }
    }
}
