# @platform/mcp-server

MCP (Model Context Protocol) server that exposes Elaro compliance data to AI assistants. Queries Salesforce org data and provides structured tools for compliance scoring, findings, frameworks, evidence, vendors, and scan history.

## Setup

### Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `ELARO_ORG_URL` | For direct API | Salesforce org URL (e.g., `https://myorg.my.salesforce.com`) |
| `ELARO_ACCESS_TOKEN` | For direct API | OAuth access token for Salesforce REST API |
| `ELARO_TARGET_ORG` | For CLI fallback | sf CLI org alias (used when direct auth not set) |
| `ELARO_MCP_ENABLED_TOOLS` | No | Comma-separated tool allowlist (empty = all enabled) |
| `ELARO_API_VERSION` | No | Salesforce API version (default: `v66.0`) |

Authentication priority:
1. `ELARO_ORG_URL` + `ELARO_ACCESS_TOKEN` (direct REST API)
2. `ELARO_TARGET_ORG` (sf CLI with specific org)
3. sf CLI default org (no env vars needed)

### Build & Run

```bash
cd platform/packages/mcp-server
npm install
npm run build
npm start
```

### MCP Client Configuration

Add to your MCP client config (e.g., Claude Desktop `claude_desktop_config.json`):

```json
{
  "mcpServers": {
    "elaro": {
      "command": "node",
      "args": ["/path/to/platform/packages/mcp-server/dist/index.js"],
      "env": {
        "ELARO_ORG_URL": "https://your-org.my.salesforce.com",
        "ELARO_ACCESS_TOKEN": "your-access-token"
      }
    }
  }
}
```

## Tool Reference

| Tool | Description |
|------|-------------|
| `get_compliance_scores` | List compliance scores, optionally filtered by framework |
| `get_score_trend` | Score history over time for a specific framework |
| `get_findings` | List compliance findings/gaps with severity, framework, status filters |
| `get_finding_details` | Full details for a single finding by ID |
| `get_frameworks` | List configured compliance frameworks |
| `get_framework_controls` | List controls/requirements for a specific framework |
| `get_evidence` | List evidence items with type and status filters |
| `get_audit_packages` | List audit packages with framework and status filters |
| `get_vendors` | List vendors with risk scores and compliance status |
| `get_vendor_details` | Full details for a single vendor by ID or name |
| `get_scan_history` | Recent compliance scan results |
| `get_scan_details` | Single scan with all step execution details |

## Eval

Run the tool selection evaluation to measure how well tool names and descriptions support natural language queries:

```bash
npm run build
npm run eval
```

This runs 30 test cases and reports tool selection accuracy. Useful for tuning tool descriptions.

## Tool Filtering

To expose only specific tools, set `ELARO_MCP_ENABLED_TOOLS`:

```bash
ELARO_MCP_ENABLED_TOOLS="get_compliance_scores,get_findings,get_vendors" npm start
```

## Architecture

```
src/
├── index.ts              # MCP server entry point (stdio transport)
├── config.ts             # Environment variable configuration
├── types.ts              # Shared TypeScript interfaces
├── sf-query.ts           # Salesforce query helper (REST API + CLI fallback)
├── registry.ts           # Tool registration and filtering
├── operations/
│   ├── common/utils.ts   # Shared response helpers, SOQL builders
│   ├── compliance-scores.ts
│   ├── findings.ts
│   ├── frameworks.ts
│   ├── evidence.ts
│   ├── vendors.ts
│   └── scans.ts
└── eval/
    ├── eval.ts           # Evaluation runner
    └── test-cases.json   # 30 test cases for tool selection eval
```
