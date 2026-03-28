/**
 * Generates an unbiased comparison report between two compliance platforms:
 * Elaro (Salesforce-native 2GP) and Vanta MCP Server (AI integration layer).
 *
 * Scores each platform on how well it achieves its own stated goals, not on
 * absolute feature count. Categories outside a platform's scope are marked N/A
 * and excluded from weighted grade calculation.
 *
 * @author Elaro Team
 * @since v3.1.0 (Spring '26)
 * @group Comparison
 * @see ComparisonGradingEngineTest
 */
public inherited sharing class ComparisonGradingEngine {

    /**
     * Represents a benchmark category with weight and applicability flags.
     */
    public class BenchmarkCategory {
        @AuraEnabled public String name;
        @AuraEnabled public Decimal weight;
        @AuraEnabled public String description;
        @AuraEnabled public Boolean applicableToPlatformA;
        @AuraEnabled public Boolean applicableToPlatformB;

        /**
         * Constructs a benchmark category.
         *
         * @param name Category display name
         * @param weight Percentage weight (0-100) toward final grade
         * @param description What this category measures
         * @param applicableA Whether this category applies to Platform A (Elaro)
         * @param applicableB Whether this category applies to Platform B (Vanta MCP)
         */
        public BenchmarkCategory(String name, Decimal weight, String description, Boolean applicableA, Boolean applicableB) {
            this.name = name;
            this.weight = weight;
            this.description = description;
            this.applicableToPlatformA = applicableA;
            this.applicableToPlatformB = applicableB;
        }
    }

    /**
     * Represents a single platform's score for one benchmark category.
     */
    public class PlatformScore {
        @AuraEnabled public String categoryName;
        @AuraEnabled public Integer score;
        @AuraEnabled public Integer maxScore;
        @AuraEnabled public Boolean applicable;
        @AuraEnabled public String justification;
        @AuraEnabled public List<String> strengths;
        @AuraEnabled public List<String> weaknesses;

        /**
         * Constructs a platform score entry.
         *
         * @param categoryName The benchmark category name
         * @param score Numeric score (0-10), ignored if not applicable
         * @param applicable Whether this category is in-scope for the platform
         * @param justification Factual rationale for the score
         * @param strengths List of specific strengths in this category
         * @param weaknesses List of specific weaknesses in this category
         */
        public PlatformScore(String categoryName, Integer score, Boolean applicable, String justification, List<String> strengths, List<String> weaknesses) {
            this.categoryName = categoryName;
            this.score = score;
            this.maxScore = 10;
            this.applicable = applicable;
            this.justification = justification;
            this.strengths = strengths;
            this.weaknesses = weaknesses;
        }
    }

    /**
     * The full comparison report with scores, grades, and summary for both platforms.
     */
    public class ComparisonReport {
        @AuraEnabled public String platformAName;
        @AuraEnabled public String platformAType;
        @AuraEnabled public String platformBName;
        @AuraEnabled public String platformBType;
        @AuraEnabled public List<PlatformScore> platformAScores;
        @AuraEnabled public List<PlatformScore> platformBScores;
        @AuraEnabled public List<BenchmarkCategory> categories;
        @AuraEnabled public Decimal platformAWeightedTotal;
        @AuraEnabled public Decimal platformBWeightedTotal;
        @AuraEnabled public String platformAGrade;
        @AuraEnabled public String platformBGrade;
        @AuraEnabled public Integer sharedCategoryCount;
        @AuraEnabled public String summary;
        @AuraEnabled public Datetime generatedDate;
    }

    /**
     * Generates the full comparison report between Elaro and Vanta MCP Server.
     *
     * @return ComparisonReport with scores, weighted totals, letter grades, and summary
     * @throws AuraHandledException if report generation fails
     */
    @AuraEnabled(cacheable=true)
    public static ComparisonReport generateReport() {
        try {
            ComparisonReport report = new ComparisonReport();
            report.platformAName = 'Elaro';
            report.platformAType = 'Full Compliance Platform (Salesforce 2GP)';
            report.platformBName = 'Vanta MCP Server';
            report.platformBType = 'AI Integration Layer (MCP Protocol)';
            report.generatedDate = Datetime.now();

            report.categories = getBenchmarkCategories();
            report.platformAScores = getElaroScores();
            report.platformBScores = getVantaScores();

            report.platformAWeightedTotal = calculateWeightedScore(report.platformAScores, report.categories);
            report.platformBWeightedTotal = calculateWeightedScore(report.platformBScores, report.categories);

            report.platformAGrade = convertToLetterGrade(report.platformAWeightedTotal);
            report.platformBGrade = convertToLetterGrade(report.platformBWeightedTotal);

            report.sharedCategoryCount = countSharedCategories(report.categories);
            report.summary = generateSummary(report);

            return report;
        } catch (Exception e) {
            ElaroLogger.error('ComparisonGradingEngine.generateReport', e.getMessage(), e.getStackTraceString());
            throw new AuraHandledException('Unable to generate comparison report. Please try again.');
        }
    }

    /**
     * Returns the 12 benchmark categories with weights and applicability flags.
     *
     * @return List of BenchmarkCategory definitions
     */
    @TestVisible
    private static List<BenchmarkCategory> getBenchmarkCategories() {
        return new List<BenchmarkCategory>{
            new BenchmarkCategory('Framework Coverage', 10, 'Number and depth of compliance frameworks supported', true, true),
            new BenchmarkCategory('Compliance Lifecycle', 10, 'Assessment, scanning, remediation, monitoring, and reporting capabilities', true, false),
            new BenchmarkCategory('Architecture & Extensibility', 10, 'Modularity, plugin system, and customization potential', true, true),
            new BenchmarkCategory('Security Model', 10, 'How the tool itself handles security, authentication, and authorization', true, true),
            new BenchmarkCategory('AI & Automation', 10, 'AI features, automated scanning, LLM optimization, and smart remediation', true, true),
            new BenchmarkCategory('Integration Breadth', 8, 'Connectivity to external systems, APIs, and data sources', true, true),
            new BenchmarkCategory('UI/UX & Reporting', 8, 'Dashboard, reporting, and visualization capabilities', true, false),
            new BenchmarkCategory('Testing & Quality Assurance', 8, 'Test coverage, CI/CD, code quality tooling, and validation', true, true),
            new BenchmarkCategory('Developer Experience', 8, 'Setup complexity, documentation, API design, and learning curve', true, true),
            new BenchmarkCategory('Scalability & Performance', 8, 'Large dataset handling, async patterns, caching, and throughput', true, true),
            new BenchmarkCategory('Vendor & Third-Party Risk', 5, 'Vendor management, supply chain risk, and third-party assessment', true, true),
            new BenchmarkCategory('Evidence & Audit Trail', 5, 'Evidence collection, audit logging, and document management', true, true)
        };
    }

    /**
     * Returns Elaro benchmark scores with factual justifications.
     *
     * @return List of PlatformScore entries for Elaro
     */
    @TestVisible
    private static List<PlatformScore> getElaroScores() {
        return new List<PlatformScore>{
            new PlatformScore(
                'Framework Coverage', 8, true,
                '14 frameworks built-in (HIPAA, SOC2, PCI-DSS, GDPR, CCPA, GLBA, ISO 27001, FINRA, FedRAMP, CMMC 2.0, SEC, NIS2, DORA, AI Governance). Some modules such as NIS2, DORA, and CMMC are early-stage.',
                new List<String>{ 'Broadest built-in framework coverage', 'Dedicated modules per framework with custom logic', 'Includes emerging regulations (AI Governance, NIS2, DORA)' },
                new List<String>{ 'Some framework modules are still under active development', 'Framework depth varies — mature for SOC2/HIPAA, early for CMMC/NIS2' }
            ),
            new PlatformScore(
                'Compliance Lifecycle', 7, true,
                'Full lifecycle coverage: assessment wizards, scanning, remediation tracking, monitoring, reporting, and scheduling. Several modules are still being built per Team 2 build plan.',
                new List<String>{ 'End-to-end lifecycle in one platform', 'Assessment wizards with guided workflows', 'Automated scanning and scheduled monitoring' },
                new List<String>{ 'Some lifecycle stages are scaffolded but not production-tested', 'Team 2 modules still in build phase' }
            ),
            new PlatformScore(
                'Architecture & Extensibility', 7, true,
                'ComplianceServiceFactory + IComplianceModule plugin system enables modular compliance modules. Rule engine and orchestration engine provide extensibility. Tightly coupled to Salesforce platform constraints.',
                new List<String>{ 'Plugin architecture via ComplianceServiceFactory', 'Rule engine supports custom compliance rules', 'Orchestration engine for complex workflows' },
                new List<String>{ 'Constrained by Salesforce governor limits', '299 classes creates a large surface area to maintain', 'Platform coupling limits portability' }
            ),
            new PlatformScore(
                'Security Model', 8, true,
                'Leverages Salesforce security model: WITH USER_MODE for SOQL, sharing keywords, FLS via stripInaccessible, Permission Sets for 2GP access control. Well-implemented but primarily platform-provided.',
                new List<String>{ 'Mature platform security model (FLS, CRUD, sharing)', 'Consistent WITH USER_MODE enforcement', 'Permission Set-based access control for managed package' },
                new List<String>{ 'Security model is platform-provided rather than custom innovation', 'Tooling API calls run in system context (documented exception)' }
            ),
            new PlatformScore(
                'AI & Automation', 6, true,
                'Includes AI Risk Predictor, AI Detection Engine, Compliance Copilot, and AI Governance module. These rely on external API callouts and are constrained by Salesforce platform limits. No LLM evaluation framework.',
                new List<String>{ 'Dedicated AI Governance module for EU AI Act / NIST AI RMF', 'Compliance Copilot for AI-assisted guidance', 'AI risk classification engine' },
                new List<String>{ 'AI features depend on external API callouts', 'No evaluation framework to validate AI accuracy', 'Salesforce callout limits constrain AI capabilities' }
            ),
            new PlatformScore(
                'Integration Breadth', 5, true,
                'Salesforce-native with Tooling API access and Platform Events. Jira integration modal exists. Limited to Salesforce ecosystem for most operations.',
                new List<String>{ 'Deep Salesforce platform integration', 'Platform Events for real-time notifications', 'Jira issue creation from compliance findings' },
                new List<String>{ 'Locked to Salesforce ecosystem', 'Limited external system integrations', 'No MCP or open protocol support' }
            ),
            new PlatformScore(
                'UI/UX & Reporting', 8, true,
                '60 LWC components including dashboards, heatmaps, trend charts, drill-down viewers, executive KPI dashboards, assessment wizards, and setup wizards. Solid Salesforce-native UI.',
                new List<String>{ '60 purpose-built LWC components', 'Executive KPI dashboards and trend analytics', 'Guided assessment wizards with progress tracking' },
                new List<String>{ 'Some LWC components lack Jest test coverage', 'UI limited to Salesforce Lightning Experience' }
            ),
            new PlatformScore(
                'Testing & Quality Assurance', 7, true,
                'Test class exists for every production Apex class. CI/CD pipeline with GitHub Actions. Jest tests for LWC exist but coverage is sparse for some components. Salesforce Code Analyzer integration.',
                new List<String>{ 'Test class for every production class', 'CI/CD pipeline with 6-stage validation', 'Code Analyzer integration for security scanning' },
                new List<String>{ 'Jest coverage is sparse for some LWC components', 'Test quality and assertion depth vary across classes' }
            ),
            new PlatformScore(
                'Developer Experience', 5, true,
                'Requires Salesforce platform expertise, scratch org setup, understanding of governor limits and sharing model. CLAUDE.md provides excellent documentation but the overall learning curve is steep.',
                new List<String>{ 'Comprehensive CLAUDE.md with coding standards', 'ComplianceTestDataFactory for test data patterns', 'Turborepo platform CLI for TypeScript tooling' },
                new List<String>{ 'Steep learning curve — requires Salesforce expertise', 'Scratch org setup adds development overhead', 'Governor limits require specialized knowledge' }
            ),
            new PlatformScore(
                'Scalability & Performance', 7, true,
                'Queueable + Cursors pattern for large dataset processing. Platform Cache (3MB ISV partition) for cross-transaction caching. Batch processing and async framework. Constrained by Salesforce governor limits.',
                new List<String>{ 'Queueable + Cursor pattern for large datasets', 'Platform Cache with configurable TTL', 'Transaction Finalizers for retry patterns' },
                new List<String>{ 'Salesforce governor limits cap throughput', 'Cursor limits: 50M rows, 10 fetches per transaction', 'Heap size limits constrain in-memory processing' }
            ),
            new PlatformScore(
                'Vendor & Third-Party Risk', 4, true,
                'Limited vendor risk management features in current codebase. No dedicated vendor management module or vendor discovery found. Focus has been on internal compliance rather than third-party risk.',
                new List<String>{ 'Compliance framework includes vendor-relevant controls', 'Trust Center components exist for transparency' },
                new List<String>{ 'No dedicated vendor management module', 'No automated vendor discovery', 'Third-party risk is a gap in current feature set' }
            ),
            new PlatformScore(
                'Evidence & Audit Trail', 7, true,
                'ElaroLogger publishes Platform Events in Publish Immediately mode (survives transaction rollback). Audit trail poller and audit package generator provide evidence collection. Logging is basic key-value format.',
                new List<String>{ 'Platform Event logging survives rollback', 'Audit package generator for evidence bundles', 'Audit trail poller for historical data' },
                new List<String>{ 'Logging format is basic key-value', 'No structured evidence linking to specific controls' }
            )
        };
    }

    /**
     * Returns Vanta MCP Server benchmark scores with factual justifications.
     *
     * @return List of PlatformScore entries for Vanta MCP Server
     */
    @TestVisible
    private static List<PlatformScore> getVantaScores() {
        return new List<PlatformScore>{
            new PlatformScore(
                'Framework Coverage', 7, true,
                'Dynamically queries whatever frameworks the Vanta org has configured. Default frameworks include SOC2, ISO 27001, HIPAA, GDPR. Actual coverage depends on Vanta subscription tier — could be 20+ frameworks.',
                new List<String>{ 'Dynamic framework support based on org configuration', 'Framework completion metrics and control mapping', 'No hard limit on framework count' },
                new List<String>{ 'Framework depth depends on Vanta platform, not MCP server', 'No custom framework logic — pure pass-through to Vanta API' }
            ),
            new PlatformScore(
                'Compliance Lifecycle', 0, false,
                'Outside scope. Vanta MCP Server is a read-only query interface, not a lifecycle management tool. Vanta the platform has full lifecycle capabilities, but those are not exposed through write operations in the MCP server.',
                new List<String>(),
                new List<String>()
            ),
            new PlatformScore(
                'Architecture & Extensibility', 9, true,
                'Registry pattern auto-discovers 18 operation modules. Zod schemas provide runtime validation. Consolidated tool design reduces endpoints to 53 well-organized tools. TypeScript strict mode. Clean separation of concerns.',
                new List<String>{ 'Auto-discovery registry pattern for operation modules', 'Zod schema validation at runtime', 'Consolidated tool design — single endpoint handles list and detail' },
                new List<String>{ 'Extensibility limited to adding new operation modules', 'No plugin system for external developers' }
            ),
            new PlatformScore(
                'Security Model', 8, true,
                'Read-only by design (principle of least privilege). OAuth 2.0 client credentials with automatic token refresh and 1-minute expiration buffer. Scoped to vanta-api.all:read. Responsible disclosure policy.',
                new List<String>{ 'Read-only scope enforces least privilege', 'OAuth 2.0 with automatic token refresh', 'Responsible disclosure security policy' },
                new List<String>{ 'Single credential model — no multi-tenant support', 'No token revocation mechanism visible', 'Credentials stored in local JSON file' }
            ),
            new PlatformScore(
                'AI & Automation', 9, true,
                'Purpose-built for AI consumption. 66-case evaluation framework validates LLM tool selection accuracy. Tool descriptions optimized for AI discoverability. Intelligent document handling returns text for readable formats, metadata for binary files.',
                new List<String>{ '66-case evaluation framework for AI accuracy', 'Tool descriptions optimized for LLM understanding', 'Intelligent format-aware document handling' },
                new List<String>{ 'AI optimization is for querying only, not remediation', 'Evaluation framework tests tool selection, not output quality' }
            ),
            new PlatformScore(
                'Integration Breadth', 9, true,
                'MCP protocol enables connection to any compatible AI client (Claude Desktop, Cursor, etc). 53 tools discover and query integrations, vendors, and resources across the entire connected toolchain. Tool filtering via allowlist.',
                new List<String>{ 'MCP protocol compatible with any MCP client', '53 tools across 6 functional domains', 'Discovers integrations and resources automatically' },
                new List<String>{ 'Read-only — cannot trigger actions in connected systems', 'Single Vanta org per server instance' }
            ),
            new PlatformScore(
                'UI/UX & Reporting', 0, false,
                'Outside scope. Vanta MCP Server is a headless protocol server by design. AI clients (Claude Desktop, Cursor) provide the user interface. The server returns structured data, not rendered UI.',
                new List<String>(),
                new List<String>()
            ),
            new PlatformScore(
                'Testing & Quality Assurance', 8, true,
                'TypeScript strict mode catches errors at compile time. 66-case evaluation framework validates tool behavior. ESLint + Prettier enforced. Smaller codebase surface area simplifies quality maintenance.',
                new List<String>{ 'TypeScript strict mode for compile-time safety', '66-case evaluation framework', 'Professional linting and formatting enforcement' },
                new List<String>{ 'Limited traditional unit test coverage visible', 'Evaluation framework focuses on tool selection, not edge cases' }
            ),
            new PlatformScore(
                'Developer Experience', 9, true,
                'Install via npx in under a minute. Single environment file for OAuth credentials. 53 self-documenting tools with Zod schemas. Any TypeScript developer can contribute. MIT license.',
                new List<String>{ 'npx one-command installation', 'Self-documenting tools via Zod schemas', 'MIT license — low barrier to contribution' },
                new List<String>{ 'Requires Vanta account with API access', 'Limited documentation beyond README' }
            ),
            new PlatformScore(
                'Scalability & Performance', 6, true,
                'Lightweight relay architecture — minimal server-side processing. No caching layer. Pagination required for large result sets (pageSize 1-100). Single OAuth credential per instance. No rate limit handling beyond token refresh.',
                new List<String>{ 'Lightweight relay with minimal overhead', 'Pagination support for large datasets', 'Stateless design enables horizontal scaling of server instances' },
                new List<String>{ 'No client-side caching', 'No rate limit headers or retry logic', 'Single credential per instance limits multi-org use' }
            ),
            new PlatformScore(
                'Vendor & Third-Party Risk', 8, true,
                'Comprehensive vendor management: discovery, compliance documents, security reviews, risk attributes, account linking. 13+ vendor-related tools including automated vendor discovery and Trust Center integration.',
                new List<String>{ 'Automated vendor discovery', 'Security review and compliance document retrieval', '13+ dedicated vendor management tools' },
                new List<String>{ 'Read-only — cannot update vendor risk status', 'Vendor data quality depends on Vanta platform configuration' }
            ),
            new PlatformScore(
                'Evidence & Audit Trail', 7, true,
                'Document retrieval with framework filtering. Evidence linking to controls. Intelligent file download (text for readable, metadata for binary). Control-document mapping. Read-only access.',
                new List<String>{ 'Evidence linked directly to controls', 'Intelligent document format handling', 'Framework-filtered document queries' },
                new List<String>{ 'Read-only — cannot upload or create evidence', 'No audit logging of MCP server queries themselves' }
            )
        };
    }

    /**
     * Calculates the weighted score for a platform, re-normalizing weights to
     * exclude categories marked as not applicable.
     *
     * @param scores List of platform scores
     * @param categories List of benchmark categories with weights
     * @return Weighted average score on a 0-10 scale
     */
    @TestVisible
    private static Decimal calculateWeightedScore(List<PlatformScore> scores, List<BenchmarkCategory> categories) {
        Map<String, PlatformScore> scoreMap = new Map<String, PlatformScore>();
        for (PlatformScore ps : scores) {
            scoreMap.put(ps.categoryName, ps);
        }

        Decimal totalApplicableWeight = 0;
        Decimal weightedSum = 0;

        for (BenchmarkCategory cat : categories) {
            PlatformScore ps = scoreMap.get(cat.name);
            if (ps != null && ps.applicable) {
                totalApplicableWeight += cat.weight;
                weightedSum += cat.weight * ps.score;
            }
        }

        if (totalApplicableWeight == 0) {
            return 0;
        }

        return (weightedSum / totalApplicableWeight).setScale(1, RoundingMode.HALF_UP);
    }

    /**
     * Converts a weighted numeric score (0-10) to a letter grade.
     *
     * @param weightedScore The weighted score on a 0-10 scale
     * @return Letter grade from A+ to F
     */
    @TestVisible
    private static String convertToLetterGrade(Decimal weightedScore) {
        if (weightedScore >= 9.5) { return 'A+'; }
        if (weightedScore >= 9.0) { return 'A'; }
        if (weightedScore >= 8.5) { return 'A-'; }
        if (weightedScore >= 8.0) { return 'B+'; }
        if (weightedScore >= 7.5) { return 'B'; }
        if (weightedScore >= 7.0) { return 'B-'; }
        if (weightedScore >= 6.5) { return 'C+'; }
        if (weightedScore >= 6.0) { return 'C'; }
        if (weightedScore >= 5.0) { return 'D'; }
        return 'F';
    }

    /**
     * Counts how many categories are applicable to both platforms.
     *
     * @param categories List of benchmark categories
     * @return Number of categories where both platforms are scored
     */
    private static Integer countSharedCategories(List<BenchmarkCategory> categories) {
        Integer count = 0;
        for (BenchmarkCategory cat : categories) {
            if (cat.applicableToPlatformA && cat.applicableToPlatformB) {
                count++;
            }
        }
        return count;
    }

    /**
     * Generates a text summary of the comparison report.
     *
     * @param report The completed comparison report
     * @return Summary string with key findings
     */
    @TestVisible
    private static String generateSummary(ComparisonReport report) {
        String summary = 'Comparison between ' + report.platformAName + ' (' + report.platformAType + ') '
            + 'and ' + report.platformBName + ' (' + report.platformBType + '). '
            + 'These are fundamentally different product types — scores reflect how well each achieves its own stated goals. ';

        summary += report.platformAName + ' scored ' + report.platformAWeightedTotal + '/10 (Grade: ' + report.platformAGrade + ') '
            + 'across all 12 categories. ';
        summary += report.platformBName + ' scored ' + report.platformBWeightedTotal + '/10 (Grade: ' + report.platformBGrade + ') '
            + 'across ' + report.sharedCategoryCount + ' applicable categories (2 marked Outside Scope). ';

        summary += report.platformAName + ' excels in framework coverage, compliance lifecycle, UI/UX, and security model. '
            + 'It falls short in developer experience, integration breadth, and AI optimization. ';
        summary += report.platformBName + ' excels in AI optimization, developer experience, integration breadth, and architecture. '
            + 'It falls short in scalability, has no write operations, and depends on the Vanta platform for framework depth.';

        return summary;
    }
}
