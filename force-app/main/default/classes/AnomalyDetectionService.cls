/**
 * AnomalyDetectionService
 * 
 * Pattern detection for compliance anomalies
 * 
 * @author Elaro
 * @version 1.0
 * @since v3.1.0 (Spring '26)
 * @group Security
 */
public with sharing class AnomalyDetectionService {
    
    /**
     * Detects anomalies in compliance data including unusual permissions, metadata changes, and access patterns.
     *
     * @param framework Framework to analyze
     * @param daysBack Number of days to look back
     * @return List of detected anomalies
     * @throws IllegalArgumentException if framework is blank
     */
    @AuraEnabled
    public static List<Anomaly> detectAnomalies(String framework, Integer daysBack) {
        try {
            if (String.isBlank(framework)) {
                throw new IllegalArgumentException('Framework is required');
            }
            if (daysBack == null || daysBack < 1) {
                daysBack = 30; // Default to 30 days
            }

            List<Anomaly> anomalies = new List<Anomaly>();
            Datetime startDate = System.now().addDays(-daysBack);

            // Detect unusual permission set assignments
            anomalies.addAll(detectUnusualPermissionAssignments(startDate));

            // Detect unusual metadata changes
            anomalies.addAll(detectUnusualMetadataChanges(startDate));

            // Detect unusual access patterns
            anomalies.addAll(detectUnusualAccessPatterns(startDate));

            return anomalies;
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            ElaroLogger.error('AnomalyDetectionService.detectAnomalies', e.getMessage(), e.getStackTraceString());
            throw new AuraHandledException('Unable to complete the operation. Please verify you have the required permissions and try again.');
        }
    }
    
    /**
     * Detect unusual permission set assignments
     */
    private static List<Anomaly> detectUnusualPermissionAssignments(Datetime startDate) {
        List<Anomaly> anomalies = new List<Anomaly>();
        
        // Find users with excessive permission sets (more than 10)
        // Note: PermissionSetAssignment doesn't have CreatedDate, using SystemModstamp instead
        List<AggregateResult> excessiveAssignments = [
            SELECT AssigneeId, COUNT(Id) assignmentCount
            FROM PermissionSetAssignment
            WHERE SystemModstamp >= :startDate
            WITH USER_MODE
            GROUP BY AssigneeId
            HAVING COUNT(Id) > 10
        ];
        
        for (AggregateResult ar : excessiveAssignments) {
            Anomaly anomaly = new Anomaly();
            anomaly.type = 'EXCESSIVE_PERMISSIONS';
            anomaly.severity = 'HIGH';
            anomaly.description = 'User has ' + ar.get('assignmentCount') + ' permission set assignments';
            anomaly.entityId = (String)ar.get('AssigneeId');
            anomalies.add(anomaly);
        }
        
        return anomalies;
    }
    
    /**
     * Detect unusual metadata changes
     */
    private static List<Anomaly> detectUnusualMetadataChanges(Datetime startDate) {
        List<Anomaly> anomalies = new List<Anomaly>();
        
        // Find high-risk metadata changes
        List<Metadata_Change__c> highRiskChanges = [
            SELECT Id, Metadata_Type__c, Metadata_Name__c, Change_Type__c, Risk_Level__c
            FROM Metadata_Change__c
            WHERE Change_Date__c >= :startDate
            AND Risk_Level__c = 'CRITICAL'
            WITH USER_MODE
        ];
        
        for (Metadata_Change__c change : highRiskChanges) {
            Anomaly anomaly = new Anomaly();
            anomaly.type = 'HIGH_RISK_CHANGE';
            anomaly.severity = 'CRITICAL';
            anomaly.description = change.Change_Type__c + ' of ' + change.Metadata_Type__c + ': ' + change.Metadata_Name__c;
            anomaly.entityId = change.Id;
            anomalies.add(anomaly);
        }
        
        return anomalies;
    }
    
    /**
     * Detects unusual access patterns from LoginHistory: failed/blocked logins and
     * off-hours (overnight) successful logins measured against a simple baseline.
     *
     * This performs a genuine baseline detection rather than returning an empty list,
     * so callers never receive a fabricated "no anomalies = safe" all-clear.
     *
     * @param startDate The lower bound of the analysis window
     * @return List of access-pattern anomalies (empty only when none are actually found)
     */
    private static List<Anomaly> detectUnusualAccessPatterns(Datetime startDate) {
        // Pull recent login history once (no SOQL in loops). LoginHistory runs in user mode.
        List<LoginHistory> logins = [
            SELECT Id, UserId, LoginTime, SourceIp, Status
            FROM LoginHistory
            WHERE LoginTime >= :startDate
            WITH USER_MODE
            ORDER BY LoginTime DESC
            LIMIT 5000
        ];

        return analyzeLoginHistory(logins);
    }

    /**
     * Analyzes LoginHistory records for access-pattern anomalies (failed/blocked logins
     * and off-hours access). Extracted from the query so it can be unit tested with
     * synthetic records, because LoginHistory is read-only and cannot be inserted in tests.
     *
     * @param logins LoginHistory records to analyze
     * @return List of access-pattern anomalies (empty only when none are actually found)
     */
    @TestVisible
    private static List<Anomaly> analyzeLoginHistory(List<LoginHistory> logins) {
        List<Anomaly> anomalies = new List<Anomaly>();

        // Off-hours window: logins before 06:00 or at/after 22:00 (GMT) are flagged for review.
        final Integer OFF_HOURS_START = 22; // 10 PM
        final Integer OFF_HOURS_END = 6;    // 6 AM

        // Aggregate failed logins per user so we flag the user, not each attempt.
        Map<Id, Integer> failedByUser = new Map<Id, Integer>();

        for (LoginHistory login : logins) {
            // 1. Failed / blocked logins are anomalous regardless of timing.
            if (String.isNotBlank(login.Status) && login.Status != 'Success') {
                Integer current = failedByUser.containsKey(login.UserId)
                    ? failedByUser.get(login.UserId)
                    : 0;
                failedByUser.put(login.UserId, current + 1);
                continue;
            }

            // 2. Off-hours successful logins (overnight access) flagged for review.
            if (login.LoginTime == null) {
                continue;
            }
            Integer hourOfDay = login.LoginTime.hourGmt();
            if (hourOfDay >= OFF_HOURS_START || hourOfDay < OFF_HOURS_END) {
                Anomaly anomaly = new Anomaly();
                anomaly.type = 'OFF_HOURS_ACCESS';
                anomaly.severity = 'MEDIUM';
                anomaly.description = 'Off-hours login at ' + login.LoginTime.formatGmt('yyyy-MM-dd HH:mm')
                    + ' GMT from IP ' + (login.SourceIp ?? 'unknown');
                anomaly.entityId = String.valueOf(login.UserId);
                anomalies.add(anomaly);
            }
        }

        // Emit one HIGH anomaly per user with repeated failed logins (>= 5 in window).
        for (Id userId : failedByUser.keySet()) {
            Integer failures = failedByUser.get(userId);
            if (failures >= 5) {
                Anomaly anomaly = new Anomaly();
                anomaly.type = 'REPEATED_LOGIN_FAILURES';
                anomaly.severity = 'HIGH';
                anomaly.description = 'User has ' + failures + ' failed/blocked login attempts in the analysis window';
                anomaly.entityId = String.valueOf(userId);
                anomalies.add(anomaly);
            }
        }

        return anomalies;
    }
    
    /**
     * Anomaly
     */
    public class Anomaly {
        @AuraEnabled public String type;
        @AuraEnabled public String severity;
        @AuraEnabled public String description;
        @AuraEnabled public String entityId;
        @AuraEnabled public Datetime detectedDate = System.now();
    }
}
