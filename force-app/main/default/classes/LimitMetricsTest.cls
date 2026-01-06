@IsTest
private class LimitMetricsTest {
    @IsTest
    static void testFetchGovernorStats() {
        Test.startTest();
        LimitMetrics.GovernorStats g = LimitMetrics.fetchGovernorStats();
        Test.stopTest();

        // Verify the object is not null
        System.assertNotEquals(null, g, 'GovernorStats should not be null');

        // Verify all fields are populated with valid values
        System.assertNotEquals(null, g.cpuMs, 'CPU time should not be null');
        System.assert(g.cpuMs >= 0, 'CPU time should be non-negative');

        System.assertNotEquals(null, g.soql, 'SOQL queries should not be null');
        System.assert(g.soql >= 0, 'SOQL queries should be non-negative');

        System.assertNotEquals(null, g.dml, 'DML statements should not be null');
        System.assert(g.dml >= 0, 'DML statements should be non-negative');

        System.assertNotEquals(null, g.heapKb, 'Heap size should not be null');
        System.assert(g.heapKb >= 0, 'Heap size should be non-negative');

        // Verify maximum limits are set
        System.assertEquals(10000, g.cpuMsMax, 'CPU max should be 10000ms');
        System.assertEquals(100, g.soqlMax, 'SOQL max should be 100');
        System.assertEquals(150, g.dmlMax, 'DML max should be 150');
        System.assertEquals(6000, g.heapKbMax, 'Heap max should be 6000KB');

        // Verify remaining limits are calculated correctly
        System.assertNotEquals(null, g.cpuMsRemaining, 'CPU remaining should not be null');
        System.assert(g.cpuMsRemaining >= 0, 'CPU remaining should be non-negative');
        System.assert(g.cpuMsRemaining <= g.cpuMsMax, 'CPU remaining should not exceed max');

        System.assertNotEquals(null, g.soqlRemaining, 'SOQL remaining should not be null');
        System.assert(g.soqlRemaining >= 0, 'SOQL remaining should be non-negative');
        System.assert(g.soqlRemaining <= g.soqlMax, 'SOQL remaining should not exceed max');

        System.assertNotEquals(null, g.dmlRemaining, 'DML remaining should not be null');
        System.assert(g.dmlRemaining >= 0, 'DML remaining should be non-negative');
        System.assert(g.dmlRemaining <= g.dmlMax, 'DML remaining should not exceed max');

        System.assertNotEquals(null, g.heapKbRemaining, 'Heap remaining should not be null');
        System.assert(g.heapKbRemaining >= 0, 'Heap remaining should be non-negative');
        System.assert(g.heapKbRemaining <= g.heapKbMax, 'Heap remaining should not exceed max');

        // Verify percentage used is calculated correctly
        System.assertNotEquals(null, g.cpuPercentUsed, 'CPU percent used should not be null');
        System.assert(g.cpuPercentUsed >= 0, 'CPU percent used should be non-negative');
        System.assert(g.cpuPercentUsed <= 100, 'CPU percent used should not exceed 100%');

        System.assertNotEquals(null, g.soqlPercentUsed, 'SOQL percent used should not be null');
        System.assert(g.soqlPercentUsed >= 0, 'SOQL percent used should be non-negative');
        System.assert(g.soqlPercentUsed <= 100, 'SOQL percent used should not exceed 100%');

        System.assertNotEquals(null, g.dmlPercentUsed, 'DML percent used should not be null');
        System.assert(g.dmlPercentUsed >= 0, 'DML percent used should be non-negative');
        System.assert(g.dmlPercentUsed <= 100, 'DML percent used should not exceed 100%');

        System.assertNotEquals(null, g.heapPercentUsed, 'Heap percent used should not be null');
        System.assert(g.heapPercentUsed >= 0, 'Heap percent used should be non-negative');
        System.assert(g.heapPercentUsed <= 100, 'Heap percent used should not exceed 100%');

        // Verify remaining = max - used (within rounding tolerance)
        System.assertEquals(g.cpuMsMax - g.cpuMs, g.cpuMsRemaining, 'CPU remaining should equal max minus used');
        System.assertEquals(g.soqlMax - g.soql, g.soqlRemaining, 'SOQL remaining should equal max minus used');
        System.assertEquals(g.dmlMax - g.dml, g.dmlRemaining, 'DML remaining should equal max minus used');
    }

    @IsTest
    static void testGovernorStatsAfterDML() {
        // Perform some DML to consume governor limits
        insert new Performance_Alert_History__c(
            Metric__c = 'TEST',
            Value__c = 100,
            Threshold__c = 50
        );

        Test.startTest();
        LimitMetrics.GovernorStats g = LimitMetrics.fetchGovernorStats();
        Test.stopTest();

        // Verify limits show usage
        System.assert(g.dml > 0, 'DML count should be greater than 0 after insert');
        System.assert(g.heapKb > 0, 'Heap should be greater than 0 after operations');

        // Verify remaining limits decrease after usage
        System.assert(g.dmlRemaining < g.dmlMax, 'DML remaining should be less than max after usage');
        System.assert(g.heapKbRemaining < g.heapKbMax, 'Heap remaining should be less than max after usage');

        // Verify percentage used increases
        System.assert(g.dmlPercentUsed > 0, 'DML percent used should be greater than 0');
        System.assert(g.heapPercentUsed > 0, 'Heap percent used should be greater than 0');
    }

    @IsTest
    static void testGovernorStatsAfterSOQL() {
        // Perform a SOQL query to consume limits
        List<Performance_Alert_History__c> records = [
            SELECT Id
            FROM Performance_Alert_History__c
            LIMIT 1
        ];

        Test.startTest();
        LimitMetrics.GovernorStats g = LimitMetrics.fetchGovernorStats();
        Test.stopTest();

        // After startTest/stopTest, governor limits reset, but we can verify the method works
        System.assertNotEquals(null, g, 'GovernorStats should be returned');
        System.assert(g.soql >= 0, 'SOQL count should be valid');
    }

    @IsTest
    static void testCacheableAnnotation() {
        // Call the method multiple times to verify cacheability doesn't cause issues
        Test.startTest();
        LimitMetrics.GovernorStats g1 = LimitMetrics.fetchGovernorStats();
        LimitMetrics.GovernorStats g2 = LimitMetrics.fetchGovernorStats();
        Test.stopTest();

        // Both calls should return valid objects
        System.assertNotEquals(null, g1, 'First call should return valid stats');
        System.assertNotEquals(null, g2, 'Second call should return valid stats');
    }
}
