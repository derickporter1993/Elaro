/**
 * Performance Alert Publisher with improved error handling
 * Best Practice: Validates inputs, provides detailed error messages, structured logging
 * Security: Input validation, secure error handling
 */
public with sharing class PerformanceAlertPublisher {
    private static final String RATE_LIMIT_PARTITION = 'PrometheionRateLimit';
    private static final Integer RATE_LIMIT_MAX_CALLS = 100;
    private static final Integer RATE_LIMIT_WINDOW_SECONDS = 60;
    
    @AuraEnabled
    public static void publish(String metric, Decimal value, Decimal threshold, String contextRecordId, String stack) {
        try {
            // Rate limiting check
            if (!checkRateLimit('PerformanceAlertPublisher')) {
                System.debug(LoggingLevel.WARN, 'PerformanceAlertPublisher: Rate limit exceeded, skipping alert publication');
                return;
            }
            // Validate inputs
            if (String.isBlank(metric)) {
                throw new IllegalArgumentException('Metric cannot be blank');
            }
            if (value == null) {
                throw new IllegalArgumentException('Value cannot be null');
            }
            if (threshold == null) {
                throw new IllegalArgumentException('Threshold cannot be null');
            }

            // Truncate and sanitize stack trace if too long (Platform Event field limits)
            String safeStack = String.isNotBlank(stack) && stack.length() > 32768
                ? stack.substring(0, 32765) + '...'
                : stack;
            // XSS protection: escape HTML special characters in stack trace
            if (String.isNotBlank(safeStack)) {
                safeStack = safeStack.replace('<', '&lt;').replace('>', '&gt;').replace('&', '&amp;');
            }

            Performance_Alert__e evt = new Performance_Alert__e(
                Metric__c = metric,
                Value__c = value,
                Threshold__c = threshold,
                Context_Record__c = contextRecordId,
                Stack__c = safeStack
            );

            Database.SaveResult sr = EventBus.publish(evt);
            if (!sr.isSuccess()) {
                String errorMsg = 'Failed to publish Performance_Alert__e for metric: ' + metric;
                List<String> errorDetails = new List<String>();
                for (Database.Error err : sr.getErrors()) {
                    String detail = 'Error: ' + err.getMessage() + 
                                   ' (Status: ' + err.getStatusCode() + 
                                   ', Fields: ' + (err.getFields() != null ? String.join(err.getFields(), ', ') : 'N/A') + ')';
                    errorDetails.add(detail);
                }
                errorMsg += '. Details: ' + String.join(errorDetails, ' | ');
                
                // Log with correlation ID
                String correlationId = 'ALERT-' + System.now().getTime() + '-' + Crypto.getRandomInteger();
                System.debug(LoggingLevel.ERROR, 
                    'PerformanceAlertPublisher: ' + errorMsg + 
                    '. CorrelationId: ' + correlationId);
                
                // TODO: Re-enable Integration_Error__c logging after creating object in org
                // Log to Integration_Error__c if available
                // try {
                //     Integration_Error__c error = new Integration_Error__c(
                //         Error_Type__c = 'API_CALLOUT',
                //         Error_Message__c = errorMsg,
                //         Stack_Trace__c = 'SaveResult errors: ' + JSON.serialize(sr.getErrors()),
                //         Correlation_Id__c = correlationId,
                //         Context__c = 'Metric: ' + metric + ', Value: ' + value + ', Threshold: ' + threshold,
                //         Status__c = 'NEW',
                //         Timestamp__c = System.now()
                //     );
                //     insert error;
                // } catch (Exception logError) {
                //     // Don't fail if error logging fails
                //     System.debug(LoggingLevel.WARN, 'Failed to log PerformanceAlertPublisher error: ' + logError.getMessage());
                // }
                System.debug(LoggingLevel.WARN, 'PerformanceAlertPublisher error: ' + errorMsg + ', CorrelationId: ' + correlationId);
                
                throw new AuraHandledException(errorMsg);
            }
        } catch (IllegalArgumentException e) {
            System.debug(LoggingLevel.ERROR, 'PerformanceAlertPublisher: Validation error: ' + e.getMessage());
            throw new AuraHandledException('Invalid input: ' + e.getMessage());
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'PerformanceAlertPublisher: Unexpected error: ' + e.getMessage() + ', Stack: ' + e.getStackTraceString());
            throw new AuraHandledException('Failed to publish alert: ' + e.getMessage());
        }
    }
    
    /**
     * Check rate limit using Cache.OrgPartition
     * Returns true if within limit, false if limit exceeded
     */
    private static Boolean checkRateLimit(String key) {
        Cache.OrgPartition orgPart = Cache.Org.getPartition(RATE_LIMIT_PARTITION);
        String cacheKey = key + '_' + String.valueOf(System.now().getTime() / (RATE_LIMIT_WINDOW_SECONDS * 1000));
        Integer currentCount = (Integer)orgPart.get(cacheKey);
        
        if (currentCount == null) {
            currentCount = 0;
        }
        
        if (currentCount >= RATE_LIMIT_MAX_CALLS) {
            return false;
        }
        
        orgPart.put(cacheKey, currentCount + 1, RATE_LIMIT_WINDOW_SECONDS);
        return true;
    }
}
