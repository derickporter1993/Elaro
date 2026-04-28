import { z } from "zod";
import type { ToolEntry } from "../types.js";
import { querySalesforce } from "../sf-query.js";
import {
  successResponse,
  errorResponse,
  escapeSoql,
} from "./common/utils.js";

export const tools: ToolEntry[] = [
  {
    name: "get_frameworks",
    description:
      "List all configured compliance frameworks with their metadata. " +
      "Returns framework name, display name, code, active status, retention settings, " +
      "and score multiplier. Queries the Framework_Config__mdt custom metadata type. " +
      "Useful for questions like 'What frameworks are configured?', " +
      "'Which compliance frameworks are active?', or 'Show me framework settings'.",
    inputSchema: z.object({
      activeOnly: z
        .boolean()
        .default(true)
        .describe("If true (default), only return active frameworks. Set false to include inactive."),
    }),
    handler: async (params) => {
      try {
        const { activeOnly } = params as { activeOnly: boolean };

        const whereClause =
          (activeOnly ?? true) ? "WHERE Is_Active__c = true" : "";

        const soql =
          `SELECT DeveloperName, MasterLabel, Framework_Name__c, Framework_Code__c, ` +
          `Display_Name__c, Is_Active__c, Retention_Days__c, Evidence_Retention_Days__c, ` +
          `Response_Deadline_Days__c, Score_Multiplier__c, Service_Class__c, ` +
          `Notification_Email__c ` +
          `FROM Framework_Config__mdt ${whereClause} ` +
          `ORDER BY Framework_Name__c ASC`;

        const result = await querySalesforce(soql);

        const frameworks = result.records.map((r) => ({
          developerName: r["DeveloperName"],
          label: r["MasterLabel"],
          frameworkName: r["Framework_Name__c"],
          frameworkCode: r["Framework_Code__c"],
          displayName: r["Display_Name__c"],
          isActive: r["Is_Active__c"],
          retentionDays: r["Retention_Days__c"],
          evidenceRetentionDays: r["Evidence_Retention_Days__c"],
          responseDeadlineDays: r["Response_Deadline_Days__c"],
          scoreMultiplier: r["Score_Multiplier__c"],
          serviceClass: r["Service_Class__c"],
          notificationEmail: r["Notification_Email__c"],
        }));

        return successResponse({
          totalSize: result.totalSize,
          records: frameworks,
        });
      } catch (error) {
        return errorResponse(
          `Failed to retrieve frameworks: ${error instanceof Error ? error.message : String(error)}`,
        );
      }
    },
  },
  {
    name: "get_framework_controls",
    description:
      "List compliance controls for a specific framework. " +
      "Controls are the individual rules/requirements that must be satisfied. " +
      "Returns control ID, name, description, severity, threshold settings, " +
      "and auto-remediation status. Queries Compliance_Control__mdt. " +
      "Useful for 'What controls does SOC2 have?', 'Show me HIPAA requirements', " +
      "or 'List critical controls for GDPR'.",
    inputSchema: z.object({
      framework: z
        .string()
        .describe(
          "The framework to list controls for (e.g., 'SOC2', 'HIPAA', 'GDPR'). " +
            "Must match the Framework__c field on Compliance_Control__mdt.",
        ),
      severity: z
        .enum(["CRITICAL", "HIGH", "MEDIUM", "LOW"])
        .optional()
        .describe("Optional filter by control severity. Values: CRITICAL, HIGH, MEDIUM, LOW."),
    }),
    handler: async (params) => {
      try {
        const { framework, severity } = params as {
          framework: string;
          severity?: string;
        };

        const conditions: string[] = [`Framework__c = '${escapeSoql(framework)}'`];
        if (severity) {
          conditions.push(`Severity__c = '${escapeSoql(severity)}'`);
        }

        const whereClause = `WHERE ${conditions.join(" AND ")}`;

        const soql =
          `SELECT DeveloperName, MasterLabel, Control_Id__c, Control_Name__c, ` +
          `Control_Description__c, Description__c, Framework__c, Severity__c, ` +
          `Threshold_Type__c, Threshold_Value__c, Auto_Remediate__c, ` +
          `Evaluation_Query__c, Related_Policies__c ` +
          `FROM Compliance_Control__mdt ${whereClause} ` +
          `ORDER BY Control_Id__c ASC`;

        const result = await querySalesforce(soql);

        const controls = result.records.map((r) => ({
          developerName: r["DeveloperName"],
          label: r["MasterLabel"],
          controlId: r["Control_Id__c"],
          controlName: r["Control_Name__c"],
          controlDescription: r["Control_Description__c"],
          description: r["Description__c"],
          framework: r["Framework__c"],
          severity: r["Severity__c"],
          thresholdType: r["Threshold_Type__c"],
          thresholdValue: r["Threshold_Value__c"],
          autoRemediate: r["Auto_Remediate__c"],
          evaluationQuery: r["Evaluation_Query__c"],
          relatedPolicies: r["Related_Policies__c"],
        }));

        return successResponse({
          framework,
          totalSize: result.totalSize,
          records: controls,
        });
      } catch (error) {
        return errorResponse(
          `Failed to retrieve framework controls: ${error instanceof Error ? error.message : String(error)}`,
        );
      }
    },
  },
];
