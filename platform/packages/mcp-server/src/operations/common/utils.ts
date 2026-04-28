import { z } from "zod";
import type { CallToolResult } from "../../types.js";

/**
 * Wraps data in a successful CallToolResult with JSON-formatted text content.
 *
 * @param data - The data to serialize and return
 * @returns A CallToolResult containing the JSON-serialized data
 */
export function successResponse(data: unknown): CallToolResult {
  return {
    content: [
      {
        type: "text",
        text: JSON.stringify(data, null, 2),
      },
    ],
  };
}

/**
 * Wraps an error message in a CallToolResult with isError: true.
 *
 * @param message - Human-readable error description
 * @returns A CallToolResult flagged as an error
 */
export function errorResponse(message: string): CallToolResult {
  return {
    content: [
      {
        type: "text",
        text: message,
      },
    ],
    isError: true,
  };
}

/**
 * Returns a Zod schema for pagination parameters used across multiple tools.
 * - pageSize: Number of records per page (1-100, default 25)
 * - pageOffset: Zero-based offset for pagination (default 0)
 */
export function paginationSchema() {
  return {
    pageSize: z
      .number()
      .int()
      .min(1)
      .max(100)
      .default(25)
      .describe("Number of records to return per page (1-100, default 25)"),
    pageOffset: z
      .number()
      .int()
      .min(0)
      .default(0)
      .describe("Zero-based offset for pagination (default 0)"),
  };
}

/**
 * Returns a Zod schema for an optional Salesforce record ID parameter.
 *
 * @param name - Human-readable name of the ID field (used in description)
 */
export function optionalIdSchema(name: string) {
  return z
    .string()
    .regex(/^[a-zA-Z0-9]{15,18}$/, `${name} must be a valid 15 or 18 character Salesforce ID`)
    .optional()
    .describe(
      `Optional Salesforce record ID for ${name}. Must be 15 or 18 characters (e.g., "001xx000003GYk1AAG").`,
    );
}

/**
 * Formats an array of Salesforce records into a readable text summary,
 * selecting only the specified fields.
 *
 * @param records - Array of Salesforce record objects
 * @param fields - Array of field API names to include in output
 * @returns A formatted text string with one record per block
 */
export function formatRecords(
  records: Record<string, unknown>[],
  fields: string[],
): string {
  if (records.length === 0) {
    return "No records found.";
  }

  return records
    .map((record, index) => {
      const lines = fields
        .map((field) => {
          const value = getNestedValue(record, field);
          const displayValue = value === null || value === undefined ? "(empty)" : String(value);
          return `  ${field}: ${displayValue}`;
        })
        .join("\n");
      return `Record ${index + 1}:\n${lines}`;
    })
    .join("\n\n");
}

/**
 * Safely retrieves a nested value from an object using dot notation.
 * e.g., getNestedValue(record, "Owner.Name") traverses record.Owner.Name.
 */
function getNestedValue(obj: Record<string, unknown>, path: string): unknown {
  const parts = path.split(".");
  let current: unknown = obj;
  for (const part of parts) {
    if (current === null || current === undefined) return undefined;
    if (typeof current !== "object") return undefined;
    current = (current as Record<string, unknown>)[part];
  }
  return current;
}

/**
 * Builds a SOQL WHERE clause from an array of optional conditions.
 * Filters out undefined/null entries and joins with AND.
 *
 * @param conditions - Array of [fieldExpression, value] tuples. If value is undefined, the condition is skipped.
 * @returns WHERE clause string (including "WHERE") or empty string if no conditions
 */
export function buildWhereClause(
  conditions: Array<[string, string | number | boolean | undefined]>,
): string {
  const clauses: string[] = [];

  for (const [expression, value] of conditions) {
    if (value === undefined || value === null) continue;

    if (typeof value === "string") {
      clauses.push(`${expression} = '${escapeSoql(value)}'`);
    } else {
      clauses.push(`${expression} = ${String(value)}`);
    }
  }

  if (clauses.length === 0) return "";
  return `WHERE ${clauses.join(" AND ")}`;
}

/**
 * Escapes a string value for safe inclusion in a SOQL query.
 * Prevents SOQL injection by escaping single quotes and backslashes.
 */
export function escapeSoql(value: string): string {
  return value.replace(/\\/g, "\\\\").replace(/'/g, "\\'");
}

/**
 * Builds a SOQL LIMIT/OFFSET clause from pagination parameters.
 */
export function buildPaginationClause(pageSize: number, pageOffset: number): string {
  let clause = `LIMIT ${pageSize}`;
  if (pageOffset > 0) {
    clause += ` OFFSET ${pageOffset}`;
  }
  return clause;
}
