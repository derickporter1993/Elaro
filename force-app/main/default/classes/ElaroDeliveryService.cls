/**
 * Delivery service for audit packages
 * Provides email delivery, shareable links, and Slack integration
 * @group Integration
 * @author Elaro Team
 * @since v3.1.0 (Spring '26)
 */
public with sharing class ElaroDeliveryService {
    
    // ═══════════════════════════════════════════════════════════════
    // PUBLIC METHODS
    // ═══════════════════════════════════════════════════════════════
    
    /**
     * Email audit package to stakeholders
     * @param packageId The audit package ID
     * @param recipientEmails List of recipient email addresses
     * @throws AuraHandledException if delivery fails
     */
    @AuraEnabled
    public static void deliverAuditPackage(String packageId, List<String> recipientEmails) {
        // Validate inputs
        if (String.isBlank(packageId)) {
            throw new AuraHandledException('Package ID is required');
        }
        
        if (recipientEmails == null || recipientEmails.isEmpty()) {
            throw new AuraHandledException('At least one recipient email is required');
        }
        
        try {
            // Query the audit package
            Elaro_Audit_Package__c pkg = [
                SELECT Id, Name, Package_Name__c, Framework__c, Status__c
                FROM Elaro_Audit_Package__c
                WHERE Id = :packageId
                WITH USER_MODE
                LIMIT 1
            ];
            
            // Generate PDF
            Id contentVersionId = ElaroPDFExporter.generateAuditPackagePDF(packageId);
            
            // Get ContentVersion details
            ContentVersion cv = [
                SELECT Id, Title, VersionData, ContentDocumentId
                FROM ContentVersion
                WHERE Id = :contentVersionId
                WITH USER_MODE
            ];
            
            // Build and send emails
            List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
            
            for (String email : recipientEmails) {
                Messaging.SingleEmailMessage message = new Messaging.SingleEmailMessage();
                message.setToAddresses(new List<String>{ email });
                message.setSubject('Audit Package: ' + pkg.Package_Name__c + ' (' + pkg.Framework__c + ')');
                message.setPlainTextBody(buildEmailBody(pkg));
                message.setHtmlBody(buildHtmlEmailBody(pkg));
                
                // Attach PDF
                Messaging.EmailFileAttachment attachment = new Messaging.EmailFileAttachment();
                attachment.setFileName(cv.Title + '.pdf');
                attachment.setBody(cv.VersionData);
                attachment.setContentType('application/pdf');
                message.setFileAttachments(new List<Messaging.EmailFileAttachment>{ attachment });
                
                emails.add(message);
            }
            
            // Send emails
            if (!Test.isRunningTest()) {
                Messaging.sendEmail(emails);
            }
            
        } catch (Exception e) {
            ElaroLogger.error('ElaroDeliveryService.deliverAuditPackage', e.getMessage(), e.getStackTraceString());
            throw new AuraHandledException('Unable to deliver the audit package. Please verify you have the required permissions and try again.');
        }
    }
    
    /**
     * Schedule recurring delivery
     * @param packageId The audit package ID
     * @param cronExpression The cron expression for scheduling
     * @param recipientEmails List of recipient email addresses
     * @return Scheduled job ID
     */
    @AuraEnabled
    public static Id scheduleRecurringDelivery(String packageId, String cronExpression, List<String> recipientEmails) {
        // Validate inputs
        if (String.isBlank(packageId)) {
            throw new AuraHandledException('Package ID is required');
        }
        
        if (String.isBlank(cronExpression)) {
            throw new AuraHandledException('Cron expression is required');
        }
        
        if (recipientEmails == null || recipientEmails.isEmpty()) {
            throw new AuraHandledException('At least one recipient email is required');
        }
        
        try {
            // Create schedulable instance
            ElaroScheduledDelivery scheduler = new ElaroScheduledDelivery(
                packageId, recipientEmails
            );
            
            // Schedule the job
            String jobName = 'Elaro_Delivery_' + packageId.substring(0, 15) + '_' + 
                             String.valueOf(Datetime.now().getTime());
            
            return System.schedule(jobName, cronExpression, scheduler);
            
        } catch (Exception e) {
            ElaroLogger.error('ElaroDeliveryService.scheduleRecurringDelivery', e.getMessage(), e.getStackTraceString());
            throw new AuraHandledException('Unable to schedule the delivery. Please try again or contact your administrator.');
        }
    }
    
    /**
     * Generate shareable link (ContentDistribution)
     * @param packageId The audit package ID
     * @param expirationDays Number of days until link expires
     * @return Shareable URL
     */
    @AuraEnabled
    public static String generateShareableLink(String packageId, Integer expirationDays) {
        if (String.isBlank(packageId)) {
            throw new AuraHandledException('Package ID is required');
        }
        
        if (expirationDays == null || expirationDays < 1) {
            expirationDays = 30; // Default to 30 days
        }
        
        try {
            // Generate PDF if not already generated
            Id contentVersionId = ElaroPDFExporter.generateAuditPackagePDF(packageId);
            
            // Get ContentDocumentId
            ContentVersion cv = [
                SELECT ContentDocumentId
                FROM ContentVersion
                WHERE Id = :contentVersionId
                WITH USER_MODE
            ];

            // Query package for naming
            Elaro_Audit_Package__c pkg = [
                SELECT Package_Name__c, Framework__c
                FROM Elaro_Audit_Package__c
                WHERE Id = :packageId
                WITH USER_MODE
            ];
            
            // Create ContentDistribution
            ContentDistribution cd = new ContentDistribution(
                Name = 'Audit Package Share - ' + pkg.Package_Name__c,
                ContentVersionId = contentVersionId,
                PreferencesAllowOriginalDownload = true,
                PreferencesAllowPDFDownload = true,
                PreferencesAllowViewInBrowser = true,
                PreferencesLinkLatestVersion = false,
                PreferencesNotifyOnVisit = true,
                PreferencesPasswordRequired = true,
                ExpiryDate = Date.today().addDays(expirationDays)
            );

            ElaroSecurityUtils.validateCRUDAccess('ContentDistribution', ElaroSecurityUtils.DmlOperation.DML_INSERT);
            insert as user cd;
            
            // Query for the generated URL
            cd = [
                SELECT DistributionPublicUrl, Password
                FROM ContentDistribution
                WHERE Id = :cd.Id
                WITH USER_MODE
            ];
            
            return cd.DistributionPublicUrl;
            
        } catch (Exception e) {
            ElaroLogger.error('ElaroDeliveryService.generateShareableLink', e.getMessage(), e.getStackTraceString());
            throw new AuraHandledException('Unable to generate a shareable link. Please verify you have the required permissions and try again.');
        }
    }
    
    /**
     * Send audit package notification to Slack via Queueable
     * @param packageId The audit package ID
     * @param channel The Slack channel
     */
    @AuraEnabled
    public static void sendToSlack(String packageId, String channel) {
        try {
            if (String.isBlank(packageId) || String.isBlank(channel)) {
                return;
            }

            if (!Test.isRunningTest()) {
                System.enqueueJob(new SlackDeliveryQueueable(packageId, channel));
            }
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            ElaroLogger.error('ElaroDeliveryService.sendToSlack', e.getMessage(), e.getStackTraceString());
            throw new AuraHandledException('Unable to complete the operation. Please verify you have the required permissions and try again.');
        }
    }
    
    /**
     * Get delivery history for a package
     * @param packageId The audit package ID
     * @return List of delivery records
     */
    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getDeliveryHistory(String packageId) {
        try {
            List<Map<String, Object>> history = new List<Map<String, Object>>();

            // Query ContentDistribution records
            List<ContentDocumentLink> links = [
                SELECT ContentDocumentId
                FROM ContentDocumentLink
                WHERE LinkedEntityId = :packageId
                WITH USER_MODE
            ];

            Set<Id> docIds = new Set<Id>();
            for (ContentDocumentLink link : links) {
                docIds.add(link.ContentDocumentId);
            }

            if (!docIds.isEmpty()) {
                List<ContentDistribution> distributions = [
                    SELECT Id, Name, DistributionPublicUrl, ExpiryDate,
                           FirstViewDate, LastViewDate, ViewCount, CreatedDate
                    FROM ContentDistribution
                    WHERE ContentDocumentId IN :docIds
                    WITH USER_MODE
                    ORDER BY CreatedDate DESC
                ];

                for (ContentDistribution cd : distributions) {
                    history.add(new Map<String, Object>{
                        'id' => cd.Id,
                        'name' => cd.Name,
                        'url' => cd.DistributionPublicUrl,
                        'expiryDate' => cd.ExpiryDate,
                        'firstViewDate' => cd.FirstViewDate,
                        'lastViewDate' => cd.LastViewDate,
                        'viewCount' => cd.ViewCount,
                        'createdDate' => cd.CreatedDate
                    });
                }
            }

            return history;
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            ElaroLogger.error('ElaroDeliveryService.getDeliveryHistory', e.getMessage(), e.getStackTraceString());
            throw new AuraHandledException('Unable to complete the operation. Please verify you have the required permissions and try again.');
        }
    }
    
    // ═══════════════════════════════════════════════════════════════
    // INNER QUEUEABLE CLASS
    // ═══════════════════════════════════════════════════════════════

    /**
     * Queueable for sending audit package notifications to Slack.
     * Replaces the previous @future sendToSlack method with better
     * error handling and monitoring capabilities.
     *
     * @author Elaro Team
     * @since v3.1.0 (Spring '26)
     * @group Export & Delivery
     * @see ElaroDeliveryService
     */
    public class SlackDeliveryQueueable implements Queueable, Database.AllowsCallouts {
        private String packageId;
        private String channel;

        /**
         * Constructs a new SlackDeliveryQueueable.
         *
         * @param packageId The audit package ID to notify about
         * @param channel The Slack channel to send the notification to
         */
        public SlackDeliveryQueueable(String packageId, String channel) {
            this.packageId = packageId;
            this.channel = channel;
        }

        /**
         * Executes the Slack notification callout for the audit package.
         *
         * @param context The QueueableContext provided by the platform
         */
        public void execute(QueueableContext context) {
            try {
                // Query package details
                Elaro_Audit_Package__c pkg = [
                    SELECT Id, Package_Name__c, Framework__c, Status__c
                    FROM Elaro_Audit_Package__c
                    WHERE Id = :packageId
                    WITH USER_MODE
                    LIMIT 1
                ];

                // Build Slack Block Kit message
                Map<String, Object> slackMessage = buildSlackMessage(pkg, channel);

                // Send to Slack webhook
                HttpRequest req = new HttpRequest();
                req.setEndpoint('callout:Elaro_Slack_Webhook');
                req.setMethod('POST');
                req.setHeader('Content-Type', 'application/json');
                req.setBody(JSON.serialize(slackMessage));
                req.setTimeout(ElaroConstants.CALLOUT_TIMEOUT_MS);

                Http http = new Http();
                HttpResponse res = http.send(req);

                if (res.getStatusCode() >= 200 && res.getStatusCode() < 300) {
                    ElaroLogger.info('ElaroDeliveryService.SlackDeliveryQueueable: Slack notification sent successfully for package ' + packageId);
                } else {
                    ElaroLogger.error('ElaroDeliveryService.SlackDeliveryQueueable: Slack notification failed with status ' + res.getStatusCode() + ': ' + res.getBody());
                }
            } catch (Exception e) {
                ElaroLogger.error('ElaroDeliveryService.SlackDeliveryQueueable: Error sending Slack notification', e);
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // PRIVATE HELPER METHODS
    // ═══════════════════════════════════════════════════════════════

    /**
     * Build plain text email body
     * @param pkg The audit package
     * @return Email body text
     */
    private static String buildEmailBody(Elaro_Audit_Package__c pkg) {
        return 'Audit Package Delivery\n\n' +
               'Package: ' + pkg.Package_Name__c + '\n' +
               'Framework: ' + pkg.Framework__c + '\n' +
               'Status: ' + pkg.Status__c + '\n\n' +
               'Please find the attached audit package PDF.\n\n' +
               'This is an automated message from Elaro Compliance Platform.';
    }
    
    /**
     * Build HTML email body
     * @param pkg The audit package
     * @return HTML email body
     */
    private static String buildHtmlEmailBody(Elaro_Audit_Package__c pkg) {
        return '&lt;html&gt;&lt;body style="font-family: Arial, sans-serif;"&gt;' +
               '&lt;div style="background-color: #032d60; color: white; padding: 20px;"&gt;' +
               '&lt;h1 style="margin: 0;"&gt;Audit Package Delivery&lt;/h1&gt;' +
               '&lt;/div&gt;' +
               '&lt;div style="padding: 20px;"&gt;' +
               '&lt;table style="border-collapse: collapse; width: 100%;"&gt;' +
               '&lt;tr&gt;&lt;td style="padding: 10px; border-bottom: 1px solid #ddd;"&gt;&lt;strong&gt;Package:&lt;/strong&gt;&lt;/td&gt;' +
               '&lt;td style="padding: 10px; border-bottom: 1px solid #ddd;"&gt;' + pkg.Package_Name__c + '&lt;/td&gt;&lt;/tr&gt;' +
               '&lt;tr&gt;&lt;td style="padding: 10px; border-bottom: 1px solid #ddd;"&gt;&lt;strong&gt;Framework:&lt;/strong&gt;&lt;/td&gt;' +
               '&lt;td style="padding: 10px; border-bottom: 1px solid #ddd;"&gt;' + pkg.Framework__c + '&lt;/td&gt;&lt;/tr&gt;' +
               '&lt;tr&gt;&lt;td style="padding: 10px; border-bottom: 1px solid #ddd;"&gt;&lt;strong&gt;Status:&lt;/strong&gt;&lt;/td&gt;' +
               '&lt;td style="padding: 10px; border-bottom: 1px solid #ddd;"&gt;' + pkg.Status__c + '&lt;/td&gt;&lt;/tr&gt;' +
               '&lt;/table&gt;' +
               '&lt;p&gt;Please find the attached audit package PDF.&lt;/p&gt;' +
               '&lt;/div&gt;' +
               '&lt;div style="background-color: #f5f5f5; padding: 10px; font-size: 12px; color: #666;"&gt;' +
               'This is an automated message from Elaro Compliance Platform.' +
               '&lt;/div&gt;' +
               '&lt;/body&gt;&lt;/html&gt;';
    }
    
    /**
     * Build Slack Block Kit message
     * @param pkg The audit package
     * @param channel The Slack channel
     * @return Slack message object
     */
    private static Map<String, Object> buildSlackMessage(Elaro_Audit_Package__c pkg, String channel) {
        List<Object> blocks = new List<Object>{
            new Map<String, Object>{
                'type' => 'header',
                'text' => new Map<String, Object>{
                    'type' => 'plain_text',
                    'text' => '📋 Audit Package Generated',
                    'emoji' => true
                }
            },
            new Map<String, Object>{
                'type' => 'section',
                'fields' => new List<Object>{
                    new Map<String, Object>{
                        'type' => 'mrkdwn',
                        'text' => '*Package:*\n' + pkg.Package_Name__c
                    },
                    new Map<String, Object>{
                        'type' => 'mrkdwn',
                        'text' => '*Framework:*\n' + pkg.Framework__c
                    },
                    new Map<String, Object>{
                        'type' => 'mrkdwn',
                        'text' => '*Status:*\n' + pkg.Status__c
                    },
                    new Map<String, Object>{
                        'type' => 'mrkdwn',
                        'text' => '*Generated:*\n' + Datetime.now().format()
                    }
                }
            },
            new Map<String, Object>{
                'type' => 'divider'
            },
            new Map<String, Object>{
                'type' => 'context',
                'elements' => new List<Object>{
                    new Map<String, Object>{
                        'type' => 'mrkdwn',
                        'text' => 'Sent from *Elaro Compliance Platform*'
                    }
                }
            }
        };
        
        return new Map<String, Object>{
            'channel' => channel,
            'blocks' => blocks
        };
    }
}
