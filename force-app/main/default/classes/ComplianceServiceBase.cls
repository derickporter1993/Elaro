/**
 * Abstract base class for compliance framework services
 * Provides shared functionality for logging, error handling, audit trails, and security enforcement
 * 
 * All compliance services should extend this class to ensure consistent patterns:
 * - WITH SECURITY_ENFORCED on all SOQL queries
 * - Security.stripInaccessible for all DML operations
 * - Structured audit logging
 * - Correlation ID tracking
 * - Error categorization and sanitization
 * 
 * @author Prometheion
 * @version 3.0
 */
public abstract with sharing class ComplianceServiceBase {
    
    // Correlation ID for request tracking
    protected String correlationId;
    
    // Framework name (must be set by subclass)
    protected abstract String getFrameworkName();
    
    /**
     * Constructor - generates correlation ID for request tracking
     */
    public ComplianceServiceBase() {
        this.correlationId = generateCorrelationId();
    }
    
    /**
     * Generate unique correlation ID for request tracking
     * @return Correlation ID string
     */
    protected String generateCorrelationId() {
        return 'CORR-' + String.valueOf(DateTime.now().getTime()) + '-' + String.valueOf(Crypto.getRandomInteger());
    }
    
    /**
     * Log audit event to Prometheion_Audit_Log__c
     * @param action Action performed (e.g., 'DATA_SUBJECT_ACCESS_REQUEST', 'BREACH_REPORTED')
     * @param entityType Type of entity affected
     * @param entityId ID of entity affected
     * @param details Additional details as JSON string
     */
    protected void logAuditEvent(String action, String entityType, Id entityId, String details) {
        try {
            Prometheion_Audit_Log__c auditLog = new Prometheion_Audit_Log__c(
                Action__c = action,
                Entity_Type__c = entityType,
                Entity_Id__c = entityId != null ? String.valueOf(entityId) : null,
                Details__c = details,
                User__c = UserInfo.getUserId(),
                Timestamp__c = DateTime.now()
            );
            
            // Enforce CRUD/FLS
            SObjectAccessDecision decision = Security.stripInaccessible(
                AccessType.CREATABLE,
                new List<Prometheion_Audit_Log__c>{ auditLog }
            );
            
            List<Prometheion_Audit_Log__c> sanitizedLogs = decision.getRecords();
            if (!sanitizedLogs.isEmpty()) {
                Database.insert(sanitizedLogs, AccessLevel.USER_MODE);
            }
        } catch (Exception e) {
            // Log to debug but don't fail the operation
            System.debug(LoggingLevel.ERROR, 
                'ComplianceServiceBase: Failed to log audit event. CorrelationId: ' + correlationId + 
                ', Error: ' + e.getMessage());
        }
    }
    
    /**
     * Log structured debug message with correlation ID
     * @param level Logging level
     * @param message Log message
     * @param additionalData Additional data map
     */
    protected void logDebug(LoggingLevel level, String message, Map<String, Object> additionalData) {
        String logMessage = '[' + getFrameworkName() + '] [' + correlationId + '] ' + message;
        if (additionalData != null && !additionalData.isEmpty()) {
            logMessage += ' | Data: ' + JSON.serialize(additionalData);
        }
        System.debug(level, logMessage);
    }
    
    /**
     * Categorize exception for safe error handling
     * @param e Exception to categorize
     * @return Error category string
     */
    protected String categorizeError(Exception e) {
        if (e instanceof DmlException) {
            return 'DML_ERROR';
        } else if (e instanceof QueryException) {
            return 'QUERY_ERROR';
        } else if (e instanceof NullPointerException) {
            return 'NULL_POINTER';
        } else if (e instanceof IllegalArgumentException) {
            return 'INVALID_ARGUMENT';
        } else {
            return 'GENERIC_ERROR';
        }
    }
    
    /**
     * Create sanitized error response for UI
     * Never exposes internal details, only generic user-safe messages
     * @param errorCategory Error category from categorizeError()
     * @return User-safe error message
     */
    protected String getSanitizedErrorMessage(String errorCategory) {
        switch on errorCategory {
            when 'DML_ERROR' {
                return 'Unable to save data. Please try again or contact your administrator.';
            }
            when 'QUERY_ERROR' {
                return 'Unable to retrieve data. Please try again or contact your administrator.';
            }
            when 'NULL_POINTER', 'INVALID_ARGUMENT' {
                return 'Invalid request. Please check your input and try again.';
            }
            when else {
                return 'An unexpected error occurred. Please contact your administrator.';
            }
        }
    }
    
    /**
     * Execute DML operation with security enforcement
     * @param records Records to insert/update/delete
     * @param operation DML operation type
     * @return Database.SaveResult or Database.DeleteResult list
     */
    protected List<Database.SaveResult> executeSecureDML(List<SObject> records, AccessType accessType) {
        if (records == null || records.isEmpty()) {
            return new List<Database.SaveResult>();
        }
        
        // Strip inaccessible fields
        SObjectAccessDecision decision = Security.stripInaccessible(accessType, records);
        List<SObject> sanitizedRecords = decision.getRecords();
        
        if (sanitizedRecords.isEmpty()) {
            logDebug(LoggingLevel.WARN, 'No accessible records to process', new Map<String, Object>{
                'originalCount' => records.size(),
                'accessType' => String.valueOf(accessType)
            });
            return new List<Database.SaveResult>();
        }
        
        // Determine operation type from access type
        if (accessType == AccessType.CREATABLE) {
            return Database.insert(sanitizedRecords, false, AccessLevel.USER_MODE);
        } else if (accessType == AccessType.UPDATABLE) {
            return Database.update(sanitizedRecords, false, AccessLevel.USER_MODE);
        } else {
            throw new IllegalArgumentException('Unsupported access type for DML: ' + accessType);
        }
    }
    
    /**
     * Execute query with security enforcement
     * @param queryString SOQL query string (must include WITH SECURITY_ENFORCED)
     * @return Query result
     */
    protected List<SObject> executeSecureQuery(String queryString) {
        if (!queryString.containsIgnoreCase('WITH SECURITY_ENFORCED')) {
            throw new IllegalArgumentException('Query must include WITH SECURITY_ENFORCED: ' + queryString);
        }
        return Database.query(queryString);
    }
    
    /**
     * Get framework configuration from custom metadata
     * @return Framework_Config__mdt record or null
     */
    protected Framework_Config__mdt getFrameworkConfig() {
        try {
            List<Framework_Config__mdt> configs = [
                SELECT Id, Framework_Name__c, Is_Active__c, Retention_Days__c, Notification_Email__c
                FROM Framework_Config__mdt
                WHERE Framework_Name__c = :getFrameworkName()
                AND Is_Active__c = true
                WITH SECURITY_ENFORCED
                LIMIT 1
            ];
            return configs.isEmpty() ? null : configs[0];
        } catch (Exception e) {
            logDebug(LoggingLevel.WARN, 'Failed to retrieve framework config', new Map<String, Object>{
                'framework' => getFrameworkName(),
                'error' => categorizeError(e)
            });
            return null;
        }
    }
    
    /**
     * Validate required parameters
     * @param paramName Parameter name
     * @param paramValue Parameter value
     * @throws IllegalArgumentException if parameter is null or empty
     */
    protected void validateRequired(String paramName, Object paramValue) {
        if (paramValue == null) {
            throw new IllegalArgumentException(paramName + ' is required and cannot be null');
        }
        if (paramValue instanceof String && String.isBlank((String)paramValue)) {
            throw new IllegalArgumentException(paramName + ' is required and cannot be blank');
        }
    }
}
