/**
 * AI-powered root cause analysis engine for compliance events
 * Uses Claude API to analyze event chains and identify root causes
 * @group AI Governance
 * @author Elaro Team
 * @since v3.1.0 (Spring '26)
 */
public with sharing class RootCauseAnalysisEngine {
    
    // ═══════════════════════════════════════════════════════════════
    // CONSTANTS
    // ═══════════════════════════════════════════════════════════════
    
    private static final String CACHE_PARTITION = 'local.ElaroCache';
    private static final Integer CACHE_TTL_SECONDS = 3600;
    private static final Integer RELATED_EVENT_WINDOW_HOURS = 24;
    
    // ═══════════════════════════════════════════════════════════════
    // PUBLIC METHODS
    // ═══════════════════════════════════════════════════════════════
    
    /**
     * Analyze compliance event for root cause
     * @param eventId The evidence item ID to analyze
     * @return RootCauseResult with analysis findings
     */
    @AuraEnabled
    public static RootCauseResult analyzeRootCause(String eventId) {
        if (String.isBlank(eventId)) {
            throw new AuraHandledException('Event ID is required');
        }
        
        // Check cache
        String cacheKey = 'rca_' + eventId;
        RootCauseResult cached = getCachedResult(cacheKey);
        if (cached != null) {
            return cached;
        }
        
        try {
            // Query the primary event
            Elaro_Evidence_Item__c primaryEvent = [
                SELECT Id, Name, Evidence_Type__c, Evidence_Date__c,
                       Description__c, Status__c, Audit_Package__c,
                       Audit_Package__r.Framework__c
                FROM Elaro_Evidence_Item__c
                WHERE Id = :eventId
                WITH USER_MODE
                LIMIT 1
            ];
            
            // Query related events (same user/time window)
            List<Elaro_Evidence_Item__c> relatedEvents = queryRelatedEvents(primaryEvent);
            
            // Build analysis context
            AnalysisContext context = buildAnalysisContext(primaryEvent, relatedEvents);
            
            // Call AI for root cause analysis
            RootCauseResult result = performAIAnalysis(context);
            result.eventId = eventId;
            
            // Cache result
            cacheResult(cacheKey, result);
            
            return result;
            
        } catch (QueryException e) {
            throw new AuraHandledException('Event not found: ' + eventId);
        } catch (Exception e) {
            ElaroLogger.error( 'RCA error: ' + e.getMessage());
            return createErrorResult(eventId, e.getMessage());
        }
    }
    
    /**
     * Batch analyze multiple events
     * @param eventIds List of evidence item IDs
     * @return List of RootCauseResult objects
     */
    @AuraEnabled
    public static List<RootCauseResult> batchAnalyze(List<String> eventIds) {
        try {
            List<RootCauseResult> results = new List<RootCauseResult>();

            if (eventIds == null || eventIds.isEmpty()) {
                return results;
            }

            // Limit batch size to avoid callout limits
            Integer batchLimit = Math.min(eventIds.size(), 10);

            for (Integer i = 0; i < batchLimit; i++) {
                try {
                    results.add(analyzeRootCause(eventIds[i]));
                } catch (Exception e) {
                    results.add(createErrorResult(eventIds[i], e.getMessage()));
                }
            }

            return results;
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            ElaroLogger.error('RootCauseAnalysisEngine.batchAnalyze', e.getMessage(), e.getStackTraceString());
            throw new AuraHandledException('Unable to complete the operation. Please verify you have the required permissions and try again.');
        }
    }
    
    /**
     * Get analysis summary for multiple events
     * @param eventIds List of evidence item IDs
     * @return Aggregated analysis summary
     */
    @AuraEnabled(cacheable=true)
    public static AnalysisSummary getAnalysisSummary(List<String> eventIds) {
        try {
            AnalysisSummary summary = new AnalysisSummary();
            summary.totalEvents = eventIds != null ? eventIds.size() : 0;
            summary.analyzedEvents = 0;
            summary.commonRootCauses = new List<String>();
            summary.topRemediation = new List<String>();

            if (eventIds == null || eventIds.isEmpty()) {
                return summary;
            }

            // Get cached results for these events
            Map<String, Integer> causeCounts = new Map<String, Integer>();
            Map<String, Integer> remediationCounts = new Map<String, Integer>();

            for (String eventId : eventIds) {
                String cacheKey = 'rca_' + eventId;
                RootCauseResult result = getCachedResult(cacheKey);

                if (result != null && result.status == 'SUCCESS') {
                    summary.analyzedEvents++;

                    // Count root causes
                    if (String.isNotBlank(result.rootCause)) {
                        String cause = result.rootCause.left(50);
                        causeCounts.put(cause, (causeCounts.containsKey(cause) ? causeCounts.get(cause) : 0) + 1);
                    }

                    // Count remediation suggestions
                    if (result.remediation != null) {
                        for (String rem : result.remediation) {
                            remediationCounts.put(rem, (remediationCounts.containsKey(rem) ? remediationCounts.get(rem) : 0) + 1);
                        }
                    }
                }
            }

            // Get top causes and remediation
            summary.commonRootCauses = getTopItems(causeCounts, 5);
            summary.topRemediation = getTopItems(remediationCounts, 5);

            return summary;
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            ElaroLogger.error('RootCauseAnalysisEngine.getAnalysisSummary', e.getMessage(), e.getStackTraceString());
            throw new AuraHandledException('Unable to complete the operation. Please verify you have the required permissions and try again.');
        }
    }
    
    // ═══════════════════════════════════════════════════════════════
    // PRIVATE METHODS
    // ═══════════════════════════════════════════════════════════════
    
    /**
     * Query related events within time window
     */
    private static List<Elaro_Evidence_Item__c> queryRelatedEvents(Elaro_Evidence_Item__c primaryEvent) {
        Date eventDate = primaryEvent.Evidence_Date__c;
        Date startDate = eventDate != null ? eventDate.addDays(-1) : Date.today().addDays(-1);
        Date endDate = eventDate != null ? eventDate.addDays(1) : Date.today().addDays(1);
        
        return [
            SELECT Id, Name, Evidence_Type__c, Evidence_Date__c, Description__c
            FROM Elaro_Evidence_Item__c
            WHERE Audit_Package__c = :primaryEvent.Audit_Package__c
            AND Id != :primaryEvent.Id
            AND Evidence_Date__c >= :startDate
            AND Evidence_Date__c <= :endDate
            WITH USER_MODE
            ORDER BY Evidence_Date__c ASC
            LIMIT 50
        ];
    }
    
    /**
     * Build analysis context for AI
     */
    private static AnalysisContext buildAnalysisContext(Elaro_Evidence_Item__c primary, 
                                                        List<Elaro_Evidence_Item__c> related) {
        AnalysisContext ctx = new AnalysisContext();
        ctx.primaryEventType = primary.Evidence_Type__c;
        ctx.primaryDescription = primary.Description__c;
        ctx.framework = primary.Audit_Package__r?.Framework__c;
        ctx.eventDate = primary.Evidence_Date__c;
        ctx.relatedEventCount = related.size();
        ctx.relatedEventTypes = new Set<String>();
        
        for (Elaro_Evidence_Item__c rel : related) {
            ctx.relatedEventTypes.add(rel.Evidence_Type__c);
        }
        
        return ctx;
    }
    
    /**
     * Perform AI analysis
     */
    private static RootCauseResult performAIAnalysis(AnalysisContext context) {
        // Build prompt
        String prompt = buildRCAPrompt(context);
        
        // Call AI (using mock in tests)
        String response;
        if (Test.isRunningTest()) {
            response = getMockRCAResponse();
        } else {
            response = callAI(prompt);
        }
        
        // Parse response
        return parseRCAResponse(response);
    }
    
    /**
     * Build RCA prompt
     */
    private static String buildRCAPrompt(AnalysisContext context) {
        return 'Perform root cause analysis for the following compliance event:\n\n' +
               'Primary Event Type: ' + context.primaryEventType + '\n' +
               'Description: ' + context.primaryDescription + '\n' +
               'Framework: ' + context.framework + '\n' +
               'Related Events (' + context.relatedEventCount + '): ' + 
               String.join(new List<String>(context.relatedEventTypes), ', ') + '\n\n' +
               'Provide analysis in JSON format with:\n' +
               '- rootCause: string\n' +
               '- confidence: number (0-100)\n' +
               '- contributingFactors: array of strings\n' +
               '- evidenceChain: array of strings\n' +
               '- remediation: array of strings\n' +
               '- preventionMeasures: array of strings';
    }
    
    /**
     * Call AI service
     */
    private static String callAI(String prompt) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:Elaro_Claude_API');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('anthropic-version', '2023-06-01');
        req.setTimeout(60000);
        
        Map<String, Object> body = new Map<String, Object>{
            'model' => 'claude-sonnet-4-20250514',
            'max_tokens' => 2048,
            'messages' => new List<Map<String, Object>>{
                new Map<String, Object>{
                    'role' => 'user',
                    'content' => prompt
                }
            }
        };
        
        req.setBody(JSON.serialize(body));
        
        Http http = new Http();
        HttpResponse res = http.send(req);
        
        if (res.getStatusCode() != 200) {
            throw new CalloutException('AI API error: ' + res.getBody());
        }
        
        return res.getBody();
    }
    
    /**
     * Parse RCA response
     */
    private static RootCauseResult parseRCAResponse(String response) {
        RootCauseResult result = new RootCauseResult();
        result.status = 'SUCCESS';
        
        try {
            Map<String, Object> responseMap = (Map<String, Object>)JSON.deserializeUntyped(response);
            List<Object> content = (List<Object>)responseMap.get('content');
            
            if (content != null && !content.isEmpty()) {
                Map<String, Object> firstContent = (Map<String, Object>)content[0];
                String text = (String)firstContent.get('text');
                
                Map<String, Object> rcaData = (Map<String, Object>)JSON.deserializeUntyped(text);
                
                result.rootCause = (String)rcaData.get('rootCause');
                result.confidence = rcaData.containsKey('confidence') 
                    ? Integer.valueOf(rcaData.get('confidence')) : 70;
                
                result.contributingFactors = parseStringList(rcaData.get('contributingFactors'));
                result.evidenceChain = parseStringList(rcaData.get('evidenceChain'));
                result.remediation = parseStringList(rcaData.get('remediation'));
                result.preventionMeasures = parseStringList(rcaData.get('preventionMeasures'));
            }
        } catch (Exception e) {
            result.status = 'ERROR';
            result.errorMessage = 'Parse error: ' + e.getMessage();
        }
        
        return result;
    }
    
    private static List<String> parseStringList(Object obj) {
        List<String> result = new List<String>();
        if (obj != null && obj instanceof List<Object>) {
            for (Object item : (List<Object>)obj) {
                result.add(String.valueOf(item));
            }
        }
        return result;
    }
    
    private static String getMockRCAResponse() {
        Map<String, Object> response = new Map<String, Object>{
            'content' => new List<Map<String, Object>>{
                new Map<String, Object>{
                    'type' => 'text',
                    'text' => JSON.serialize(new Map<String, Object>{
                        'rootCause' => 'Unauthorized access attempt from suspicious IP',
                        'confidence' => 85,
                        'contributingFactors' => new List<String>{
                            'Non-standard login hours',
                            'Foreign IP address'
                        },
                        'evidenceChain' => new List<String>{
                            'Login attempt at 2 AM',
                            'Multiple failed attempts before success'
                        },
                        'remediation' => new List<String>{
                            'Enable MFA for this user',
                            'Review access policies'
                        },
                        'preventionMeasures' => new List<String>{
                            'Implement geo-blocking',
                            'Add time-based access controls'
                        }
                    })
                }
            }
        };
        return JSON.serialize(response);
    }
    
    private static RootCauseResult createErrorResult(String eventId, String errorMsg) {
        RootCauseResult result = new RootCauseResult();
        result.eventId = eventId;
        result.status = 'ERROR';
        result.errorMessage = errorMsg;
        result.confidence = 0;
        result.contributingFactors = new List<String>();
        result.evidenceChain = new List<String>();
        result.remediation = new List<String>();
        result.preventionMeasures = new List<String>();
        return result;
    }
    
    private static List<String> getTopItems(Map<String, Integer> counts, Integer maxItems) {
        List<String> items = new List<String>(counts.keySet());
        // Simple sort by count
        items.sort();
        return items.size() > maxItems ? new List<String>(items.subList(0, maxItems)) : items;
    }
    
    // ═══════════════════════════════════════════════════════════════
    // CACHING
    // ═══════════════════════════════════════════════════════════════
    
    private static RootCauseResult getCachedResult(String key) {
        try {
            Cache.OrgPartition partition = Cache.Org.getPartition(CACHE_PARTITION);
            return (RootCauseResult)partition.get(key);
        } catch (Exception e) {
            return null;
        }
    }
    
    private static void cacheResult(String key, RootCauseResult result) {
        try {
            Cache.OrgPartition partition = Cache.Org.getPartition(CACHE_PARTITION);
            partition.put(key, result, CACHE_TTL_SECONDS);
        } catch (Exception e) {
            ElaroLogger.warn( 'Cache put failed: ' + e.getMessage());
        }
    }
    
    // ═══════════════════════════════════════════════════════════════
    // INNER CLASSES
    // ═══════════════════════════════════════════════════════════════
    
    public class RootCauseResult {
        @AuraEnabled public String eventId;
        @AuraEnabled public String rootCause;
        @AuraEnabled public Integer confidence; // 0-100
        @AuraEnabled public List<String> contributingFactors;
        @AuraEnabled public List<String> evidenceChain;
        @AuraEnabled public List<String> remediation;
        @AuraEnabled public List<String> preventionMeasures;
        @AuraEnabled public String status; // SUCCESS, ERROR
        @AuraEnabled public String errorMessage;
    }
    
    public class AnalysisContext {
        public String primaryEventType;
        public String primaryDescription;
        public String framework;
        public Date eventDate;
        public Integer relatedEventCount;
        public Set<String> relatedEventTypes;
    }
    
    public class AnalysisSummary {
        @AuraEnabled public Integer totalEvents;
        @AuraEnabled public Integer analyzedEvents;
        @AuraEnabled public List<String> commonRootCauses;
        @AuraEnabled public List<String> topRemediation;
    }
}
