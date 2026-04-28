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
    name: "get_scan_history",
    description:
      "List recent compliance scan (workflow execution) results. " +
      "Each scan executes a set of compliance rules and produces pass/fail results. " +
      "Useful for questions like 'Show me recent scans', 'What was the last scan result?', " +
      "'List all failed scans', or 'Show SOC2 scan history'. " +
      "Status values: PENDING, RUNNING, COMPLETED, FAILED.",
    inputSchema: z.object({
      framework: z
        .string()
        .optional()
        .describe("Filter by compliance framework (e.g., 'SOC2', 'HIPAA'). Omit for all frameworks."),
      status: z
        .string()
        .optional()
        .describe(
          "Filter by scan status. Values: PENDING, RUNNING, COMPLETED, FAILED. Omit for all statuses.",
        ),
      days: z
        .number()
        .int()
        .min(1)
        .max(365)
        .default(30)
        .describe("Number of days of history to retrieve (1-365, default 30)"),
      ...paginationSchema(),
    }),
    handler: async (params) => {
      try {
        const { framework, status, days, pageSize, pageOffset } = params as {
          framework?: string;
          status?: string;
          days: number;
          pageSize: number;
          pageOffset: number;
        };

        const effectiveDays = days ?? 30;
        const conditions: string[] = [
          `Started_At__c >= LAST_N_DAYS:${effectiveDays}`,
        ];
        if (framework) conditions.push(`Framework__c = '${escapeSoql(framework)}'`);
        if (status) conditions.push(`Status__c = '${escapeSoql(status)}'`);

        const whereClause = `WHERE ${conditions.join(" AND ")}`;

        const soql =
          `SELECT Id, Name, Template_Name__c, Framework__c, Status__c, ` +
          `Compliance_Score__c, Total_Rules__c, Rules_Passed__c, Rules_Failed__c, ` +
          `Started_At__c, Completed_At__c, Error_Message__c ` +
          `FROM Workflow_Execution__c ${whereClause} ` +
          `ORDER BY Started_At__c DESC ` +
          buildPaginationClause(pageSize ?? 25, pageOffset ?? 0);

        const result = await querySalesforce(soql);

        const scans = result.records.map((r) => ({
          id: r["Id"],
          name: r["Name"],
          templateName: r["Template_Name__c"],
          framework: r["Framework__c"],
          status: r["Status__c"],
          complianceScore: r["Compliance_Score__c"],
          totalRules: r["Total_Rules__c"],
          rulesPassed: r["Rules_Passed__c"],
          rulesFailed: r["Rules_Failed__c"],
          startedAt: r["Started_At__c"],
          completedAt: r["Completed_At__c"],
          errorMessage: r["Error_Message__c"],
        }));

        return successResponse({
          totalSize: result.totalSize,
          filters: { framework, status, days: effectiveDays },
          records: scans,
        });
      } catch (error) {
        return errorResponse(
          `Failed to retrieve scan history: ${error instanceof Error ? error.message : String(error)}`,
        );
      }
    },
  },
  {
    name: "get_scan_details",
    description:
      "Get full details for a single compliance scan (workflow execution) by its Salesforce record ID, " +
      "including all individual step execution results. Each step represents one rule evaluation. " +
      "Use this after get_scan_history to drill into a specific scan and see which rules passed or failed.",
    inputSchema: z.object({
      scanId: z
        .string()
        .regex(
          /^[a-zA-Z0-9]{15,18}$/,
          "Must be a valid 15 or 18 character Salesforce ID",
        )
        .describe(
          'The Salesforce record ID of the Workflow_Execution__c record (e.g., "a0Cxx0000004567AAA").',
        ),
    }),
    handler: async (params) => {
      try {
        const { scanId } = params as { scanId: string };

        // Fetch the workflow execution record
        const scanSoql =
          `SELECT Id, Name, Template_Name__c, Framework__c, Status__c, ` +
          `Compliance_Score__c, Total_Rules__c, Rules_Passed__c, Rules_Failed__c, ` +
          `Started_At__c, Completed_At__c, Error_Message__c, ` +
          `CreatedDate, LastModifiedDate ` +
          `FROM Workflow_Execution__c ` +
          `WHERE Id = '${escapeSoql(scanId)}' ` +
          `LIMIT 1`;

        const scanResult = await querySalesforce(scanSoql);

        if (scanResult.records.length === 0) {
          return errorResponse(
            `No scan found with ID "${scanId}". Verify the ID is a valid Workflow_Execution__c record.`,
          );
        }

        const scan = scanResult.records[0]!;

        // Fetch all step executions for this scan
        const stepsSoql =
          `SELECT Id, Name, Rule_Name__c, Rule_Developer_Name__c, ` +
          `Status__c, Severity__c, Finding_Details__c, ` +
          `Execution_Time_Ms__c, Executed_At__c ` +
          `FROM Step_Execution__c ` +
          `WHERE Workflow_Execution__c = '${escapeSoql(scanId)}' ` +
          `ORDER BY Executed_At__c ASC ` +
          `LIMIT 200`;

        const stepsResult = await querySalesforce(stepsSoql);

        const steps = stepsResult.records.map((r) => ({
          id: r["Id"],
          name: r["Name"],
          ruleName: r["Rule_Name__c"],
          ruleDeveloperName: r["Rule_Developer_Name__c"],
          status: r["Status__c"],
          severity: r["Severity__c"],
          findingDetails: r["Finding_Details__c"],
          executionTimeMs: r["Execution_Time_Ms__c"],
          executedAt: r["Executed_At__c"],
        }));

        return successResponse({
          scan: {
            id: scan["Id"],
            name: scan["Name"],
            templateName: scan["Template_Name__c"],
            framework: scan["Framework__c"],
            status: scan["Status__c"],
            complianceScore: scan["Compliance_Score__c"],
            totalRules: scan["Total_Rules__c"],
            rulesPassed: scan["Rules_Passed__c"],
            rulesFailed: scan["Rules_Failed__c"],
            startedAt: scan["Started_At__c"],
            completedAt: scan["Completed_At__c"],
            errorMessage: scan["Error_Message__c"],
            createdDate: scan["CreatedDate"],
            lastModifiedDate: scan["LastModifiedDate"],
          },
          steps: {
            totalSize: stepsResult.totalSize,
            records: steps,
          },
        });
      } catch (error) {
        return errorResponse(
          `Failed to retrieve scan details: ${error instanceof Error ? error.message : String(error)}`,
        );
      }
    },
  },
];
