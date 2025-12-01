# Sentinel Evidence Generation

**Purpose**: Automate compliance evidence collection for SOC2, HIPAA, and FedRAMP audits
**Time Saved**: 40+ hours per audit quarter
**Status**: ✅ **Configured and Ready**

---

## Overview

The Sentinel Evidence Generator automatically exports Salesforce configuration data into audit-ready CSV files that auditors can review. This replaces the manual process of taking screenshots and copying data from Setup screens.

### What Gets Exported

1. **User Access** - Active users, profiles, roles, last login dates
2. **Role Hierarchy** - Complete role structure and relationships
3. **Permission Sets** - All permission sets and their assignments
4. **Flows** - Active flows and automation triggers
5. **Deployment History** - Recent changes and who made them
6. **Active Alerts** - Current compliance violations detected

---

## Quick Start

### Prerequisites

1. **Salesforce CLI (sfdx) installed**:
   ```bash
   npm install -g sfdx-cli
   ```

2. **Authenticated to your Salesforce org**:
   ```bash
   sfdx auth:web:login -d
   ```

3. **Sentinel deployed to the org**:
   ```bash
   sfdx force:source:push
   ```

4. **SentinelAdmin or SentinelAuditor permission set assigned**:
   ```bash
   sfdx force:user:permset:assign -n SentinelAdmin
   ```

---

## Usage

### Option 1: NPM Scripts (Recommended)

**Generate SOC2 Evidence** (default):
```bash
npm run evidence
```

**Generate HIPAA Evidence**:
```bash
npm run evidence:hipaa
```

**Generate FedRAMP Evidence**:
```bash
npm run evidence:fedramp
```

**Generate SOC2 Evidence** (explicit):
```bash
npm run evidence:soc2
```

### Option 2: Direct Script Execution

**SOC2** (default if no parameter):
```bash
bash scripts/generate-evidence.sh
```

**HIPAA**:
```bash
bash scripts/generate-evidence.sh HIPAA
```

**FedRAMP**:
```bash
bash scripts/generate-evidence.sh FedRAMP
```

---

## What Happens When You Run It

### Step-by-Step Process

1. **Checks Prerequisites**
   - ✅ Verifies SFDX is installed
   - ✅ Verifies you're authenticated to an org
   - ✅ Shows which framework you're generating evidence for

2. **Creates Apex Execution Script**
   - Creates temporary Apex file in `/tmp`
   - Calls `SentinelEvidenceEngine.generateEvidencePack(framework)`

3. **Executes in Salesforce**
   - Runs Apex code using `sfdx force:apex:execute`
   - Queries all relevant metadata
   - Generates CSV files for each category

4. **Outputs Results**
   - Evidence generation summary logged to Apex debug logs
   - CSV data exported to Salesforce Content or Static Resources (depending on implementation)

5. **Cleanup**
   - Removes temporary Apex file
   - Shows success message

### Example Output

```
🔍 Sentinel Evidence Generator
==============================

📊 Framework: SOC2
✅ SFDX authenticated

🚀 Generating evidence pack...

Success: Executed anonymous Apex code
  Evidence Pack Result: SOC2 Evidence Pack Generated Successfully
  - UserAccess: 42 records
  - RoleHierarchy: 18 records
  - PermissionSets: 23 records
  - Flows: 12 records

✅ Evidence pack generation complete!
📁 Check Salesforce Content for downloadable files
```

---

## Understanding the Output Files

### 1. UserAccess.csv

**What it contains**: All active Salesforce users with their access levels

**Columns**:
- UserId
- Username
- Profile
- Role
- IsActive
- LastLogin

**Audit Purpose**: Demonstrates access controls and user lifecycle management (SOC2 CC6.1, CC6.2)

**Example**:
```csv
UserId,Username,Profile,Role,IsActive,LastLogin
005xx000001234,admin@company.com,System Administrator,CEO,true,2025-12-01
005xx000005678,user@company.com,Standard User,Sales Rep,true,2025-11-30
```

### 2. RoleHierarchy.csv

**What it contains**: Complete role hierarchy structure

**Columns**:
- RoleId
- RoleName
- ParentRoleId
- ParentRoleName

**Audit Purpose**: Shows organizational structure and separation of duties (SOC2 CC6.3)

**Example**:
```csv
RoleId,RoleName,ParentRoleId,ParentRoleName
00Exx000001234,CEO,,
00Exx000005678,VP Sales,00Exx000001234,CEO
00Exx000009012,Sales Rep,00Exx000005678,VP Sales
```

