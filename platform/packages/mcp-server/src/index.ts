#!/usr/bin/env node

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";
import { getTools, getTool } from "./registry.js";

/**
 * Elaro MCP Server
 *
 * Exposes Elaro compliance data to AI assistants via the Model Context Protocol.
 * Queries Salesforce org data through the REST API or sf CLI fallback.
 *
 * Environment variables:
 *   ELARO_ORG_URL        - Salesforce org instance URL
 *   ELARO_ACCESS_TOKEN   - OAuth access token
 *   ELARO_TARGET_ORG     - sf CLI org alias (fallback)
 *   ELARO_MCP_ENABLED_TOOLS - Comma-separated tool allowlist (empty = all)
 */

const server = new McpServer({
  name: "elaro-mcp",
  version: "0.1.0",
});

// Register all enabled tools with the MCP server
const enabledTools = getTools();

for (const tool of enabledTools) {
  // Extract the shape from the Zod schema for the MCP SDK registration
  const shape = getZodShape(tool.inputSchema);

  server.tool(
    tool.name,
    tool.description,
    shape,
    async (params) => {
      const result = await tool.handler(params as Record<string, unknown>);
      return result;
    },
  );
}

/**
 * Extracts the Zod shape object from a ZodType.
 * The MCP SDK server.tool() method expects a shape object (Record<string, ZodType>)
 * rather than a wrapped z.object(). This function handles that extraction.
 */
function getZodShape(schema: z.ZodType): Record<string, z.ZodType> {
  if (schema instanceof z.ZodObject) {
    return schema.shape as Record<string, z.ZodType>;
  }
  // Fallback: return empty shape for non-object schemas
  return {};
}

/**
 * Starts the MCP server using stdio transport.
 * The server communicates via stdin/stdout following the MCP protocol.
 */
async function main(): Promise<void> {
  const transport = new StdioServerTransport();

  // Log to stderr (not stdout, which is reserved for MCP protocol messages)
  console.error(
    `[elaro-mcp] Starting server with ${enabledTools.length} tools enabled`,
  );

  await server.connect(transport);
}

main().catch((error) => {
  console.error("[elaro-mcp] Fatal error:", error);
  process.exit(1);
});
