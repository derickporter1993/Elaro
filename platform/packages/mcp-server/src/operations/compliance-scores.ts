import { z } from "zod";
import type { ToolEntry } from "../types.js";
import { querySalesforce } from "../sf-query.js";
import {
  successResponse,
  errorResponse,
  paginationSchema,
  buildWhereClause,
  buildPaginationClause,
  escapeSoql,
} from "./common/utils.js";

export const tools: ToolEntry[] = [
  {
    name: "get_compliance_scores",
    description:
      "List compliance scores across all frameworks or for a specific framework. " +
      "Returns framework-level scores, risk scores, and calculation timestamps. " +
      "Useful for answering questions like 'What is our SOC2 score?' or " +
      "'Show me all compliance scores'. " +
      "Supported frameworks: SOC2, HIPAA, GDPR, CCPA, GLBA, ISO27001, PCI_DSS, NIST, FINRA, FedRAMP, CMMC.",
    inputSchema: z.object({
      framework: z
        .string()
        .optional()
        .describe(
          "Filter by compliance framework name (e.g., 'SOC2', 'HIPAA', 'GDPR'). " +
            "Omit to return scores for all frameworks.",
        ),
      ...paginationSchema(),
    }),
    handler: async (params) => {
      try {
        const { framework, pageSize, pageOffset } = params as {
          framework?: string;
          pageSize: number;
          pageOffset: number;
        };

        const whereClause = framework
          ? `WHERE Entity_Type__c = '${escapeSoql(framework)}'`
          : "";

        const soql =
          `SELECT Id, Name, Entity_Type__c, Risk_Score__c, Framework_Scores__c, ` +
          `Calculated_At__c, Findings__c ` +
          `FROM Compliance_Score__c ${whereClause} ` +
          `ORDER BY Calculated_At__c DESC ` +
          buildPaginationClause(pageSize ?? 25, pageOffset ?? 0);

        const result = await querySalesforce(soql);

        const scores = result.records.map((r) => ({
          id: r["Id"],
          name: r["Name"],
          framework: r["Entity_Type__c"],
          riskScore: r["Risk_Score__c"],
          frameworkScores: parseJsonField(r["Framework_Scores__c"]),
          calculatedAt: r["Calculated_At__c"],
          findingsCount: countFindings(r["Findings__c"]),
        }));

        return successResponse({
          totalSize: result.totalSize,
          records: scores,
        });
      } catch (error) {
        return errorResponse(
          `Failed to retrieve compliance scores: ${error instanceof Error ? error.message : String(error)}`,
        );
      }
    },
  },
  {
    name: "get_score_trend",
    description:
      "Get compliance score history over time for a specific framework. " +
      "Returns chronological score data points for trend analysis. " +
      "Useful for answering 'How has our HIPAA score changed over the last 90 days?' or " +
      "'Show me the SOC2 compliance trend'.",
    inputSchema: z.object({
      framework: z
        .string()
        .describe(
          "The compliance framework to get trend data for (e.g., 'SOC2', 'HIPAA', 'GDPR'). Required.",
        ),
      days: z
        .number()
        .int()
        .min(1)
        .max(365)
        .default(90)
        .describe("Number of days of history to retrieve (1-365, default 90)"),
    }),
    handler: async (params) => {
      try {
        const { framework, days } = params as {
          framework: string;
          days: number;
        };

        const effectiveDays = days ?? 90;

        const soql =
          `SELECT Id, Name, Risk_Score__c, Framework_Scores__c, Calculated_At__c ` +
          `FROM Compliance_Score__c ` +
          `WHERE Entity_Type__c = '${escapeSoql(framework)}' ` +
          `AND Calculated_At__c >= LAST_N_DAYS:${effectiveDays} ` +
          `ORDER BY Calculated_At__c ASC ` +
          `LIMIT 500`;

        const result = await querySalesforce(soql);

        const trendData = result.records.map((r) => ({
          id: r["Id"],
          riskScore: r["Risk_Score__c"],
          frameworkScores: parseJsonField(r["Framework_Scores__c"]),
          calculatedAt: r["Calculated_At__c"],
        }));

        return successResponse({
          framework,
          periodDays: effectiveDays,
          dataPoints: trendData.length,
          trend: trendData,
        });
      } catch (error) {
        return errorResponse(
          `Failed to retrieve score trend: ${error instanceof Error ? error.message : String(error)}`,
        );
      }
    },
  },
];

/**
 * Safely parses a JSON string field from a Salesforce record.
 * Returns the parsed object, or null if the field is empty or invalid.
 */
function parseJsonField(value: unknown): unknown {
  if (typeof value !== "string" || value.length === 0) return null;
  try {
    return JSON.parse(value);
  } catch {
    return null;
  }
}

/**
 * Counts the number of findings in a JSON findings field.
 * The field stores a JSON array of finding objects.
 */
function countFindings(value: unknown): number {
  const parsed = parseJsonField(value);
  if (Array.isArray(parsed)) return parsed.length;
  return 0;
}
