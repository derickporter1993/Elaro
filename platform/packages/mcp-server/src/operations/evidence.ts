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
    name: "get_evidence",
    description:
      "List compliance evidence items with optional filtering by type and status. " +
      "Evidence items are collected artifacts that prove compliance controls are operating. " +
      "Useful for questions like 'Show me all evidence items', " +
      "'What evidence has been approved?', or 'List all permission set evidence'. " +
      "Type values: SETUP_AUDIT_TRAIL, FIELD_HISTORY, PERMISSION_SET, SHARING_RULE, " +
      "LOGIN_HISTORY, API_USAGE, FLOW_EXECUTION, METADATA_CHANGE, DOCUMENT. " +
      "Status values: COLLECTED, REVIEWED, APPROVED, REJECTED.",
    inputSchema: z.object({
      type: z
        .enum([
          "SETUP_AUDIT_TRAIL",
          "FIELD_HISTORY",
          "PERMISSION_SET",
          "SHARING_RULE",
          "LOGIN_HISTORY",
          "API_USAGE",
          "FLOW_EXECUTION",
          "METADATA_CHANGE",
          "DOCUMENT",
        ])
        .optional()
        .describe(
          "Filter by evidence type. Omit to return all types.",
        ),
      status: z
        .enum(["COLLECTED", "REVIEWED", "APPROVED", "REJECTED"])
        .optional()
        .describe(
          "Filter by evidence status. Values: COLLECTED, REVIEWED, APPROVED, REJECTED. Omit for all statuses.",
        ),
      ...paginationSchema(),
    }),
    handler: async (params) => {
      try {
        const { type, status, pageSize, pageOffset } = params as {
          type?: string;
          status?: string;
          pageSize: number;
          pageOffset: number;
        };

        const conditions: string[] = [];
        if (type) conditions.push(`Evidence_Type__c = '${escapeSoql(type)}'`);
        if (status) conditions.push(`Status__c = '${escapeSoql(status)}'`);

        const whereClause =
          conditions.length > 0 ? `WHERE ${conditions.join(" AND ")}` : "";

        const soql =
          `SELECT Id, Name, Evidence_Type__c, Evidence_Date__c, Description__c, ` +
          `Status__c, File_Reference__c, Audit_Package__c, ` +
          `Framework_Mapping__c, Reviewed_Date__c, ` +
          `CreatedDate, LastModifiedDate ` +
          `FROM Elaro_Evidence_Item__c ${whereClause} ` +
          `ORDER BY Evidence_Date__c DESC ` +
          buildPaginationClause(pageSize ?? 25, pageOffset ?? 0);

        const result = await querySalesforce(soql);

        const evidence = result.records.map((r) => ({
          id: r["Id"],
          name: r["Name"],
          evidenceType: r["Evidence_Type__c"],
          evidenceDate: r["Evidence_Date__c"],
          description: r["Description__c"],
          status: r["Status__c"],
          fileReference: r["File_Reference__c"],
          auditPackageId: r["Audit_Package__c"],
          frameworkMappingId: r["Framework_Mapping__c"],
          reviewedDate: r["Reviewed_Date__c"],
          createdDate: r["CreatedDate"],
          lastModifiedDate: r["LastModifiedDate"],
        }));

        return successResponse({
          totalSize: result.totalSize,
          filters: { type, status },
          records: evidence,
        });
      } catch (error) {
        return errorResponse(
          `Failed to retrieve evidence items: ${error instanceof Error ? error.message : String(error)}`,
        );
      }
    },
  },
  {
    name: "get_audit_packages",
    description:
      "List audit packages that bundle evidence for compliance audits. " +
      "Each audit package covers a specific framework and time period. " +
      "Useful for questions like 'Show me all audit packages', " +
      "'What SOC2 audit packages exist?', or 'List completed audit packages'. " +
      "Status values: DRAFT, IN_PROGRESS, COMPLETED, ARCHIVED. " +
      "Framework values: SOX, SOC2, HIPAA, GDPR, CCPA, GLBA, NIST, ISO27001, PCI_DSS.",
    inputSchema: z.object({
      framework: z
        .string()
        .optional()
        .describe("Filter by compliance framework (e.g., 'SOC2', 'HIPAA'). Omit for all frameworks."),
      status: z
        .enum(["DRAFT", "IN_PROGRESS", "COMPLETED", "ARCHIVED"])
        .optional()
        .describe(
          "Filter by audit package status. Values: DRAFT, IN_PROGRESS, COMPLETED, ARCHIVED. Omit for all statuses.",
        ),
      ...paginationSchema(),
    }),
    handler: async (params) => {
      try {
        const { framework, status, pageSize, pageOffset } = params as {
          framework?: string;
          status?: string;
          pageSize: number;
          pageOffset: number;
        };

        const conditions: string[] = [];
        if (framework) conditions.push(`Framework__c = '${escapeSoql(framework)}'`);
        if (status) conditions.push(`Status__c = '${escapeSoql(status)}'`);

        const whereClause =
          conditions.length > 0 ? `WHERE ${conditions.join(" AND ")}` : "";

        const soql =
          `SELECT Id, Name, Package_Name__c, Framework__c, Status__c, ` +
          `Audit_Period_Start__c, Audit_Period_End__c, Description__c, ` +
          `CreatedDate, LastModifiedDate ` +
          `FROM Elaro_Audit_Package__c ${whereClause} ` +
          `ORDER BY Audit_Period_End__c DESC ` +
          buildPaginationClause(pageSize ?? 25, pageOffset ?? 0);

        const result = await querySalesforce(soql);

        const packages = result.records.map((r) => ({
          id: r["Id"],
          name: r["Name"],
          packageName: r["Package_Name__c"],
          framework: r["Framework__c"],
          status: r["Status__c"],
          auditPeriodStart: r["Audit_Period_Start__c"],
          auditPeriodEnd: r["Audit_Period_End__c"],
          description: r["Description__c"],
          createdDate: r["CreatedDate"],
          lastModifiedDate: r["LastModifiedDate"],
        }));

        return successResponse({
          totalSize: result.totalSize,
          filters: { framework, status },
          records: packages,
        });
      } catch (error) {
        return errorResponse(
          `Failed to retrieve audit packages: ${error instanceof Error ? error.message : String(error)}`,
        );
      }
    },
  },
];