### 3. PermissionSets.csv

**What it contains**: All permission sets and their assignments

**Columns**:
- PermissionSetId
- PermissionSetName
- Type
- Description
- AssignedUsers (count)

**Audit Purpose**: Demonstrates least privilege access (SOC2 CC6.3, HIPAA 164.308(a)(3))

**Example**:
```csv
PermissionSetId,PermissionSetName,Type,Description,AssignedUsers
0PSxx000001234,SentinelAdmin,PermissionSet,Full Sentinel access,3
0PSxx000005678,SentinelViewer,PermissionSet,Read-only dashboards,15
```

### 4. Flows.csv

**What it contains**: All active automation (Flows, Process Builder)

**Columns**:
- FlowId
- FlowName
- FlowType
- Status
- LastModifiedDate
- LastModifiedBy

**Audit Purpose**: Shows automation controls and change management (SOC2 CC7.2, CC8.1)

**Example**:
```csv
FlowId,FlowName,FlowType,Status,LastModifiedDate,LastModifiedBy
300xx000001234,Lead_Assignment_Flow,AutoLaunchedFlow,Active,2025-11-15,admin@company.com
300xx000005678,Opportunity_Stage_Change,RecordTriggeredFlow,Active,2025-10-20,admin@company.com
```

---

## How Auditors Use These Files

### SOC2 Audit (Type 2)

**Control**: CC6.1 - Logical and physical access controls restrict access to authorized users

**Evidence Required**: List of all users with access levels

**What to provide**: `UserAccess.csv` + `PermissionSets.csv`

**What auditor checks**:
- ✅ Are all users authorized?
- ✅ Do terminated employees still have access? (IsActive=false check)
- ✅ Are permissions appropriate for job roles?

---

### HIPAA Audit

**Control**: 164.308(a)(4)(i) - Access Management

**Evidence Required**: Role-based access controls

**What to provide**: `RoleHierarchy.csv` + `PermissionSets.csv`

**What auditor checks**:
- ✅ Is access granted based on role?
- ✅ Is there separation of duties?
- ✅ Can users access only what they need?

---

### FedRAMP Audit

**Control**: AC-2 - Account Management

**Evidence Required**: User account inventory and permissions

**What to provide**: All 4 CSVs (UserAccess, RoleHierarchy, PermissionSets, Flows)

**What auditor checks**:
- ✅ Account creation/modification/termination processes
- ✅ Privileged access controls
- ✅ Automated account management

---

## Troubleshooting

### Error: "SFDX is not installed"

**Solution**:
```bash
npm install -g sfdx-cli
```

### Error: "No authenticated orgs found"

**Solution**:
```bash
sfdx auth:web:login -d
```

### Error: "Method does not exist: generateEvidencePack"

**Cause**: Sentinel not deployed to the org

**Solution**:
```bash
sfdx force:source:push
```

### Error: "Insufficient permissions to export user data"

**Cause**: User doesn't have SentinelAdmin or SentinelAuditor permission set

**Solution**:
```bash
sfdx force:user:permset:assign -n SentinelAdmin
```

### Error: "sed: command not found" (Windows)

**Cause**: `sed` command not available on Windows

**Solution**: Install Git Bash or WSL, or use:
```bash
# On Windows (PowerShell)
(Get-Content /tmp/sentinel-evidence.apex) -replace 'FRAMEWORK_PLACEHOLDER', 'SOC2' | Set-Content /tmp/sentinel-evidence.apex
```

---

## Customization

### Add Custom Evidence Categories

Edit `SentinelEvidenceEngine.cls` and add new export methods:

```apex
private static String exportCustomData(String framework) {
    String csvData = 'Column1,Column2\n';

    // Your SOQL query here
    List<SObject> records = [SELECT fields FROM Object__c];

    for (SObject record : records) {
        csvData += record.get('Field1') + ',' + record.get('Field2') + '\n';
    }

    return csvData;
}
```

Then call it from `generateEvidencePack()`:
```apex
evidenceFiles.put('CustomData', exportCustomData(frameworkName));
```

### Change Output Format

Currently outputs to Apex debug logs. To save to Salesforce Files:

