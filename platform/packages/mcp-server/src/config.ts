/**
 * Configuration module for the Elaro MCP server.
 * Reads environment variables for Salesforce authentication and tool filtering.
 */

export interface McpServerConfig {
  /** Salesforce org instance URL (e.g., https://myorg.my.salesforce.com) */
  orgUrl: string | undefined;
  /** OAuth access token for Salesforce REST API */
  accessToken: string | undefined;
  /** SF CLI org alias fallback when direct auth is not configured */
  targetOrg: string | undefined;
  /** Comma-separated allowlist of enabled tool names. Empty means all tools enabled. */
  enabledTools: string[];
  /** Salesforce API version */
  apiVersion: string;
}

/**
 * Loads configuration from environment variables.
 *
 * Authentication priority:
 *   1. ELARO_ORG_URL + ELARO_ACCESS_TOKEN (direct REST API auth)
 *   2. ELARO_TARGET_ORG (sf CLI alias fallback)
 *   3. sf CLI default org (no env vars needed)
 */
export function loadConfig(): McpServerConfig {
  const enabledToolsRaw = process.env["ELARO_MCP_ENABLED_TOOLS"] ?? "";
  const enabledTools = enabledToolsRaw
    .split(",")
    .map((t) => t.trim())
    .filter((t) => t.length > 0);

  return {
    orgUrl: process.env["ELARO_ORG_URL"],
    accessToken: process.env["ELARO_ACCESS_TOKEN"],
    targetOrg: process.env["ELARO_TARGET_ORG"],
    enabledTools,
    apiVersion: process.env["ELARO_API_VERSION"] ?? "v66.0",
  };
}

/**
 * Returns true if direct Salesforce REST API auth is configured.
 */
export function hasDirectAuth(config: McpServerConfig): boolean {
  return config.orgUrl !== undefined && config.accessToken !== undefined;
}

/**
 * Returns true if a specific tool name is enabled (or if no filter is set, all are enabled).
 */
export function isToolEnabled(
  config: McpServerConfig,
  toolName: string,
): boolean {
  if (config.enabledTools.length === 0) return true;
  return config.enabledTools.includes(toolName);
}
