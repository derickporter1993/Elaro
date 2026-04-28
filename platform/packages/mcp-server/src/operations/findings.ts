import { z } from "zod";
import type { ToolEntry } from "../types.js";
import { querySalesforce } from "../sf-query.js";
import {
  successResponse,
  errorResponse,
  paginationSchema,
  buildPaginationClause,
  escapeSoql,
} from "./common/utils.js";

export const tools: ToolEntry[] = [
  {
    name: "get_findings",
    description:
      "List compliance findings (gaps) with optional filtering by severity, framework, and status. " +
      "Findings represent compliance gaps that need remediation. " +
      "Useful for questions like 'Show me all critical findings', " +
      "'What HIPAA gaps are still open?', or 'List high severity issues in progress'. " +
      "Severity values: CRITICAL, HIGH, MEDIUM, LOW. " +
      "Status values: OPEN, IN_PROGRESS, REMEDIATED, VERIFIED, ACCEPTED_RISK. " +
      "Framework values: SOX, SOC2, HIPAA, GDPR, CCPA, GLBA, NIST, ISO27001, PCI_DSS.",
    inputSchema: z.object({
      severity: z
        .enum(["CRITICAL", "HIGH", "MEDIUM", "LOW"])
        .optional()
        .describe(
          "Filter by severity level. Values: CRITICAL, HIGH, MEDIUM, LOW. Omit for all severities.",
        ),
      framework: z
        .string()
        .optional()
        .describe(
          "Filter by compliance framework (e.g., 'SOC2', 'HIPAA', 'GDPR'). Omit for all frameworks.",
        ),
      status: z
        .enum(["OPEN", "IN_PROGRESS", "REMEDIATED", "VERIFIED", "ACCEPTED_RISK"])
        .optional()
        .describe(
          "Filter by remediation status. Values: OPEN, IN_PROGRESS, REMEDIATED, VERIFIED, ACCEPTED_RISK. Omit for all statuses.",
        ),
      ...paginationSchema(),
    }),
    handler: async (params) => {
      try {
        const { severity, framework, status, pageSize, pageOffset } = params as {
          severity?: string;
          framework?: string;
          status?: string;
          pageSize: number;
          pageOffset: number;
        };

        const conditions: string[] = [];
        if (severity) conditions.push(`Severity__c = '${escapeSoql(severity)}'`);
        if (framework) conditions.push(`Framework__c = '${escapeSoql(framework)}'`);
        if (status) conditions.push(`Status__c = '${escapeSoql(status)}'`);

        const whereClause =
          conditions.length > 0 ? `WHERE ${conditions.join(" AND ")}` : "";

        const soql =
          `SELECT Id, Name, Framework__c, Severity__c, Status__c, ` +
          `Gap_Description__c, Risk_Score__c, Detected_Date__c, ` +
          `Target_Remediation_Date__c, Actual_Remediation_Date__c, ` +
          `Policy_Reference__c, Entity_Type__c, Jira_Issue_Key__c ` +
          `FROM Compliance_Gap__c ${whereClause} ` +
          `ORDER BY Severity__c ASC, Detected_Date__c DESC ` +
          buildPaginationClause(pageSize ?? 25, pageOffset ?? 0);

        const result = await querySalesforce(soql);

        const findings = result.records.map((r) => ({
          id: r["Id"],
          name: r["Name"],
          framework: r["Framework__c"],
          severity: r["Severity__c"],
          status: r["Status__c"],
          description: r["Gap_Description__c"],
          riskScore: r["Risk_Score__c"],
          detectedDate: r["Detected_Date__c"],
          targetRemediationDate: r["Target_Remediation_Date__c"],
          actualRemediationDate: r["Actual_Remediation_Date__c"],
          policyReference: r["Policy_Reference__c"],
          entityType: r["Entity_Type__c"],
          jiraIssueKey: r["Jira_Issue_Key__c"],
        }));

        return successResponse({
          totalSize: result.totalSize,
          filters: { severity, framework, status },
          records: findings,
        });
      } catch (error) {
        return errorResponse(
          `Failed to retrieve findings: ${error instanceof Error ? error.message : String(error)}`,
        );
      }
    },
  },
  {
    name: "get_finding_details",
    description:
      "Get full details for a single compliance finding (gap) by its Salesforce record ID. " +
      "Returns all fields including remediation plan, notes, Jira integration status, " +
      "and alert escalation details. " +
      "Use this after get_findings to drill into a specific finding.",
    inputSchema: z.object({
      findingId: z
        .string()
        .regex(
          /^[a-zA-Z0-9]{15,18}$/,
          "Must be a valid 15 or 18 character Salesforce ID",
        )
        .describe(
          'The Salesforce record ID of the Compliance_Gap__c record (e.g., "a0Bxx0000001234AAA").',
        ),
    }),
    handler: async (params) => {
      try {
        const { findingId } = params as { findingId: string };

        const soql =
          `SELECT Id, Name, Framework__c, Severity__c, Status__c, ` +
          `Gap_Description__c, Risk_Score__c, Detected_Date__c, ` +
          `Target_Remediation_Date__c, Actual_Remediation_Date__c, ` +
          `Policy_Reference__c, Entity_Type__c, Entity_Id__c, ` +
          `Remediation_Plan__c, Notes__c, ` +
          `Jira_Issue_Key__c, Jira_Issue_URL__c, Jira_Status__c, Jira_Last_Sync__c, ` +
          `Alert_Acknowledged__c, Alert_Escalation_Level__c, ` +
          `Alert_Snoozed_Until__c, Alert_Sent_At__c, ` +
          `CreatedDate, LastModifiedDate ` +
          `FROM Compliance_Gap__c ` +
          `WHERE Id = '${escapeSoql(findingId)}' ` +
          `LIMIT 1`;

        const result = await querySalesforce(soql);

        if (result.records.length === 0) {
          return errorResponse(
            `No finding found with ID "${findingId}". Verify the ID is a valid Compliance_Gap__c record.`,
          );
        }

        const r = result.records[0]!;

        return successResponse({
          id: r["Id"],
          name: r["Name"],
          framework: r["Framework__c"],
          severity: r["Severity__c"],
          status: r["Status__c"],
          description: r["Gap_Description__c"],
          riskScore: r["Risk_Score__c"],
          detectedDate: r["Detected_Date__c"],
          targetRemediationDate: r["Target_Remediation_Date__c"],
          actualRemediationDate: r["Actual_Remediation_Date__c"],
          policyReference: r["Policy_Reference__c"],
          entityType: r["Entity_Type__c"],
          entityId: r["Entity_Id__c"],
          remediationPlan: r["Remediation_Plan__c"],
          notes: r["Notes__c"],
          jira: {
            issueKey: r["Jira_Issue_Key__c"],
            issueUrl: r["Jira_Issue_URL__c"],
            status: r["Jira_Status__c"],
            lastSync: r["Jira_Last_Sync__c"],
          },
          alerting: {
            acknowledged: r["Alert_Acknowledged__c"],
            escalationLevel: r["Alert_Escalation_Level__c"],
            snoozedUntil: r["Alert_Snoozed_Until__c"],
            sentAt: r["Alert_Sent_At__c"],
          },
          createdDate: r["CreatedDate"],
          lastModifiedDate: r["LastModifiedDate"],
        });
      } catch (error) {
        return errorResponse(
          `Failed to retrieve finding details: ${error instanceof Error ? error.message : String(error)}`,
        );
      }
    },
  },
];
