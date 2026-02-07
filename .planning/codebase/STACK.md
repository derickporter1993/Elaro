# Technology Stack

## Overview

Elaro is a Salesforce-native compliance and AI governance platform built on Salesforce Platform with extensive Node.js tooling for Lightning Web Components.

## Core Technologies

### Salesforce Platform

- **API Version**: 65.0 (Winter '26)
- **Package**: v3.0 Enterprise (Unlocked Package)
- **Namespace**: None (unmanaged)
- **Scratch Org Definition**: `config/elaro-scratch-def.json`

### Backend (Apex)

- **Language**: Apex (Salesforce proprietary Java-like language)
- **Classes**: 290+ Apex classes
- **Test Classes**: 140 test classes (48% test coverage ratio)
- **Triggers**: 5 Apex triggers
- **Platform Events**: 4 platform events (temporarily excluded from deployment due to org limits)
  - `Performance_Alert__e`
  - `PCI_Access_Event__e`
  - `GLBA_Compliance_Event__e`
  - `Elaro_Alert_Event__e`

### Frontend (Lightning Web Components)

- **Framework**: Lightning Web Components (LWC)
- **JavaScript**: ES6+ with Salesforce-specific decorators
- **Components**: 43 LWC components (80 JS files)
- **Testing**: Jest with `@salesforce/sfdx-lwc-jest`

### Build & Development Tools

- **Node.js**: >= 20.0.0
- **npm**: >= 10.0.0
- **Package Manager**: npm with workspaces
- **Formatter**: Prettier 3.7.4
- **Linter**: ESLint 9.39.2 with LWC plugin
- **Bundler**: Salesforce CLI (sf)

## Development Toolchain

### Code Quality

```json
{
  "eslint": "^9.39.2",
  "prettier": "^3.7.4",
  "@salesforce/eslint-config-lwc": "^4.1.2",
  "@lwc/eslint-plugin-lwc": "^3.3.0"
}
```

### Testing Stack

- **Unit Testing**: Jest 30.2.0 with `@salesforce/sfdx-lwc-jest`
- **Accessibility**: axe-core 4.11.1 with jest-axe
- **Apex Testing**: Native Salesforce testing framework
- **Coverage**: Code coverage reporting for both LWC and Apex

### Scripts (from package.json)

- `npm run fmt` - Format all code with Prettier
- `npm run lint` - Lint JavaScript with ESLint
- `npm run test` - Run Jest unit tests
- `npm run test:unit:coverage` - Run tests with coverage
- `npm run test:a11y` - Accessibility audit
- `npm run sf:deploy` - Deploy to scratch org
- `npm run test:apex` - Run Apex tests

## Salesforce Features Used

### Core Platform

- **Apex Classes**: Service layer, triggers, utilities
- **Lightning Web Components**: UI components with modern JavaScript
- **Platform Events**: Event-driven architecture (temporarily disabled)
- **Big Objects**: `Elaro_Compliance_Graph__b` for historical data
- **Custom Metadata**: `Compliance_Policy__mdt`, `Elaro_AI_Settings__c`
- **Custom Objects**: Evidence items, audit packages, compliance gaps
- **Named Credentials**: External API authentication

### Security Features

- **Shield Platform Encryption**: Field-level encryption
- **Setup Audit Trail**: Configuration change tracking
- **Field History Tracking**: Data audit trails
- **Organization-Wide Defaults (OWD)**: Record-level security

### Automation

- **Queueable Apex**: Asynchronous processing with callouts
- **Schedulable Apex**: Time-based job scheduling
- **@future Methods**: Legacy async processing
- **Batch Apex**: Large data processing (some implementations)
- **Platform Cache**: Session and org-level caching
- **Platform Events**: Real-time event publishing (excluded from deploy)

### AI Integration

- **Einstein Platform**: Risk prediction (TODO - not yet implemented)
- **Claude API Integration**: Natural language processing via Named Credential
- **Custom ML Models**: Compliance scoring algorithms

## Configuration Files

### Salesforce

- `sfdx-project.json` - Project configuration
- `package.xml` - Metadata manifest
- `config/elaro-scratch-def.json` - Scratch org definition
- `.forceignore` - Files excluded from deployment

### Development

- `.eslintrc.json` - ESLint configuration
- `jest.config.js` - Jest test configuration
- `.prettierrc` - Prettier formatting rules
- `.claude/` - Claude Code configuration (GSD)
- `.planning/` - GSD planning documents

## Dependencies

### Production Dependencies

None (Salesforce manages runtime dependencies)

### External Services (via Named Credentials)

- `Elaro_Claude_API` - Anthropic Claude API
- `Slack_Webhook` - Slack notifications
- `Teams_Webhook` - Microsoft Teams notifications
- `Jira_API` - Atlassian Jira integration
- `ServiceNow_API` - ServiceNow integration
- `PagerDuty_API` - PagerDuty incident management

### Development Dependencies

See `package.json` for full list. Key packages:

- `@salesforce/sfdx-lwc-jest` - LWC testing
- `@babel/core` - JavaScript transpilation
- `eslint` - Code linting
- `prettier` - Code formatting

## Architecture Patterns

### Design Patterns

- **Service Layer Pattern**: `ComplianceServiceBase` abstract class
- **Factory Pattern**: `ComplianceServiceFactory`
- **Queueable Pattern**: Async processing with `Database.AllowsCallouts`
- **Trigger Handler Pattern**: Framework-agnostic trigger handling
- **Cache Pattern**: Static caching for expensive queries

### Data Storage

- **Standard Objects**: Account, User, PermissionSet, etc.
- **Custom Objects**: 20+ custom objects for compliance tracking
- **Big Objects**: Compliance graph data for historical analysis
- **Custom Settings**: `Elaro_AI_Settings__c` for org-wide configuration
- **Custom Metadata**: Compliance policies and frameworks

## Version Control

- **Git**: Repository hosted on GitHub
- **Branching**: Feature branches with PR workflow
- **Commits**: Atomic commits enforced by GSD workflow
- **Hooks**: Pre-commit formatting and linting with lint-staged

## Deployment

- **Primary**: Salesforce CLI (sf commands)
- **CI/CD**: GitHub Actions (inferred from scripts)
- **Environments**: Scratch orgs for development, sandboxes for testing
- **Packaging**: Unlocked package for distribution

## Notes

- Platform events are currently excluded from deployment due to org custom object limits
- Einstein Platform integration is planned but not yet implemented
- Node.js tooling is for LWC development only; Apex has no external dependencies
