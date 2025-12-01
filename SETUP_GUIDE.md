# Sentinel Setup Guide

**Target Audience**: Salesforce Administrators, Compliance Officers, IT Managers
**Time to Complete**: 30-45 minutes
**Skill Level**: Intermediate Salesforce Administration

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Installation Methods](#installation-methods)
3. [Step-by-Step Deployment](#step-by-step-deployment)
4. [Configuration](#configuration)
5. [User Access Setup](#user-access-setup)
6. [Verification & Testing](#verification--testing)
7. [Troubleshooting](#troubleshooting)
8. [Next Steps](#next-steps)

---

## Prerequisites

### Required Access

- ✅ **Salesforce System Administrator** profile or equivalent
- ✅ **Modify All Data** permission (for deployment)
- ✅ **Author Apex** permission (for test execution)
- ✅ **Customize Application** permission (for object/field creation)

### Required Tools

**Option A: Salesforce CLI (Recommended)**
```bash
# Install Salesforce CLI
npm install -g @salesforce/cli

# Verify installation
sf --version
```

**Option B: Salesforce DX (Legacy)**
```bash
npm install -g sfdx-cli
sfdx --version
```

**Option C: Change Sets** (no CLI required)
- Use Salesforce Setup UI to deploy via Change Sets
- Requires sandbox org for testing first

### System Requirements

- **Salesforce Edition**: Enterprise, Unlimited, or Developer Edition
- **API Version**: 63.0 or higher
- **Node.js**: 18.x or higher (for CLI installation)
- **Git**: 2.x or higher (for source control deployment)

---

## Installation Methods

Choose the method that fits your organization:

| Method | Best For | Time Required | Technical Level |
|--------|----------|---------------|-----------------|
| **Scratch Org** | Testing/Demo | 15 min | Intermediate |
| **Sandbox** | Pre-Production | 30 min | Intermediate |
| **Production** | Live Deployment | 45 min | Advanced |
| **Change Set** | No CLI Access | 60 min | Intermediate |

---

## Step-by-Step Deployment

### Method 1: Deploy to Scratch Org (Testing)

**Use case**: Quick demo, feature testing, development

```bash
# 1. Clone the repository
git clone https://github.com/derickporter1993/Ops-Gurdian.git
cd Ops-Gurdian

# 2. Create scratch org
sf org create scratch \
  --definition-file config/project-scratch-def.json \
  --alias sentinel-demo \
  --set-default

# 3. Push source code
sf project deploy start --target-org sentinel-demo

# 4. Assign permission set to yourself
sf org assign permset --name SentinelAdmin

# 5. Open the org
sf org open
```

**Total time**: ~15 minutes

---

### Method 2: Deploy to Sandbox (Recommended)

**Use case**: Pre-production testing before deploying to production

```bash
# 1. Clone the repository
git clone https://github.com/derickporter1993/Ops-Gurdian.git
cd Ops-Gurdian

# 2. Authenticate to your sandbox
sf org login web --alias sentinel-sandbox --instance-url https://test.salesforce.com

# 3. Deploy source code
sf project deploy start \
  --target-org sentinel-sandbox \
  --wait 15

# 4. Run test suite (verify 75%+ coverage)
sf apex run test \
  --test-level RunLocalTests \
  --code-coverage \
  --result-format human \
  --wait 10 \
  --target-org sentinel-sandbox

# 5. Verify deployment
sf apex get test --test-run-id <test-run-id> --code-coverage
```

**Total time**: ~30 minutes

---

### Method 3: Deploy to Production (Go-Live)

**Use case**: Final production deployment

⚠️ **CRITICAL**: Always test in sandbox first!

```bash
# 1. Authenticate to production
sf org login web --alias sentinel-prod --instance-url https://login.salesforce.com

# 2. Run validation deploy (doesn't actually deploy, just validates)
sf project deploy start \
  --target-org sentinel-prod \
  --test-level RunLocalTests \
  --dry-run \
  --wait 15

# 3. Review validation results
# Check for:
# - 0 code coverage failures
# - 0 test failures
# - 75%+ overall coverage

# 4. Deploy to production (if validation passes)
sf project deploy start \
  --target-org sentinel-prod \
  --test-level RunLocalTests \
  --wait 20

# 5. Monitor deployment
sf project deploy report --target-org sentinel-prod
```

**Total time**: ~45 minutes

---

### Method 4: Deploy via Change Set (No CLI)

**Use case**: Organizations without CLI access or Salesforce DX enabled

1. **In Sandbox (Source Org)**:
   - Setup → Outbound Change Sets → New
   - Name: "Sentinel Compliance Platform"
   - Add Components:
     - Apex Classes (all Sentinel* classes and tests)
     - Custom Object: Alert__c (with all fields)
     - Permission Sets (3): SentinelAdmin, SentinelViewer, SentinelAuditor
     - Lightning Web Components: sentinelReadinessScore, sentinelDriftPanel
   - Upload

2. **In Production (Target Org)**:
   - Setup → Inbound Change Sets
   - Click "Deploy" on Sentinel change set
   - Select "Run Specified Tests" → Add all Sentinel*Test classes
   - Deploy

**Total time**: ~60 minutes

---

## Configuration

### 1. Create Custom Settings (Optional)

**Purpose**: Store baseline timestamps for drift detection

```apex
// In Developer Console, execute this anonymous Apex:
SentinelConfiguration__c config = new SentinelConfiguration__c(
    Name = 'Default',
    LastBaselineScan__c = DateTime.now(),
    DriftDetectionEnabled__c = true,
    AlertThreshold__c = 'HIGH'
);
insert config;
```

### 2. Configure Sharing Rules

**Purpose**: Control who sees which alerts

Setup → Sharing Settings → Alert__c:
- **Default Internal Access**: Private
- **Sharing Rule**: "All Admins See All Alerts"
  - Owned by: All Internal Users
  - Share with: Role → CEO (and subordinates)
  - Access Level: Read/Write

### 3. Create Sample Alert Data (Optional)

**Purpose**: Test dashboards with realistic data

```apex
// In Developer Console, execute this:
List<Alert__c> sampleAlerts = new List<Alert__c>();

sampleAlerts.add(new Alert__c(
    Title__c = 'Admin Permission Set Assigned',
    Description__c = 'System Admin permission set assigned to Sales Rep',
    AlertType__c = 'PERMISSION_DRIFT',
    Severity__c = 'HIGH',
    RecordId__c = '005xx000001234',
    Acknowledged__c = false
));

sampleAlerts.add(new Alert__c(
    Title__c = 'Flow Modified Without Review',
    Description__c = 'Lead Assignment flow changed outside of release window',
    AlertType__c = 'FLOW_DRIFT',
    Severity__c = 'MEDIUM',
    RecordId__c = '300xx000005678',
    Acknowledged__c = false
));

insert sampleAlerts;
```

---

## User Access Setup

### Step 1: Assign Permission Sets

**For Compliance Officers** (full access):
```bash
sf org assign permset --name SentinelAdmin --target-org <org-alias> --username admin@example.com
```

**For Managers/Developers** (read-only):
```bash
sf org assign permset --name SentinelViewer --target-org <org-alias> --username manager@example.com
```

**For External Auditors** (evidence export):
```bash
sf org assign permset --name SentinelAuditor --target-org <org-alias> --username auditor@example.com
```

### Step 2: Create User Groups (Optional)

Setup → Public Groups → New:
- **Name**: Sentinel Compliance Team
- **Members**: Add all users who need access
- **Use**: Share dashboards and reports with this group

### Step 3: Add to App Launcher

Setup → App Manager → New Lightning App:
- **App Name**: Sentinel Compliance
- **Add Items**:
  - Alert__c tab
  - sentinelReadinessScore component (Home page)
  - sentinelDriftPanel component (Alert page)

---

## Verification & Testing

### Test 1: Verify Apex Classes Deployed

Setup → Apex Classes → Search "Sentinel"

**Expected**: 10 classes (5 main + 5 test)
- ✅ SentinelDriftDetector
- ✅ SentinelDriftDetectorTest
- ✅ SentinelComplianceScorer
- ✅ SentinelComplianceScorerTest
- ✅ SentinelEvidenceEngine
- ✅ SentinelEvidenceEngineTest
- ✅ SentinelAIPredictor
- ✅ SentinelAIPredictorTest
- ✅ SentinelAlertService
- ✅ SentinelAlertServiceTest

### Test 2: Verify Custom Object

Setup → Object Manager → Alert__c

**Expected**:
- ✅ 8 custom fields
- ✅ Auto-number Name field (ALERT-{0000})
- ✅ Feed tracking enabled
- ✅ History tracking enabled

### Test 3: Run Test Suite

```bash
sf apex run test \
  --test-level RunLocalTests \
  --code-coverage \
  --result-format human \
  --wait 10
```

**Expected**:
- ✅ 44 test methods pass
- ✅ 0 test failures
- ✅ 75%+ code coverage on all classes

### Test 4: Verify Permission Sets

Setup → Permission Sets

**Expected**: 3 permission sets
- ✅ SentinelAdmin (5 Apex classes, full CRUD on Alert__c)
- ✅ SentinelViewer (2 Apex classes, read-only)
- ✅ SentinelAuditor (3 Apex classes, limited edit)

### Test 5: Test Components in UI

1. **Navigate to App Launcher** → Search "Sentinel" (if you created custom app)
2. **Test Readiness Score Component**:
   - Should display 0-100 score
   - Should show 4 category breakdowns
   - Refresh button should work
3. **Test Drift Panel Component**:
   - Should display active alerts
   - Click "Acknowledge" → should work
   - Severity colors should display correctly

### Test 6: Generate Evidence Pack

```bash
npm run evidence:soc2
```

**Expected**:
```
🔍 Sentinel Evidence Generator
==============================
📊 Framework: SOC2
✅ SFDX authenticated
🚀 Generating evidence pack...
✅ Evidence pack generation complete!
```

---

## Troubleshooting

### Problem: Deployment Fails with "Code Coverage Failure"

**Error**: "Test coverage of selected Apex Trigger is 0%, at least 1% test coverage is required"

**Solution**:
```bash
# Run tests explicitly before deployment
sf apex run test --test-level RunLocalTests --wait 10

# Then deploy with tests
sf project deploy start --test-level RunLocalTests --wait 15
```

---

### Problem: "Method does not exist or incorrect signature"

**Error**: "Method does not exist or incorrect signature: void calculateReadinessScore()"

**Cause**: Version mismatch or incomplete deployment

**Solution**:
```bash
# Force redeploy all metadata
sf project deploy start --metadata-dir force-app --wait 15
```

---

### Problem: Permission Set Assignment Fails

**Error**: "This permission set couldn't be assigned because it contains a field or object permission for Alert__c"

**Cause**: Alert__c object not deployed yet

**Solution**: Deploy in 2 stages:
```bash
# Stage 1: Deploy object first
sf project deploy start --metadata-dir force-app/main/default/objects --wait 10

# Stage 2: Deploy everything else
sf project deploy start --wait 15
```

---

### Problem: Lightning Components Don't Show Up

**Error**: Component not visible in App Builder or Home page

**Cause**: Components not exposed as targets

**Solution**: Add to component `.js-meta.xml`:
```xml
<targets>
    <target>lightning__AppPage</target>
    <target>lightning__HomePage</target>
</targets>
```

---

### Problem: Tests Pass Locally but Fail in Production

**Error**: "System.QueryException: List has no rows for assignment"

**Cause**: Test is querying production data instead of test data

**Solution**: Ensure tests use `@testSetup` and don't rely on existing data:
```apex
@testSetup
static void setup() {
    // Create test data here
}
```

---

## Next Steps

### Immediate (Day 1)

1. ✅ **Verify deployment** - All tests pass, no errors
2. ✅ **Assign permission sets** - Give users appropriate access
3. ✅ **Create sample alerts** - Test UI with realistic data
4. ✅ **Train admin team** - Walk through features and workflows

### Short Term (Week 1)

1. **Customize for your org**:
   - Update restricted permission set list in `SentinelDriftDetector`
   - Configure baseline scan frequency
   - Set up email alerts (future feature)

2. **Integrate with monitoring**:
   - Add Sentinel score to executive dashboard
   - Create reports on Alert__c object
   - Set up Slack/Teams notifications (custom)

3. **Establish processes**:
   - Weekly drift detection scans
   - Alert acknowledgment workflow
   - Quarterly evidence generation

### Medium Term (Month 1)

1. **Pilot with small team** (5-10 users)
2. **Collect feedback** on UI and workflows
3. **Tune alert thresholds** to reduce noise
4. **Document custom procedures** for your org
5. **Run first audit** with generated evidence

### Long Term (Quarter 1)

1. **Roll out org-wide** (all users)
2. **Submit to AppExchange** (if desired)
3. **Integrate AI predictions** (Einstein)
4. **Connect to GRC tools** (Vanta, Drata, etc.)
5. **Achieve SOC2 certification** using Sentinel evidence

---

## Training Resources

### For Admins

- **Setup Guide**: This document
- **Architecture Overview**: See README.md
- **API Documentation**: `/docs/apex-reference`
- **Video Tutorial**: (coming soon)

### For End Users

- **User Guide**: `/docs/user-guide.md`
- **Evidence Generation**: `EVIDENCE_GENERATION.md`
- **FAQ**: `/docs/faq.md`
- **Support**: sentinel-support@example.com

---

## Support & Maintenance

### Regular Maintenance Tasks

**Weekly**:
- Review active alerts
- Acknowledge false positives
- Run drift detection scans

**Monthly**:
- Review compliance score trends
- Update restricted permission set list
- Audit user access

**Quarterly**:
- Generate evidence packs for auditors
- Review test coverage after updates
- Update Sentinel to latest version

### Getting Help

**Documentation**: Check `/docs` folder first
**Issues**: Open GitHub issue with logs
**Community**: Join Salesforce Trailblazer Community
**Commercial Support**: Contact sentinel-support@example.com

---

## Security Recommendations

1. **Limit Admin Access**:
   - Only 2-3 users should have SentinelAdmin
   - Use SentinelViewer for most users
   - Create separate permission set for read-only executives

2. **Enable Field History Tracking**:
   - Track all changes to Alert__c
   - Set up field history report for compliance

3. **Review Permissions Quarterly**:
   - Remove permission sets from terminated users
   - Verify no unauthorized SentinelAdmin assignments

4. **Secure Evidence Files**:
   - Encrypt before sending to auditors
   - Store in Salesforce Content (not shared drives)
   - Delete after audit complete (retention policy)

---

## Compliance Checklist

Before your first audit:

- [ ] All Apex classes deployed and passing tests (75%+)
- [ ] Alert__c object created with all 8 fields
- [ ] 3 permission sets deployed and assigned correctly
- [ ] Evidence generation tested successfully
- [ ] Compliance score displayed on dashboard
- [ ] Drift detection ran at least once
- [ ] Sample alerts created and acknowledged
- [ ] User access documented (who has what permission)
- [ ] Baseline scan timestamp recorded
- [ ] Audit trail enabled on Alert__c object

---

## Appendix A: Metadata Overview

### Apex Classes (5)
1. **SentinelDriftDetector** - Detects unauthorized config changes
2. **SentinelComplianceScorer** - Calculates 0-100 compliance score
3. **SentinelEvidenceEngine** - Exports audit evidence
4. **SentinelAIPredictor** - Predicts compliance violations
5. **SentinelAlertService** - Manages alert lifecycle

### Custom Objects (1)
1. **Alert__c** - Stores compliance alerts (8 fields)

### Permission Sets (3)
1. **SentinelAdmin** - Full access (compliance officers)
2. **SentinelViewer** - Read-only (managers, developers)
3. **SentinelAuditor** - Evidence export (external auditors)

### Lightning Web Components (2)
1. **sentinelReadinessScore** - Compliance score gauge
2. **sentinelDriftPanel** - Active alerts dashboard

---

## Appendix B: Package Contents

```
force-app/main/default/
├── classes/
│   ├── SentinelDriftDetector.cls
│   ├── SentinelDriftDetectorTest.cls
│   ├── SentinelComplianceScorer.cls
│   ├── SentinelComplianceScorerTest.cls
│   ├── SentinelEvidenceEngine.cls
│   ├── SentinelEvidenceEngineTest.cls
│   ├── SentinelAIPredictor.cls
│   ├── SentinelAIPredictorTest.cls
│   ├── SentinelAlertService.cls
│   └── SentinelAlertServiceTest.cls
├── objects/
│   └── Alert__c/
│       ├── Alert__c.object-meta.xml
│       └── fields/
│           ├── AlertType__c.field-meta.xml
│           ├── Severity__c.field-meta.xml
│           ├── Title__c.field-meta.xml
│           ├── Description__c.field-meta.xml
│           ├── RecordId__c.field-meta.xml
│           ├── Acknowledged__c.field-meta.xml
│           ├── AcknowledgedBy__c.field-meta.xml
│           └── AcknowledgedAt__c.field-meta.xml
├── permissionsets/
│   ├── SentinelAdmin.permissionset-meta.xml
│   ├── SentinelViewer.permissionset-meta.xml
│   └── SentinelAuditor.permissionset-meta.xml
└── lwc/
    ├── sentinelReadinessScore/
    │   ├── sentinelReadinessScore.html
    │   ├── sentinelReadinessScore.js
    │   └── sentinelReadinessScore.js-meta.xml
    └── sentinelDriftPanel/
        ├── sentinelDriftPanel.html
        ├── sentinelDriftPanel.js
        └── sentinelDriftPanel.js-meta.xml
```

---

**Document Version**: 1.0
**Last Updated**: 2025-12-01
**Salesforce API**: 63.0
**Support**: sentinel-support@example.com
