@IsTest
private class FlowBenchmarkServiceTest {
    @TestSetup
    static void setup() {
        // Create test data with known distribution for percentile testing
        List<Flow_Execution__c> executions = new List<Flow_Execution__c>();

        // TestFlow1 - 30 executions with predictable CPU distribution
        // Range: 1000ms to 10000ms (increments of ~310ms)
        for (Integer i = 0; i < 30; i++) {
            executions.add(
                new Flow_Execution__c(
                    Flow_Name__c = 'TestFlow1',
                    CPU__c = 1000 + (i * 310), // 1000, 1310, 1620, ... 9990ms
                    SOQL__c = 5 + i / 3,
                    DML__c = 2 + i / 6,
                    Status__c = 'SUCCESS',
                    Run_Time__c = System.now().addMinutes(-i)
                )
            );
        }

        // TestFlow2 - 20 executions (smaller sample)
        for (Integer i = 0; i < 20; i++) {
            executions.add(
                new Flow_Execution__c(
                    Flow_Name__c = 'TestFlow2',
                    CPU__c = 2000 + (i * 100), // 2000, 2100, ... 3900ms
                    SOQL__c = 3,
                    DML__c = 1,
                    Status__c = 'SUCCESS',
                    Run_Time__c = System.now().addMinutes(-i)
                )
            );
        }

        // TestFlow3 - Only 5 executions (below minimum for reliable stats)
        for (Integer i = 0; i < 5; i++) {
            executions.add(
                new Flow_Execution__c(
                    Flow_Name__c = 'TestFlow3',
                    CPU__c = 5000,
                    SOQL__c = 10,
                    DML__c = 5,
                    Status__c = 'SUCCESS',
                    Run_Time__c = System.now().addHours(-i)
                )
            );
        }

        insert executions;
    }

    @IsTest
    static void testGetFlowBenchmarks() {
        Test.startTest();
        FlowBenchmarkService.BenchmarkStats stats = FlowBenchmarkService.getFlowBenchmarks(
            'TestFlow1',
            30
        );
        Test.stopTest();

        System.assertNotEquals(null, stats, 'Stats should not be null');
        System.assertEquals('TestFlow1', stats.flowName, 'Flow name should match');
        System.assertEquals(30, stats.sampleSize, 'Should have 30 samples');

        // Verify percentile calculations (approximately)
        // With 30 samples (1000-9990ms):
        // 50th percentile should be around 5500ms
        // 90th percentile should be around 9000ms
        // 99th percentile should be around 9990ms
        System.assert(
            stats.percentile50 >= 5000 && stats.percentile50 <= 6000,
            'Percentile 50 should be ~5500ms, got: ' + stats.percentile50
        );
        System.assert(
            stats.percentile90 >= 8500 && stats.percentile90 <= 9500,
            'Percentile 90 should be ~9000ms, got: ' + stats.percentile90
        );
        System.assert(
            stats.percentile99 >= 9500,
            'Percentile 99 should be ~9990ms, got: ' + stats.percentile99
        );

        // Verify min/max
        System.assertEquals(1000, stats.minCpu, 'Min should be 1000ms');
        System.assertEquals(9990, stats.maxCpu, 'Max should be 9990ms');

        // Verify average is in expected range
        System.assert(
            stats.averageCpu >= 5000 && stats.averageCpu <= 6000,
            'Average should be ~5500ms'
        );
    }

    @IsTest
    static void testGetFlowBenchmarksSmallSample() {
        Test.startTest();
        FlowBenchmarkService.BenchmarkStats stats = FlowBenchmarkService.getFlowBenchmarks(
            'TestFlow3',
            30
        );
        Test.stopTest();

        System.assertNotEquals(null, stats, 'Stats should not be null');
        System.assertEquals(5, stats.sampleSize, 'Should have 5 samples');
        System.assertEquals(5000, stats.percentile50, 'All values are same');
        System.assertEquals(5000, stats.percentile90, 'All values are same');
        System.assertEquals(5000, stats.percentile99, 'All values are same');
    }

