import { readFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";
import { getTools } from "../registry.js";

/**
 * Evaluation framework for the Elaro MCP server.
 *
 * Loads test cases from test-cases.json and evaluates how well a tool selection
 * algorithm would perform. For each test case, it compares the expected tool
 * and parameters against what a simple keyword-based selector would choose.
 *
 * This provides a baseline for measuring tool description quality — better
 * descriptions lead to better LLM tool selection in production.
 */

interface TestCase {
  query: string;
  expectedTool: string;
  expectedParams: Record<string, unknown>;
}

interface EvalResult {
  query: string;
  expectedTool: string;
  selectedTool: string | null;
  toolMatch: boolean;
  paramMatch: boolean;
  expectedParams: Record<string, unknown>;
  matchedParams: Record<string, unknown>;
}

/**
 * Simple keyword-based tool selector that simulates how an LLM might match
 * a natural language query to a tool. This is intentionally naive — the real
 * selection happens in the LLM, but this helps validate tool naming and descriptions.
 */
function selectTool(query: string): { tool: string | null; params: Record<string, unknown> } {
  const tools = getTools();
  const lowerQuery = query.toLowerCase();

  // Score each tool based on keyword matches in name and description
  let bestTool: string | null = null;
  let bestScore = 0;

  for (const tool of tools) {
    let score = 0;
    const nameWords = tool.name.split("_");
    const descWords = tool.description.toLowerCase().split(/\s+/);

    // Name word matches (weighted higher)
    for (const word of nameWords) {
      if (lowerQuery.includes(word)) score += 3;
    }

    // Description keyword matches
    for (const word of lowerQuery.split(/\s+/)) {
      if (word.length > 3 && descWords.includes(word)) score += 1;
    }

    // Boost for specific patterns
    if (lowerQuery.includes("trend") && tool.name.includes("trend")) score += 10;
    if (lowerQuery.includes("detail") && tool.name.includes("details")) score += 10;
    if (lowerQuery.includes("score") && tool.name.includes("score")) score += 5;
    if (lowerQuery.includes("finding") && tool.name.includes("finding")) score += 5;
    if (lowerQuery.includes("gap") && tool.name.includes("finding")) score += 5;
    if (lowerQuery.includes("vendor") && tool.name.includes("vendor")) score += 5;
    if (lowerQuery.includes("evidence") && tool.name.includes("evidence")) score += 5;
    if (lowerQuery.includes("audit") && tool.name.includes("audit")) score += 5;
    if (lowerQuery.includes("scan") && tool.name.includes("scan")) score += 5;
    if (lowerQuery.includes("framework") && tool.name.includes("framework")) score += 5;
    if (lowerQuery.includes("control") && tool.name.includes("control")) score += 5;
    if (lowerQuery.includes("history") && tool.name.includes("history")) score += 5;

    if (score > bestScore) {
      bestScore = score;
      bestTool = tool.name;
    }
  }

  // Extract basic params from query
  const params = extractParams(lowerQuery);

  return { tool: bestTool, params };
}

/**
 * Extracts common parameter values from a natural language query.
 */
function extractParams(query: string): Record<string, unknown> {
  const params: Record<string, unknown> = {};

  // Framework detection
  const frameworks = [
    "SOC2", "HIPAA", "GDPR", "CCPA", "GLBA", "ISO27001",
    "PCI_DSS", "NIST", "FINRA", "FedRAMP", "CMMC", "SOX",
  ];
  for (const fw of frameworks) {
    if (query.toLowerCase().includes(fw.toLowerCase())) {
      params["framework"] = fw;
      break;
    }
  }

  // Severity detection
  const severities = ["CRITICAL", "HIGH", "MEDIUM", "LOW"];
  for (const sev of severities) {
    if (query.toLowerCase().includes(sev.toLowerCase())) {
      params["severity"] = sev;
      break;
    }
  }

  // Status detection
  const statuses = [
    "OPEN", "IN_PROGRESS", "REMEDIATED", "VERIFIED", "ACCEPTED_RISK",
    "ACTIVE", "UNDER_REVIEW", "SUSPENDED", "TERMINATED",
    "DRAFT", "COMPLETED", "ARCHIVED",
    "PENDING", "RUNNING", "FAILED",
  ];
  for (const st of statuses) {
    if (query.toLowerCase().includes(st.toLowerCase().replace(/_/g, " "))) {
      params["status"] = st;
      break;
    }
  }

  // Days detection
  const daysMatch = query.match(/(\d+)\s*days?/);
  if (daysMatch) {
    params["days"] = parseInt(daysMatch[1]!, 10);
  }

  return params;
}

/**
 * Compares expected params against matched params, returning true if
 * all expected param keys have matching values.
 */
function compareParams(
  expected: Record<string, unknown>,
  matched: Record<string, unknown>,
): boolean {
  for (const [key, value] of Object.entries(expected)) {
    if (matched[key] !== value) return false;
  }
  return true;
}

async function runEval(): Promise<void> {
  const currentDir = dirname(fileURLToPath(import.meta.url));
  const testCasesPath = join(currentDir, "test-cases.json");

  let testCases: TestCase[];
  try {
    const content = await readFile(testCasesPath, "utf-8");
    testCases = JSON.parse(content) as TestCase[];
  } catch (error) {
    console.error(
      `Failed to load test cases from ${testCasesPath}:`,
      error instanceof Error ? error.message : error,
    );
    process.exit(1);
  }

  console.log(`\n  Elaro MCP Server — Tool Selection Evaluation`);
  console.log(`  ${"=".repeat(50)}`);
  console.log(`  Test cases: ${testCases.length}`);
  console.log(`  Available tools: ${getTools().length}\n`);

  const results: EvalResult[] = [];

  for (const testCase of testCases) {
    const { tool: selectedTool, params: matchedParams } = selectTool(testCase.query);
    const toolMatch = selectedTool === testCase.expectedTool;
    const paramMatch = compareParams(testCase.expectedParams, matchedParams);

    results.push({
      query: testCase.query,
      expectedTool: testCase.expectedTool,
      selectedTool,
      toolMatch,
      paramMatch,
      expectedParams: testCase.expectedParams,
      matchedParams,
    });
  }

  // Print results table
  console.log(
    `  ${"#".padEnd(3)} ${"Query".padEnd(50)} ${"Tool".padEnd(7)} ${"Params".padEnd(7)}`,
  );
  console.log(`  ${"-".repeat(3)} ${"-".repeat(50)} ${"-".repeat(7)} ${"-".repeat(7)}`);

  for (let i = 0; i < results.length; i++) {
    const r = results[i]!;
    const queryTrunc =
      r.query.length > 48 ? r.query.substring(0, 48) + ".." : r.query;
    const toolIcon = r.toolMatch ? "PASS" : "FAIL";
    const paramIcon = r.paramMatch ? "PASS" : "FAIL";
    console.log(
      `  ${String(i + 1).padEnd(3)} ${queryTrunc.padEnd(50)} ${toolIcon.padEnd(7)} ${paramIcon.padEnd(7)}`,
    );

    if (!r.toolMatch) {
      console.log(
        `      Expected: ${r.expectedTool}, Got: ${r.selectedTool ?? "(none)"}`,
      );
    }
  }

  // Summary
  const toolCorrect = results.filter((r) => r.toolMatch).length;
  const paramCorrect = results.filter((r) => r.paramMatch).length;
  const fullCorrect = results.filter((r) => r.toolMatch && r.paramMatch).length;

  console.log(`\n  ${"=".repeat(50)}`);
  console.log(`  Tool accuracy:  ${toolCorrect}/${results.length} (${((toolCorrect / results.length) * 100).toFixed(1)}%)`);
  console.log(`  Param accuracy: ${paramCorrect}/${results.length} (${((paramCorrect / results.length) * 100).toFixed(1)}%)`);
  console.log(`  Full accuracy:  ${fullCorrect}/${results.length} (${((fullCorrect / results.length) * 100).toFixed(1)}%)`);
  console.log();
}

runEval().catch((error) => {
  console.error("Eval failed:", error);
  process.exit(1);
});
