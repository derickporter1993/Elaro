/**
 * Bridges the compliance Rule Engine (IComplianceModule and IRiskScoringService)
 * with the Event Monitoring subsystem. Converts compliance findings, violations,
 * control evaluation results, and gaps into Platform Events (ComplianceAlert__e)
 * so the Event Monitoring pipeline can correlate, alert, and track them.
 *
 * Also provides reverse integration: converts Event Monitoring outputs
 * (BreachPatternMatcher analyses and ConfigDriftDetector drift events) into
 * compliance findings that the Rule Engine can process.
 *
 * SECURITY: without sharing required because this class publishes Platform Events
 * for compliance alerting which must succeed regardless of the running user's
 * record access. Caller permission validation happens in the controller/service layer.
 *
 * @author Elaro Team
 * @since v3.1.0 (Spring '26)
 * @group Event Monitoring
 * @see ComplianceAlertPublisher
 * @see IComplianceModule
 * @see IRiskScoringService
 * @see BreachPatternMatcher
 * @see ConfigDriftDetector
 */
public without sharing class RuleEngineEventBridge {

    private static final String CLASS_NAME = 'RuleEngineEventBridge';

    /**
     * Represents a normalized compliance finding that can originate from any
     * source: IComplianceModule control evaluations, IRiskScoringService violations,
     * BreachPatternMatcher analyses, or ConfigDriftDetector drift events.
     */
    public class ComplianceFinding {
        @AuraEnabled public String framework;
        @AuraEnabled public String controlReference;
        @AuraEnabled public String severity;
        @AuraEnabled public String findingSummary;
        @AuraEnabled public String alertType;
        @AuraEnabled public String sourceRecordId;
        @AuraEnabled public String sourceSystem;
        @AuraEnabled public Decimal riskScore;
        @AuraEnabled public Datetime detectedAt;

        /**
         * Constructs a ComplianceFinding with required fields.
         *
         * @param framework The compliance framework identifier
         * @param controlReference The control or rule reference
         * @param severity The finding severity level
         * @param findingSummary Description of the finding
         */
        public ComplianceFinding(String framework, String controlReference,
                                  String severity, String findingSummary) {
            this.framework = framework;
            this.controlReference = controlReference;
            this.severity = severity ?? ElaroConstants.SEVERITY_MEDIUM;
            this.findingSummary = findingSummary;
            this.alertType = ComplianceAlertPublisher.ALERT_TYPE_FINDING;
            this.detectedAt = System.now();
        }
    }

    // =========================================================================
    // Rule Engine -> Event Monitoring (forward integration)
    // =========================================================================

    /**
     * Publishes ComplianceAlert__e events for all non-compliant control results
     * from an IComplianceModule gap analysis. Called after the Rule Engine evaluates
     * controls and identifies gaps for a given audit package.
     *
     * @param module The compliance module that produced the gaps
     * @param gaps List of compliance gaps from IComplianceModule.identifyGaps()
     * @return List of ComplianceFinding objects that were published as events
     */
    public static List<ComplianceFinding> publishGapsAsAlerts(
        IComplianceModule module,
        List<ComplianceModuleTypes.Gap> gaps
    ) {
        List<ComplianceFinding> findings = new List<ComplianceFinding>();

        if (gaps == null || gaps.isEmpty()) {
            return findings;
        }

        String frameworkName = module != null ? module.getFrameworkName() : 'UNKNOWN';

        try {
            List<ComplianceAlert__e> alerts = new List<ComplianceAlert__e>();

            for (ComplianceModuleTypes.Gap gap : gaps) {
                ComplianceFinding finding = new ComplianceFinding(
                    frameworkName,
                    gap.controlCode ?? gap.controlId,
                    gap.severity ?? ElaroConstants.SEVERITY_MEDIUM,
                    buildGapSummary(gap)
                );
                finding.alertType = ComplianceAlertPublisher.ALERT_TYPE_FINDING;
                finding.sourceRecordId = gap.id;
                finding.sourceSystem = 'IComplianceModule';
                finding.riskScore = gap.riskScore;
                findings.add(finding);

                alerts.add(new ComplianceAlert__e(
                    Framework__c = finding.framework,
                    Control_Reference__c = finding.controlReference,
                    Severity__c = finding.severity,
                    Finding_Summary__c = truncate(finding.findingSummary, 255),
                    Alert_Type__c = finding.alertType,
                    Source_Record_Id__c = finding.sourceRecordId
                ));
            }

            List<Database.SaveResult> results = ComplianceAlertPublisher.publishAlerts(alerts);
            logPublishResults(CLASS_NAME + '.publishGapsAsAlerts', frameworkName, results);

        } catch (Exception e) {
            ElaroLogger.error(CLASS_NAME + '.publishGapsAsAlerts', e);
        }

        return findings;
    }

    /**
     * Publishes ComplianceAlert__e events for violations detected by an
     * IRiskScoringService implementation. Each violation with a risk score
     * above the medium threshold is published as a compliance alert.
     *
     * @param service The risk scoring service that produced the violations
     * @return List of ComplianceFinding objects that were published as events
     */
    public static List<ComplianceFinding> publishViolationsAsAlerts(
        IRiskScoringService service
    ) {
        List<ComplianceFinding> findings = new List<ComplianceFinding>();

        if (service == null) {
            return findings;
        }

        try {
            String frameworkName = service.getFrameworkName() ?? 'UNKNOWN';
            List<Violation> violations = service.getViolations();

            if (violations == null || violations.isEmpty()) {
                return findings;
            }

            List<ComplianceAlert__e> alerts = new List<ComplianceAlert__e>();

            for (Violation v : violations) {
                String severity = ElaroConstants.getSeverityFromRiskScore(v.riskScore);

                ComplianceFinding finding = new ComplianceFinding(
                    frameworkName,
                    v.title ?? 'VIOLATION',
                    severity,
                    v.description ?? 'Compliance violation detected'
                );
                finding.alertType = ComplianceAlertPublisher.ALERT_TYPE_POLICY;
                finding.sourceRecordId = v.entityId;
                finding.sourceSystem = 'IRiskScoringService';
                finding.riskScore = v.riskScore;
                findings.add(finding);

                alerts.add(new ComplianceAlert__e(
                    Framework__c = finding.framework,
                    Control_Reference__c = finding.controlReference,
                    Severity__c = finding.severity,
                    Finding_Summary__c = truncate(finding.findingSummary, 255),
                    Alert_Type__c = finding.alertType,
                    Source_Record_Id__c = finding.sourceRecordId
                ));
            }

            List<Database.SaveResult> results = ComplianceAlertPublisher.publishAlerts(alerts);
            logPublishResults(CLASS_NAME + '.publishViolationsAsAlerts', frameworkName, results);

        } catch (Exception e) {
            ElaroLogger.error(CLASS_NAME + '.publishViolationsAsAlerts', e);
        }

        return findings;
    }

    /**
     * Publishes a ComplianceAlert__e event for a single non-compliant
     * ComplianceModuleTypes.ControlResult. Use this for real-time alerting
     * during individual control evaluations rather than batch gap analysis.
     *
     * @param frameworkName The compliance framework identifier
     * @param controlId The control identifier that was evaluated
     * @param controlResult The evaluation result to publish
     * @return ComplianceFinding if published, null if the result was compliant
     */
    public static ComplianceFinding publishControlResultAsAlert(
        String frameworkName,
        String controlId,
        ComplianceModuleTypes.ControlResult controlResult
    ) {
        if (controlResult == null || controlResult.passed) {
            return null;
        }

        try {
            String severity = mapControlStatusToSeverity(controlResult.status);

            ComplianceFinding finding = new ComplianceFinding(
                frameworkName ?? 'UNKNOWN',
                controlId,
                severity,
                controlResult.finding ?? 'Control evaluation failed'
            );
            finding.alertType = ComplianceAlertPublisher.ALERT_TYPE_FINDING;
            finding.sourceSystem = 'IComplianceModule';
            finding.riskScore = controlResult.score != null
                ? (100 - controlResult.score) / 10
                : ElaroConstants.DEFAULT_RISK_SCORE;

            ComplianceAlertPublisher.publishAlert(
                finding.framework,
                finding.controlReference,
                finding.severity,
                truncate(finding.findingSummary, 255),
                finding.alertType,
                finding.sourceRecordId
            );

            ElaroLogger.info(CLASS_NAME + '.publishControlResultAsAlert: Alert published', new Map<String, Object>{
                'framework' => frameworkName,
                'controlId' => controlId,
                'status' => controlResult.status
            });

            return finding;

        } catch (Exception e) {
            ElaroLogger.error(CLASS_NAME + '.publishControlResultAsAlert', e);
            return null;
        }
    }

    // =========================================================================
    // Event Monitoring -> Rule Engine (reverse integration)
    // =========================================================================

    /**
     * Converts BreachPatternMatcher analysis results into normalized
     * ComplianceFinding objects. These findings can be stored as evidence
     * or fed into the compliance scoring pipeline.
     *
     * @param analyses List of PatternAnalysis results from BreachPatternMatcher
     * @return List of ComplianceFinding objects representing the breach patterns
     */
    public static List<ComplianceFinding> convertBreachAnalysesToFindings(
        List<BreachPatternMatcher.PatternAnalysis> analyses
    ) {
        List<ComplianceFinding> findings = new List<ComplianceFinding>();

        if (analyses == null || analyses.isEmpty()) {
            return findings;
        }

        for (BreachPatternMatcher.PatternAnalysis analysis : analyses) {
            String framework = inferFrameworkFromPattern(analysis.patternName);

            ComplianceFinding finding = new ComplianceFinding(
                framework,
                'BREACH-' + sanitizeForReference(analysis.patternName),
                analysis.severity ?? ElaroConstants.SEVERITY_HIGH,
                buildBreachSummary(analysis)
            );
            finding.alertType = ComplianceAlertPublisher.ALERT_TYPE_BREACH;
            finding.sourceSystem = 'BreachPatternMatcher';
            finding.riskScore = analysis.threatScore;
            finding.sourceRecordId = analysis.userId;
            findings.add(finding);
        }

        ElaroLogger.info(CLASS_NAME + '.convertBreachAnalysesToFindings: Converted analyses', new Map<String, Object>{
            'analysisCount' => analyses.size(),
            'findingCount' => findings.size()
        });

        return findings;
    }

    /**
     * Converts ConfigDriftDetector drift events into normalized
     * ComplianceFinding objects. Drift events map to multiple frameworks
     * (SOC2 CC8.1, HIPAA 164.312, etc.) depending on the change type.
     *
     * @param driftEvents List of DriftEvent objects from ConfigDriftDetector
     * @return List of ComplianceFinding objects representing the drift detections
     */
    public static List<ComplianceFinding> convertDriftEventsToFindings(
        List<ConfigDriftDetector.DriftEvent> driftEvents
    ) {
        List<ComplianceFinding> findings = new List<ComplianceFinding>();

        if (driftEvents == null || driftEvents.isEmpty()) {
            return findings;
        }

        for (ConfigDriftDetector.DriftEvent drift : driftEvents) {
            String framework = inferFrameworkFromDrift(drift.changedObject);

            ComplianceFinding finding = new ComplianceFinding(
                framework,
                'DRIFT-' + sanitizeForReference(drift.changedObject),
                drift.riskLevel ?? ElaroConstants.SEVERITY_MEDIUM,
                buildDriftSummary(drift)
            );
            finding.alertType = ComplianceAlertPublisher.ALERT_TYPE_DRIFT;
            finding.sourceSystem = 'ConfigDriftDetector';
            finding.sourceRecordId = drift.changedBy;
            findings.add(finding);
        }

        ElaroLogger.info(CLASS_NAME + '.convertDriftEventsToFindings: Converted drifts', new Map<String, Object>{
            'driftCount' => driftEvents.size(),
            'findingCount' => findings.size()
        });

        return findings;
    }

    // =========================================================================
    // Full Pipeline: Detect -> Convert -> Publish
    // =========================================================================

    /**
     * Executes the full Event Monitoring-to-Rule Engine pipeline for drift events:
     * detects configuration drift, converts to findings, and publishes as
     * ComplianceAlert__e Platform Events.
     *
     * @param hoursBack Number of hours to scan for drift
     * @return List of ComplianceFinding objects that were detected and published
     */
    public static List<ComplianceFinding> detectAndPublishDriftFindings(Integer hoursBack) {
        List<ComplianceFinding> findings = new List<ComplianceFinding>();

        try {
            ConfigDriftDetector detector = new ConfigDriftDetector();
            List<ConfigDriftDetector.DriftEvent> driftEvents = detector.detectDrift(
                hoursBack ?? 1
            );

            if (driftEvents.isEmpty()) {
                return findings;
            }

            findings = convertDriftEventsToFindings(driftEvents);
            publishFindingsAsAlerts(findings);

        } catch (Exception e) {
            ElaroLogger.error(CLASS_NAME + '.detectAndPublishDriftFindings', e);
        }

        return findings;
    }

    /**
     * Executes the full Event Monitoring-to-Rule Engine pipeline for breach patterns:
     * analyzes security events, converts matched patterns to findings, and publishes
     * as ComplianceAlert__e Platform Events.
     *
     * @param events List of SecurityEvent objects to analyze for breach patterns
     * @return List of ComplianceFinding objects that were detected and published
     */
    public static List<ComplianceFinding> analyzeAndPublishBreachFindings(
        List<EventCorrelationEngine.SecurityEvent> events
    ) {
        List<ComplianceFinding> findings = new List<ComplianceFinding>();

        try {
            List<BreachPatternMatcher.PatternAnalysis> analyses =
                BreachPatternMatcher.analyzeEvents(events);

            if (analyses.isEmpty()) {
                return findings;
            }

            findings = convertBreachAnalysesToFindings(analyses);
            publishFindingsAsAlerts(findings);

        } catch (Exception e) {
            ElaroLogger.error(CLASS_NAME + '.analyzeAndPublishBreachFindings', e);
        }

        return findings;
    }

    /**
     * Publishes a list of ComplianceFinding objects as ComplianceAlert__e
     * Platform Events via ComplianceAlertPublisher.
     *
     * @param findings List of ComplianceFinding objects to publish
     * @return List of Database.SaveResult from the publish operation
     */
    public static List<Database.SaveResult> publishFindingsAsAlerts(
        List<ComplianceFinding> findings
    ) {
        if (findings == null || findings.isEmpty()) {
            return new List<Database.SaveResult>();
        }

        List<ComplianceAlert__e> alerts = new List<ComplianceAlert__e>();

        for (ComplianceFinding finding : findings) {
            alerts.add(new ComplianceAlert__e(
                Framework__c = finding.framework ?? 'UNKNOWN',
                Control_Reference__c = truncate(finding.controlReference, 255),
                Severity__c = finding.severity ?? ElaroConstants.SEVERITY_MEDIUM,
                Finding_Summary__c = truncate(finding.findingSummary, 255),
                Alert_Type__c = finding.alertType ?? ComplianceAlertPublisher.ALERT_TYPE_FINDING,
                Source_Record_Id__c = finding.sourceRecordId
            ));
        }

        List<Database.SaveResult> results = ComplianceAlertPublisher.publishAlerts(alerts);
        logPublishResults(CLASS_NAME + '.publishFindingsAsAlerts', 'MULTI', results);

        return results;
    }

    // =========================================================================
    // Private Helper Methods
    // =========================================================================

    /**
     * Builds a human-readable summary from an ComplianceModuleTypes.Gap object.
     *
     * @param gap The compliance gap to summarize
     * @return Formatted summary string
     */
    @TestVisible
    private static String buildGapSummary(ComplianceModuleTypes.Gap gap) {
        String summary = '';
        if (String.isNotBlank(gap.controlName)) {
            summary += gap.controlName + ': ';
        }
        summary += gap.description ?? 'Compliance gap detected';
        if (String.isNotBlank(gap.recommendation)) {
            summary += ' | Recommendation: ' + gap.recommendation;
        }
        return summary;
    }

    /**
     * Builds a human-readable summary from a BreachPatternMatcher.PatternAnalysis.
     *
     * @param analysis The breach analysis to summarize
     * @return Formatted summary string
     */
    @TestVisible
    private static String buildBreachSummary(BreachPatternMatcher.PatternAnalysis analysis) {
        String summary = 'Breach pattern matched: ' + (analysis.patternName ?? 'Unknown');
        if (analysis.matchedEventCount != null && analysis.matchedEventCount > 0) {
            summary += ' (' + analysis.matchedEventCount + ' events';
            if (analysis.timeWindowMinutes != null) {
                summary += ' in ' + analysis.timeWindowMinutes + ' min window';
            }
            summary += ')';
        }
        if (analysis.threatScore != null) {
            summary += ' | Threat score: ' + analysis.threatScore.setScale(1);
        }
        return summary;
    }

    /**
     * Builds a human-readable summary from a ConfigDriftDetector.DriftEvent.
     *
     * @param drift The drift event to summarize
     * @return Formatted summary string
     */
    @TestVisible
    private static String buildDriftSummary(ConfigDriftDetector.DriftEvent drift) {
        String summary = 'Configuration drift: ' + (drift.changeType ?? 'Unknown change');
        summary += ' on ' + (drift.changedObject ?? 'Unknown object');
        if (String.isNotBlank(drift.changedBy)) {
            summary += ' by ' + drift.changedBy;
        }
        if (String.isNotBlank(drift.oldValue) || String.isNotBlank(drift.newValue)) {
            summary += ' | Changed from: ' + (drift.oldValue ?? 'N/A')
                    + ' to: ' + (drift.newValue ?? 'N/A');
        }
        return summary;
    }

    /**
     * Maps ComplianceModuleTypes.ControlResult status to a severity level.
     *
     * @param status The control result status (COMPLIANT, NON_COMPLIANT, PARTIAL, NOT_APPLICABLE)
     * @return Corresponding severity level
     */
    @TestVisible
    private static String mapControlStatusToSeverity(String status) {
        if (String.isBlank(status)) {
            return ElaroConstants.SEVERITY_MEDIUM;
        }
        switch on status {
            when 'NON_COMPLIANT' {
                return ElaroConstants.SEVERITY_HIGH;
            }
            when 'PARTIAL' {
                return ElaroConstants.SEVERITY_MEDIUM;
            }
            when 'NOT_APPLICABLE' {
                return ElaroConstants.SEVERITY_LOW;
            }
            when else {
                return ElaroConstants.SEVERITY_MEDIUM;
            }
        }
    }

    /**
     * Infers the most relevant compliance framework from a breach pattern name.
     * Defaults to SOC2 since breach patterns typically map to SOC2 CC6/CC7 controls.
     *
     * @param patternName The breach pattern name
     * @return Framework identifier
     */
    @TestVisible
    private static String inferFrameworkFromPattern(String patternName) {
        if (String.isBlank(patternName)) {
            return ElaroConstants.FRAMEWORK_SOC2;
        }
        String lower = patternName.toLowerCase();
        if (lower.contains('hipaa') || lower.contains('phi') || lower.contains('ephi')) {
            return ElaroConstants.FRAMEWORK_HIPAA;
        }
        if (lower.contains('pci') || lower.contains('cardholder')) {
            return ElaroConstants.FRAMEWORK_PCI_DSS;
        }
        if (lower.contains('gdpr') || lower.contains('data subject')) {
            return ElaroConstants.FRAMEWORK_GDPR;
        }
        return ElaroConstants.FRAMEWORK_SOC2;
    }

    /**
     * Infers the most relevant compliance framework from a drift detection section.
     * Security-related drifts map to SOC2 CC6.1; access-related drifts to HIPAA 164.312.
     *
     * @param changedObject The SetupAuditTrail section or object name
     * @return Framework identifier
     */
    @TestVisible
    private static String inferFrameworkFromDrift(String changedObject) {
        if (String.isBlank(changedObject)) {
            return ElaroConstants.FRAMEWORK_SOC2;
        }
        String lower = changedObject.toLowerCase();
        if (lower.contains('permission') || lower.contains('sharing')
            || lower.contains('manage users')) {
            return ElaroConstants.FRAMEWORK_HIPAA;
        }
        if (lower.contains('network') || lower.contains('certificate')
            || lower.contains('connected app')) {
            return ElaroConstants.FRAMEWORK_PCI_DSS;
        }
        return ElaroConstants.FRAMEWORK_SOC2;
    }

    /**
     * Sanitizes a string for use as a control reference. Removes special
     * characters and truncates to a reasonable length.
     *
     * @param input The raw string to sanitize
     * @return Sanitized reference string
     */
    @TestVisible
    private static String sanitizeForReference(String input) {
        if (String.isBlank(input)) {
            return 'UNKNOWN';
        }
        String sanitized = input.replaceAll('[^a-zA-Z0-9_\\-]', '_');
        return truncate(sanitized, 80);
    }

    /**
     * Truncates a string to the specified maximum length.
     *
     * @param input The string to truncate
     * @param maxLength Maximum allowed length
     * @return Truncated string
     */
    private static String truncate(String input, Integer maxLength) {
        if (String.isBlank(input)) {
            return input;
        }
        return input.length() > maxLength ? input.substring(0, maxLength) : input;
    }

    /**
     * Logs the results of a bulk Platform Event publish operation.
     *
     * @param methodName The calling method for log context
     * @param framework The framework being processed
     * @param results List of Database.SaveResult from the publish
     */
    private static void logPublishResults(
        String methodName,
        String framework,
        List<Database.SaveResult> results
    ) {
        if (results == null) {
            return;
        }
        Integer successCount = 0;
        Integer failCount = 0;
        for (Database.SaveResult sr : results) {
            if (sr.isSuccess()) {
                successCount++;
            } else {
                failCount++;
            }
        }
        ElaroLogger.info(methodName + ': Publish complete', new Map<String, Object>{
            'framework' => framework,
            'total' => results.size(),
            'succeeded' => successCount,
            'failed' => failCount
        });
    }
}
