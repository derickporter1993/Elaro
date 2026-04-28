import { loadConfig, isToolEnabled } from "./config.js";
import type { ToolEntry } from "./types.js";

import { tools as complianceScoreTools } from "./operations/compliance-scores.js";
import { tools as findingsTools } from "./operations/findings.js";
import { tools as frameworkTools } from "./operations/frameworks.js";
import { tools as evidenceTools } from "./operations/evidence.js";
import { tools as vendorTools } from "./operations/vendors.js";
import { tools as scanTools } from "./operations/scans.js";

/**
 * All registered tool entries from all operation modules.
 */
const allTools: ToolEntry[] = [
  ...complianceScoreTools,
  ...findingsTools,
  ...frameworkTools,
  ...evidenceTools,
  ...vendorTools,
  ...scanTools,
];

/**
 * Registers and collects all operations from all modules.
 * Called once during server startup.
 *
 * @returns The complete list of registered ToolEntry objects
 */
export function registerAllOperations(): ToolEntry[] {
  return allTools;
}

/**
 * Returns the list of tools filtered by the ELARO_MCP_ENABLED_TOOLS allowlist.
 * If no allowlist is configured, all tools are returned.
 *
 * @returns Filtered array of ToolEntry objects that are enabled
 */
export function getTools(): ToolEntry[] {
  const config = loadConfig();
  return allTools.filter((tool) => isToolEnabled(config, tool.name));
}

/**
 * Finds a single tool by name from the filtered (enabled) tools list.
 *
 * @param name - The tool name to look up
 * @returns The ToolEntry if found and enabled, or undefined
 */
export function getTool(name: string): ToolEntry | undefined {
  const tools = getTools();
  return tools.find((t) => t.name === name);
}
