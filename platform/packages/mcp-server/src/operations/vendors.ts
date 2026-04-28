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
    name: "get_vendors",
    description:
      "List third-party vendors with their risk scores, compliance status, and frameworks. " +
      "Useful for questions like 'List all vendors', 'Show me high-risk vendors', " +
      "'Which vendors are under review?', or 'What vendors handle HIPAA data?'. " +
      "Status values: ACTIVE, UNDER_REVIEW, SUSPENDED, TERMINATED. " +
      "Vendor type values: CLOUD_SERVICE, INTEGRATION, DATA_PROCESSOR, CONSULTING, OTHER.",
    inputSchema: z.object({
      status: z
        .enum(["ACTIVE", "UNDER_REVIEW", "SUSPENDED", "TERMINATED"])
        .optional()
        .describe(
          "Filter by vendor status. Values: ACTIVE, UNDER_REVIEW, SUSPENDED, TERMINATED. Omit for all statuses.",
        ),
      vendorType: z
        .enum(["CLOUD_SERVICE", "INTEGRATION", "DATA_PROCESSOR", "CONSULTING", "OTHER"])
        .optional()
        .describe(
          "Filter by vendor type. Values: CLOUD_SERVICE, INTEGRATION, DATA_PROCESSOR, CONSULTING, OTHER.",
        ),
      ...paginationSchema(),
    }),
    handler: async (params) => {
      try {
        const { status, vendorType, pageSize, pageOffset } = params as {
          status?: string;
          vendorType?: string;
          pageSize: number;
          pageOffset: number;
        };

        const conditions: string[] = [];
        if (status) conditions.push(`Status__c = '${escapeSoql(status)}'`);
        if (vendorType) conditions.push(`Vendor_Type__c = '${escapeSoql(vendorType)}'`);

        const whereClause =
          conditions.length > 0 ? `WHERE ${conditions.join(" AND ")}` : "";

        const soql =
          `SELECT Id, Name, Vendor_Name__c, Vendor_Type__c, Status__c, ` +
          `Risk_Score__c, Compliance_Frameworks__c, ` +
          `Last_Assessment_Date__c, Next_Assessment_Date__c, ` +
          `Data_Processing_Agreement__c, Security_Certifications__c, ` +
          `Contract_Reference__c, Assessment_Notes__c ` +
          `FROM Vendor_Compliance__c ${whereClause} ` +
          `ORDER BY Risk_Score__c DESC NULLS LAST ` +
          buildPaginationClause(pageSize ?? 25, pageOffset ?? 0);

        const result = await querySalesforce(soql);

        const vendors = result.records.map((r) => ({
          id: r["Id"],
          name: r["Name"],
          vendorName: r["Vendor_Name__c"],
          vendorType: r["Vendor_Type__c"],
          status: r["Status__c"],
          riskScore: r["Risk_Score__c"],
          complianceFrameworks: r["Compliance_Frameworks__c"],
          lastAssessmentDate: r["Last_Assessment_Date__c"],
          nextAssessmentDate: r["Next_Assessment_Date__c"],
          dataProcessingAgreement: r["Data_Processing_Agreement__c"],
          securityCertifications: r["Security_Certifications__c"],
          contractReference: r["Contract_Reference__c"],
        }));

        return successResponse({
          totalSize: result.totalSize,
          filters: { status, vendorType },
          records: vendors,
        });
      } catch (error) {
        return errorResponse(
          `Failed to retrieve vendors: ${error instanceof Error ? error.message : String(error)}`,
        );
      }
    },
  },
  {
    name: "get_vendor_details",
    description:
      "Get full details for a single vendor by Salesforce record ID or vendor name. " +
      "Returns all fields including assessment notes, security certifications, " +
      "and data processing agreement status. " +
      "Use this after get_vendors to drill into a specific vendor.",
    inputSchema: z.object({
      vendorId: z
        .string()
        .optional()
        .describe(
          'Salesforce record ID of the Vendor_Compliance__c record. Provide either vendorId or vendorName.',
        ),
      vendorName: z
        .string()
        .optional()
        .describe(
          "Vendor name to search for (exact match on Vendor_Name__c). Provide either vendorId or vendorName.",
        ),
    }),
    handler: async (params) => {
      try {
        const { vendorId, vendorName } = params as {
          vendorId?: string;
          vendorName?: string;
        };

        if (!vendorId && !vendorName) {
          return errorResponse(
            "Either vendorId or vendorName must be provided.",
          );
        }

        let whereClause: string;
        if (vendorId) {
          whereClause = `WHERE Id = '${escapeSoql(vendorId)}'`;
        } else {
          whereClause = `WHERE Vendor_Name__c = '${escapeSoql(vendorName!)}'`;
        }

        const soql =
          `SELECT Id, Name, Vendor_Name__c, Vendor_Type__c, Status__c, ` +
          `Risk_Score__c, Compliance_Frameworks__c, ` +
          `Last_Assessment_Date__c, Next_Assessment_Date__c, ` +
          `Assessment_Notes__c, Contract_Reference__c, ` +
          `Data_Processing_Agreement__c, Security_Certifications__c, ` +
          `CreatedDate, LastModifiedDate ` +
          `FROM Vendor_Compliance__c ${whereClause} ` +
          `LIMIT 1`;

        const result = await querySalesforce(soql);

        if (result.records.length === 0) {
          const identifier = vendorId ?? vendorName;
          return errorResponse(
            `No vendor found matching "${identifier}". Verify the ID or name is correct.`,
          );
        }

        const r = result.records[0]!;

        return successResponse({
          id: r["Id"],
          name: r["Name"],
          vendorName: r["Vendor_Name__c"],
          vendorType: r["Vendor_Type__c"],
          status: r["Status__c"],
          riskScore: r["Risk_Score__c"],
          complianceFrameworks: r["Compliance_Frameworks__c"],
          lastAssessmentDate: r["Last_Assessment_Date__c"],
          nextAssessmentDate: r["Next_Assessment_Date__c"],
          assessmentNotes: r["Assessment_Notes__c"],
          contractReference: r["Contract_Reference__c"],
          dataProcessingAgreement: r["Data_Processing_Agreement__c"],
          securityCertifications: r["Security_Certifications__c"],
          createdDate: r["CreatedDate"],
          lastModifiedDate: r["LastModifiedDate"],
        });
      } catch (error) {
        return errorResponse(
          `Failed to retrieve vendor details: ${error instanceof Error ? error.message : String(error)}`,
        );
      }
    },
  },
];
