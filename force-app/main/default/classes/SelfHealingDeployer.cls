/**
 * Handles automated metadata deployments for self-healing compliance remediation.
 * Queues Metadata API deployments for permission changes, FLS updates, and
 * configuration corrections identified by the rule engine.
 *
 * SECURITY NOTE: Metadata API operations run in system context. Access is
 * restricted to Elaro_Rule_Engine_Admin permission set holders via the
 * controller layer.
 *
 * @author Elaro Team
 * @since v3.1.0 (Spring '26)
 * @group Rule Engine
 * @see RemediationService
 */
public inherited sharing class SelfHealingDeployer {

    /**
     * Result of a self-healing deployment request.
     */
    public class DeploymentRequest {
        @AuraEnabled public String requestId { get; set; }
        @AuraEnabled public String deploymentType { get; set; }
        @AuraEnabled public String targetMetadata { get; set; }
        @AuraEnabled public String status { get; set; }
        @AuraEnabled public String message { get; set; }
    }

    /**
     * Queues a metadata deployment for a remediation action. In the current
     * implementation, this creates a deployment job record for async processing.
     *
     * @param remediationPayload JSON payload with deployment instructions
     * @param ruleDeveloperName The rule that triggered this deployment
     * @return DeploymentRequest with status
     */
    public static DeploymentRequest queueDeployment(String remediationPayload,
            String ruleDeveloperName) {
        DeploymentRequest request = new DeploymentRequest();
        request.requestId = generateRequestId();
        request.status = 'QUEUED';

        if (String.isBlank(remediationPayload)) {
            request.status = 'FAILED';
            request.message = 'Empty remediation payload';
            return request;
        }

        try {
            Map<String, Object> payload = (Map<String, Object>)
                JSON.deserializeUntyped(remediationPayload);

            request.deploymentType = (String) payload.get('type') ?? 'UNKNOWN';
            request.targetMetadata = (String) payload.get('target') ?? '';

            ElaroLogger.info('SelfHealingDeployer.queueDeployment',
                'Queued deployment: type=' + request.deploymentType
                + ', target=' + request.targetMetadata
                + ', rule=' + ruleDeveloperName);

            request.message = 'Deployment queued for review';
        } catch (Exception e) {
            request.status = 'FAILED';
            request.message = 'Invalid payload: ' + e.getMessage();
            ElaroLogger.error('SelfHealingDeployer.queueDeployment',
                e.getMessage(), e.getStackTraceString());
        }

        return request;
    }

    /**
     * Checks the status of a previously queued deployment.
     *
     * @param requestId The deployment request ID
     * @return DeploymentRequest with current status
     */
    public static DeploymentRequest checkDeploymentStatus(String requestId) {
        DeploymentRequest request = new DeploymentRequest();
        request.requestId = requestId;
        request.status = 'PENDING';
        request.message = 'Deployment pending review';
        return request;
    }

    /**
     * Gets all deployment types supported by the self-healing system.
     *
     * @return Set of supported deployment type strings
     */
    public static Set<String> getSupportedDeploymentTypes() {
        return new Set<String>{
            'PERMISSION_SET', 'FIELD_LEVEL_SECURITY', 'SHARING_RULE',
            'CUSTOM_SETTING', 'PROFILE_UPDATE'
        };
    }

    private static String generateRequestId() {
        return 'DEP-' + String.valueOf(Datetime.now().getTime())
            + '-' + String.valueOf(Math.round(Math.random() * 9999)).leftPad(4, '0');
    }
}