    @IsTest
    static void testGetFlowBenchmarksNoData() {
        Test.startTest();
        FlowBenchmarkService.BenchmarkStats stats = FlowBenchmarkService.getFlowBenchmarks(
            'NonExistentFlow',
            30
        );
        Test.stopTest();

        System.assertNotEquals(null, stats, 'Stats should not be null');
        System.assertEquals('NonExistentFlow', stats.flowName, 'Flow name should match');
        System.assertEquals(0, stats.sampleSize, 'Should have 0 samples');
        System.assertEquals(0, stats.percentile50, 'Should be 0 for empty data');
        System.assertEquals(0, stats.percentile90, 'Should be 0 for empty data');
        System.assertEquals(0, stats.percentile99, 'Should be 0 for empty data');
    }

    @IsTest
    static void testRateFlowExecutionExcellent() {
        // CPU below 50th percentile should be Excellent
        Test.startTest();
        FlowBenchmarkService.PerformanceRating rating = FlowBenchmarkService.rateFlowExecution(
            'TestFlow1',
            3000, // Well below 50th percentile (~5500ms)
            30
        );
        Test.stopTest();

        System.assertNotEquals(null, rating, 'Rating should not be null');
        System.assertEquals(
            'Excellent',
            rating.rating,
            'Should be Excellent for CPU below p50'
        );
        System.assert(
            rating.percentileRank < 50,
            'Percentile rank should be < 50'
        );
        System.assertNotEquals(
            null,
            rating.message,
            'Should have descriptive message'
        );
    }

    @IsTest
    static void testRateFlowExecutionGood() {
        // CPU between 50th and 90th percentile should be Good
        Test.startTest();
        FlowBenchmarkService.PerformanceRating rating = FlowBenchmarkService.rateFlowExecution(
            'TestFlow1',
            7000, // Between p50 (~5500) and p90 (~9000)
            30
        );
        Test.stopTest();

        System.assertNotEquals(null, rating, 'Rating should not be null');
        System.assertEquals('Good', rating.rating, 'Should be Good for CPU between p50-p90');
        System.assert(
            rating.percentileRank >= 50 && rating.percentileRank < 90,
            'Percentile rank should be 50-90, got: ' + rating.percentileRank
        );
    }

    @IsTest
    static void testRateFlowExecutionSlow() {
        // CPU between 90th and 99th percentile should be Slow
        Test.startTest();
        FlowBenchmarkService.PerformanceRating rating = FlowBenchmarkService.rateFlowExecution(
            'TestFlow1',
            9500, // Between p90 (~9000) and p99 (~9990)
            30
        );
        Test.stopTest();

        System.assertNotEquals(null, rating, 'Rating should not be null');
        System.assertEquals('Slow', rating.rating, 'Should be Slow for CPU between p90-p99');
        System.assert(
            rating.percentileRank >= 90 && rating.percentileRank < 99,
            'Percentile rank should be 90-99'
        );
    }

    @IsTest
    static void testRateFlowExecutionCritical() {
        // CPU above 99th percentile should be Critical
        Test.startTest();
        FlowBenchmarkService.PerformanceRating rating = FlowBenchmarkService.rateFlowExecution(
            'TestFlow1',
            12000, // Well above p99 (~9990ms)
            30
        );
        Test.stopTest();

        System.assertNotEquals(null, rating, 'Rating should not be null');
        System.assertEquals(
            'Critical',
            rating.rating,
            'Should be Critical for CPU above p99'
        );
        System.assert(rating.percentileRank >= 99, 'Percentile rank should be >= 99');
    }

    @IsTest
    static void testRateFlowExecutionNoData() {
        // Rating with no historical data should default to 'Good'
        Test.startTest();
        FlowBenchmarkService.PerformanceRating rating = FlowBenchmarkService.rateFlowExecution(
            'NonExistentFlow',
            5000,
            30
        );
        Test.stopTest();

        System.assertNotEquals(null, rating, 'Rating should not be null');
        System.assertEquals(
            'Good',
            rating.rating,
            'Should default to Good when no data'
        );
        System.assertEquals(
            50,
            rating.percentileRank,
            'Should default to 50th percentile'
        );
        System.assert(
            rating.message.contains('insufficient data'),
            'Message should mention insufficient data'
        );
    }

