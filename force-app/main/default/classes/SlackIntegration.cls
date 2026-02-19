/**
 * Slack integration service for Elaro.
 * Provides alert notifications, audit package sharing, and daily digest delivery
 * via a consolidated Queueable pattern for all async Slack callouts.
 *
 * @group Integration
 * @author Elaro Team
 * @since v3.1.0 (Spring '26)
 * @see ElaroDailyDigest
 */
public with sharing class SlackIntegration {

    private static final String NAMED_CREDENTIAL = 'callout:Slack_Webhook';

    // ═══════════════════════════════════════════════════════════════
    // NOTIFICATION TYPE ENUM
    // ═══════════════════════════════════════════════════════════════

    /**
     * Defines the types of Slack notifications supported by the integration.
     *
     * @since v3.1.0 (Spring '26)
     */
    public enum NotificationType {
        ALERT,
        AUDIT_PACKAGE,
        DAILY_DIGEST,
        CUSTOM_MESSAGE
    }

    // ═══════════════════════════════════════════════════════════════
    // PUBLIC METHODS
    // ═══════════════════════════════════════════════════════════════

    /**
     * Sends an alert notification to the configured Slack channel.
     *
     * @param alertDataJson JSON-serialized alert data including severity, message, etc.
     * @since v3.1.0 (Spring '26)
     */
    public static void sendAlert(String alertDataJson) {
        Map<String, Object> alertData = (Map<String, Object>)JSON.deserializeUntyped(alertDataJson);

        String severity = (String)alertData.get('severity');
        String color = getColorForSeverity(severity);

        Map<String, Object> message = new Map<String, Object>{
            'attachments' => new List<Object>{
                new Map<String, Object>{
                    'color' => color,
                    'blocks' => new List<Object>{
                        new Map<String, Object>{
                            'type' => 'header',
                            'text' => new Map<String, Object>{
                                'type' => 'plain_text',
                                'text' => '⚠️ Elaro Compliance Alert',
                                'emoji' => true
                            }
                        },
                        new Map<String, Object>{
                            'type' => 'section',
                            'fields' => new List<Object>{
                                new Map<String, Object>{'type' => 'mrkdwn', 'text' => '*Severity:*\n' + severity},
                                new Map<String, Object>{'type' => 'mrkdwn', 'text' => '*Alert ID:*\n' + alertData.get('alertId')},
                                new Map<String, Object>{'type' => 'mrkdwn', 'text' => '*Event Type:*\n' + alertData.get('eventType')},
                                new Map<String, Object>{'type' => 'mrkdwn', 'text' => '*Risk Score:*\n' + alertData.get('riskScore')}
                            }
                        },
                        new Map<String, Object>{
                            'type' => 'section',
                            'text' => new Map<String, Object>{
                                'type' => 'mrkdwn',
                                'text' => '*Details:*\n' + alertData.get('message')
                            }
                        },
                        new Map<String, Object>{
                            'type' => 'actions',
                            'elements' => new List<Object>{
                                new Map<String, Object>{
                                    'type' => 'button',
                                    'text' => new Map<String, Object>{'type' => 'plain_text', 'text' => 'View in Salesforce'},
                                    'url' => URL.getOrgDomainUrl().toExternalForm() + '/lightning/r/Elaro_Evidence_Item__c/' + alertData.get('eventId') + '/view'
                                }
                            }
                        }
                    }
                }
            }
        };

        enqueueNotification(NotificationType.ALERT, message);
    }

    /**
     * Sends an audit package notification to Slack.
     *
     * @param packageId Audit package ID
     * @param channel Slack channel name
     * @since v3.1.0 (Spring '26)
     */
    public static void sendAuditPackageNotification(String packageId, String channel) {
        Elaro_Audit_Package__c pkg = [
            SELECT Id, Name, Package_Name__c, Framework__c, Status__c
            FROM Elaro_Audit_Package__c
            WHERE Id = :packageId
            WITH USER_MODE
            LIMIT 1
        ];

        Map<String, Object> message = new Map<String, Object>{
            'channel' => channel,
            'blocks' => new List<Object>{
                new Map<String, Object>{
                    'type' => 'header',
                    'text' => new Map<String, Object>{
                        'type' => 'plain_text',
                        'text' => '📋 Audit Package Generated'
                    }
                },
                new Map<String, Object>{
                    'type' => 'section',
                    'fields' => new List<Object>{
                        new Map<String, Object>{'type' => 'mrkdwn', 'text' => '*Package:*\n' + pkg.Package_Name__c},
                        new Map<String, Object>{'type' => 'mrkdwn', 'text' => '*Framework:*\n' + pkg.Framework__c},
                        new Map<String, Object>{'type' => 'mrkdwn', 'text' => '*Status:*\n' + pkg.Status__c},
                        new Map<String, Object>{'type' => 'mrkdwn', 'text' => '*Generated:*\n' + Datetime.now().format()}
                    }
                },
                new Map<String, Object>{
                    'type' => 'actions',
                    'elements' => new List<Object>{
                        new Map<String, Object>{
                            'type' => 'button',
                            'text' => new Map<String, Object>{'type' => 'plain_text', 'text' => 'View Package'},
                            'style' => 'primary',
                            'url' => URL.getOrgDomainUrl().toExternalForm() + '/lightning/r/Elaro_Audit_Package__c/' + packageId + '/view'
                        }
                    }
                }
            }
        };

        enqueueNotification(NotificationType.AUDIT_PACKAGE, message);
    }

    /**
     * Sends a daily digest notification to Slack.
     *
     * @param digestJson JSON-serialized digest data
     * @since v3.1.0 (Spring '26)
     */
    public static void sendDailyDigest(String digestJson) {
        Map<String, Object> digest = (Map<String, Object>)JSON.deserializeUntyped(digestJson);

        Map<String, Object> stats = (Map<String, Object>)digest.get('statistics');

        Map<String, Object> message = new Map<String, Object>{
            'blocks' => new List<Object>{
                new Map<String, Object>{
                    'type' => 'header',
                    'text' => new Map<String, Object>{
                        'type' => 'plain_text',
                        'text' => '📊 Daily Compliance Digest - ' + Date.today().format()
                    }
                },
                new Map<String, Object>{
                    'type' => 'section',
                    'fields' => new List<Object>{
                        new Map<String, Object>{'type' => 'mrkdwn', 'text' => '*Compliance Score:*\n' + digest.get('complianceScore') + '%'},
                        new Map<String, Object>{'type' => 'mrkdwn', 'text' => '*Total Events:*\n' + stats.get('totalEvents')},
                        new Map<String, Object>{'type' => 'mrkdwn', 'text' => '*High Risk:*\n' + stats.get('highRiskEvents')},
                        new Map<String, Object>{'type' => 'mrkdwn', 'text' => '*Resolved:*\n' + stats.get('resolvedEvents')}
                    }
                },
                new Map<String, Object>{
                    'type' => 'section',
                    'text' => new Map<String, Object>{
                        'type' => 'mrkdwn',
                        'text' => '*AI Summary:*\n' + digest.get('aiSummary')
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
                            'text' => 'Sent by Elaro Compliance Platform'
                        }
                    }
                }
            }
        };

        enqueueNotification(NotificationType.DAILY_DIGEST, message);
    }

    /**
     * Sends a custom message to a Slack channel.
     *
     * @param channel Channel name
     * @param text Message text
     * @since v3.1.0 (Spring '26)
     */
    public static void sendMessage(String channel, String text) {
        Map<String, Object> message = new Map<String, Object>{
            'channel' => channel,
            'text' => text
        };

        enqueueNotification(NotificationType.CUSTOM_MESSAGE, message);
    }

    // ═══════════════════════════════════════════════════════════════
    // PRIVATE METHODS
    // ═══════════════════════════════════════════════════════════════

    /**
     * Enqueues a Slack notification via the consolidated SlackNotificationQueueable.
     *
     * @param notificationType The type of notification being sent
     * @param message The Slack message payload
     */
    private static void enqueueNotification(NotificationType notificationType, Map<String, Object> message) {
        if (!Test.isRunningTest()) {
            System.enqueueJob(new SlackNotificationQueueable(notificationType, message));
        }
    }

    private static String getColorForSeverity(String severity) {
        Map<String, String> colors = new Map<String, String>{
            'CRITICAL' => '#c23934',
            'HIGH' => '#e87722',
            'MEDIUM' => '#f7b924',
            'LOW' => '#4bca81',
            'INFO' => '#2196f3'
        };
        return colors.containsKey(severity) ? colors.get(severity) : '#666666';
    }

    // ═══════════════════════════════════════════════════════════════
    // INNER QUEUEABLE CLASS
    // ═══════════════════════════════════════════════════════════════

    /**
     * Consolidated Queueable for all Slack notification types.
     * Replaces four separate @future methods with a single Queueable class
     * that routes to the correct HTTP callout based on the notification type enum.
     *
     * @author Elaro Team
     * @since v3.1.0 (Spring '26)
     * @group Integrations
     * @see SlackIntegration.NotificationType
     */
    public class SlackNotificationQueueable implements Queueable, Database.AllowsCallouts {
        private NotificationType notificationType;
        private Map<String, Object> message;

        /**
         * Constructs a new SlackNotificationQueueable.
         *
         * @param notificationType The type of notification to send
         * @param message The Slack message payload to deliver
         */
        public SlackNotificationQueueable(NotificationType notificationType, Map<String, Object> message) {
            this.notificationType = notificationType;
            this.message = message;
        }

        /**
         * Executes the Slack callout, sending the notification payload to the webhook.
         *
         * @param context The QueueableContext provided by the platform
         */
        public void execute(QueueableContext context) {
            try {
                HttpRequest req = new HttpRequest();
                req.setEndpoint(NAMED_CREDENTIAL);
                req.setMethod('POST');
                req.setHeader('Content-Type', 'application/json');
                req.setBody(JSON.serialize(message));
                req.setTimeout(ElaroConstants.CALLOUT_TIMEOUT_MS);

                Http http = new Http();
                HttpResponse res = http.send(req);

                if (res.getStatusCode() >= 200 && res.getStatusCode() < 300) {
                    ElaroLogger.info('SlackIntegration.SlackNotificationQueueable',
                        new Map<String, Object>{
                            'notificationType' => notificationType.name(),
                            'status' => 'success'
                        });
                } else {
                    ElaroLogger.error('SlackIntegration.SlackNotificationQueueable: Slack send failed with status '
                        + res.getStatusCode(),
                        new Map<String, Object>{
                            'notificationType' => notificationType.name(),
                            'responseBody' => res.getBody()
                        });
                }
            } catch (Exception e) {
                ElaroLogger.error('SlackIntegration.SlackNotificationQueueable: '
                    + notificationType.name() + ' notification failed', e);
            }
        }
    }
}
