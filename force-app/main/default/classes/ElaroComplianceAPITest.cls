/**
 * Test class for ElaroComplianceAPI REST resource.
 * Validates all routing, response formatting, filtering, and error handling.
 *
 * @author Elaro Team
 * @since v3.1.0 (Spring '26)
 * @group Integration
 * @see ElaroComplianceAPI
 */
@IsTest(testFor=ElaroComplianceAPI.class)
private class ElaroComplianceAPITest {

    private static final String BASE_URI = '/services/apexrest/elaro/v1/compliance';

    @TestSetup
    static void makeData() {
        // Create Compliance_Score__c records
        List<Compliance_Score__c> scores = new List<Compliance_Score__c>();
        scores.add(new Compliance_Score__c(
            Org_ID__c = UserInfo.getOrganizationId(),
            Entity_Type__c = 'Organization',
            Entity_Id__c = UserInfo.getOrganizationId(),
            Risk_Score__c = 25,
            Framework_Scores__c = '{"SOC2": 85, "HIPAA": 72, "GDPR": 90}',
            Calculated_At__c = Datetime.now()
        ));
        scores.add(new Compliance_Score__c(
            Org_ID__c = UserInfo.getOrganizationId(),
            Entity_Type__c = 'Organization',
            Entity_Id__c = UserInfo.getOrganizationId(),
            Risk_Score__c = 30,
            Framework_Scores__c = '{"SOC2": 80, "HIPAA": 68}',
            Calculated_At__c = Datetime.now().addDays(-7)
        ));
        insert scores;

        // Create Compliance_Gap__c records
        List<Compliance_Gap__c> gaps = new List<Compliance_Gap__c>();
        gaps.add(new Compliance_Gap__c(
            Framework__c = 'SOC2',
            Policy_Reference__c = 'SOC2_ACCESS_CONTROL',
            Severity__c = 'Critical',
            Status__c = 'OPEN',
            Gap_Description__c = 'Critical access control finding',
            Entity_Type__c = 'PERMISSION_SET',
            Entity_Id__c = '0PS000000000001',
            Risk_Score__c = 9.5,
            Detected_Date__c = Datetime.now()
        ));
        gaps.add(new Compliance_Gap__c(
            Framework__c = 'HIPAA',
            Policy_Reference__c = 'HIPAA_PHI_ACCESS',
            Severity__c = 'High',
            Status__c = 'IN_PROGRESS',
            Gap_Description__c = 'PHI access not restricted',
            Entity_Type__c = 'CUSTOM_FIELD',
            Entity_Id__c = 'Contact.SSN__c',
            Risk_Score__c = 7.0,
            Detected_Date__c = Datetime.now()
        ));
        gaps.add(new Compliance_Gap__c(
            Framework__c = 'GDPR',
            Policy_Reference__c = 'GDPR_CONSENT',
            Severity__c = 'Medium',
            Status__c = 'OPEN',
            Gap_Description__c = 'Missing consent records',
            Entity_Type__c = 'OBJECT',
            Entity_Id__c = 'Consent__c',
            Risk_Score__c = 5.0,
            Detected_Date__c = Datetime.now()
        ));
        gaps.add(new Compliance_Gap__c(
            Framework__c = 'SOC2',
            Policy_Reference__c = 'SOC2_LOGGING',
            Severity__c = 'Low',
            Status__c = 'Resolved',
            Gap_Description__c = 'Logging gap resolved',
            Entity_Type__c = 'OBJECT',
            Entity_Id__c = 'EventLog__c',
            Risk_Score__c = 2.0,
            Detected_Date__c = Datetime.now().addDays(-30)
        ));
        insert gaps;

        // Create Vendor_Compliance__c records
        List<Vendor_Compliance__c> vendors = new List<Vendor_Compliance__c>();
        vendors.add(new Vendor_Compliance__c(
            Vendor_Name__c = 'Acme Cloud Services',
            Vendor_Type__c = 'CLOUD_SERVICE',
            Compliance_Frameworks__c = 'SOC2;ISO27001',
            Risk_Score__c = 3.0,
            Status__c = 'ACTIVE',
            Last_Assessment_Date__c = Date.today().addDays(-60),
            Next_Assessment_Date__c = Date.today().addDays(30),
            Data_Processing_Agreement__c = true,
            Security_Certifications__c = 'SOC2 Type II;ISO 27001'
        ));
        vendors.add(new Vendor_Compliance__c(
            Vendor_Name__c = 'Legacy Hosting Inc',
            Vendor_Type__c = 'INFRASTRUCTURE',
            Compliance_Frameworks__c = 'SOC2',
            Risk_Score__c = 8.0,
            Status__c = 'ACTIVE',
            Last_Assessment_Date__c = Date.today().addDays(-365),
            Next_Assessment_Date__c = Date.today().addDays(-30),
            Data_Processing_Agreement__c = false,
            Security_Certifications__c = null
        ));
        insert vendors;
    }

