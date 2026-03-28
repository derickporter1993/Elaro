/**
 * Tests for ComparisonGradingEngine covering report generation, weighted score
 * calculation, letter grade conversion, and N/A category handling.
 *
 * @author Elaro Team
 * @since v3.1.0 (Spring '26)
 * @group Comparison
 * @see ComparisonGradingEngine
 */
@IsTest(testFor=ComparisonGradingEngine.class)
private class ComparisonGradingEngineTest {

    @IsTest
    static void shouldGenerateReportWithAllCategories() {
        Test.startTest();
        ComparisonGradingEngine.ComparisonReport report = ComparisonGradingEngine.generateReport();
        Test.stopTest();

        Assert.isNotNull(report, 'Report should not be null');
        Assert.areEqual('Elaro', report.platformAName, 'Platform A should be Elaro');
        Assert.areEqual('Vanta MCP Server', report.platformBName, 'Platform B should be Vanta MCP Server');
        Assert.areEqual(12, report.platformAScores.size(), 'Elaro should have 12 category scores');
        Assert.areEqual(12, report.platformBScores.size(), 'Vanta should have 12 category scores');
        Assert.areEqual(12, report.categories.size(), 'Should have 12 benchmark categories');
    }

    @IsTest
    static void shouldCalculateWeightedTotals() {
        Test.startTest();
        ComparisonGradingEngine.ComparisonReport report = ComparisonGradingEngine.generateReport();
        Test.stopTest();

        Assert.isTrue(report.platformAWeightedTotal >= 0 && report.platformAWeightedTotal <= 10,
            'Elaro weighted total should be 0-10, got: ' + report.platformAWeightedTotal);
        Assert.isTrue(report.platformBWeightedTotal >= 0 && report.platformBWeightedTotal <= 10,
            'Vanta weighted total should be 0-10, got: ' + report.platformBWeightedTotal);
    }

    @IsTest
    static void shouldAssignLetterGrades() {
        Test.startTest();
        ComparisonGradingEngine.ComparisonReport report = ComparisonGradingEngine.generateReport();
        Test.stopTest();

        Set<String> validGrades = new Set<String>{ 'A+', 'A', 'A-', 'B+', 'B', 'B-', 'C+', 'C', 'D', 'F' };
        Assert.isTrue(validGrades.contains(report.platformAGrade),
            'Elaro grade should be valid letter grade, got: ' + report.platformAGrade);
        Assert.isTrue(validGrades.contains(report.platformBGrade),
            'Vanta grade should be valid letter grade, got: ' + report.platformBGrade);
    }

    @IsTest
    static void shouldCountSharedCategories() {
        Test.startTest();
        ComparisonGradingEngine.ComparisonReport report = ComparisonGradingEngine.generateReport();
        Test.stopTest();

        Assert.areEqual(10, report.sharedCategoryCount,
            'Should have 10 shared categories (2 are N/A for Vanta)');
    }

    @IsTest
    static void shouldMarkVantaNACategories() {
        Test.startTest();
        ComparisonGradingEngine.ComparisonReport report = ComparisonGradingEngine.generateReport();
        Test.stopTest();

        Map<String, ComparisonGradingEngine.PlatformScore> vantaScoreMap = new Map<String, ComparisonGradingEngine.PlatformScore>();
        for (ComparisonGradingEngine.PlatformScore ps : report.platformBScores) {
            vantaScoreMap.put(ps.categoryName, ps);
        }

        Assert.isFalse(vantaScoreMap.get('Compliance Lifecycle').applicable,
            'Compliance Lifecycle should be N/A for Vanta MCP');
        Assert.isFalse(vantaScoreMap.get('UI/UX & Reporting').applicable,
            'UI/UX & Reporting should be N/A for Vanta MCP');
    }

    @IsTest
    static void shouldHaveAllElaroScoresApplicable() {
        Test.startTest();
        ComparisonGradingEngine.ComparisonReport report = ComparisonGradingEngine.generateReport();
        Test.stopTest();

        for (ComparisonGradingEngine.PlatformScore ps : report.platformAScores) {
            Assert.isTrue(ps.applicable,
                'All Elaro scores should be applicable, but ' + ps.categoryName + ' was N/A');
        }
    }

