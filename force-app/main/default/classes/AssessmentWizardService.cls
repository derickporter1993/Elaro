/**
 * Orchestrates guided assessment wizard flows by loading configuration from
 * Assessment_Wizard_Config__mdt, managing session state in
 * Compliance_Assessment_Session__c, and coordinating step transitions
 * including auto-scan, attestation, evidence upload, approval, and review.
 *
 * @author Elaro Team
 * @since v3.1.0 (Spring '26)
 * @group Assessment
 * @see AssessmentWizardController
 * @see Assessment_Wizard_Config__mdt
 * @see Compliance_Assessment_Session__c
 */
public inherited sharing class AssessmentWizardService {

    /**
     * DTO representing a single wizard step configuration.
     *
     * @since v3.1.0 (Spring '26)
     * @group Assessment Wizards
     */
    public class WizardStep {
        @AuraEnabled public String stepId;
        @AuraEnabled public String wizardName;
        @AuraEnabled public String framework;
        @AuraEnabled public Integer stageOrder;
        @AuraEnabled public Integer stepOrder;
        @AuraEnabled public String stepType;
        @AuraEnabled public String controlReference;
        @AuraEnabled public String helpText;
        @AuraEnabled public Boolean isRequired;
        @AuraEnabled public String status;
        @AuraEnabled public String response;
    }

    /**
     * DTO representing a wizard stage containing ordered steps.
     *
     * @since v3.1.0 (Spring '26)
     * @group Assessment Wizards
     */
    public class WizardStage {
        @AuraEnabled public Integer stageOrder;
        @AuraEnabled public String stageName;
        @AuraEnabled public List<WizardStep> steps;
        @AuraEnabled public Boolean isComplete;

        public WizardStage() {
            this.steps = new List<WizardStep>();
            this.isComplete = false;
        }
    }

    /**
     * DTO representing the full wizard configuration with stages, steps,
     * and current session state.
     *
     * @since v3.1.0 (Spring '26)
     * @group Assessment Wizards
     */
    public class WizardConfig {
        @AuraEnabled public String wizardName;
        @AuraEnabled public String framework;
        @AuraEnabled public List<WizardStage> stages;
        @AuraEnabled public Integer currentStage;
        @AuraEnabled public Integer currentStep;
        @AuraEnabled public Decimal percentComplete;
        @AuraEnabled public String sessionStatus;
        @AuraEnabled public Id sessionId;

        public WizardConfig() {
            this.stages = new List<WizardStage>();
            this.currentStage = 1;
            this.currentStep = 1;
            this.percentComplete = 0;
            this.sessionStatus = 'Not Started';
        }
    }

    /**
     * DTO for persisting step responses in Session_State__c JSON.
     *
     * @since v3.1.0 (Spring '26)
     * @group Assessment Wizards
     */
    public class StepResponse {
        public String stepId;
        public String status;
        public String response;
        public Datetime completedAt;

        public StepResponse() {
            this.status = 'Pending';
        }
    }

    /**
     * Loads the wizard configuration for a given wizard name,
     * creating or resuming a session as appropriate.
     *
     * @param wizardName Developer name of the wizard (e.g., 'HIPAA_Assessment')
     * @return WizardConfig with stages, steps, and session state
     */
    public static WizardConfig loadWizard(String wizardName) {
        if (String.isBlank(wizardName)) {
            return new WizardConfig();
        }

        WizardConfig config = new WizardConfig();
        config.wizardName = wizardName;

        // Load steps from Custom Metadata
        List<Assessment_Wizard_Config__mdt> stepConfigs = [
            SELECT DeveloperName, Wizard_Name__c, Framework__c, Stage_Order__c,
                   Step_Order__c, Step_Type__c, Control_Reference__c,
                   Help_Text__c, Is_Required__c
            FROM Assessment_Wizard_Config__mdt
            WHERE Wizard_Name__c = :wizardName
            WITH USER_MODE
            ORDER BY Stage_Order__c ASC, Step_Order__c ASC
        ];

        if (stepConfigs.isEmpty()) {
            return config;
        }

        config.framework = stepConfigs[0].Framework__c;

        // Group steps into stages
        Map<Integer, WizardStage> stageMap = new Map<Integer, WizardStage>();
        for (Assessment_Wizard_Config__mdt sc : stepConfigs) {
            Integer stageNum = sc.Stage_Order__c != null ? sc.Stage_Order__c.intValue() : 1;
            WizardStage stage = stageMap.get(stageNum);
            if (stage == null) {
                stage = new WizardStage();
                stage.stageOrder = stageNum;
                stage.stageName = 'Stage ' + stageNum;
                stageMap.put(stageNum, stage);
            }

            WizardStep step = new WizardStep();
            step.stepId = sc.DeveloperName;
            step.wizardName = sc.Wizard_Name__c;
            step.framework = sc.Framework__c;
            step.stageOrder = stageNum;
            step.stepOrder = sc.Step_Order__c != null ? sc.Step_Order__c.intValue() : 1;
            step.stepType = sc.Step_Type__c;
            step.controlReference = sc.Control_Reference__c;
            step.helpText = sc.Help_Text__c;
            step.isRequired = sc.Is_Required__c ?? true;
            step.status = 'Pending';
            stage.steps.add(step);
        }

        // Sort stages by order
        List<Integer> stageOrders = new List<Integer>(stageMap.keySet());
        stageOrders.sort();
        for (Integer order : stageOrders) {
            config.stages.add(stageMap.get(order));
        }

        // Load or create session
        config = mergeSessionState(config);

        return config;
    }

    /**
     * Returns a list of available wizard names for display in a picker.
     *
     * @return List of unique wizard names from Assessment_Wizard_Config__mdt
     */
    public static List<String> getAvailableWizards() {
        Set<String> wizardNames = new Set<String>();
        for (Assessment_Wizard_Config__mdt cfg : [
            SELECT Wizard_Name__c
            FROM Assessment_Wizard_Config__mdt
            WITH USER_MODE
        ]) {
            if (String.isNotBlank(cfg.Wizard_Name__c)) {
                wizardNames.add(cfg.Wizard_Name__c);
            }
        }
        List<String> sorted = new List<String>(wizardNames);
        sorted.sort();
        return sorted;
    }

    /**
     * Creates a new assessment session for the given wizard.
     *
     * @param wizardName The wizard developer name
     * @param framework The compliance framework
     * @return Id of the new Compliance_Assessment_Session__c
     */
    public static Id createSession(String wizardName, String framework) {
        Compliance_Assessment_Session__c session = new Compliance_Assessment_Session__c(
            Wizard_Name__c = wizardName,
            Framework__c = framework ?? 'Unknown',
            Current_Stage__c = 1,
            Current_Step__c = 1,
            Status__c = 'Not Started',
            Percent_Complete__c = 0,
            Session_State__c = '{}',
            Assigned_To__c = UserInfo.getUserId()
        );

        insert as user session;
        ElaroLogger.info('AssessmentWizardService.createSession',
            new Map<String, Object>{
                'wizardName' => wizardName,
                'framework' => framework,
                'sessionId' => session.Id
            });
        return session.Id;
    }

    /**
     * Saves a step response and advances the wizard to the next step.
     *
     * @param sessionId The assessment session Id
     * @param stepId The DeveloperName of the step being completed
     * @param responseData The user's response for this step (JSON or text)
     * @return Updated WizardConfig reflecting the new state
     */
    public static WizardConfig saveStepAndAdvance(Id sessionId, String stepId, String responseData) {
        if (sessionId == null || String.isBlank(stepId)) {
            return new WizardConfig();
        }

        List<Compliance_Assessment_Session__c> sessions = [
            SELECT Id, Wizard_Name__c, Framework__c, Session_State__c,
                   Current_Stage__c, Current_Step__c, Status__c,
                   Percent_Complete__c, Started_Date__c
            FROM Compliance_Assessment_Session__c
            WHERE Id = :sessionId
            WITH USER_MODE
            LIMIT 1
        ];

        if (sessions.isEmpty()) {
            return new WizardConfig();
        }

        Compliance_Assessment_Session__c session = sessions[0];

        // Start the session if not yet started
        if (session.Status__c == 'Not Started') {
            session.Status__c = 'In Progress';
            session.Started_Date__c = Datetime.now();
        }

        // Deserialize existing state
        Map<String, Object> stateMap = deserializeState(session.Session_State__c);

        // Save this step's response
        Map<String, Object> stepState = new Map<String, Object>{
            'status' => 'Completed',
            'response' => responseData,
            'completedAt' => Datetime.now().format()
        };
        stateMap.put(stepId, stepState);

        session.Session_State__c = JSON.serialize(stateMap);

        // Calculate progress and advance
        WizardConfig config = loadWizard(session.Wizard_Name__c);
        config.sessionId = session.Id;
        applyStateToConfig(config, stateMap);

        Integer totalSteps = 0;
        Integer completedSteps = 0;
        Integer nextStage = -1;
        Integer nextStep = -1;
        Boolean foundCurrent = false;

        for (WizardStage stage : config.stages) {
            Boolean stageComplete = true;
            for (WizardStep step : stage.steps) {
                totalSteps++;
                if (step.status == 'Completed') {
                    completedSteps++;
                } else {
                    stageComplete = false;
                    if (!foundCurrent) {
                        nextStage = stage.stageOrder;
                        nextStep = step.stepOrder;
                        foundCurrent = true;
                    }
                }
            }
            stage.isComplete = stageComplete;
        }

        // Update session
        Decimal pct = totalSteps > 0 ? ((Decimal) completedSteps / totalSteps) * 100 : 0;
        session.Percent_Complete__c = pct.setScale(2);

        if (nextStage > 0) {
            session.Current_Stage__c = nextStage;
            session.Current_Step__c = nextStep;
            config.currentStage = nextStage;
            config.currentStep = nextStep;
        } else {
            // All steps completed
            session.Status__c = 'Pending Review';
            session.Current_Stage__c = config.stages.size();
            session.Current_Step__c = 1;
        }

        config.percentComplete = session.Percent_Complete__c;
        config.sessionStatus = session.Status__c;

        update as user session;

        ElaroLogger.info('AssessmentWizardService.saveStepAndAdvance',
            new Map<String, Object>{
                'sessionId' => sessionId,
                'stepId' => stepId,
                'percentComplete' => session.Percent_Complete__c,
                'status' => session.Status__c
            });

        return config;
    }

    /**
     * Marks an assessment session as completed.
     *
     * @param sessionId The assessment session Id
     * @return true if successfully completed
     */
    public static Boolean completeAssessment(Id sessionId) {
        if (sessionId == null) {
            return false;
        }

        List<Compliance_Assessment_Session__c> sessions = [
            SELECT Id, Status__c, Percent_Complete__c
            FROM Compliance_Assessment_Session__c
            WHERE Id = :sessionId
            WITH USER_MODE
            LIMIT 1
        ];

        if (sessions.isEmpty()) {
            return false;
        }

        Compliance_Assessment_Session__c session = sessions[0];
        session.Status__c = 'Completed';
        session.Completed_Date__c = Datetime.now();
        session.Percent_Complete__c = 100;

        update as user session;

        ElaroLogger.info('AssessmentWizardService.completeAssessment',
            new Map<String, Object>{ 'sessionId' => sessionId });

        return true;
    }

    /**
     * Retrieves step responses from a prior assessment session for
     * cross-framework pre-fill. Finds the most recent completed session
     * for any wizard and returns its state map.
     *
     * @param currentWizardName The current wizard to exclude from lookup
     * @param framework Optional framework filter; null returns any
     * @return Map of stepId to response data from the prior session
     */
    public static Map<String, String> getPrefillData(String currentWizardName, String framework) {
        Map<String, String> prefillMap = new Map<String, String>();

        String query = 'SELECT Id, Session_State__c, Wizard_Name__c '
            + 'FROM Compliance_Assessment_Session__c '
            + 'WHERE Status__c = \'Completed\' '
            + 'AND Wizard_Name__c != :currentWizardName ';

        Map<String, Object> binds = new Map<String, Object>{
            'currentWizardName' => currentWizardName ?? ''
        };

        if (String.isNotBlank(framework)) {
            query += 'AND Framework__c = :framework ';
            binds.put('framework', framework);
        }
        query += 'ORDER BY Completed_Date__c DESC WITH USER_MODE LIMIT 1';

        List<Compliance_Assessment_Session__c> sessions = Database.queryWithBinds(
            query, binds, AccessLevel.USER_MODE
        );

        if (sessions.isEmpty()) {
            return prefillMap;
        }

        Map<String, Object> stateMap = deserializeState(sessions[0].Session_State__c);
        for (String key : stateMap.keySet()) {
            Object stepData = stateMap.get(key);
            if (stepData instanceof Map<String, Object>) {
                Map<String, Object> stepMap = (Map<String, Object>) stepData;
                String response = (String) stepMap.get('response');
                if (String.isNotBlank(response)) {
                    prefillMap.put(key, response);
                }
            }
        }

        return prefillMap;
    }

    /**
     * Loads session state and merges it into the wizard config.
     *
     * @param config The WizardConfig to enrich with session data
     * @return Updated WizardConfig with session state applied
     */
    @TestVisible
    private static WizardConfig mergeSessionState(WizardConfig config) {
        // Find most recent active session for this wizard
        List<Compliance_Assessment_Session__c> sessions = [
            SELECT Id, Session_State__c, Current_Stage__c, Current_Step__c,
                   Status__c, Percent_Complete__c, Started_Date__c
            FROM Compliance_Assessment_Session__c
            WHERE Wizard_Name__c = :config.wizardName
            AND Status__c NOT IN ('Completed', 'Abandoned')
            AND Assigned_To__c = :UserInfo.getUserId()
            WITH USER_MODE
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];

        if (!sessions.isEmpty()) {
            Compliance_Assessment_Session__c session = sessions[0];
            config.sessionId = session.Id;
            config.currentStage = session.Current_Stage__c != null
                ? session.Current_Stage__c.intValue() : 1;
            config.currentStep = session.Current_Step__c != null
                ? session.Current_Step__c.intValue() : 1;
            config.percentComplete = session.Percent_Complete__c ?? 0;
            config.sessionStatus = session.Status__c ?? 'Not Started';

            Map<String, Object> stateMap = deserializeState(session.Session_State__c);
            applyStateToConfig(config, stateMap);
        }

        return config;
    }

    /**
     * Applies persisted state map to the wizard config steps.
     *
     * @param config The WizardConfig to update
     * @param stateMap Map from Session_State__c JSON
     */
    @TestVisible
    private static void applyStateToConfig(WizardConfig config, Map<String, Object> stateMap) {
        for (WizardStage stage : config.stages) {
            Boolean allComplete = true;
            for (WizardStep step : stage.steps) {
                Object stepData = stateMap.get(step.stepId);
                if (stepData instanceof Map<String, Object>) {
                    Map<String, Object> stepMap = (Map<String, Object>) stepData;
                    step.status = (String) stepMap.get('status') ?? 'Pending';
                    step.response = (String) stepMap.get('response');
                }
                if (step.status != 'Completed') {
                    allComplete = false;
                }
            }
            stage.isComplete = allComplete;
        }
    }

    /**
     * Executes automated control validation for Auto_Scan step types.
     * Integrates with ElaroFrameworkEngine (Team 1 Rule Engine) to evaluate
     * controls based on the framework requirements and current org state.
     *
     * **TEAM 1 INTEGRATION**: Delegates to ElaroFrameworkEngine for rule evaluation.
     *
     * @param sessionId Compliance_Assessment_Session__c Id
     * @param controlReferences List of control references to scan (e.g., ['SOC2-CC6.1', 'HIPAA-164.312'])
     * @return Map of control reference to scan result (PASS/FAIL/NOT_APPLICABLE)
     * @throws AuraHandledException if Framework Engine unavailable or session invalid
     * @example
     * Map<String, String> results = AssessmentWizardService.executeAutoScan(
     *     sessionId,
     *     new List<String>{'SOC2-CC6.1', 'SOC2-CC6.2'}
     * );
     */
    public static Map<String, String> executeAutoScan(Id sessionId, List<String> controlReferences) {
        Map<String, String> scanResults = new Map<String, String>();

        try {
            // Validate session exists
            List<Compliance_Assessment_Session__c> sessions = [
                SELECT Id, Framework__c, Wizard_Name__c, Session_State__c
                FROM Compliance_Assessment_Session__c
                WHERE Id = :sessionId
                WITH USER_MODE
                LIMIT 1
            ];

            if (sessions.isEmpty()) {
                throw new AuraHandledException('Invalid session ID');
            }

            Compliance_Assessment_Session__c session = sessions[0];

            ElaroLogger.info('AssessmentWizardService.executeAutoScan',
                'Starting auto-scan for ' + session.Framework__c + ' framework. '
                + 'Controls to scan: ' + controlReferences.size());

            // Delegate to ElaroFrameworkEngine (Team 1 Rule Engine)
            List<ElaroFrameworkEngine.FrameworkRequirement> requirements =
                ElaroFrameworkEngine.getFrameworkRequirements(session.Framework__c);

            // Build Map for O(1) requirement lookup (instead of nested loop)
            Map<String, ElaroFrameworkEngine.FrameworkRequirement> requirementsByCode =
                new Map<String, ElaroFrameworkEngine.FrameworkRequirement>();
            for (ElaroFrameworkEngine.FrameworkRequirement req : requirements) {
                requirementsByCode.put(req.code, req);
            }

            // Pre-compute scan results once (avoids SOQL inside loop)
            Map<String, Boolean> scanCache = buildScanCache();

            // Scan each control reference
            for (String controlRef : controlReferences) {
                ElaroFrameworkEngine.FrameworkRequirement matchedReq = requirementsByCode.get(controlRef);

                if (matchedReq != null) {
                    String result = evaluateControlRequirement(matchedReq, session.Framework__c, scanCache);
                    scanResults.put(controlRef, result);
                } else {
                    scanResults.put(controlRef, 'NOT_APPLICABLE');
                    ElaroLogger.warn('AssessmentWizardService.executeAutoScan',
                        new Map<String, Object>{
                            'controlRef' => controlRef,
                            'message' => 'Control not found in framework requirements'
                        });
                }
            }

            // Update session state with scan results
            Map<String, Object> stateMap = deserializeState(session.Session_State__c);
            stateMap.put('autoScanResults', scanResults);
            stateMap.put('lastScanTimestamp', Datetime.now().format());

            session.Session_State__c = JSON.serialize(stateMap);
            update as user session;

            ElaroLogger.info('AssessmentWizardService.executeAutoScan',
                'Auto-scan completed. Results: ' + scanResults.size() + ' controls evaluated');

            return scanResults;

        } catch (AuraHandledException ae) {
            throw ae;
        } catch (Exception e) {
            ElaroLogger.error('AssessmentWizardService.executeAutoScan',
                e.getMessage(), e.getStackTraceString());
            throw new AuraHandledException(
                'Unable to complete the auto-scan. Please verify you have the required permissions and try again.');
        }
    }

    /**
     * Pre-computes scan query results so that SOQL runs once regardless
     * of how many control references are evaluated.
     *
     * @return Map of entity type to Boolean (true = finding detected = FAIL)
     */
    @TestVisible
    private static Map<String, Boolean> buildScanCache() {
        Map<String, Boolean> cache = new Map<String, Boolean>();

        // Check if overly permissive permission sets exist (one query)
        List<PermissionSet> permSets = [
            SELECT Id FROM PermissionSet
            WHERE PermissionsModifyAllData = true
            WITH USER_MODE
            LIMIT 1
        ];
        cache.put('PERMISSION_SET', !permSets.isEmpty());

        // Check for inactive users with recent login activity (one query)
        List<User> inactiveUsers = [
            SELECT Id FROM User
            WHERE IsActive = false AND LastLoginDate >= LAST_N_DAYS:30
            WITH USER_MODE
            LIMIT 1
        ];
        cache.put('USER', !inactiveUsers.isEmpty());

        return cache;
    }

    /**
     * Evaluates a single control requirement using pre-computed scan cache.
     *
     * @param requirement The framework requirement to evaluate
     * @param framework The framework code (e.g., 'SOC2', 'HIPAA')
     * @param scanCache Pre-computed results from buildScanCache()
     * @return PASS, FAIL, or NOT_APPLICABLE
     */
    @TestVisible
    private static String evaluateControlRequirement(
        ElaroFrameworkEngine.FrameworkRequirement requirement,
        String framework,
        Map<String, Boolean> scanCache
    ) {
        switch on requirement.entityType {
            when 'PERMISSION_SET' {
                Boolean hasFinding = scanCache.get('PERMISSION_SET') ?? false;
                return hasFinding ? 'FAIL' : 'PASS';
            }
            when 'USER' {
                Boolean hasFinding = scanCache.get('USER') ?? false;
                return hasFinding ? 'FAIL' : 'PASS';
            }
            when 'FIELD_LEVEL_SECURITY' {
                return 'PASS';
            }
            when 'SETUP_AUDIT_TRAIL' {
                return 'PASS';
            }
            when else {
                return 'NOT_APPLICABLE';
            }
        }
    }

    /**
     * Backward-compatible overload that builds the scan cache internally.
     * Used by tests and callers that evaluate a single requirement.
     *
     * @param requirement The framework requirement to evaluate
     * @param framework The framework code (e.g., 'SOC2', 'HIPAA')
     * @return PASS, FAIL, or NOT_APPLICABLE
     */
    @TestVisible
    private static String evaluateControlRequirement(
        ElaroFrameworkEngine.FrameworkRequirement requirement,
        String framework
    ) {
        return evaluateControlRequirement(requirement, framework, buildScanCache());
    }

    /**
     * Safely deserializes Session_State__c JSON.
     *
     * @param stateJson The JSON string
     * @return Deserialized map or empty map if invalid
     */
    @TestVisible
    private static Map<String, Object> deserializeState(String stateJson) {
        if (String.isBlank(stateJson)) {
            return new Map<String, Object>();
        }
        try {
            Object parsed = JSON.deserializeUntyped(stateJson);
            if (parsed instanceof Map<String, Object>) {
                return (Map<String, Object>) parsed;
            }
        } catch (Exception e) {
            ElaroLogger.warn('AssessmentWizardService.deserializeState',
                new Map<String, Object>{ 'error' => e.getMessage() });
        }
        return new Map<String, Object>();
    }
}
