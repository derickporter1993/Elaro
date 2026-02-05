# Directory Structure

## Root Layout

```
/Users/derickporter/Elaro/
├── .claude/                          # Claude Code configuration
│   ├── commands/gsd/                 # GSD commands (27 files)
│   ├── agents/                       # GSD agents
│   ├── hooks/                        # GSD hooks
│   └── ...
├── .config/opencode/                 # OpenCode configuration
│   ├── command/                      # GSD commands (27 files)
│   └── ...
├── .planning/                        # GSD planning documents
│   ├── codebase/                     # Codebase documentation
│   │   ├── STACK.md
│   │   ├── INTEGRATIONS.md
│   │   ├── ARCHITECTURE.md
│   │   ├── STRUCTURE.md
│   │   ├── CONVENTIONS.md
│   │   ├── TESTING.md
│   │   └── CONCERNS.md
│   └── config.json                   # GSD configuration
├── .github/                          # GitHub workflows and templates
├── assets/                           # Project assets
├── bin/                              # Utility scripts
├── commands/gsd/                     # GSD command definitions
├── config/                           # Salesforce configuration
│   └── elaro-scratch-def.json        # Scratch org definition
├── docs/                             # Additional documentation
├── force-app/                        # Main source code
│   └── main/default/
│       ├── classes/                  # Apex classes (290 files)
│       ├── lwc/                      # Lightning Web Components (43)
│       ├── triggers/                 # Apex triggers (5)
│       ├── objects/                  # Custom objects
│       ├── layouts/                  # Page layouts
│       ├── permissionsets/           # Permission sets
│       ├── staticresources/          # Static resources
│       └── ...                       # Other metadata
├── scripts/                          # Build and utility scripts
├── .forceignore                      # Deployment exclusions
├── .gitignore                        # Git exclusions
├── package.json                      # Node.js configuration
├── sfdx-project.json                 # Salesforce project config
└── README.md                         # Project readme
```

## Source Code Structure

### Apex Classes (`force-app/main/default/classes/`)

**290 total classes organized by function:**

#### Core Framework (50+ classes)

- `ComplianceServiceBase.cls` - Abstract base class
- `ComplianceServiceFactory.cls` - Service factory
- `ComplianceFrameworkService.cls` - Framework management
- `Elaro*ComplianceService.cls` - Framework-specific services (10 files)

#### Security & Utilities (30+ classes)

- `ElaroSecurityUtils.cls` - Security utilities
- `ElaroConstants.cls` - Constants
- `ElaroGraphIndexer.cls` - Graph indexing
- `ElaroEventProcessor.cls` - Event processing
- `ElaroTestDataFactory.cls` - Test data
- `ComplianceTestDataFactory.cls` - Compliance test data
- `TriggerRecursionGuard.cls` - Recursion guard

#### AI & Copilot (10+ classes)

- `ElaroComplianceCopilot.cls` - Main copilot
- `ElaroComplianceCopilotService.cls` - AI service
- `NaturalLanguageQueryService.cls` - NL queries
- `ElaroAIRiskPredictor.cls` - Risk prediction
- `RootCauseAnalysisEngine.cls` - Root cause analysis

#### Integrations (20+ classes)

- `SlackIntegration.cls` - Slack
- `SlackNotifier.cls` - Slack notifications
- `ElaroSlackNotifierQueueable.cls` - Slack queueable
- `TeamsNotifier.cls` - Teams
- `ElaroTeamsNotifierQueueable.cls` - Teams queueable
- `JiraIntegrationService.cls` - Jira
- `ServiceNowIntegration.cls` - ServiceNow
- `PagerDutyIntegration.cls` - PagerDuty

#### Automation (15+ classes)

- `ElaroAlertQueueable.cls` - Alert processing
- `ElaroDailyDigest.cls` - Daily reports
- `ElaroDeliveryService.cls` - Delivery orchestration
- `ElaroEventProcessor.cls` - Event processing
- `*Scheduler.cls` - Scheduled jobs (5+ files)

