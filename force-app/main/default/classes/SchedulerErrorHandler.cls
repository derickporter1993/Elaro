/**
 * @description Centralized error handling utility for all Prometheion schedulers and batch jobs.
 *              Provides logging, Slack notifications, and success tracking.
 * @author Prometheion Team
 * @date 2025
 */
public without sharing class SchedulerErrorHandler {
    
    // Custom Metadata for configuration (will be created in CFG2)
    private static final String SLACK_WEBHOOK_SETTING = 'Prometheion_Slack_Webhook';
    private static final String ERROR_LOG_OBJECT = 'Prometheion_Audit_Log__c';
    
    /**
     * @description Logs a scheduler/batch execution error with full context
     * @param schedulerName The name of the scheduler or batch class
     * @param e The exception that occurred
     * @return Id of the created audit log record (null if logging fails)
     */
    public static Id logError(String schedulerName, Exception e) {
        return logError(schedulerName, e, null);
    }
    
    /**
     * @description Logs a scheduler/batch execution error with full context and additional details
     * @param schedulerName The name of the scheduler or batch class
     * @param e The exception that occurred
     * @param additionalContext JSON string with extra context (record IDs, batch info, etc.)
     * @return Id of the created audit log record (null if logging fails)
     */
    public static Id logError(String schedulerName, Exception e, String additionalContext) {
        try {
            Prometheion_Audit_Log__c logRecord = new Prometheion_Audit_Log__c(
                Action__c = 'SCHEDULER_ERROR',
                Category__c = 'System',
                Details__c = buildErrorDetails(schedulerName, e, additionalContext),
                Status__c = 'Error',
                Timestamp__c = Datetime.now(),
                User__c = UserInfo.getUserId()
            );
            
            // Use Database.insert to handle partial failures gracefully
            Database.SaveResult sr = Database.insert(logRecord, false);
            
            if (sr.isSuccess()) {
                return sr.getId();
            } else {
                System.debug(LoggingLevel.ERROR, 'Failed to create error log: ' + sr.getErrors()[0].getMessage());
                return null;
            }
        } catch (Exception logException) {
            // Last resort - system debug if logging itself fails
            System.debug(LoggingLevel.ERROR, 'SchedulerErrorHandler.logError failed: ' + logException.getMessage());
            System.debug(LoggingLevel.ERROR, 'Original error: ' + e.getMessage());
            return null;
        }
    }
    
    /**
     * @description Logs successful scheduler/batch execution
     * @param schedulerName The name of the scheduler or batch class
     * @param details Summary of what was processed (e.g., "Processed 150 records")
     * @return Id of the created audit log record (null if logging fails)
     */
    public static Id logSuccess(String schedulerName, String details) {
        try {
            Prometheion_Audit_Log__c logRecord = new Prometheion_Audit_Log__c(
                Action__c = 'SCHEDULER_SUCCESS',
                Category__c = 'System',
                Details__c = JSON.serialize(new Map<String, Object>{
                    'schedulerName' => schedulerName,
                    'details' => details,
                    'executionTime' => Datetime.now().format('yyyy-MM-dd HH:mm:ss'),
                    'runningUser' => UserInfo.getUserName()
                }),
                Status__c = 'Success',
                Timestamp__c = Datetime.now(),
                User__c = UserInfo.getUserId()
            );
            
            Database.SaveResult sr = Database.insert(logRecord, false);
            return sr.isSuccess() ? sr.getId() : null;
            
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'SchedulerErrorHandler.logSuccess failed: ' + e.getMessage());
            return null;
        }
    }
    
    /**
     * @description Sends Slack notification on scheduler failure (async to avoid blocking)
     * @param schedulerName The name of the scheduler or batch class
     * @param e The exception that occurred
     */
    @future(callout=true)
    public static void notifyOnFailure(String schedulerName, String errorMessage, String stackTrace) {
        notifyOnFailureSync(schedulerName, errorMessage, stackTrace);
    }
    
    /**
     * @description Synchronous version for use in finish() methods where @future isn't allowed
     * @param schedulerName The name of the scheduler or batch class  
     * @param errorMessage The error message
     * @param stackTrace The stack trace
     */
    public static void notifyOnFailureSync(String schedulerName, String errorMessage, String stackTrace) {
        try {
            // Get Slack webhook URL from Custom Metadata or Custom Setting
            String webhookUrl = getSlackWebhookUrl();
            
            if (String.isBlank(webhookUrl)) {
                System.debug(LoggingLevel.WARN, 'Slack webhook URL not configured. Skipping notification.');
                return;
            }
            
            // Build Slack message payload
            Map<String, Object> payload = buildSlackPayload(schedulerName, errorMessage, stackTrace);
            
            HttpRequest req = new HttpRequest();
            req.setEndpoint(webhookUrl);
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setBody(JSON.serialize(payload));
            req.setTimeout(10000); // 10 second timeout
            
            Http http = new Http();
            HttpResponse res = http.send(req);
            
            if (res.getStatusCode() != 200) {
                System.debug(LoggingLevel.ERROR, 'Slack notification failed: ' + res.getStatusCode() + ' - ' + res.getBody());
            }
            
        } catch (Exception notifyException) {
            // Don't let notification failure cascade
            System.debug(LoggingLevel.ERROR, 'Failed to send Slack notification: ' + notifyException.getMessage());
        }
    }
    
    /**
     * @description Handles Database.SaveResult arrays and logs any failures
     * @param results Array of SaveResult from Database.update/insert
     * @param schedulerName Context for logging
     * @param operationType 'INSERT' or 'UPDATE'
     * @return Number of failed records
     */
    public static Integer handleSaveResults(List<Database.SaveResult> results, String schedulerName, String operationType) {
        List<String> errorMessages = new List<String>();
        Integer failureCount = 0;
        
        for (Integer i = 0; i < results.size(); i++) {
            Database.SaveResult sr = results[i];
            if (!sr.isSuccess()) {
                failureCount++;
                for (Database.Error err : sr.getErrors()) {
                    errorMessages.add('Record ' + i + ': ' + err.getStatusCode() + ' - ' + err.getMessage());
                }
            }
        }
        
        if (failureCount > 0) {
            String errorSummary = operationType + ' failures in ' + schedulerName + ':\n' + String.join(errorMessages, '\n');
            
            // Log but don't throw - let the scheduler continue with successful records
            logError(schedulerName, new SchedulerException(errorSummary), JSON.serialize(new Map<String, Object>{
                'totalRecords' => results.size(),
                'failedRecords' => failureCount,
                'successfulRecords' => results.size() - failureCount
            }));
        }
        
        return failureCount;
    }
    
    /**
     * @description Checks if today is a business day (Mon-Fri, not a holiday)
     * @return true if today is a business day
     */
    public static Boolean isBusinessDay() {
        Date today = Date.today();
        Datetime dt = Datetime.newInstance(today, Time.newInstance(0, 0, 0, 0));
        String dayOfWeek = dt.format('EEEE');
        
        // Check weekend
        if (dayOfWeek == 'Saturday' || dayOfWeek == 'Sunday') {
            return false;
        }
        
        // Check holidays (query Custom Metadata if exists)
        try {
            Integer holidayCount = [
                SELECT COUNT() 
                FROM Prometheion_Holiday__mdt 
                WHERE Holiday_Date__c = :today 
                AND Is_Active__c = true
                LIMIT 1
            ];
            return holidayCount == 0;
        } catch (Exception e) {
            // If holiday metadata doesn't exist, assume business day
            return true;
        }
    }
    
    /**
     * @description Creates a savepoint for transaction rollback
     * @return Savepoint object
     */
    public static Savepoint setSavepoint() {
        return Database.setSavepoint();
    }
    
    /**
     * @description Rolls back to a savepoint and logs the rollback
     * @param sp The savepoint to rollback to
     * @param schedulerName Context for logging
     * @param reason Why the rollback occurred
     */
    public static void rollbackAndLog(Savepoint sp, String schedulerName, String reason) {
        Database.rollback(sp);
        logError(schedulerName, new SchedulerException('Transaction rolled back: ' + reason));
    }
    
    // ============ PRIVATE HELPER METHODS ============
    
    private static String buildErrorDetails(String schedulerName, Exception e, String additionalContext) {
        Map<String, Object> details = new Map<String, Object>{
            'schedulerName' => schedulerName,
            'errorMessage' => e.getMessage(),
            'errorType' => e.getTypeName(),
            'stackTrace' => e.getStackTraceString(),
            'lineNumber' => e.getLineNumber(),
            'executionTime' => Datetime.now().format('yyyy-MM-dd HH:mm:ss'),
            'runningUser' => UserInfo.getUserName(),
            'orgId' => UserInfo.getOrganizationId()
        };
        
        if (String.isNotBlank(additionalContext)) {
            details.put('additionalContext', additionalContext);
        }
        
        return JSON.serializePretty(details);
    }
    
    private static String getSlackWebhookUrl() {
        try {
            // Try Custom Metadata first
            List<Prometheion_Integration_Setting__mdt> settings = [
                SELECT Value__c 
                FROM Prometheion_Integration_Setting__mdt 
                WHERE DeveloperName = :SLACK_WEBHOOK_SETTING 
                AND Is_Active__c = true
                LIMIT 1
            ];
            
            if (!settings.isEmpty()) {
                return settings[0].Value__c;
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'Could not query Slack webhook setting: ' + e.getMessage());
        }
        
        return null;
    }
    
    private static Map<String, Object> buildSlackPayload(String schedulerName, String errorMessage, String stackTrace) {
        String orgName = UserInfo.getOrganizationName();
        String truncatedStack = stackTrace.length() > 500 ? stackTrace.substring(0, 500) + '...' : stackTrace;
        
        return new Map<String, Object>{
            'blocks' => new List<Object>{
                new Map<String, Object>{
                    'type' => 'header',
                    'text' => new Map<String, Object>{
                        'type' => 'plain_text',
                        'text' => 'Scheduler Error: ' + schedulerName,
                        'emoji' => true
                    }
                },
                new Map<String, Object>{
                    'type' => 'section',
                    'fields' => new List<Object>{
                        new Map<String, Object>{
                            'type' => 'mrkdwn',
                            'text' => '*Org:*\n' + orgName
                        },
                        new Map<String, Object>{
                            'type' => 'mrkdwn',
                            'text' => '*Time:*\n' + Datetime.now().format('yyyy-MM-dd HH:mm:ss z')
                        }
                    }
                },
                new Map<String, Object>{
                    'type' => 'section',
                    'text' => new Map<String, Object>{
                        'type' => 'mrkdwn',
                        'text' => '*Error:*\n```' + errorMessage + '```'
                    }
                },
                new Map<String, Object>{
                    'type' => 'section',
                    'text' => new Map<String, Object>{
                        'type' => 'mrkdwn',
                        'text' => '*Stack Trace:*\n```' + truncatedStack + '```'
                    }
                }
            }
        };
    }
    
    // Custom exception for scheduler-specific errors
    public class SchedulerException extends Exception {}
}
