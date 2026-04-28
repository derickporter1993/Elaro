import { z } from "zod";

/**
 * Represents a single tool that can be registered with the MCP server.
 * Each tool has a name, description (optimized for LLM consumption),
 * a Zod schema for input validation, and an async handler function.
 */
export interface ToolEntry {
  name: string;
  description: string;
  inputSchema: z.ZodType;
  handler: (params: Record<string, unknown>) => Promise<CallToolResult>;
}

/**
 * The result returned from a tool invocation, following the MCP protocol
 * content structure. Each result contains one or more text content blocks.
 * The index signature is required for compatibility with the MCP SDK's Result base type.
 */
export interface CallToolResult {
  content: Array<{ type: "text"; text: string }>;
  isError?: boolean;
  [key: string]: unknown;
}

/**
 * Represents the JSON response from a Salesforce REST API SOQL query.
 * Includes pagination support via nextRecordsUrl.
 */
export interface SalesforceQueryResult {
  totalSize: number;
  done: boolean;
  nextRecordsUrl?: string;
  records: Record<string, unknown>[];
}