    @IsTest
    static void shouldHaveScoresInValidRange() {
        Test.startTest();
        ComparisonGradingEngine.ComparisonReport report = ComparisonGradingEngine.generateReport();
        Test.stopTest();

        for (ComparisonGradingEngine.PlatformScore ps : report.platformAScores) {
            if (ps.applicable) {
                Assert.isTrue(ps.score >= 0 && ps.score <= 10,
                    'Elaro score for ' + ps.categoryName + ' should be 0-10, got: ' + ps.score);
            }
        }
        for (ComparisonGradingEngine.PlatformScore ps : report.platformBScores) {
            if (ps.applicable) {
                Assert.isTrue(ps.score >= 0 && ps.score <= 10,
                    'Vanta score for ' + ps.categoryName + ' should be 0-10, got: ' + ps.score);
            }
        }
    }

    @IsTest
    static void shouldHaveMaxScoreOf10() {
        Test.startTest();
        ComparisonGradingEngine.ComparisonReport report = ComparisonGradingEngine.generateReport();
        Test.stopTest();

        for (ComparisonGradingEngine.PlatformScore ps : report.platformAScores) {
            Assert.areEqual(10, ps.maxScore, 'Max score should always be 10');
        }
    }

    @IsTest
    static void shouldCalculateWeightedScoreWithKnownInputs() {
        List<ComparisonGradingEngine.BenchmarkCategory> categories = new List<ComparisonGradingEngine.BenchmarkCategory>{
            new ComparisonGradingEngine.BenchmarkCategory('Cat A', 50, 'Test A', true, true),
            new ComparisonGradingEngine.BenchmarkCategory('Cat B', 50, 'Test B', true, true)
        };

        List<ComparisonGradingEngine.PlatformScore> scores = new List<ComparisonGradingEngine.PlatformScore>{
            new ComparisonGradingEngine.PlatformScore('Cat A', 8, true, 'Test', new List<String>(), new List<String>()),
            new ComparisonGradingEngine.PlatformScore('Cat B', 6, true, 'Test', new List<String>(), new List<String>())
        };

        Test.startTest();
        Decimal result = ComparisonGradingEngine.calculateWeightedScore(scores, categories);
        Test.stopTest();

        Assert.areEqual(7.0, result, 'Weighted score of 8 and 6 with equal weights should be 7.0');
    }

    @IsTest
    static void shouldExcludeNAFromWeightedCalculation() {
        List<ComparisonGradingEngine.BenchmarkCategory> categories = new List<ComparisonGradingEngine.BenchmarkCategory>{
            new ComparisonGradingEngine.BenchmarkCategory('Cat A', 50, 'Test A', true, true),
            new ComparisonGradingEngine.BenchmarkCategory('Cat B', 50, 'Test B', true, false)
        };

        List<ComparisonGradingEngine.PlatformScore> scores = new List<ComparisonGradingEngine.PlatformScore>{
            new ComparisonGradingEngine.PlatformScore('Cat A', 8, true, 'Test', new List<String>(), new List<String>()),
            new ComparisonGradingEngine.PlatformScore('Cat B', 0, false, 'N/A', new List<String>(), new List<String>())
        };

        Test.startTest();
        Decimal result = ComparisonGradingEngine.calculateWeightedScore(scores, categories);
        Test.stopTest();

        Assert.areEqual(8.0, result, 'N/A category should be excluded; only Cat A score of 8 should count');
    }

    @IsTest
    static void shouldHandleAllWeightsZero() {
        List<ComparisonGradingEngine.BenchmarkCategory> categories = new List<ComparisonGradingEngine.BenchmarkCategory>{
            new ComparisonGradingEngine.BenchmarkCategory('Cat A', 50, 'Test', true, true)
        };

        List<ComparisonGradingEngine.PlatformScore> scores = new List<ComparisonGradingEngine.PlatformScore>{
            new ComparisonGradingEngine.PlatformScore('Cat A', 0, false, 'N/A', new List<String>(), new List<String>())
        };

        Test.startTest();
        Decimal result = ComparisonGradingEngine.calculateWeightedScore(scores, categories);
        Test.stopTest();

        Assert.areEqual(0, result, 'All N/A scores should return 0');
    }