#### Mobile & Alerts (10+ classes)

- `MobileAlertPublisher.cls` - Alert publishing
- `MobileAlertEscalator.cls` - Alert escalation
- `MobileAlertCleanup.cls` - Alert cleanup

#### ISO 27001 (10+ classes)

- `ElaroISO27001AccessReviewService.cls` - Access reviews
- `ElaroISO27001QuarterlyScheduler.cls` - Quarterly reviews

#### Test Classes (140 files)

- `*Test.cls` - One test class per production class
- `ElaroTestDataFactory.cls` - Shared test utilities

### Lightning Web Components (`force-app/main/default/lwc/`)

**43 components organized by feature:**

#### Core Components

- `elaroCopilot/` - AI assistant
- `complianceCopilot/` - Alternative copilot
- `elaroDashboard/` - Main dashboard
- `elaroSetupWizard/` - Setup wizard

#### UI Components

- `elaroChart/` - Charts
- `elaroMetricCard/` - Metric displays
- `elaroScoreGauge/` - Score visualization
- `elaroRiskIndicator/` - Risk indicators

#### Feature Components

- `elaroEvidenceViewer/` - Evidence display
- `elaroGapList/` - Gap management
- `elaroAlertPanel/` - Alert display
- `elaroAuditPackage/` - Audit packages

Each component contains:

- `.js` - JavaScript controller
- `.html` - HTML template
- `.css` - Scoped CSS (optional)
- `.js-meta.xml` - Component metadata

### Triggers (`force-app/main/default/triggers/`)

**5 triggers:**

- `ElaroAlertTrigger.trigger` - Alert processing
- `ElaroEventCaptureTrigger.trigger` - Event capture
- `ElaroConsentWithdrawalTrigger.trigger` - GDPR consent
- `ElaroPCIAccessAlertTrigger.trigger` - PCI alerts
- `ElaroAlertTrigger.trigger-meta.xml` - Trigger metadata

### Metadata (`force-app/main/default/`)

#### Objects

- `objects/Compliance_Gap__c/` - Compliance violations
- `objects/Elaro_Evidence_Item__c/` - Audit evidence
- `objects/Elaro_Audit_Package__c/` - Audit packages
- `objects/Integration_Error__c/` - Error tracking
- `objects/Access_Review__c/` - ISO 27001 reviews

#### Layouts

- `layouts/` - Page layouts for all objects

#### Permission Sets

- `permissionsets/` - Granular permissions

#### Static Resources

- `staticresources/` - Images, CSS, JS libraries

#### Named Credentials

- `namedCredentials/` - External API auth
  - `Elaro_Claude_API`
  - `Slack_Webhook`
  - `Teams_Webhook`
  - `Jira_API`
  - `ServiceNow_API`
  - `PagerDuty_API`

#### Custom Metadata

- `customMetadata/` - Policy definitions
  - `Compliance_Policy.*` - Framework policies

#### Custom Settings

- `customSettings/` - Org configuration
  - `Elaro_AI_Settings__c`

#### Big Objects

- `objects/Elaro_Compliance_Graph__b/` - Historical data

## Configuration Files

### Salesforce Configuration

- `sfdx-project.json` - Project configuration
  - Package: `elaro`
  - Version: `3.0.0.NEXT`
  - API Version: `65.0`
- `package.xml` - Metadata manifest

- `config/elaro-scratch-def.json` - Scratch org definition
  - Features, settings, org shape

### Development Configuration

- `.forceignore` - Files excluded from deployment
  - Platform events (temporarily)
  - Test files
  - IDE configs

- `.eslintrc.json` - ESLint rules

- `jest.config.js` - Jest test configuration

- `.prettierrc` - Prettier formatting rules

### Node.js Configuration

- `package.json` - npm configuration
  - Scripts for build/test/deploy
  - Dev dependencies
  - Lint-staged config

