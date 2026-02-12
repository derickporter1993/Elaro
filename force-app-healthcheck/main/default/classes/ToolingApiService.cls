/**
 * Provides HTTP REST access to the Salesforce Tooling API for querying
 * SecurityHealthCheck, SecurityHealthCheckRisks, and other Tooling objects.
 *
 * SECURITY NOTE: Tooling API runs in system context. No WITH USER_MODE equivalent.
 * Caller permission validation happens in the controller layer (with sharing).
 * Tooling queries return org-wide security settings, not user record data.
 *
 * @author Elaro Team
 * @since v1.0.0 (Spring '26)
 * @group Health Check
 * @see HealthCheckScanner
 * @see SessionSettingsScanner
 */
public inherited sharing class ToolingApiService {

    private static final String TOOLING_ENDPOINT = '/services/data/v66.0/tooling/query/?q=';

    /**
     * Executes a SOQL query against the Salesforce Tooling API and returns
     * the parsed JSON response as a map.
     *
     * @param query The SOQL query string (e.g., 'SELECT Score FROM SecurityHealthCheck')
     * @return Parsed JSON response as Map containing 'records' key
     * @throws AuraHandledException if the HTTP request fails with a non-200 status code
     * @example
     * Map<String, Object> result = ToolingApiService.queryTooling(
     *     'SELECT Id, Score FROM SecurityHealthCheck'
     * );
     * List<Object> records = (List<Object>) result.get('records');
     */
    public static Map<String, Object> queryTooling(String query) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(
            URL.getOrgDomainUrl().toExternalForm()
            + TOOLING_ENDPOINT
            + EncodingUtil.urlEncode(query, 'UTF-8')
        );
        req.setMethod('GET');
        req.setHeader('Authorization', 'Bearer ' + UserInfo.getSessionId());
        req.setHeader('Content-Type', 'application/json');

        Http http = new Http();
        HttpResponse res = http.send(req);

        if (res.getStatusCode() != 200) {
            HCLogger.error('ToolingApiService.queryTooling: HTTP '
                + res.getStatusCode() + ' - ' + res.getStatus());
            throw new AuraHandledException(
                'Tooling API query failed: ' + res.getStatus()
            );
        }

        return (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
    }
}