    // ═══════════════════════════════════════════════════════════════
    // SCORES ENDPOINT TESTS
    // ═══════════════════════════════════════════════════════════════

    @IsTest
    static void shouldReturnAllScores() {
        RestRequest req = new RestRequest();
        req.requestURI = BASE_URI + '/scores';
        req.httpMethod = 'GET';
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        ElaroComplianceAPI.doGet();
        Test.stopTest();

        RestResponse res = RestContext.response;
        Assert.areEqual(200, res.statusCode, 'Should return 200 for /scores');
        Assert.isNotNull(res.responseBody, 'Response body should not be null');

        String body = res.responseBody.toString();
        List<Object> scores = (List<Object>) JSON.deserializeUntyped(body);
        Assert.areEqual(2, scores.size(), 'Should return 2 score records');

        // Verify first record has expected fields
        Map<String, Object> firstScore = (Map<String, Object>) scores[0];
        Assert.isNotNull(firstScore.get('riskScore'), 'Should include riskScore');
        Assert.isNotNull(firstScore.get('complianceScore'), 'Should include complianceScore');
        Assert.isNotNull(firstScore.get('calculatedAt'), 'Should include calculatedAt');
        Assert.isNotNull(firstScore.get('frameworkScores'), 'Should include frameworkScores');
    }

    @IsTest
    static void shouldReturnScoreByFramework() {
        RestRequest req = new RestRequest();
        req.requestURI = BASE_URI + '/scores/SOC2';
        req.httpMethod = 'GET';
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        ElaroComplianceAPI.doGet();
        Test.stopTest();

        RestResponse res = RestContext.response;
        Assert.areEqual(200, res.statusCode, 'Should return 200 for /scores/SOC2');

        String body = res.responseBody.toString();
        Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(body);
        Assert.areEqual('SOC2', result.get('framework'), 'Framework should be SOC2');
        Assert.isNotNull(result.get('score'), 'Score should be present for SOC2');
        Assert.areEqual(85, (Integer) result.get('score'), 'SOC2 score should be 85');
        Assert.isNotNull(result.get('openGapCount'), 'Should include open gap count');
    }

    // ═══════════════════════════════════════════════════════════════
    // FINDINGS ENDPOINT TESTS
    // ═══════════════════════════════════════════════════════════════

    @IsTest
    static void shouldReturnFindings() {
        RestRequest req = new RestRequest();
        req.requestURI = BASE_URI + '/findings';
        req.httpMethod = 'GET';
        req.params = new Map<String, String>();
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        ElaroComplianceAPI.doGet();
        Test.stopTest();

        RestResponse res = RestContext.response;
        Assert.areEqual(200, res.statusCode, 'Should return 200 for /findings');

        String body = res.responseBody.toString();
        List<Object> findings = (List<Object>) JSON.deserializeUntyped(body);
        Assert.areEqual(4, findings.size(), 'Should return all 4 gap records');

        // Verify structure of a finding
        Map<String, Object> finding = (Map<String, Object>) findings[0];
        Assert.isNotNull(finding.get('framework'), 'Should include framework');
        Assert.isNotNull(finding.get('severity'), 'Should include severity');
        Assert.isNotNull(finding.get('status'), 'Should include status');
    }

    @IsTest
    static void shouldFilterFindingsBySeverity() {
        RestRequest req = new RestRequest();
        req.requestURI = BASE_URI + '/findings';
        req.httpMethod = 'GET';
        req.params = new Map<String, String>{ 'severity' => 'Critical' };
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        ElaroComplianceAPI.doGet();
        Test.stopTest();

        RestResponse res = RestContext.response;
        Assert.areEqual(200, res.statusCode, 'Should return 200 for filtered findings');

        String body = res.responseBody.toString();
        List<Object> findings = (List<Object>) JSON.deserializeUntyped(body);
        Assert.areEqual(1, findings.size(), 'Should return only 1 Critical finding');

        Map<String, Object> finding = (Map<String, Object>) findings[0];
        Assert.areEqual('Critical', finding.get('severity'), 'Severity should be Critical');
        Assert.areEqual('SOC2', finding.get('framework'), 'Framework should be SOC2');
    }

    @IsTest
    static void shouldFilterFindingsByStatus() {
        RestRequest req = new RestRequest();
        req.requestURI = BASE_URI + '/findings';
        req.httpMethod = 'GET';
        req.params = new Map<String, String>{ 'status' => 'OPEN' };
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        ElaroComplianceAPI.doGet();
        Test.stopTest();

        RestResponse res = RestContext.response;
        Assert.areEqual(200, res.statusCode, 'Should return 200 for status-filtered findings');

        String body = res.responseBody.toString();
        List<Object> findings = (List<Object>) JSON.deserializeUntyped(body);
        Assert.areEqual(2, findings.size(), 'Should return 2 OPEN findings (SOC2 Critical + GDPR Medium)');
    }

    // ═══════════════════════════════════════════════════════════════
    // FRAMEWORKS ENDPOINT TESTS
    // ═══════════════════════════════════════════════════════════════