    @IsTest
    static void shouldConvertLetterGradeBoundaries() {
        Test.startTest();
        Assert.areEqual('A+', ComparisonGradingEngine.convertToLetterGrade(9.5), 'Score 9.5 should be A+');
        Assert.areEqual('A+', ComparisonGradingEngine.convertToLetterGrade(10.0), 'Score 10.0 should be A+');
        Assert.areEqual('A', ComparisonGradingEngine.convertToLetterGrade(9.0), 'Score 9.0 should be A');
        Assert.areEqual('A-', ComparisonGradingEngine.convertToLetterGrade(8.5), 'Score 8.5 should be A-');
        Assert.areEqual('B+', ComparisonGradingEngine.convertToLetterGrade(8.0), 'Score 8.0 should be B+');
        Assert.areEqual('B', ComparisonGradingEngine.convertToLetterGrade(7.5), 'Score 7.5 should be B');
        Assert.areEqual('B-', ComparisonGradingEngine.convertToLetterGrade(7.0), 'Score 7.0 should be B-');
        Assert.areEqual('C+', ComparisonGradingEngine.convertToLetterGrade(6.5), 'Score 6.5 should be C+');
        Assert.areEqual('C', ComparisonGradingEngine.convertToLetterGrade(6.0), 'Score 6.0 should be C');
        Assert.areEqual('D', ComparisonGradingEngine.convertToLetterGrade(5.0), 'Score 5.0 should be D');
        Assert.areEqual('F', ComparisonGradingEngine.convertToLetterGrade(4.9), 'Score 4.9 should be F');
        Assert.areEqual('F', ComparisonGradingEngine.convertToLetterGrade(0), 'Score 0 should be F');
        Test.stopTest();
    }

    @IsTest
    static void shouldGenerateSummary() {
        Test.startTest();
        ComparisonGradingEngine.ComparisonReport report = ComparisonGradingEngine.generateReport();
        Test.stopTest();

        Assert.isNotNull(report.summary, 'Summary should not be null');
        Assert.isTrue(report.summary.contains('Elaro'), 'Summary should mention Elaro');
        Assert.isTrue(report.summary.contains('Vanta MCP Server'), 'Summary should mention Vanta MCP Server');
        Assert.isTrue(report.summary.contains('fundamentally different'), 'Summary should note different product types');
    }

    @IsTest
    static void shouldHaveGeneratedDate() {
        Test.startTest();
        ComparisonGradingEngine.ComparisonReport report = ComparisonGradingEngine.generateReport();
        Test.stopTest();

        Assert.isNotNull(report.generatedDate, 'Generated date should not be null');
    }

    @IsTest
    static void shouldHavePlatformTypes() {
        Test.startTest();
        ComparisonGradingEngine.ComparisonReport report = ComparisonGradingEngine.generateReport();
        Test.stopTest();

        Assert.isTrue(report.platformAType.contains('Salesforce'), 'Elaro type should mention Salesforce');
        Assert.isTrue(report.platformBType.contains('MCP'), 'Vanta type should mention MCP');
    }

    @IsTest
    static void shouldHaveWeightsSumToHundred() {
        List<ComparisonGradingEngine.BenchmarkCategory> categories = ComparisonGradingEngine.getBenchmarkCategories();
        Decimal totalWeight = 0;
        for (ComparisonGradingEngine.BenchmarkCategory cat : categories) {
            totalWeight += cat.weight;
        }
        Assert.areEqual(100, totalWeight, 'Category weights should sum to 100, got: ' + totalWeight);
    }

    @IsTest
    static void shouldHaveJustificationsForAllApplicableScores() {
        Test.startTest();
        ComparisonGradingEngine.ComparisonReport report = ComparisonGradingEngine.generateReport();
        Test.stopTest();

        for (ComparisonGradingEngine.PlatformScore ps : report.platformAScores) {
            if (ps.applicable) {
                Assert.isTrue(String.isNotBlank(ps.justification),
                    'Elaro score for ' + ps.categoryName + ' should have a justification');
            }
        }
        for (ComparisonGradingEngine.PlatformScore ps : report.platformBScores) {
            if (ps.applicable) {
                Assert.isTrue(String.isNotBlank(ps.justification),
                    'Vanta score for ' + ps.categoryName + ' should have a justification');
            }
        }
    }
}