    @IsTest
    static void testGetRecentExecutionsWithRatings() {
        Test.startTest();
        List<FlowBenchmarkService.ExecutionWithRating> executions = FlowBenchmarkService.getRecentExecutionsWithRatings(
            'TestFlow1',
            10,
            30
        );
        Test.stopTest();

        System.assertNotEquals(
            null,
            executions,
            'Executions should not be null'
        );
        System.assert(executions.size() > 0, 'Should have executions');
        System.assert(
            executions.size() <= 10,
            'Should respect limit of 10'
        );

        // Verify each execution has required fields
        for (FlowBenchmarkService.ExecutionWithRating exec : executions) {
            System.assertNotEquals(
                null,
                exec.execution,
                'Execution record should not be null'
            );
            System.assertNotEquals(
                null,
                exec.rating,
                'Rating should not be null'
            );
            System.assertEquals(
                'TestFlow1',
                exec.execution.Flow_Name__c,
                'Flow name should match'
            );
            System.assert(
                exec.rating.rating == 'Excellent' ||
                exec.rating.rating == 'Good' ||
                exec.rating.rating == 'Slow' ||
                exec.rating.rating == 'Critical',
                'Rating should be valid: ' + exec.rating.rating
            );
        }
    }

    @IsTest
    static void testGetRecentExecutionsWithRatingsLimit() {
        Test.startTest();
        List<FlowBenchmarkService.ExecutionWithRating> executions = FlowBenchmarkService.getRecentExecutionsWithRatings(
            'TestFlow1',
            5,
            30
        );
        Test.stopTest();

        System.assertEquals(
            5,
            executions.size(),
            'Should respect limit of 5'
        );
    }

    @IsTest
    static void testGetRecentExecutionsWithRatingsNoData() {
        Test.startTest();
        List<FlowBenchmarkService.ExecutionWithRating> executions = FlowBenchmarkService.getRecentExecutionsWithRatings(
            'NonExistentFlow',
            10,
            30
        );
        Test.stopTest();

        System.assertNotEquals(
            null,
            executions,
            'Executions should not be null'
        );
        System.assertEquals(
            0,
            executions.size(),
            'Should have no executions'
        );
    }

    @IsTest
    static void testTrendCalculation() {
        // Create executions with clear trend: older ones slower, newer ones faster
        List<Flow_Execution__c> trendData = new List<Flow_Execution__c>();

        // Older executions (10-5 days ago): slow (8000-9000ms)
        for (Integer i = 5; i < 10; i++) {
            trendData.add(
                new Flow_Execution__c(
                    Flow_Name__c = 'TrendFlow',
                    CPU__c = 8000 + (i * 100),
                    SOQL__c = 10,
                    DML__c = 5,
                    Status__c = 'SUCCESS',
                    Run_Time__c = System.now().addDays(-i - 5)
                )
            );
        }

        // Newer executions (0-5 days ago): fast (2000-3000ms)
        for (Integer i = 0; i < 5; i++) {
            trendData.add(
                new Flow_Execution__c(
                    Flow_Name__c = 'TrendFlow',
                    CPU__c = 2000 + (i * 200),
                    SOQL__c = 3,
                    DML__c = 1,
                    Status__c = 'SUCCESS',
                    Run_Time__c = System.now().addDays(-i)
                )
            );
        }

        insert trendData;

        Test.startTest();
        FlowBenchmarkService.BenchmarkStats stats = FlowBenchmarkService.getFlowBenchmarks(
            'TrendFlow',
            15
        );
        Test.stopTest();

        System.assertNotEquals(null, stats, 'Stats should not be null');
        System.assertNotEquals(null, stats.trend, 'Trend should be calculated');
        System.assertEquals(
            'Improving',
            stats.trend,
            'Trend should be Improving (newer executions faster)'
        );
    }

    @IsTest
    static void testPercentileCalculationEdgeCases() {
        // Test with TestFlow2 (20 samples)
        Test.startTest();
        FlowBenchmarkService.BenchmarkStats stats = FlowBenchmarkService.getFlowBenchmarks(
            'TestFlow2',
            30
        );
        Test.stopTest();

        System.assertEquals(20, stats.sampleSize, 'Should have 20 samples');
        System.assert(
            stats.percentile50 > 0,
            'Percentile 50 should be calculated'
        );
        System.assert(
            stats.percentile90 > stats.percentile50,
            'Percentile 90 should be > percentile 50'
        );
        System.assert(
            stats.percentile99 >= stats.percentile90,
            'Percentile 99 should be >= percentile 90'
        );
    }
}
