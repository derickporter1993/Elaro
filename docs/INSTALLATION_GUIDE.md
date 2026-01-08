# Prometheion Installation Guide

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Package Installation](#package-installation)
3. [Permission Set Assignment](#permission-set-assignment)
4. [Named Credentials Setup](#named-credentials-setup)
5. [Custom Metadata Configuration](#custom-metadata-configuration)
6. [Scheduled Jobs Setup](#scheduled-jobs-setup)
7. [Post-Installation Verification](#post-installation-verification)
8. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Salesforce Edition Requirements
Prometheion requires one of the following Salesforce editions:
- Enterprise Edition
- Unlimited Edition
- Performance Edition
- Developer Edition (for testing/development)

### Required Permissions
The installing user must have:
- **System Administrator** profile, OR
- The following permissions:
  - Customize Application
  - Modify All Data
  - Author Apex
  - Manage Named Credentials
  - Schedule Apex Jobs

### Browser Compatibility
Supported browsers for Lightning Experience:
- Google Chrome (latest)
- Mozilla Firefox (latest)
- Microsoft Edge (Chromium-based)
- Safari (latest, macOS only)

### API Version
Prometheion uses API version **63.0**. Ensure your org supports this version.

---

## Package Installation

### Option 1: Production/Sandbox Installation

1. Navigate to the AppExchange listing for Prometheion
2. Click **Get It Now**
3. Select the destination org (Production or Sandbox)
4. Choose **Install for Admins Only** (recommended for initial setup)
5. Click **Install**
6. Wait for the installation email confirmation

### Option 2: Installation via URL

**Production:**
```
https://login.salesforce.com/packaging/installPackage.apexp?p0=<PACKAGE_ID>
```

**Sandbox:**
```
https://test.salesforce.com/packaging/installPackage.apexp?p0=<PACKAGE_ID>
```

### Option 3: SFDX CLI Installation (Dev/CI)

```bash
# Install to default org
sf package install --package <PACKAGE_ID> --wait 20

# Install to specific org
sf package install --package <PACKAGE_ID> --target-org myorg --wait 20

# Check installation status
sf package install report --request-id <REQUEST_ID>
```

### Installation Options
| Option | Recommended For |
|--------|-----------------|
| Install for Admins Only | Initial setup, evaluation |
| Install for All Users | Full deployment after testing |
| Install for Specific Profiles | Phased rollout |

---

## Permission Set Assignment

Prometheion includes four permission sets for different user roles:

### Permission Sets Overview

| Permission Set | Description | Recommended For |
|----------------|-------------|-----------------|
| **Prometheion Admin** | Full read/write access to all objects and features | System Administrators, Compliance Officers |
| **Prometheion Admin Extended** | Admin + additional batch job permissions | Integration administrators |
| **Prometheion User** | Read-only access to compliance data | Business users, stakeholders |
| **Prometheion Auditor** | Read access + report generation | External auditors, reviewers |

### Assigning Permission Sets via Setup

1. Go to **Setup** → **Users** → **Permission Sets**
2. Click on the appropriate permission set (e.g., **Prometheion Admin**)
3. Click **Manage Assignments**
4. Click **Add Assignments**
5. Select the users to assign
6. Click **Assign**

### Assigning Permission Sets via SFDX

```bash
# Assign to a single user
sf org assign permset --name Prometheion_Admin --onbehalfof user@example.com

# Assign to multiple users (comma-separated)
sf org assign permset --name Prometheion_User --onbehalfof user1@example.com,user2@example.com
```

### Minimum Permission Set Requirements

| Role | Required Permission Set |
|------|-------------------------|
| Compliance Administrator | Prometheion Admin |
| Compliance Manager | Prometheion Admin |
| Business User | Prometheion User |
| External Auditor | Prometheion Auditor |
| Integration Service | Prometheion Admin Extended |

---

## Named Credentials Setup

Prometheion uses Named Credentials for secure integration with Slack and Microsoft Teams.

### Slack Webhook Configuration

1. **Create a Slack App:**
   - Go to [https://api.slack.com/apps](https://api.slack.com/apps)
   - Click **Create New App** → **From scratch**
   - Name your app (e.g., "Prometheion Alerts")
   - Select your workspace

2. **Enable Incoming Webhooks:**
   - Navigate to **Features** → **Incoming Webhooks**
   - Toggle **Activate Incoming Webhooks** to On
   - Click **Add New Webhook to Workspace**
   - Select the channel for notifications
   - Click **Allow**
   - Copy the Webhook URL

3. **Update Named Credential in Salesforce:**
   - Go to **Setup** → **Named Credentials** → **Named Credentials**
   - Click on **Slack_Webhook**
   - Click **Edit**
   - Replace `YOUR_WEBHOOK_URL` with your actual webhook URL
   - Click **Save**

### Microsoft Teams Webhook Configuration

1. **Create an Incoming Webhook:**
   - In Microsoft Teams, navigate to the channel for notifications
   - Click **•••** (More options) → **Connectors**
   - Find **Incoming Webhook** and click **Configure**
   - Name your webhook (e.g., "Prometheion Alerts")
   - Click **Create**
   - Copy the Webhook URL

2. **Update Named Credential in Salesforce:**
   - Go to **Setup** → **Named Credentials** → **Named Credentials**
   - Click on **Teams_Webhook**
   - Click **Edit**
   - Replace `YOUR_WEBHOOK_URL` with your actual webhook URL
   - Click **Save**

### Verifying Named Credentials

Test the connections by running in Developer Console:
```apex
// Test Slack
SlackNotifier.notifyAsync('Test message from Prometheion');

// Test Teams
TeamsNotifier.notifyAsync('Test message from Prometheion');
```

---

## Custom Metadata Configuration

### Scheduler Configuration

Prometheion uses Custom Metadata (`Prometheion_Scheduler_Config__mdt`) to manage scheduled job settings. This allows administrators to modify CRON schedules without code changes.

**Navigate to:** Setup → Custom Metadata Types → Prometheion Scheduler Config → Manage Records

### Default Scheduler Configurations

| Scheduler | CRON Expression | Description |
|-----------|-----------------|-------------|
| CCPASLAMonitor | `0 0 8 * * ?` | Daily at 8 AM - Monitors CCPA request deadlines |
| DormantAccountAlert | `0 0 6 * * ?` | Daily at 6 AM - Identifies dormant accounts |
| GLBAAnnualNotice | `0 0 9 1 * ?` | 1st of month at 9 AM - GLBA annual notice reminders |
| ISO27001QuarterlyReview | `0 0 8 1 1,4,7,10 ?` | Quarterly on 1st at 8 AM - ISO 27001 access reviews |
| ISO27001MonthlyPrivileged | `0 0 7 15 * ?` | 15th of month at 7 AM - Privileged access reviews |
| WeeklyScorecard | `0 0 9 ? * MON` | Monday at 9 AM - Weekly compliance scorecard |

### Modifying CRON Schedules

1. Go to **Setup** → **Custom Metadata Types**
2. Find **Prometheion Scheduler Config** and click **Manage Records**
3. Click on the scheduler to modify
4. Update the **CRON Expression** field
5. Click **Save**

**CRON Expression Format:**
```
Seconds Minutes Hours Day_of_Month Month Day_of_Week [Year]
```

**Examples:**
- `0 0 9 * * ?` - Daily at 9:00 AM
- `0 0 9 ? * MON-FRI` - Weekdays at 9:00 AM
- `0 0 8 1 * ?` - 1st of month at 8:00 AM
- `0 0 9 ? * MON` - Every Monday at 9:00 AM

### Compliance Policy Metadata

Prometheion includes pre-configured compliance policies for:
- HIPAA
- SOC 2
- GDPR
- PCI-DSS
- CCPA
- GLBA
- ISO 27001
- NIST
- FedRAMP
- SOX

These can be viewed and customized at:
**Setup** → **Custom Metadata Types** → **Compliance Policy** → **Manage Records**

---

## Scheduled Jobs Setup

### Scheduling Jobs via Apex

Execute the following in Developer Console (**Setup** → **Developer Console** → **Debug** → **Open Execute Anonymous Window**):

```apex
// Schedule all Prometheion jobs
// CCPA SLA Monitor - Daily at 8 AM
System.schedule(
    'Prometheion CCPA SLA Monitor',
    '0 0 8 * * ?',
    new PrometheionCCPASLAMonitorScheduler()
);

// Dormant Account Alert - Daily at 6 AM
System.schedule(
    'Prometheion Dormant Account Alert',
    '0 0 6 * * ?',
    new PrometheionDormantAccountAlertScheduler()
);

// GLBA Annual Notice - 1st of month at 9 AM
System.schedule(
    'Prometheion GLBA Annual Notice',
    '0 0 9 1 * ?',
    new PrometheionGLBAAnnualNoticeScheduler()
);

// ISO 27001 Quarterly Review - Quarterly
System.schedule(
    'Prometheion ISO 27001 Quarterly Review',
    '0 0 8 1 1,4,7,10 ?',
    new PrometheionISO27001QuarterlyScheduler()
);

// Weekly Scorecard - Monday at 9 AM
System.schedule(
    'Prometheion Weekly Scorecard',
    '0 0 9 ? * MON',
    new WeeklyScorecardScheduler()
);
```

### Verifying Scheduled Jobs

1. Go to **Setup** → **Apex Jobs** → **Scheduled Jobs**
2. Verify all Prometheion jobs are listed
3. Check the **Next Scheduled Run** column for expected times

### Managing Scheduled Jobs

**To abort a scheduled job:**
1. Go to **Setup** → **Scheduled Jobs**
2. Click **Del** next to the job to remove

**To reschedule:**
1. Abort the existing job
2. Run the scheduling Apex again with updated CRON expression

---

## Post-Installation Verification

### Verification Checklist

| # | Verification Step | How to Verify |
|---|-------------------|---------------|
| 1 | Package installed | Setup → Installed Packages |
| 2 | Custom objects visible | Setup → Object Manager |
| 3 | Permission sets assigned | Setup → Users → Permission Sets |
| 4 | Named credentials configured | Setup → Named Credentials |
| 5 | Scheduled jobs running | Setup → Scheduled Jobs |
| 6 | App accessible | App Launcher → Prometheion |

### Test the Installation

Run the following in Developer Console to verify core functionality:

```apex
// Test compliance scorer
PrometheionComplianceScorer.ScoreResult result = PrometheionComplianceScorer.calculateReadinessScore();
System.debug('Compliance Score: ' + result.overallScore);
System.debug('Rating: ' + result.rating);

// Test framework engine
List<String> frameworks = PrometheionFrameworkEngine.getSupportedFrameworks();
System.debug('Supported Frameworks: ' + frameworks);
```

### Access the Application

1. Click the **App Launcher** (grid icon)
2. Search for **Prometheion**
3. Click the app to open the compliance dashboard

---

## Troubleshooting

### Common Issues

#### Installation Failed - Missing Dependencies
**Symptom:** Installation fails with dependency errors
**Solution:** Ensure you have the required Salesforce features enabled:
- Platform Events
- Custom Metadata Types
- Named Credentials

#### Named Credential Connection Failed
**Symptom:** Slack/Teams notifications not sending
**Solution:**
1. Verify the webhook URL is correctly entered
2. Check that the URL is accessible from Salesforce
3. Test with a simple HTTP callout:
```apex
Http http = new Http();
HttpRequest req = new HttpRequest();
req.setEndpoint('callout:Slack_Webhook');
req.setMethod('POST');
req.setHeader('Content-Type', 'application/json');
req.setBody('{"text":"Test"}');
HttpResponse res = http.send(req);
System.debug('Status: ' + res.getStatusCode());
```

#### Scheduled Jobs Not Running
**Symptom:** Jobs show as scheduled but don't execute
**Solution:**
1. Check for existing jobs with the same name (duplicates blocked)
2. Verify the user who scheduled has API access
3. Check Apex Job Queue for errors:
   - Setup → Apex Jobs → Apex Job Queue

#### Permission Errors
**Symptom:** Users can't access Prometheion objects/features
**Solution:**
1. Verify permission set assignment
2. Check field-level security
3. Verify user's license type supports custom objects

#### Governor Limit Errors
**Symptom:** Batch jobs failing with limit errors
**Solution:**
1. Reduce batch size in Custom Metadata:
   - Edit `Batch_Size__c` field in scheduler config
2. Check for large data volumes
3. Review debug logs for specific limits hit

### Getting Help

- **Documentation:** See `docs/` folder in package
- **Support:** [support@prometheion.io](mailto:support@prometheion.io)
- **Issues:** [GitHub Issues](https://github.com/prometheion/issues)

---

## Appendix: Object Reference

### Custom Objects Installed

| Object | API Name | Description |
|--------|----------|-------------|
| Audit Package | `Prometheion_Audit_Package__c` | Audit package configurations |
| Framework Mapping | `Prometheion_Framework_Mapping__c` | Compliance framework requirements |
| Evidence Item | `Prometheion_Evidence_Item__c` | Collected compliance evidence |
| Compliance Score | `Compliance_Score__c` | Historical score records |
| Compliance Gap | `Compliance_Gap__c` | Identified compliance gaps |
| Compliance Evidence | `Compliance_Evidence__c` | Evidence attachments |
| CCPA Request | `CCPA_Request__c` | CCPA consumer requests |
| GDPR Erasure Request | `GDPR_Erasure_Request__c` | GDPR erasure requests |
| Privacy Notice | `Privacy_Notice__c` | GLBA privacy notices |
| Integration Error | `Integration_Error__c` | Integration error logs |
| Performance Alert History | `Performance_Alert_History__c` | Governor limit alerts |
| Flow Execution | `Flow_Execution__c` | Flow performance tracking |

### Custom Metadata Types

| Type | API Name | Description |
|------|----------|-------------|
| Scheduler Config | `Prometheion_Scheduler_Config__mdt` | Scheduler CRON expressions |
| Compliance Policy | `Compliance_Policy__mdt` | Compliance framework policies |

---

*Last Updated: January 2026*
*Version: 3.0*
