/**
 * ServiceNow integration service for Elaro
 * Provides control sync, evidence push, and incident creation
 * @group Integration
 * @author Elaro Team
 * @since v3.1.0 (Spring '26)
 */
public with sharing class ServiceNowIntegration {
    
    private static final String NAMED_CREDENTIAL = 'callout:ServiceNow_API';
    
    /**
     * Sync controls from Elaro to ServiceNow GRC using Queueable
     * @param frameworkName Framework name (HIPAA, SOC2, etc.)
     */
    public static void syncControls(String frameworkName) {
        if (!Test.isRunningTest()) {
            System.enqueueJob(new ServiceNowSyncControlsQueueable(frameworkName));
        }
    }
    
    /**
     * Push evidence to ServiceNow using Queueable
     * @param evidenceId Evidence item ID
     */
    public static void pushEvidence(String evidenceId) {
        if (!Test.isRunningTest()) {
            System.enqueueJob(new ServiceNowPushEvidenceQueueable(evidenceId));
        }
    }
    
    /**
     * Sync compliance status to ServiceNow using Queueable
     * @param auditPackageId Audit package ID
     */
    public static void syncComplianceStatus(String auditPackageId) {
        if (!Test.isRunningTest()) {
            System.enqueueJob(new ServiceNowSyncStatusQueueable(auditPackageId));
        }
    }
    
    /**
     * @description Queueable implementation for syncing controls to ServiceNow
     */
    public class ServiceNowSyncControlsQueueable implements Queueable, Database.AllowsCallouts {
        private String frameworkName;

        public ServiceNowSyncControlsQueueable(String frameworkName) {
            this.frameworkName = frameworkName;
        }

        /** Retrieves framework controls and syncs each to ServiceNow GRC via REST API. */
        public void execute(QueueableContext context) {
            System.attachFinalizer(new ServiceNowSyncControlsQueueableFinalizer());
            try {
                // Get controls based on framework
                List<Map<String, Object>> controls = getControlsForFramework(frameworkName);
                
                for (Map<String, Object> control : controls) {
                    syncSingleControl(control);
                }
                
                ElaroLogger.info('ServiceNowIntegration.ServiceNowSyncControlsQueueable',
                    'Successfully synced ' + controls.size() + ' controls for ' + frameworkName);
            } catch (Exception e) {
                ElaroLogger.error('ServiceNowIntegration.ServiceNowSyncControlsQueueable',
                    e.getMessage(), e.getStackTraceString());
            }
        }

        /**
         * Transaction Finalizer for error logging and optional retry.
         */
        private class ServiceNowSyncControlsQueueableFinalizer implements Finalizer {
            public void execute(FinalizerContext ctx) {
                if (ctx.getResult() == ParentJobResult.UNHANDLED_EXCEPTION) {
                    ElaroLogger.error('ServiceNowSyncControlsQueueable: Unhandled exception: ' + ctx.getException().getMessage());
                }
            }
        }
    }
    
    /**
     * @description Queueable implementation for pushing evidence to ServiceNow
     */
    public class ServiceNowPushEvidenceQueueable implements Queueable, Database.AllowsCallouts {
        private String evidenceId;

        public ServiceNowPushEvidenceQueueable(String evidenceId) {
            this.evidenceId = evidenceId;
        }

        /** Queries the evidence item and pushes it to ServiceNow's compliance evidence table. */
        public void execute(QueueableContext context) {
            System.attachFinalizer(new ServiceNowPushEvidenceQueueableFinalizer());
            try {
                Elaro_Evidence_Item__c evidence = [
                    SELECT Id, Name, Evidence_Type__c, Description__c, Evidence_Date__c, Status__c
                    FROM Elaro_Evidence_Item__c
                    WHERE Id = :evidenceId
                    WITH USER_MODE
                    LIMIT 1
                ];

                // Sanitize data before sending externally
                SObjectAccessDecision decision = Security.stripInaccessible(
                    AccessType.READABLE, new List<Elaro_Evidence_Item__c>{ evidence }
                );
                Elaro_Evidence_Item__c sanitizedEvidence = (Elaro_Evidence_Item__c) decision.getRecords()[0];

                Map<String, Object> snowEvidence = new Map<String, Object>{
                    'u_external_id' => sanitizedEvidence.Id,
                    'u_evidence_type' => sanitizedEvidence.Evidence_Type__c,
                    'short_description' => sanitizedEvidence.Name,
                    'description' => sanitizedEvidence.Description__c,
                    'u_evidence_date' => sanitizedEvidence.Evidence_Date__c,
                    'u_status' => sanitizedEvidence.Status__c,
                    'u_source' => 'Elaro'
                };
                
                HttpRequest req = new HttpRequest();
                req.setEndpoint(NAMED_CREDENTIAL + '/api/now/table/u_compliance_evidence');
                req.setMethod('POST');
                req.setHeader('Content-Type', 'application/json');
                req.setHeader('Accept', 'application/json');
                req.setBody(JSON.serialize(snowEvidence));
                req.setTimeout(60000);
                
                Http http = new Http();
                HttpResponse res = http.send(req);
                
                if (res.getStatusCode() == 201) {
                    ElaroLogger.info('ServiceNowIntegration.ServiceNowPushEvidenceQueueable',
                        'Evidence pushed to ServiceNow: ' + evidenceId);
                } else {
                    ElaroLogger.error('ServiceNowIntegration.ServiceNowPushEvidenceQueueable',
                        'ServiceNow push failed: ' + res.getBody(), '');
                }
            } catch (Exception e) {
                ElaroLogger.error('ServiceNowIntegration.ServiceNowPushEvidenceQueueable',
                    e.getMessage(), e.getStackTraceString());
            }
        }

        /**
         * Transaction Finalizer for error logging and optional retry.
         */
        private class ServiceNowPushEvidenceQueueableFinalizer implements Finalizer {
            public void execute(FinalizerContext ctx) {
                if (ctx.getResult() == ParentJobResult.UNHANDLED_EXCEPTION) {
                    ElaroLogger.error('ServiceNowPushEvidenceQueueable: Unhandled exception: ' + ctx.getException().getMessage());
                }
            }
        }
    }
    
    /**
     * @description Queueable implementation for syncing compliance status to ServiceNow
     */
    public class ServiceNowSyncStatusQueueable implements Queueable, Database.AllowsCallouts {
        private String auditPackageId;

        public ServiceNowSyncStatusQueueable(String auditPackageId) {
            this.auditPackageId = auditPackageId;
        }

        /** Calculates the current compliance score and posts it to ServiceNow's status table. */
        public void execute(QueueableContext context) {
            System.attachFinalizer(new ServiceNowSyncStatusQueueableFinalizer());
            try {
                Elaro_Audit_Package__c pkg = [
                    SELECT Id, Name, Package_Name__c, Framework__c, Status__c
                    FROM Elaro_Audit_Package__c
                    WHERE Id = :auditPackageId
                    WITH USER_MODE
                    LIMIT 1
                ];
                
                // Calculate compliance score
                Map<String, Object> scoreData = ElaroComplianceScorer.calculateComplianceScore();
                Decimal score = (Decimal)scoreData.get('overallScore');
                
                Map<String, Object> complianceStatus = new Map<String, Object>{
                    'u_framework' => pkg.Framework__c,
                    'u_audit_package_id' => pkg.Id,
                    'u_package_name' => pkg.Package_Name__c,
                    'u_compliance_score' => score,
                    'u_status' => pkg.Status__c,
                    'u_source' => 'Elaro',
                    'u_sync_date' => DateTime.now().format('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'')
                };
                
                HttpRequest req = new HttpRequest();
                req.setEndpoint(NAMED_CREDENTIAL + '/api/now/table/u_compliance_status');
                req.setMethod('POST');
                req.setHeader('Content-Type', 'application/json');
                req.setHeader('Accept', 'application/json');
                req.setBody(JSON.serialize(complianceStatus));
                req.setTimeout(60000);
                
                Http http = new Http();
                HttpResponse res = http.send(req);
                
                if (res.getStatusCode() >= 200 && res.getStatusCode() < 300) {
                    ElaroLogger.info('ServiceNowIntegration.ServiceNowSyncStatusQueueable',
                        'Compliance status synced to ServiceNow');
                } else {
                    ElaroLogger.error('ServiceNowIntegration.ServiceNowSyncStatusQueueable',
                        'ServiceNow sync failed: ' + res.getBody(), '');
                }
            } catch (Exception e) {
                ElaroLogger.error('ServiceNowIntegration.ServiceNowSyncStatusQueueable',
                    e.getMessage(), e.getStackTraceString());
            }
        }

        /**
         * Transaction Finalizer for error logging and optional retry.
         */
        private class ServiceNowSyncStatusQueueableFinalizer implements Finalizer {
            public void execute(FinalizerContext ctx) {
                if (ctx.getResult() == ParentJobResult.UNHANDLED_EXCEPTION) {
                    ElaroLogger.error('ServiceNowSyncStatusQueueable: Unhandled exception: ' + ctx.getException().getMessage());
                }
            }
        }
    }
    
    /**
     * Create incident in ServiceNow
     * @param incidentData Incident details
     * @return ServiceNow incident sys_id
     */
    @AuraEnabled
    public static String createIncident(Map<String, Object> incidentData) {
        Map<String, Object> snowIncident = new Map<String, Object>{
            'short_description' => incidentData.get('title'),
            'description' => incidentData.get('description'),
            'urgency' => mapUrgency((String)incidentData.get('severity')),
            'impact' => mapImpact((String)incidentData.get('severity')),
            'category' => 'Security',
            'subcategory' => 'Compliance',
            'u_compliance_alert_id' => incidentData.get('alertId'),
            'u_source' => 'Elaro'
        };
        
        HttpRequest req = new HttpRequest();
        req.setEndpoint(NAMED_CREDENTIAL + '/api/now/table/incident');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('Accept', 'application/json');
        req.setBody(JSON.serialize(snowIncident));
        req.setTimeout(60000);
        
        try {
            Http http = new Http();
            HttpResponse res = http.send(req);
            
            if (res.getStatusCode() == 201) {
                Map<String, Object> response = (Map<String, Object>)JSON.deserializeUntyped(res.getBody());
                Map<String, Object> result = (Map<String, Object>)response.get('result');
                return (String)result.get('sys_id');
            } else {
                ElaroLogger.error('ServiceNowIntegration.createIncident', 'ServiceNow incident creation failed with status ' + res.getStatusCode() + ': ' + res.getBody(), '');
                throw new AuraHandledException('ServiceNow incident creation failed. Please verify your ServiceNow configuration and try again.');
            }
        } catch (CalloutException e) {
            ElaroLogger.error('ServiceNowIntegration.createIncident', e.getMessage(), e.getStackTraceString());
            throw new AuraHandledException('Unable to connect to ServiceNow. Please verify your connection settings and try again.');
        }
    }
    
    /**
     * Get incident status from ServiceNow
     * @param incidentSysId ServiceNow incident sys_id
     * @return Incident status
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getIncidentStatus(String incidentSysId) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(NAMED_CREDENTIAL + '/api/now/table/incident/' + incidentSysId);
        req.setMethod('GET');
        req.setHeader('Accept', 'application/json');
        req.setTimeout(ElaroConstants.CALLOUT_TIMEOUT_MS);
        
        try {
            Http http = new Http();
            HttpResponse res = http.send(req);
            
            if (res.getStatusCode() == 200) {
                Map<String, Object> response = (Map<String, Object>)JSON.deserializeUntyped(res.getBody());
                return (Map<String, Object>)response.get('result');
            }
        } catch (Exception e) {
            ElaroLogger.error( 'ServiceNow query error: ' + e.getMessage());
        }
        
        return new Map<String, Object>();
    }
    
    private static List<Map<String, Object>> getControlsForFramework(String framework) {
        List<Map<String, Object>> controls = new List<Map<String, Object>>();
        
        // Get controls from framework module
        IComplianceModule module = getModuleForFramework(framework);
        if (module != null) {
            for (IComplianceModule.Control ctrl : module.getControls()) {
                controls.add(new Map<String, Object>{
                    'code' => ctrl.code,
                    'name' => ctrl.name,
                    'description' => ctrl.description,
                    'severity' => ctrl.severity,
                    'framework' => framework
                });
            }
        }
        
        return controls;
    }
    
    private static void syncSingleControl(Map<String, Object> control) {
        Map<String, Object> snowControl = new Map<String, Object>{
            'u_control_id' => control.get('code'),
            'name' => control.get('name'),
            'description' => control.get('description'),
            'u_severity' => control.get('severity'),
            'u_framework' => control.get('framework'),
            'u_source' => 'Elaro'
        };
        
        HttpRequest req = new HttpRequest();
        req.setEndpoint(NAMED_CREDENTIAL + '/api/now/table/u_compliance_control');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setBody(JSON.serialize(snowControl));
        req.setTimeout(60000);

        try {
            Http http = new Http();
            http.send(req);
        } catch (Exception e) {
            ElaroLogger.warn( 'Control sync failed: ' + e.getMessage());
        }
    }
    
    private static IComplianceModule getModuleForFramework(String framework) {
        switch on framework {
            when 'HIPAA' { return new HIPAAModule(); }
            when 'SOC2' { return new SOC2Module(); }
            when 'GDPR' { return new GDPRModule(); }
            when 'FINRA' { return new FINRAModule(); }
            when else { return null; }
        }
    }
    
    private static String mapUrgency(String severity) {
        Map<String, String> urgencyMap = new Map<String, String>{
            'CRITICAL' => '1',
            'HIGH' => '2',
            'MEDIUM' => '3',
            'LOW' => '4'
        };
        return urgencyMap.containsKey(severity) ? urgencyMap.get(severity) : '3';
    }
    
    private static String mapImpact(String severity) {
        Map<String, String> impactMap = new Map<String, String>{
            'CRITICAL' => '1',
            'HIGH' => '2',
            'MEDIUM' => '2',
            'LOW' => '3'
        };
        return impactMap.containsKey(severity) ? impactMap.get(severity) : '2';
    }
}