## Naming Conventions

### Apex Classes

- **Prefix**: `Elaro` for all custom classes
- **Pattern**: `Elaro[Feature][Type].cls`
- **Examples**:
  - `ElaroSecurityUtils.cls`
  - `ElaroComplianceCopilot.cls`
  - `ElaroGraphIndexer.cls`
  - `ElaroTestDataFactory.cls`

### Test Classes

- **Pattern**: `[ClassName]Test.cls`
- **Examples**:
  - `ElaroSecurityUtilsTest.cls`
  - `ElaroComplianceCopilotTest.cls`

### LWC Components

- **Pattern**: `elaro[ComponentName]` (camelCase)
- **Examples**:
  - `elaroCopilot`
  - `elaroDashboard`
  - `elaroSetupWizard`

### Custom Objects

- **Pattern**: `Elaro_[Object_Name__c]`
- **Examples**:
  - `Elaro_Evidence_Item__c`
  - `Elaro_Audit_Package__c`

### Triggers

- **Pattern**: `Elaro[Object]Trigger.trigger`
- **Examples**:
  - `ElaroAlertTrigger.trigger`
  - `ElaroEventCaptureTrigger.trigger`

## Key File Locations

### Entry Points

- **LWC Entry**: `lwc/elaroDashboard/`
- **Service Entry**: `classes/ElaroComplianceCopilot.cls`
- **Trigger Entry**: `triggers/ElaroAlertTrigger.trigger`

### Configuration

- **Project**: `sfdx-project.json`
- **Settings**: `force-app/main/default/customSettings/`
- **Policies**: `force-app/main/default/customMetadata/`

### Documentation

- **Project**: `README.md`
- **GSD**: `.planning/codebase/`
- **API**: `docs/` (if present)

### Build

- **Package**: `package.json`
- **Deploy**: Scripts in `package.json`
- **Scripts**: `scripts/` directory

## Excluded Files

### From Deployment (`.forceignore`)

- `**/jsconfig.json` - IDE configs
- `**/.eslintrc.json` - Lint configs
- `**/Performance_Alert__e/**` - Platform events (org limits)
- `**/PCI_Access_Event__e/**` - Platform events
- `**/GLBA_Compliance_Event__e/**` - Platform events
- `**/Elaro_Alert_Event__e/**` - Platform events
- `__tests__/` - Test files (handled separately)

### From Git (`.gitignore`)

- `.sfdx/` - Salesforce CLI metadata
- `node_modules/` - npm packages
- `.localdevserver/` - Local dev server
- `.vscode/` - VS Code settings (usually)
- `.idea/` - IntelliJ settings

## File Counts Summary

| Type           | Count | Location            |
| -------------- | ----- | ------------------- |
| Apex Classes   | 290   | `classes/`          |
| Test Classes   | 140   | `classes/`          |
| LWC Components | 43    | `lwc/`              |
| LWC JS Files   | 80    | `lwc/`              |
| Triggers       | 5     | `triggers/`         |
| Total Files    | 1185  | Entire `force-app/` |

## Navigation Tips

### Find By Type

- **Services**: `classes/*Service.cls`
- **Controllers**: `classes/*Controller.cls`
- **Tests**: `classes/*Test.cls`
- **Utils**: `classes/*Utils.cls`
- **Components**: `lwc/*/`

### Find By Feature

- **AI/Copilot**: Search for `Copilot` in class names
- **Integrations**: Search for `Integration`, `Notifier`, `Slack`, `Jira`
- **Security**: `ElaroSecurityUtils`, `ElaroGraphIndexer`
- **Frameworks**: `Elaro*ComplianceService.cls`

### Find By Pattern

- **Abstract Classes**: `ComplianceServiceBase`
- **Queueable**: `*Queueable.cls`
- **Schedulable**: `*Scheduler.cls`
- **Factories**: `ComplianceServiceFactory`
