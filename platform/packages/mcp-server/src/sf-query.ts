import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { loadConfig, hasDirectAuth } from "./config.js";
import type { SalesforceQueryResult } from "./types.js";

const execFileAsync = promisify(execFile);

/**
 * Executes a SOQL query against Salesforce and returns all records,
 * automatically handling pagination via nextRecordsUrl.
 *
 * Authentication strategy:
 *   1. If ELARO_ORG_URL + ELARO_ACCESS_TOKEN are set, uses direct REST API calls.
 *   2. Otherwise falls back to `sf data query` CLI (uses ELARO_TARGET_ORG or default org).
 *
 * @param soql - The SOQL query string to execute
 * @returns Aggregated query result with all records across pages
 */
export async function querySalesforce(
  soql: string,
): Promise<SalesforceQueryResult> {
  const config = loadConfig();

  if (hasDirectAuth(config)) {
    return queryViaRestApi(soql, config.orgUrl!, config.accessToken!, config.apiVersion);
  }

  return queryViaCli(soql, config.targetOrg);
}

/**
 * Queries Salesforce using the REST API directly. Handles pagination
 * by following nextRecordsUrl until all records are retrieved.
 */
async function queryViaRestApi(
  soql: string,
  orgUrl: string,
  accessToken: string,
  apiVersion: string,
): Promise<SalesforceQueryResult> {
  const baseUrl = orgUrl.replace(/\/+$/, "");
  const queryUrl = `${baseUrl}/services/data/${apiVersion}/query/?q=${encodeURIComponent(soql)}`;

  let result = await fetchQuery(queryUrl, accessToken);
  const allRecords = [...result.records];

  while (!result.done && result.nextRecordsUrl) {
    const nextUrl = `${baseUrl}${result.nextRecordsUrl}`;
    result = await fetchQuery(nextUrl, accessToken);
    allRecords.push(...result.records);
  }

  return {
    totalSize: allRecords.length,
    done: true,
    records: allRecords,
  };
}

/**
 * Makes a single authenticated GET request to a Salesforce query endpoint.
 */
async function fetchQuery(
  url: string,
  accessToken: string,
): Promise<SalesforceQueryResult> {
  const response = await fetch(url, {
    method: "GET",
    headers: {
      Authorization: `Bearer ${accessToken}`,
      "Content-Type": "application/json",
      Accept: "application/json",
    },
  });

  if (!response.ok) {
    const errorBody = await response.text();
    throw new Error(
      `Salesforce query failed (${response.status} ${response.statusText}): ${errorBody}`,
    );
  }

  return (await response.json()) as SalesforceQueryResult;
}

/**
 * Queries Salesforce via the `sf` CLI. Uses the target org alias if provided,
 * otherwise uses the CLI default org.
 */
async function queryViaCli(
  soql: string,
  targetOrg?: string,
): Promise<SalesforceQueryResult> {
  const args = ["data", "query", "--query", soql, "--json"];

  if (targetOrg) {
    args.push("--target-org", targetOrg);
  }

  try {
    const { stdout } = await execFileAsync("sf", args, {
      maxBuffer: 10 * 1024 * 1024, // 10MB buffer for large result sets
      timeout: 120_000, // 2 minute timeout
    });

    const parsed = JSON.parse(stdout) as {
      status: number;
      result: { totalSize: number; done: boolean; records: Record<string, unknown>[] };
    };

    if (parsed.status !== 0) {
      throw new Error(`sf CLI query returned non-zero status: ${parsed.status}`);
    }

    return {
      totalSize: parsed.result.totalSize,
      done: parsed.result.done,
      records: parsed.result.records,
    };
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    throw new Error(
      `Salesforce CLI query failed. Ensure 'sf' is installed and an org is authorized. Details: ${message}`,
    );
  }
}
