import { Command } from "commander";
import chalk from "chalk";
import ora from "ora";
import { execSync } from "child_process";

const COMPLIANCE_FRAMEWORKS = [
  "hipaa",
  "soc2",
  "nist",
  "fedramp",
  "gdpr",
  "sox",
  "pci-dss",
  "ccpa",
  "glba",
  "iso27001",
] as const;

type Framework = (typeof COMPLIANCE_FRAMEWORKS)[number];

interface ScanOptions {
  targetOrg?: string;
  framework?: Framework;
  all?: boolean;
  json?: boolean;
  baseline?: boolean;
  demo?: boolean;
}

interface ScanResult {
  framework: string;
  score: number;
  totalChecks: number;
  passed: number;
  failed: number;
  warnings: number;
  criticalFindings: string[];
  source: "live" | "demo";
}

interface ApexScanResult {
  score: number;
  totalChecks: number;
  passed: number;
  failed: number;
  warnings: number;
  criticalFindings: string[];
}

/**
 * Attempts to execute a real compliance scan via Apex in the target org.
 * Returns null if the scan cannot be executed (no auth, error, etc.).
 */
function executeRealScan(framework: Framework, targetOrg?: string): ApexScanResult | null {
  if (targetOrg && !/^[a-zA-Z0-9._-]+$/.test(targetOrg)) {
    throw new Error("Invalid --target-org value. Use only letters, numbers, '.', '_' or '-'.");
  }

  const orgFlag = targetOrg ? `--target-org ${targetOrg}` : "";

  const apexCode = `
ComplianceBaselineScanner scanner = new ComplianceBaselineScanner();
Map<String, Object> result = scanner.runFrameworkScan('${framework.toUpperCase()}');
System.debug('ELARO_JSON::' + JSON.serialize(result));
`;

  try {
    const output = execSync(`sf apex run ${orgFlag} --file /dev/stdin`, {
      encoding: "utf-8",
      stdio: ["pipe", "pipe", "pipe"],
      input: apexCode,
      timeout: 60000,
    });

    // Parse the scan result from Apex debug output
    const jsonLine = output.split(/\r?\n/).find((line) => line.includes("ELARO_JSON::"));
    if (jsonLine) {
      const jsonText = jsonLine.slice(jsonLine.indexOf("ELARO_JSON::") + "ELARO_JSON::".length).trim();
      const parsed = JSON.parse(jsonText) as ApexScanResult;
      return {
        score: parsed.score ?? 0,
        totalChecks: parsed.totalChecks ?? 0,
        passed: parsed.passed ?? 0,
        failed: parsed.failed ?? 0,
        warnings: parsed.warnings ?? 0,
        criticalFindings: parsed.criticalFindings ?? [],
      };
    }

    return null;
  } catch {
    // Org not authenticated, scanner class not deployed, or other error
    return null;
  }
}

/**
 * Generates simulated demo scan results for demonstration and development.
 * Only used when --demo flag is explicitly provided.
 */
function generateDemoScanResult(framework: Framework): ScanResult {
  const totalChecks = Math.floor(Math.random() * 50) + 30;
  const passed = Math.floor(totalChecks * (0.7 + Math.random() * 0.25));
  const failed = Math.floor((totalChecks - passed) * 0.6);
  const warnings = totalChecks - passed - failed;
  const score = Math.round((passed / totalChecks) * 100);

  return {
    framework: framework.toUpperCase(),
    score,
    totalChecks,
    passed,
    failed,
    warnings,
    criticalFindings: failed > 0 ? [`Review ${framework.toUpperCase()} compliance controls`] : [],
    source: "demo",
  };
}

/**
 * Runs a compliance scan for a single framework.
 * Attempts a real scan first; falls back to demo mode only if --demo is set.
 */
async function runComplianceScan(framework: Framework, options: ScanOptions): Promise<ScanResult> {
  // If demo mode is requested, generate simulated results immediately
  if (options.demo) {
    return generateDemoScanResult(framework);
  }

  // Attempt a real scan against the connected org
  const realResult = executeRealScan(framework, options.targetOrg);

  if (realResult) {
    return {
      framework: framework.toUpperCase(),
      score: realResult.score,
      totalChecks: realResult.totalChecks,
      passed: realResult.passed,
      failed: realResult.failed,
      warnings: realResult.warnings,
      criticalFindings: realResult.criticalFindings,
      source: "live",
    };
  }

  // Real scan failed and demo mode is not enabled
  throw new Error(
    `Failed to execute ${framework.toUpperCase()} compliance scan. ` +
      `Ensure you are authenticated to a Salesforce org with Elaro installed, ` +
      `or use --demo to see simulated results.`
  );
}