```apex
ContentVersion cv = new ContentVersion();
cv.Title = 'SOC2_UserAccess_' + DateTime.now().format('yyyy-MM-dd');
cv.PathOnClient = 'UserAccess.csv';
cv.VersionData = Blob.valueOf(csvData);
cv.IsMajorVersion = true;
insert cv;
```

---

## Integration with CI/CD

### GitHub Actions Example

```yaml
name: Generate Quarterly Evidence
on:
  schedule:
    - cron: '0 0 1 */3 *'  # First day of every quarter

jobs:
  evidence:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - uses: actions/setup-node@v2
      - run: npm install -g sfdx-cli
      - run: echo "${{ secrets.SFDX_AUTH_URL }}" > sfdx_auth
      - run: sfdx auth:sfdxurl:store -f sfdx_auth -d
      - run: npm run evidence:soc2
      - run: npm run evidence:hipaa
```

### Jenkins Pipeline Example

```groovy
pipeline {
    agent any
    triggers {
        cron('0 0 1 */3 *')  // Quarterly
    }
    stages {
        stage('Generate Evidence') {
            steps {
                sh 'npm install -g sfdx-cli'
                sh 'sfdx auth:sfdxurl:store -f $SFDX_AUTH_FILE -d'
                sh 'npm run evidence:soc2'
                sh 'npm run evidence:hipaa'
            }
        }
    }
}
```

---

## Best Practices

### 1. Run Before Each Audit

Generate fresh evidence 1-2 days before auditor arrives:
```bash
npm run evidence:soc2
```

### 2. Quarterly Snapshots

Set up automated quarterly evidence generation to show continuous compliance:
```bash
# Add to crontab
0 0 1 */3 * cd /path/to/sentinel && npm run evidence:soc2
```

### 3. Version Control Evidence

Save generated CSV files in a secure location:
```bash
mkdir -p evidence/$(date +%Y-%m-%d)
# Copy CSVs from Salesforce to evidence folder
```

### 4. Review Before Sharing

Always review exported data before sending to auditors:
- ✅ Verify no sensitive data (SSNs, passwords, etc.)
- ✅ Check data is current (timestamps match)
- ✅ Remove test/sandbox data if production evidence

### 5. Document Your Process

Create a runbook for your audit team:
1. Run `npm run evidence:soc2`
2. Download CSV files from Salesforce Content
3. Review for accuracy
4. Upload to auditor portal
5. Add to evidence package

---

## Security Considerations

### Data Classification

- **PII/PHI**: User emails, names, roles (may contain sensitive info)
- **Confidential**: Permission sets, flows (reveal business logic)
- **Public**: Role hierarchy structure (less sensitive)

### Encryption

Always encrypt evidence files before sharing:
```bash
# Use GPG to encrypt
gpg --encrypt --recipient auditor@example.com UserAccess.csv

# Or use ZIP with password
zip -e evidence.zip *.csv
```

### Access Control

- ✅ Only SentinelAdmin and SentinelAuditor can generate evidence
- ✅ Requires View All Records permission on User, PermissionSet, Flow
- ✅ FLS checks prevent exporting restricted fields
- ✅ Audit trail logs who generated evidence and when

---

## Compliance Validation Checklist

Before sending to auditors:

- [ ] Generated within last 48 hours (current data)
- [ ] All 4 CSV files present (UserAccess, RoleHierarchy, PermissionSets, Flows)
- [ ] No test/demo users in production evidence
- [ ] Terminated employees marked as IsActive=false
- [ ] No placeholder/default passwords visible
- [ ] Files encrypted before transmission
- [ ] Auditor has signed NDA
- [ ] Evidence upload logged in audit trail

---

## Roadmap

### v1.1 (Current)
- ✅ Manual execution via npm script
- ✅ Apex debug log output
- ✅ SOC2, HIPAA, FedRAMP support

### v1.5 (Q2 2026)
- [ ] Automated quarterly generation
- [ ] Save directly to Salesforce Files
- [ ] Email evidence pack to auditors
- [ ] PDF summary report with charts

### v2.0 (Q4 2026)
- [ ] Real-time continuous evidence
- [ ] Integration with GRC platforms (Vanta, Drata, SecureFrame)
- [ ] Evidence validation (detect incomplete/stale data)
- [ ] Auditor self-service portal

---

## Support

**Issues**: Open GitHub issue with "evidence" label
**Documentation**: `/docs/evidence-generation`
**Slack**: #sentinel-support

---

**Last Updated**: 2025-12-01
**Script Version**: 1.0
**Apex API Version**: 63.0
