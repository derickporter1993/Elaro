/**
 * Reads and parses workflow templates from Compliance_Workflow_Template__mdt.
 * Provides strongly-typed access to workflow step configurations.
 *
 * @author Elaro Team
 * @since v3.1.0 (Spring '26)
 * @group Rule Engine
 * @see ComplianceOrchestrationEngine
 */
public inherited sharing class WorkflowTemplateReader {

    /**
     * Represents a single step within a workflow template.
     */
    public class WorkflowStep implements Comparable {
        @AuraEnabled public Integer stepOrder { get; set; }
        @AuraEnabled public String stepType { get; set; }
        @AuraEnabled public String framework { get; set; }
        @AuraEnabled public String category { get; set; }
        @AuraEnabled public String description { get; set; }
        @AuraEnabled public Map<String, Object> config { get; set; }

        /**
         * Compares steps by stepOrder for sorting.
         *
         * @param compareTo The object to compare against
         * @return Negative if this comes first, positive if after, 0 if equal
         */
        public Integer compareTo(Object compareTo) {
            WorkflowStep other = (WorkflowStep) compareTo;
            Integer thisOrder = this.stepOrder ?? 0;
            Integer otherOrder = other.stepOrder ?? 0;
            return thisOrder - otherOrder;
        }
    }

    /**
     * Represents a parsed workflow template with its steps.
     */
    public class WorkflowTemplate {
        @AuraEnabled public String developerName { get; set; }
        @AuraEnabled public String templateName { get; set; }
        @AuraEnabled public String framework { get; set; }
        @AuraEnabled public String description { get; set; }
        @AuraEnabled public List<WorkflowStep> steps { get; set; }
    }

    /**
     * Loads an active workflow template by DeveloperName.
     *
     * @param templateDevName The DeveloperName of the template
     * @return Parsed WorkflowTemplate, or null if not found
     */
    public static WorkflowTemplate loadTemplate(String templateDevName) {
        if (String.isBlank(templateDevName)) {
            return null;
        }

        List<Compliance_Workflow_Template__mdt> templates = [
            SELECT DeveloperName, Template_Name__c, Framework__c,
                   Steps_JSON__c, Is_Active__c, Description__c
            FROM Compliance_Workflow_Template__mdt
            WHERE DeveloperName = :templateDevName
            AND Is_Active__c = true
            WITH USER_MODE
            LIMIT 1
        ];

        if (templates.isEmpty()) {
            return null;
        }

        return parseTemplate(templates[0]);
    }

    /**
     * Loads all active workflow templates for a framework.
     *
     * @param framework The compliance framework name
     * @return List of parsed WorkflowTemplates
     */
    public static List<WorkflowTemplate> loadTemplatesForFramework(String framework) {
        if (String.isBlank(framework)) {
            return new List<WorkflowTemplate>();
        }

        List<Compliance_Workflow_Template__mdt> templates = [
            SELECT DeveloperName, Template_Name__c, Framework__c,
                   Steps_JSON__c, Is_Active__c, Description__c
            FROM Compliance_Workflow_Template__mdt
            WHERE Framework__c = :framework
            AND Is_Active__c = true
            WITH USER_MODE
        ];

        List<WorkflowTemplate> parsed = new List<WorkflowTemplate>();
        for (Compliance_Workflow_Template__mdt tmpl : templates) {
            parsed.add(parseTemplate(tmpl));
        }
        return parsed;
    }

    /**
     * Parses a Custom Metadata record into a WorkflowTemplate.
     *
     * @param record The raw metadata record
     * @return Parsed WorkflowTemplate
     */
    @TestVisible
    private static WorkflowTemplate parseTemplate(Compliance_Workflow_Template__mdt record) {
        WorkflowTemplate template = new WorkflowTemplate();
        template.developerName = record.DeveloperName;
        template.templateName = record.Template_Name__c;
        template.framework = record.Framework__c;
        template.description = record.Description__c ?? '';
        template.steps = parseSteps(record.Steps_JSON__c);
        return template;
    }

    /**
     * Parses the Steps_JSON__c field into a list of WorkflowSteps.
     *
     * @param stepsJson The JSON array string
     * @return List of WorkflowSteps sorted by stepOrder
     */
    @TestVisible
    private static List<WorkflowStep> parseSteps(String stepsJson) {
        List<WorkflowStep> steps = new List<WorkflowStep>();
        if (String.isBlank(stepsJson)) {
            return steps;
        }

        try {
            List<Object> rawSteps = (List<Object>) JSON.deserializeUntyped(stepsJson);
            for (Object rawStep : rawSteps) {
                Map<String, Object> stepMap = (Map<String, Object>) rawStep;
                WorkflowStep step = new WorkflowStep();
                step.stepOrder = stepMap.containsKey('order')
                    ? ((Decimal) stepMap.get('order')).intValue() : 0;
                step.stepType = (String) stepMap.get('type') ?? 'EVALUATE';
                step.framework = (String) stepMap.get('framework');
                step.category = (String) stepMap.get('category');
                step.description = (String) stepMap.get('description') ?? '';
                step.config = stepMap;
                steps.add(step);
            }
        } catch (Exception e) {
            ElaroLogger.error('WorkflowTemplateReader.parseSteps',
                e.getMessage(), e.getStackTraceString());
        }

        steps.sort();
        return steps;
    }
}
