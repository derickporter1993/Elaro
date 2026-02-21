# Elaro

**AI-Powered Compliance & DevOps Platform for Salesforce**

Automated compliance monitoring, audit evidence generation, and DevOps intelligence for regulated organizations.

_Current: v3.0.0 — Spring '26 | API v66.0 | 2GP Managed Package_

<div align="center">

[![Salesforce API](https://img.shields.io/badge/Salesforce-v66.0-blue.svg)](https://developer.salesforce.com)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![CI/CD](https://img.shields.io/badge/CI%2FCD-GitHub%20Actions-success.svg)](.github/workflows)

[Quick Start](#quick-start) | [Architecture](#architecture) | [Documentation](docs/) | [Contributing](CONTRIBUTING.md)

</div>

---

## Overview

Elaro is a **2GP managed package** for Salesforce that automates compliance across 14 regulatory frameworks. It monitors configuration drift, scores compliance posture, generates audit evidence, and provides AI-powered risk analysis — all within your Salesforce org.

### Supported Frameworks

HIPAA | SOC 2 | PCI-DSS | GDPR | CCPA | GLBA | ISO 27001 | FINRA | FedRAMP | CMMC 2.0 | SEC Cybersecurity | NIS2 | DORA | AI Governance (EU AI Act / NIST AI RMF)

### Who It's For

Elaro is built for **regulated organizations running Salesforce**:

- **Healthcare** — HIPAA Privacy/Security Rules, PHI protection, breach notification tracking
- **Financial Services** — SOC 2, PCI-DSS, GLBA, FINRA, SEC Cybersecurity, SOX compliance
- **Government & Defense** — FedRAMP, CMMC 2.0, NIST controls
- **EU-Regulated Organizations** — GDPR, NIS2, DORA, EU AI Act
- **Any Regulated Org** — ISO 27001, CCPA, AI Governance (NIST AI RMF)

### By the Numbers

| Metric                           | Count |
| -------------------------------- | ----- |
| Apex Classes                     | 349   |
| LWC Components                   | 57    |
| Custom Objects & Platform Events | 72    |
| Apex Triggers                    | 5     |
| Permission Sets                  | 8     |
| Compliance Frameworks            | 14    |

---

## Key Capabilities

### Compliance Engine

- **Multi-framework scoring** — Real-time compliance scores across all 14 frameworks
- **Gap analysis** — Identifies control gaps per framework with remediation guidance
- **Audit evidence packs** — Auto-generated, auditor-ready documentation (PDF, CSV, JSON)
- **Compliance Copilot** — Natural language queries against your compliance posture

### Configuration Drift Detection

- **Real-time monitoring** — Platform Events capture permission, sharing, and metadata changes
- **Risk scoring** — Every change scored by compliance impact (Critical/High/Medium/Low)
- **Alert routing** — Slack, Teams, PagerDuty, ServiceNow, email, and mobile push notifications
- **Audit trail correlation** — Links changes to change control tickets

### DevOps Intelligence

- **Governor limit tracking** — CPU, heap, SOQL, DML monitoring with threshold alerts
- **API usage forecasting** — Predicts limit exhaustion before it happens
- **Flow execution monitoring** — Tracks flow runs, faults, and performance
- **Deployment metrics** — Job tracking with test pass/fail analysis

### AI & Reasoning

- **AI risk prediction** — Identifies high-risk changes before they cause violations
- **Change intent analysis** — Explains the compliance impact of configuration changes
- **Reasoning engine** — Traces violation root causes across the compliance graph
- **AI Governance module** — EU AI Act and NIST AI RMF compliance tracking

### Enterprise Features

- **Multi-org management** — Monitor compliance across connected orgs
- **Trust Center** — Public compliance status page for customers
- **Blockchain verification** — Tamper-proof audit evidence
- **Segregation of duties** — Automated SoD conflict detection
- **Data retention enforcement** — Policy-driven record lifecycle management

---

## Quick Start

### Prerequisites

- Salesforce org (Enterprise Edition or higher)
- [Salesforce CLI](https://developer.salesforce.com/tools/salesforcecli) (`sf`) installed
- Node.js 20+ (for local development)

### Deploy to an Org

```bash
git clone https://github.com/derickporter1993/elaro.git
cd elaro
npm install

# Authenticate to your org
sf org login web --alias myorg

# Deploy
sf project deploy start --target-org myorg

# Assign permissions
sf org assign permset --name Elaro_Admin --target-org myorg

# Open
sf org open --target-org myorg
```

### Create a Scratch Org

```bash
sf org create scratch \
  --definition-file config/project-scratch-def.json \
  --duration-days 30 \
  --alias elaro-dev

sf project deploy start --target-org elaro-dev
sf org assign permset --name Elaro_Admin --target-org elaro-dev
sf org open --target-org elaro-dev
```

### Permission Sets

Assign permission sets based on user role:

| Permission Set              | Role                 | Access                                                         |
| --------------------------- | -------------------- | -------------------------------------------------------------- |
| `Elaro_Admin`               | Compliance Admin     | Full read/write access to all Elaro objects, classes, and tabs |
| `Elaro_Admin_Extended`      | Super Admin          | Extended admin capabilities                                    |
| `Elaro_User`                | Compliance User      | Read/execute access to dashboards and reports                  |
| `Elaro_Auditor`             | External Auditor     | Read-only access to compliance data and evidence               |
| `Elaro_SEC_Admin`           | SEC Compliance Lead  | SEC disclosure workflow management                             |
| `Elaro_AI_Governance_Admin` | AI Governance Lead   | AI system registry and classification management               |
| `Elaro_AI_Governance_User`  | AI Governance Viewer | Read access to AI governance data                              |
| `Elaro_Health_Check_Admin`  | HC Admin             | Health Check full access                                       |
| `Elaro_Health_Check_User`   | HC User              | Health Check read/execute access                               |

---

## Architecture

Elaro is structured as two 2GP managed packages with a TypeScript CLI monorepo:

```
elaro/
├── force-app/                          # Main Elaro 2GP (elaro namespace)
│   └── main/default/
│       ├── classes/                    # Apex classes
│       ├── lwc/                        # Lightning Web Components
│       ├── objects/                    # Custom objects & platform events
│       ├── triggers/                   # Apex triggers
│       └── permissionsets/             # Permission sets
├── force-app-healthcheck/              # Health Check 2GP (elaroHC namespace)
│   └── main/default/
│       ├── classes/                    # Health Check Apex
│       └── lwc/                        # Health Check LWC
├── platform/                           # TypeScript monorepo (Turborepo)
│   └── packages/
│       ├── cli/                        # elaro CLI
│       ├── sf-client/                  # Salesforce API client
│       ├── types/                      # Shared types
│       └── masking/                    # Data masking utilities
├── config/                             # Salesforce & PMD config
├── scripts/                            # Automation scripts
└── docs/                               # Documentation
```

### Core Patterns

| Pattern                                              | Purpose                                                                |
| ---------------------------------------------------- | ---------------------------------------------------------------------- |
| **ComplianceServiceFactory** + **IComplianceModule** | Extensible module registration for compliance frameworks               |
| **ElaroLogger**                                      | Structured logging via Platform Events (survives transaction rollback) |
| **ElaroSecurityUtils**                               | Defense-in-depth security utilities                                    |
| **ElaroConstants**                                   | Centralized constants                                                  |
| **ComplianceTestDataFactory**                        | Shared test data factory                                               |
| **Transaction Finalizers**                           | Error logging on all Queueable classes                                 |

### Security Model

- All SOQL: `WITH USER_MODE` (enforces FLS, CRUD, and sharing)
- All DML: `as user`
- Dynamic SOQL: `Database.queryWithBinds()` only
- Controllers: `with sharing`
- Services: `inherited sharing`
- System operations: `without sharing` (documented exceptions only)

### Two-Team Build Structure

| Team                              | Focus                                           | Modules                                                                                                     |
| --------------------------------- | ----------------------------------------------- | ----------------------------------------------------------------------------------------------------------- |
| Team 1 — Sovereign Infrastructure | Backend engine and cross-cutting concerns       | Async Framework, CMMC 2.0, Rule Engine, Orchestration, NIS2/DORA                                            |
| Team 2 — User-Facing Modules      | Dashboards, wizards, and framework-specific UIs | Health Check, Command Center, Event Monitoring, Assessment Wizards, SEC Module, AI Governance, Trust Center |

---

## Development

### Commands

```bash
# Code Quality
npm run fmt              # Format with Prettier
npm run fmt:check        # Check formatting
npm run lint             # ESLint (max 3 warnings)

# Testing
npm run test:unit        # LWC Jest tests
npm run test:unit:watch  # Watch mode
sf apex run test -o <org> -c   # Apex tests with coverage

# Validation
npm run precommit        # fmt:check + lint + test:unit

# Salesforce
sf project deploy start -o <org>             # Deploy
sf project deploy start -o <org> --dry-run   # Validate only

# Security Scan
sf scanner run --pmdconfig config/pmd-ruleset.xml --target force-app --format table

# Platform CLI
cd platform && npm install && npm run build
```

### Test Standards

- **Coverage**: 85%+ per class (Salesforce requires 75% minimum)
- **Assertions**: `Assert` class only — never `System.assertEquals`
- **Naming**: `testMethodName_scenario_expectedResult`
- **Structure**: Arrange/Act/Assert with `Test.startTest()` / `Test.stopTest()`
- **Data**: `@TestSetup` + `ComplianceTestDataFactory` — never rely on org data

### Git Workflow

```
feature/[ticket]-[description]    # Feature branches
bugfix/[ticket]-[description]     # Bug fixes
hotfix/[ticket]-[description]     # Production hotfixes
```

Commit format: `type(scope): description` — e.g., `feat(compliance): add DORA framework module`

---

## Configuration

### Alert Integrations

| Channel             | Setup                                                                                                                                                |
| ------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Slack**           | Named Credential `Slack_Webhook` with your webhook URL. Routes CRITICAL and HIGH severity alerts.                                                    |
| **Microsoft Teams** | Named Credential `Teams_Webhook` with Incoming Webhook URL.                                                                                          |
| **PagerDuty**       | Named Credential `PagerDuty_API` with Events API v2 integration key.                                                                                 |
| **Jira**            | Named Credential `Jira_API` with Jira Cloud URL and API token. Configure `Elaro_Jira_Settings__c`. Register webhook URL (`/jira/webhook/*`) in Jira. |
| **AI (Claude)**     | Named Credential `Elaro_Claude_API` with Anthropic API key. Configure `Elaro_AI_Settings__c`.                                                        |

### Custom Settings

| Setting                  | Description                                                                   |
| ------------------------ | ----------------------------------------------------------------------------- |
| `Elaro_AI_Settings__c`   | AI confidence thresholds, auto-remediation flags, human approval requirements |
| `Elaro_Alert_Config__c`  | Alert routing and severity thresholds                                         |
| `Elaro_Jira_Settings__c` | Jira project key, webhook secret, sync preferences                            |
| `Elaro_Feature_Flags__c` | Per-feature kill switches for subscriber orgs                                 |
| `CCX_Settings__c`        | General platform configuration                                                |

---

## FAQ

**Does Elaro require Shield Platform Encryption?**
No, but Elaro flags missing encryption as a compliance risk. Shield is strongly recommended for HIPAA and PCI-DSS.

**Does Elaro store data outside Salesforce?**
No. All data stays in your Salesforce org. External integrations (Slack, Jira, PagerDuty, Teams, ServiceNow, Claude API) only send alerts or receive webhooks — no compliance data is stored externally.

**Can I use Elaro in a sandbox?**
Yes. Elaro works in Production, Sandbox, Scratch Orgs, and Developer Edition orgs.

**Can I customize compliance scoring?**
Yes. Compliance controls, policies, and actions are driven by Custom Metadata (`Compliance_Control__mdt`, `Compliance_Policy__mdt`, `Compliance_Action__mdt`), which you can configure per org.

**What about the Health Check package?**
Health Check is a separate 2GP managed package (`elaroHC` namespace) that can be installed independently for organizations that only need security posture scanning without full compliance automation.

---

## Documentation

| Category            | Docs                                                                                                                                          |
| ------------------- | --------------------------------------------------------------------------------------------------------------------------------------------- |
| **Getting Started** | [Installation Guide](docs/user/INSTALLATION_GUIDE.md) · [Setup Guide](docs/user/SETUP_GUIDE.md) · [Admin Guide](docs/user/ADMIN_GUIDE.md)     |
| **Architecture**    | [Technical Deep Dive](docs/developer/TECHNICAL_DEEP_DIVE.md) · [Data Flows](docs/developer/DATA_FLOWS.md) · [ADRs](docs/architecture/)        |
| **Development**     | [Contributing](CONTRIBUTING.md) · [API Reference](docs/developer/API_REFERENCE.md) · [External Services](docs/developer/EXTERNAL_SERVICES.md) |
| **Security**        | [Security Review Checklist](docs/security/SECURITY_REVIEW_CHECKLIST.md) · [FLS Audit](docs/security/FLS_AUDIT_REPORT.md)                      |
| **AppExchange**     | [Listing](docs/appexchange/APPEXCHANGE_LISTING.md) · [Security Review](docs/appexchange/SECURITY_REVIEW.md)                                   |
| **Operations**      | [Operations Guide](docs/user/OPERATIONS_GUIDE.md) · [Changelog](docs/CHANGELOG.md) · [Roadmap](docs/ROADMAP.md)                               |

---

## License

MIT License — see [LICENSE](LICENSE) for details.

---

_Elaro — Compliance intelligence for Salesforce._
