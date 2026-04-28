/**
 * REST API exposing Elaro compliance data to external consumers.
 * Supports compliance scores, findings, framework status, and vendor risk.
 *
 * Endpoints:
 *   GET /services/apexrest/elaro/v1/compliance/scores — All framework scores
 *   GET /services/apexrest/elaro/v1/compliance/scores/{framework} — Single framework score
 *   GET /services/apexrest/elaro/v1/compliance/findings?severity=X&status=Y — Compliance gaps
 *   GET /services/apexrest/elaro/v1/compliance/frameworks — Available framework configurations
 *   GET /services/apexrest/elaro/v1/compliance/vendors — Vendor compliance records
 *
 * @author Elaro Team
 * @since v3.1.0 (Spring '26)
 * @group Integration
 * @see ComplianceServiceFactory
 * @see VendorRiskService
 */
@RestResource(urlMapping='/elaro/v1/compliance/*')
global with sharing class ElaroComplianceAPI {

    private static final String LOG_SOURCE = 'ElaroComplianceAPI';

    /**
     * Handles GET requests for compliance data.
     * Routes based on the path segment after /elaro/v1/compliance.
     */
    @HttpGet
    global static void doGet() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        res.addHeader('Content-Type', 'application/json');

        String path = req.requestURI.substringAfter('/elaro/v1/compliance');

        try {
            if (path == '/scores' || path == '/scores/') {
                res.statusCode = 200;
                res.responseBody = Blob.valueOf(JSON.serialize(getAllScores()));
            } else if (path.startsWith('/scores/')) {
                String framework = path.substringAfter('/scores/');
                res.statusCode = 200;
                res.responseBody = Blob.valueOf(JSON.serialize(getScoreByFramework(framework)));
            } else if (path == '/findings' || path == '/findings/') {
                String severity = req.params.get('severity');
                String status = req.params.get('status');
                res.statusCode = 200;
                res.responseBody = Blob.valueOf(JSON.serialize(getFindings(severity, status)));
            } else if (path == '/frameworks' || path == '/frameworks/') {
                res.statusCode = 200;
                res.responseBody = Blob.valueOf(JSON.serialize(getFrameworks()));
            } else if (path == '/vendors' || path == '/vendors/') {
                res.statusCode = 200;
                res.responseBody = Blob.valueOf(JSON.serialize(getVendors()));
            } else {
                res.statusCode = 404;
                res.responseBody = Blob.valueOf(buildErrorResponse('Unknown endpoint: ' + path));
            }
        } catch (Exception e) {
            ElaroLogger.error(LOG_SOURCE + '.doGet', e.getMessage(), e.getStackTraceString());
            res.statusCode = 500;
            res.responseBody = Blob.valueOf(buildErrorResponse('Internal server error'));
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // PRIVATE HELPERS
    // ═══════════════════════════════════════════════════════════════

    /**
     * Retrieves the most recent compliance scores grouped by framework.
     *
     * @return List of ScoreDTO with framework name, score, and timestamp
     */
    private static List<ScoreDTO> getAllScores() {
        List<Compliance_Score__c> scores = [
            SELECT Id, Risk_Score__c, Framework_Scores__c, Calculated_At__c, Org_ID__c
            FROM Compliance_Score__c
            WITH USER_MODE
            ORDER BY Calculated_At__c DESC
            LIMIT 50
        ];

        List<ScoreDTO> results = new List<ScoreDTO>();

        for (Compliance_Score__c score : scores) {
            ScoreDTO dto = new ScoreDTO();
            dto.id = score.Id;
            dto.riskScore = score.Risk_Score__c ?? 0;
            dto.complianceScore = 100 - (score.Risk_Score__c ?? 0);
            dto.calculatedAt = score.Calculated_At__c;
            dto.orgId = score.Org_ID__c;

            // Parse per-framework breakdown if available
            if (String.isNotBlank(score.Framework_Scores__c)) {
                try {
                    dto.frameworkScores = (Map<String, Object>) JSON.deserializeUntyped(
                        score.Framework_Scores__c
                    );
                } catch (Exception e) {
                    dto.frameworkScores = new Map<String, Object>();
                }
            } else {
                dto.frameworkScores = new Map<String, Object>();
            }

            results.add(dto);
        }

        return results;
    }

    /**
     * Retrieves compliance scores filtered to a specific framework.
     *
     * @param framework The framework code (e.g. SOC2, HIPAA, GDPR)
     * @return FrameworkScoreDTO with framework-specific score details
     */
    private static FrameworkScoreDTO getScoreByFramework(String framework) {
        if (String.isBlank(framework)) {
            throw new IllegalArgumentException('Framework parameter is required');
        }

        String normalizedFramework = framework.toUpperCase();

        // Get the latest score record that contains framework breakdown
        List<Compliance_Score__c> scores = [
            SELECT Id, Risk_Score__c, Framework_Scores__c, Calculated_At__c
            FROM Compliance_Score__c
            WHERE Framework_Scores__c != NULL
            WITH USER_MODE
            ORDER BY Calculated_At__c DESC
            LIMIT 1
        ];

        FrameworkScoreDTO result = new FrameworkScoreDTO();
        result.framework = normalizedFramework;
        result.score = null;
        result.calculatedAt = null;

        if (!scores.isEmpty()) {
            Compliance_Score__c latest = scores[0];
            result.calculatedAt = latest.Calculated_At__c;

            if (String.isNotBlank(latest.Framework_Scores__c)) {
                try {
                    Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(
                        latest.Framework_Scores__c
                    );
                    // Look for the framework in the map (case-insensitive)
                    for (String key : parsed.keySet()) {
                        if (key.toUpperCase() == normalizedFramework) {
                            result.score = (Decimal) parsed.get(key);
                            break;
                        }
                    }
                } catch (Exception e) {
                    ElaroLogger.warn(LOG_SOURCE + '.getScoreByFramework',
                        'Failed to parse Framework_Scores__c: ' + e.getMessage());
                }
            }
        }

        // Also count open gaps for this framework
        List<AggregateResult> gapCounts = [
            SELECT COUNT(Id) cnt
            FROM Compliance_Gap__c
            WHERE Framework__c = :normalizedFramework
                AND Status__c != 'Resolved'
                AND Status__c != 'REMEDIATED'
            WITH USER_MODE
        ];

        result.openGapCount = (Integer) gapCounts[0].get('cnt');

        return result;
    }

    /**
     * Retrieves compliance findings (gaps) with optional severity and status filters.
     *
     * @param severity Optional severity filter (Critical, High, Medium, Low)
     * @param status Optional status filter (OPEN, IN_PROGRESS, REMEDIATED, Resolved)
     * @return List of FindingDTO representing compliance gaps
     */
    private static List<FindingDTO> getFindings(String severity, String status) {
        String query = 'SELECT Id, Name, Framework__c, Severity__c, Status__c, '
            + 'Gap_Description__c, Description__c, Policy_Reference__c, '
            + 'Risk_Score__c, Detected_Date__c, CreatedDate '
            + 'FROM Compliance_Gap__c';

        List<String> conditions = new List<String>();
        Map<String, Object> binds = new Map<String, Object>();

        if (String.isNotBlank(severity)) {
            conditions.add('Severity__c = :severity');
            binds.put('severity', severity);
        }
        if (String.isNotBlank(status)) {
            conditions.add('Status__c = :status');
            binds.put('status', status);
        }

        if (!conditions.isEmpty()) {
            query += ' WHERE ' + String.join(conditions, ' AND ');
        }

        query += ' WITH USER_MODE ORDER BY Severity__c DESC, CreatedDate DESC LIMIT 200';

        List<Compliance_Gap__c> gaps = Database.queryWithBinds(query, binds, AccessLevel.USER_MODE);

        List<FindingDTO> results = new List<FindingDTO>();
        for (Compliance_Gap__c gap : gaps) {
            FindingDTO dto = new FindingDTO();
            dto.id = gap.Id;
            dto.name = gap.Name;
            dto.framework = gap.Framework__c;
            dto.severity = gap.Severity__c;
            dto.status = gap.Status__c;
            dto.description = gap.Gap_Description__c ?? gap.Description__c ?? '';
            dto.policyReference = gap.Policy_Reference__c;
            dto.riskScore = gap.Risk_Score__c;
            dto.detectedDate = gap.Detected_Date__c;
            dto.createdDate = gap.CreatedDate;
            results.add(dto);
        }

        return results;
    }

    /**
     * Retrieves available compliance framework configurations from custom metadata.
     *
     * @return List of FrameworkDTO with framework details
     */
    private static List<FrameworkDTO> getFrameworks() {
        List<Framework_Config__mdt> configs = [
            SELECT DeveloperName, Framework_Code__c, Display_Name__c,
                   Score_Multiplier__c, Response_Deadline_Days__c,
                   Evidence_Retention_Days__c, Is_Active__c
            FROM Framework_Config__mdt
            WITH USER_MODE
            ORDER BY Display_Name__c ASC
        ];

        List<FrameworkDTO> results = new List<FrameworkDTO>();
        for (Framework_Config__mdt config : configs) {
            FrameworkDTO dto = new FrameworkDTO();
            dto.developerName = config.DeveloperName;
            dto.frameworkCode = config.Framework_Code__c;
            dto.displayName = config.Display_Name__c;
            dto.scoreMultiplier = config.Score_Multiplier__c;
            dto.responseDeadlineDays = config.Response_Deadline_Days__c;
            dto.evidenceRetentionDays = config.Evidence_Retention_Days__c;
            dto.isActive = config.Is_Active__c ?? false;
            results.add(dto);
        }

        return results;
    }

    /**
     * Retrieves vendor compliance records with summary information.
     *
     * @return List of VendorDTO with vendor risk and compliance data
     */
    private static List<VendorDTO> getVendors() {
        List<Vendor_Compliance__c> vendors = [
            SELECT Id, Name, Vendor_Name__c, Vendor_Type__c, Compliance_Frameworks__c,
                Risk_Score__c, Status__c, Last_Assessment_Date__c, Next_Assessment_Date__c,
                Data_Processing_Agreement__c, Security_Certifications__c
            FROM Vendor_Compliance__c
            WITH USER_MODE
            ORDER BY Risk_Score__c DESC NULLS LAST, Vendor_Name__c ASC
            LIMIT 200
        ];

        List<VendorDTO> results = new List<VendorDTO>();
        for (Vendor_Compliance__c vendor : vendors) {
            VendorDTO dto = new VendorDTO();
            dto.id = vendor.Id;
            dto.name = vendor.Name;
            dto.vendorName = vendor.Vendor_Name__c;
            dto.vendorType = vendor.Vendor_Type__c;
            dto.complianceFrameworks = vendor.Compliance_Frameworks__c;
            dto.riskScore = vendor.Risk_Score__c;
            dto.status = vendor.Status__c;
            dto.lastAssessmentDate = vendor.Last_Assessment_Date__c;
            dto.nextAssessmentDate = vendor.Next_Assessment_Date__c;
            dto.hasDataProcessingAgreement = vendor.Data_Processing_Agreement__c ?? false;
            dto.securityCertifications = vendor.Security_Certifications__c;
            results.add(dto);
        }

        return results;
    }

    /**
     * Builds a JSON error response body.
     *
     * @param message The error message to include
     * @return Serialized JSON error object
     */
    private static String buildErrorResponse(String message) {
        Map<String, String> errorBody = new Map<String, String>{
            'error' => message
        };
        return JSON.serialize(errorBody);
    }

    // ═══════════════════════════════════════════════════════════════
    // DTO INNER CLASSES
    // ═══════════════════════════════════════════════════════════════

    /**
     * Data transfer object for compliance score responses.
     */
    global class ScoreDTO {
        /** Record Id */
        public Id id;
        /** Risk score (0-100, higher = more risk) */
        public Decimal riskScore;
        /** Compliance score (inverse of risk: 100 - riskScore) */
        public Decimal complianceScore;
        /** When the score was calculated */
        public Datetime calculatedAt;
        /** Org identifier */
        public String orgId;
        /** Per-framework score breakdown */
        public Map<String, Object> frameworkScores;
    }

    /**
     * Data transfer object for a single framework score response.
     */
    global class FrameworkScoreDTO {
        /** Framework code (e.g. SOC2, HIPAA) */
        public String framework;
        /** Framework-specific score */
        public Decimal score;
        /** When last calculated */
        public Datetime calculatedAt;
        /** Number of open compliance gaps for this framework */
        public Integer openGapCount;
    }

    /**
     * Data transfer object for compliance findings (gaps).
     */
    global class FindingDTO {
        /** Record Id */
        public Id id;
        /** Record Name */
        public String name;
        /** Framework this finding belongs to */
        public String framework;
        /** Severity level (Critical, High, Medium, Low) */
        public String severity;
        /** Current status (OPEN, IN_PROGRESS, REMEDIATED, Resolved) */
        public String status;
        /** Description of the compliance gap */
        public String description;
        /** Reference to the violated policy */
        public String policyReference;
        /** Numeric risk score */
        public Decimal riskScore;
        /** When the gap was detected */
        public Datetime detectedDate;
        /** Record creation date */
        public Datetime createdDate;
    }

    /**
     * Data transfer object for framework configuration.
     */
    global class FrameworkDTO {
        /** Developer name of the metadata record */
        public String developerName;
        /** Framework code (e.g. SOC2, HIPAA) */
        public String frameworkCode;
        /** Human-readable display name */
        public String displayName;
        /** Score multiplier for weighted calculations */
        public Decimal scoreMultiplier;
        /** Days allowed for response to findings */
        public Decimal responseDeadlineDays;
        /** Days to retain evidence records */
        public Decimal evidenceRetentionDays;
        /** Whether this framework is currently active */
        public Boolean isActive;
    }

    /**
     * Data transfer object for vendor compliance data.
     */
    global class VendorDTO {
        /** Record Id */
        public Id id;
        /** Record Name */
        public String name;
        /** Vendor display name */
        public String vendorName;
        /** Vendor type classification */
        public String vendorType;
        /** Comma-separated compliance frameworks */
        public String complianceFrameworks;
        /** Vendor risk score (0-10) */
        public Decimal riskScore;
        /** Vendor status (ACTIVE, SUSPENDED, etc.) */
        public String status;
        /** Date of last compliance assessment */
        public Date lastAssessmentDate;
        /** Date of next scheduled assessment */
        public Date nextAssessmentDate;
        /** Whether a DPA is in place */
        public Boolean hasDataProcessingAgreement;
        /** Security certifications held */
        public String securityCertifications;
    }
}
