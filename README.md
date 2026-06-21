# Elaro

Salesforce compliance automation for regulated organizations.

Elaro is a second-generation managed package project for continuous compliance monitoring,
evidence collection, security review workflows, and AppExchange-ready delivery.

## Current Status

- Main package: `force-app`
- Health Check package: `force-app-healthcheck`
- Salesforce API version: `66.0`
- Node.js: `20.19+`
- npm: `10+`
- Local static validation: passing with documented AppExchange follow-up items
- Org validation: requires a valid Salesforce CLI auth session

## Package Surfaces

| Path                    | Package              | Purpose                                     |
| ----------------------- | -------------------- | ------------------------------------------- |
| `force-app`             | `elaro`              | Main compliance and audit readiness package |
| `force-app-healthcheck` | `Elaro Health Check` | Separate Health Check package surface       |
| `platform`              | Elaro platform tools | TypeScript CLI, Salesforce client, masking  |

Validate both Salesforce package directories independently before release.

## Capabilities

- Compliance scoring and framework-specific controls
- Configuration drift detection
- Audit evidence collection and export
- Trust Center publishing with token-scoped public access
- Security incident tracking and breach workflow support
- Assessment workflows driven by Salesforce metadata
- Salesforce Shield and Event Monitoring integration points
- Multi-channel alert integrations
- Platform tooling for CLI workflows, Salesforce API access, and data masking

## Supported Compliance Areas

- HIPAA
- SOC 2
- PCI-DSS
- GDPR
- CCPA
- GLBA
- ISO 27001
- FINRA
- SEC Cybersecurity
- FedRAMP
- CMMC 2.0
- NIS2
- DORA
- EU AI Act and NIST AI RMF

## Repository Layout

```text
.
├── force-app/                  # Main Salesforce package
├── force-app-healthcheck/      # Health Check package
├── platform/                   # TypeScript platform tooling
├── config/                     # Scratch org definitions
├── docs/                       # Current project documentation
├── examples/                   # Example artifacts
├── manifest/                   # Salesforce manifests
├── scripts/                    # Validation and utility scripts
└── sfdx-project.json           # Salesforce package configuration
```

## Prerequisites

- Salesforce CLI: `sf`
- Node.js `20.19+`
- npm `10+`
- Java runtime for Salesforce Code Analyzer
- Authorized Salesforce org and Dev Hub for deploy, Apex, and package validation

## Setup

```bash
npm ci
```

The root install also prepares the `platform` workspace.

## Local Validation

Run the standard local gate:

```bash
npm run precommit
```

This runs:

- workspace preflight checks
- Prettier format check
- ESLint
- LWC Jest tests

Run production dependency audit:

```bash
npm audit --omit=dev --audit-level=high
```

Validate both Salesforce package directories:

```bash
sf project convert source --root-dir force-app --output-dir /tmp/elaro-main-mdapi
sf project convert source --root-dir force-app-healthcheck --output-dir /tmp/elaro-healthcheck-mdapi
```

Run the local AppExchange static scan:

```bash
sf code-analyzer run \
  --workspace force-app \
  --workspace force-app-healthcheck \
  --rule-selector AppExchange \
  --rule-selector Recommended:Security \
  --output-file /tmp/elaro-code-analyzer.html \
  --output-file /tmp/elaro-code-analyzer.json
```

Run platform workspace checks:

```bash
cd platform
npm run format:check
npm run lint
npm run typecheck
npm run test
npm run build
```

## Org Validation

Org-level validation requires working Salesforce CLI authentication.

```bash
sf org display -o elaro-dev --json
sf package list --target-dev-hub my-prod-org --json
sf project deploy start -o elaro-dev --dry-run --json
sf apex run test -o elaro-dev --test-level RunLocalTests --code-coverage --wait 30 --json
```

Do not treat local validation as final release readiness until deploy validation, Apex tests,
coverage, and package visibility have passed in the target org.

## Security Standards

The project follows AppExchange-oriented Salesforce security rules:

- SOQL uses `WITH USER_MODE`
- DML uses user-mode operations such as `insert as user`
- Apex classes declare an explicit sharing model
- Dynamic SOQL uses bind variables and approved query APIs
- Public Trust Center access is token validated and returns only public-safe records
- Secrets and credentials are configured through Salesforce metadata, not source literals

See [docs/appexchange/preflight-2026-06-20.md](docs/appexchange/preflight-2026-06-20.md)
for the latest local preflight evidence.

## Documentation

- [Documentation Index](docs/README.md)
- [AppExchange Preflight](docs/appexchange/preflight-2026-06-20.md)
- [Sensitive Data Disposition](docs/appexchange/protect-sensitive-data-disposition-2026-06-20.md)
- [Technical Debt Report](docs/techdebt/techdebt-2026-06-20.md)
- [Platform Workspace](platform/README.md)

## GitHub Workflow

The repository CI checks formatting, linting, tests, Salesforce metadata structure, CodeQL,
Code Analyzer, and platform builds. Release branches should be validated through a pull request
before merge.

## License

MIT. See [LICENSE](LICENSE).