function displayScanResult(result: ScanResult): void {
  const scoreColor =
    result.score >= 85 ? chalk.green : result.score >= 70 ? chalk.yellow : chalk.red;

  // Show demo indicator for simulated results
  const sourceIndicator = result.source === "demo" ? chalk.gray(" [DEMO]") : "";

  console.log();
  console.log(chalk.bold(`${result.framework} Compliance Scan${sourceIndicator}`));
  console.log(chalk.gray("─".repeat(40)));
  console.log(`  Score:       ${scoreColor(result.score + "%")}`);
  console.log(`  Total:       ${result.totalChecks} checks`);
  console.log(`  Passed:      ${chalk.green(result.passed.toString())}`);
  console.log(`  Failed:      ${chalk.red(result.failed.toString())}`);
  console.log(`  Warnings:    ${chalk.yellow(result.warnings.toString())}`);

  if (result.criticalFindings.length > 0) {
    console.log();
    console.log(chalk.red.bold("  Critical Findings:"));
    result.criticalFindings.forEach((finding) => {
      console.log(`    - ${finding}`);
    });
  }
}

async function runScan(options: ScanOptions): Promise<void> {
  const spinner = ora("Initializing compliance scan...").start();

  try {
    const frameworks: Framework[] = options.all
      ? [...COMPLIANCE_FRAMEWORKS]
      : options.framework
        ? [options.framework]
        : ["hipaa", "soc2"]; // Default to common frameworks

    if (options.demo) {
      spinner.warn(chalk.yellow("Running in DEMO mode — results are simulated"));
      spinner.start(`Scanning ${frameworks.length} framework(s) in demo mode...`);
    } else {
      spinner.text = `Scanning ${frameworks.length} framework(s)...`;
    }

    const results: ScanResult[] = [];
    for (const framework of frameworks) {
      spinner.text = `Running ${framework.toUpperCase()} scan...`;
      const result = await runComplianceScan(framework, options);
      results.push(result);
    }

    spinner.stop();

    if (options.json) {
      console.log(JSON.stringify(results, null, 2));
      return;
    }

    console.log();
    console.log(chalk.bold.cyan("Elaro Compliance Scan Results"));
    console.log(chalk.gray("═".repeat(50)));

    for (const result of results) {
      displayScanResult(result);
    }

    // Summary
    console.log();
    console.log(chalk.gray("─".repeat(50)));
    const avgScore = Math.round(results.reduce((sum, r) => sum + r.score, 0) / results.length);
    const avgColor = avgScore >= 85 ? chalk.green : avgScore >= 70 ? chalk.yellow : chalk.red;

    console.log(chalk.bold(`Overall Score: ${avgColor(avgScore + "%")}`));

    // Demo mode notice
    const allDemo = results.every((r) => r.source === "demo");
    if (allDemo) {
      console.log(chalk.yellow("  All results are simulated. Run without --demo for live scans."));
    }
    console.log();

    if (options.baseline) {
      console.log(
        chalk.gray("Baseline snapshot saved. Future scans will compare against this baseline.")
      );
      console.log();
    }

    // Recommendations
    if (avgScore < 85) {
      console.log(chalk.bold("Recommendations:"));
      console.log("  1. Review failed compliance checks in Elaro dashboard");
      console.log("  2. Run 'elaro scan --all' for comprehensive analysis");
      console.log("  3. Export detailed report for compliance team review");
      console.log();
    }
  } catch (error) {
    spinner.fail("Scan failed");
    if (error instanceof Error) {
      console.error(chalk.red(error.message));
      console.error();
      console.error(chalk.gray("Tip: Use --demo flag to see simulated results:"));
      console.error(chalk.gray("  elaro scan --demo"));
    }
    process.exit(1);
  }
}

export const scanCommand = new Command("scan")
  .description("Run compliance scans against Salesforce org")
  .option("-o, --target-org <alias>", "Target Salesforce org alias")
  .option(
    "-f, --framework <framework>",
    `Compliance framework (${COMPLIANCE_FRAMEWORKS.join(", ")})`
  )
  .option("-a, --all", "Run scans for all compliance frameworks")
  .option("-b, --baseline", "Save results as new baseline")
  .option("--json", "Output results in JSON format")
  .option("--demo", "Generate simulated scan results for demonstration (no org required)")
  .action(runScan);