/**
 * SlackNotifier - Slack Integration for Solentra Compliance Alerts
 * 
 * Sends notifications to Slack channels via Incoming Webhooks.
 * Supports both simple text messages and rich Block Kit messages.
 * 
 * @author Solentra
 * @version 1.0
 */
public with sharing class SlackNotifier {
    
    /**
     * Send simple text notification to Slack asynchronously
     * @param text The message text to send
     */
    @future(callout=true)
    public static void notifyAsync(String text) {
        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint('callout:Slack_Webhook');
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setBody(JSON.serialize(new Map<String, Object>{ 'text' => text }));
            HttpResponse res = new Http().send(req);
            if (res.getStatusCode() < 200 || res.getStatusCode() >= 300) {
                System.debug(LoggingLevel.ERROR, '[SlackNotifier] Notify failed: ' + res.getStatus());
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, '[SlackNotifier] Notify exception: ' + e.getMessage());
        }
    }
    
    /**
     * Send rich Block Kit notification to Slack asynchronously
     * @param jsonPayload The full Slack Block Kit payload as JSON string
     */
    @future(callout=true)
    public static void notifyRichAsync(String jsonPayload) {
        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint('callout:Slack_Webhook');
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setBody(jsonPayload);
            HttpResponse res = new Http().send(req);
            if (res.getStatusCode() < 200 || res.getStatusCode() >= 300) {
                System.debug(LoggingLevel.ERROR, '[SlackNotifier] Rich notify failed: ' + res.getStatus());
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, '[SlackNotifier] Rich notify exception: ' + e.getMessage());
        }
    }
    
    /**
     * Send compliance alert with rich formatting
     * @param title Alert title
     * @param severity Severity level (CRITICAL, HIGH, MEDIUM, LOW)
     * @param framework Compliance framework (HIPAA, SOC2, etc.)
     * @param description Alert description
     * @param nodeId Graph node ID for linking
     * @param confidence AI confidence score (0-1)
     */
    public static void notifyComplianceAlert(
        String title,
        String severity,
        String framework,
        String description,
        String nodeId,
        Decimal confidence
    ) {
        String emoji = severity == SolentraConstants.SEVERITY_CRITICAL ? '🔴' : 
                       severity == SolentraConstants.SEVERITY_HIGH ? '🟡' : 'ℹ️';
        String color = severity == SolentraConstants.SEVERITY_CRITICAL ? '#e74c3c' : 
                       severity == SolentraConstants.SEVERITY_HIGH ? '#f39c12' : '#3498db';
        
        String orgUrl = URL.getOrgDomainUrl().toExternalForm();
        
        Map<String, Object> payload = new Map<String, Object>();
        payload.put('text', emoji + ' Solentra Compliance Alert: ' + title);
        
        List<Map<String, Object>> blocks = new List<Map<String, Object>>();
        
        // Header
        blocks.add(new Map<String, Object>{
            'type' => 'header',
            'text' => new Map<String, Object>{
                'type' => 'plain_text',
                'text' => emoji + ' ' + title
            }
        });
        
        // Details section
        blocks.add(new Map<String, Object>{
            'type' => 'section',
            'fields' => new List<Map<String, Object>>{
                new Map<String, Object>{'type' => 'mrkdwn', 'text' => '*Severity:*\n' + severity},
                new Map<String, Object>{'type' => 'mrkdwn', 'text' => '*Framework:*\n' + framework},
                new Map<String, Object>{'type' => 'mrkdwn', 'text' => '*Confidence:*\n' + (confidence * 100).setScale(1) + '%'}
            }
        });
        
        // Description
        blocks.add(new Map<String, Object>{
            'type' => 'section',
            'text' => new Map<String, Object>{
                'type' => 'mrkdwn',
                'text' => description
            }
        });
        
        blocks.add(new Map<String, Object>{ 'type' => 'divider' });
        
        // Action buttons
        blocks.add(new Map<String, Object>{
            'type' => 'actions',
            'elements' => new List<Map<String, Object>>{
                new Map<String, Object>{
                    'type' => 'button',
                    'text' => new Map<String, Object>{'type' => 'plain_text', 'text' => '📊 View in Solentra'},
                    'url' => orgUrl + '/lightning/page/home'
                }
            }
        });
        
        payload.put('blocks', blocks);
        
        // Color attachment
        payload.put('attachments', new List<Map<String, Object>>{
            new Map<String, Object>{'color' => color}
        });
        
        notifyRichAsync(JSON.serialize(payload));
    }
    
    /**
     * Send remediation notification
     * @param result The remediation result
     * @param framework The compliance framework
     */
    public static void notifyRemediation(SentinelRemediationEngine.RemediationResult result, String framework) {
        String emoji = result.success ? '🛡️' : '⚠️';
        String color = result.success ? '#2ecc71' : '#f39c12';
        
        Map<String, Object> payload = new Map<String, Object>();
        payload.put('text', emoji + ' Solentra Auto-Remediation: ' + result.action);
        
        List<Map<String, Object>> blocks = new List<Map<String, Object>>();
        
        blocks.add(new Map<String, Object>{
            'type' => 'header',
            'text' => new Map<String, Object>{
                'type' => 'plain_text',
                'text' => emoji + ' Auto-Remediation ' + (result.success ? 'Complete' : 'Pending Review')
            }
        });
        
        blocks.add(new Map<String, Object>{
            'type' => 'section',
            'fields' => new List<Map<String, Object>>{
                new Map<String, Object>{'type' => 'mrkdwn', 'text' => '*Action:*\n' + result.action},
                new Map<String, Object>{'type' => 'mrkdwn', 'text' => '*Framework:*\n' + framework},
                new Map<String, Object>{'type' => 'mrkdwn', 'text' => '*Status:*\n' + (result.success ? 'Success' : 'Pending')}
            }
        });
        
        blocks.add(new Map<String, Object>{
            'type' => 'section',
            'text' => new Map<String, Object>{
                'type' => 'mrkdwn',
                'text' => result.message
            }
        });
        
        payload.put('blocks', blocks);
        payload.put('attachments', new List<Map<String, Object>>{
            new Map<String, Object>{'color' => color}
        });
        
        notifyRichAsync(JSON.serialize(payload));
    }
}