    @IsTest
    static void shouldReturnFrameworks() {
        RestRequest req = new RestRequest();
        req.requestURI = BASE_URI + '/frameworks';
        req.httpMethod = 'GET';
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        ElaroComplianceAPI.doGet();
        Test.stopTest();

        RestResponse res = RestContext.response;
        Assert.areEqual(200, res.statusCode, 'Should return 200 for /frameworks');

        String body = res.responseBody.toString();
        // Framework_Config__mdt may or may not have records in test context
        // but the response should be valid JSON array
        List<Object> frameworks = (List<Object>) JSON.deserializeUntyped(body);
        Assert.isNotNull(frameworks, 'Frameworks response should be a valid list');
    }

    // ═══════════════════════════════════════════════════════════════
    // VENDORS ENDPOINT TESTS
    // ═══════════════════════════════════════════════════════════════

    @IsTest
    static void shouldReturnVendors() {
        RestRequest req = new RestRequest();
        req.requestURI = BASE_URI + '/vendors';
        req.httpMethod = 'GET';
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        ElaroComplianceAPI.doGet();
        Test.stopTest();

        RestResponse res = RestContext.response;
        Assert.areEqual(200, res.statusCode, 'Should return 200 for /vendors');

        String body = res.responseBody.toString();
        List<Object> vendors = (List<Object>) JSON.deserializeUntyped(body);
        Assert.areEqual(2, vendors.size(), 'Should return 2 vendor records');

        // Verify ordering (highest risk first)
        Map<String, Object> firstVendor = (Map<String, Object>) vendors[0];
        Assert.areEqual('Legacy Hosting Inc', firstVendor.get('vendorName'),
            'Highest risk vendor should be first');
        Assert.areEqual(8.0, (Decimal) firstVendor.get('riskScore'),
            'First vendor risk score should be 8.0');
    }

    // ═══════════════════════════════════════════════════════════════
    // ERROR HANDLING TESTS
    // ═══════════════════════════════════════════════════════════════

    @IsTest
    static void shouldReturn404ForUnknownPath() {
        RestRequest req = new RestRequest();
        req.requestURI = BASE_URI + '/nonexistent';
        req.httpMethod = 'GET';
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        ElaroComplianceAPI.doGet();
        Test.stopTest();

        RestResponse res = RestContext.response;
        Assert.areEqual(404, res.statusCode, 'Should return 404 for unknown path');

        String body = res.responseBody.toString();
        Assert.isTrue(body.contains('error'), 'Response should contain error key');
        Assert.isTrue(body.contains('Unknown endpoint'), 'Error should mention unknown endpoint');
    }

    @IsTest
    static void shouldReturn500OnError() {
        // Simulate an error by passing a URI that will cause an internal exception.
        // We use a malformed scores path with special characters that will trigger
        // an exception in the framework lookup logic.
        RestRequest req = new RestRequest();
        // Use a path that routes to scores but with a null requestURI to force NPE
        req.requestURI = null;
        req.httpMethod = 'GET';
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        ElaroComplianceAPI.doGet();
        Test.stopTest();

        RestResponse res = RestContext.response;
        Assert.areEqual(500, res.statusCode, 'Should return 500 on internal error');

        String body = res.responseBody.toString();
        Assert.isTrue(body.contains('error'), 'Response should contain error key');
        Assert.isTrue(body.contains('Internal server error'),
            'Error message should be generic (not expose internals)');
    }

    // ═══════════════════════════════════════════════════════════════
    // EDGE CASE TESTS
    // ═══════════════════════════════════════════════════════════════

    @IsTest
    static void shouldHandleTrailingSlashOnScores() {
        RestRequest req = new RestRequest();
        req.requestURI = BASE_URI + '/scores/';
        req.httpMethod = 'GET';
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        ElaroComplianceAPI.doGet();
        Test.stopTest();

        RestResponse res = RestContext.response;
        Assert.areEqual(200, res.statusCode, 'Should handle trailing slash on /scores/');
    }

    @IsTest
    static void shouldHandleCombinedFilters() {
        RestRequest req = new RestRequest();
        req.requestURI = BASE_URI + '/findings';
        req.httpMethod = 'GET';
        req.params = new Map<String, String>{
            'severity' => 'High',
            'status' => 'IN_PROGRESS'
        };
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        ElaroComplianceAPI.doGet();
        Test.stopTest();

        RestResponse res = RestContext.response;
        Assert.areEqual(200, res.statusCode, 'Should return 200 for combined filters');

        String body = res.responseBody.toString();
        List<Object> findings = (List<Object>) JSON.deserializeUntyped(body);
        Assert.areEqual(1, findings.size(), 'Should return 1 finding matching both filters');

        Map<String, Object> finding = (Map<String, Object>) findings[0];
        Assert.areEqual('High', finding.get('severity'), 'Severity should be High');
        Assert.areEqual('IN_PROGRESS', finding.get('status'), 'Status should be IN_PROGRESS');
    }
}
