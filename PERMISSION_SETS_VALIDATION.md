# Sentinel Permission Sets Validation

**Generated**: 2025-12-01
**Status**: ✅ **ALL PERMISSION SETS VALIDATED**

---

## Overview

Sentinel includes **3 role-based permission sets** designed for different user personas:
1. **SentinelAdmin** - Full administrative access
2. **SentinelViewer** - Read-only dashboard access
3. **SentinelAuditor** - Evidence export + acknowledgment access

---

## Permission Set Comparison Matrix

| Feature | Admin | Viewer | Auditor | Notes |
|---------|-------|--------|---------|-------|
| **Apex Class Access** | | | | |
| SentinelDriftDetector | ✅ | ❌ | ❌ | Admin only (creates alerts) |
| SentinelComplianceScorer | ✅ | ✅ | ✅ | All users can view scores |
| SentinelEvidenceEngine | ✅ | ❌ | ✅ | Admin + Auditor can export |
| SentinelAIPredictor | ✅ | ❌ | ❌ | Admin only (predictions) |
| SentinelAlertService | ✅ | ✅ | ✅ | All users can view alerts |
| **Alert__c Object Permissions** | | | | |
| Read (allowRead) | ✅ | ✅ | ✅ | All users can read |
| Create (allowCreate) | ✅ | ❌ | ❌ | Admin only |
| Edit (allowEdit) | ✅ | ❌ | ✅ | Admin + Auditor |
| Delete (allowDelete) | ✅ | ❌ | ❌ | Admin only |
| View All Records | ✅ | ✅ | ✅ | All users see all alerts |
| Modify All Records | ✅ | ❌ | ❌ | Admin only |
| **Alert__c Field Permissions** | | | | |
| AlertType__c | Edit | Read | Read | |
| Severity__c | Edit | Read | Read | |
| Title__c | Edit | Read | Read | |
| Description__c | Edit | Read | Read | |
| RecordId__c | Edit | Read | Read | |
| Acknowledged__c | Edit | Read | **Edit** | Auditor can acknowledge |
| AcknowledgedBy__c | Edit | Read | **Edit** | Auditor can acknowledge |
| AcknowledgedAt__c | Edit | Read | **Edit** | Auditor can acknowledge |

---

## 1. SentinelAdmin Permission Set

**File**: `force-app/main/default/permissionsets/SentinelAdmin.permissionset-meta.xml`

### Purpose
Full administrative access for compliance officers and Salesforce administrators who manage the Sentinel platform.

### Capabilities
✅ **Can do everything**:
- Run drift detection scans
- View compliance scores and breakdowns
- Generate evidence packs (SOC2, HIPAA, FedRAMP)
- Make AI predictions on config changes
- Create, read, update, and delete alerts
- Acknowledge alerts
- View all alerts in the org (View All Records)
- Modify all alerts in the org (Modify All Records)

### Apex Classes (5)
- ✅ SentinelDriftDetector
- ✅ SentinelComplianceScorer
- ✅ SentinelEvidenceEngine
- ✅ SentinelAIPredictor
- ✅ SentinelAlertService

### Alert__c Permissions
- ✅ Read, Create, Edit, Delete
- ✅ All 8 fields: Full edit access
- ✅ View All Records: Yes
- ✅ Modify All Records: Yes

### Use Cases
- Compliance Officers setting up Sentinel
- Salesforce Admins configuring drift detection
- Security teams investigating violations
- Platform administrators

---

## 2. SentinelViewer Permission Set

**File**: `force-app/main/default/permissionsets/SentinelViewer.permissionset-meta.xml`

### Purpose
Read-only access for managers, developers, and stakeholders who need visibility into compliance status but shouldn't modify data.

### Capabilities
✅ **Can view**:
- Compliance readiness scores
- Score breakdowns by category
- Active alerts and alert history
- Alert details and severity

❌ **Cannot**:
- Create or delete alerts
- Edit alert fields
- Run drift detection
- Generate evidence packs
- Make AI predictions
- Acknowledge alerts

### Apex Classes (2)
- ✅ SentinelComplianceScorer (read-only scoring)
- ✅ SentinelAlertService (read-only alert viewing)

### Alert__c Permissions
- ✅ Read only
- ❌ Create, Edit, Delete
- ✅ All 8 fields: Read-only
- ✅ View All Records: Yes (can see all alerts)
- ❌ Modify All Records: No

### Use Cases
- Developers monitoring compliance status
- Managers viewing dashboards
- Stakeholders reviewing compliance trends
- Non-admin users needing visibility

---

## 3. SentinelAuditor Permission Set

**File**: `force-app/main/default/permissionsets/SentinelAuditor.permissionset-meta.xml`

### Purpose
Specialized access for external auditors and compliance teams who need to export evidence and acknowledge alerts, but not create or delete data.

### Capabilities
✅ **Can do**:
- View compliance scores
- Generate evidence packs (SOC2, HIPAA, FedRAMP)
- Export user access, roles, permission sets, flows
- View all alerts
- **Acknowledge alerts** (special permission)
- Update Acknowledged__c, AcknowledgedBy__c, AcknowledgedAt__c fields

❌ **Cannot**:
- Create or delete alerts
- Edit core alert fields (type, severity, title, description)
- Run drift detection
- Make AI predictions
- Modify all records

### Apex Classes (3)
- ✅ SentinelComplianceScorer (scoring)
- ✅ SentinelEvidenceEngine (evidence export)
- ✅ SentinelAlertService (alert viewing)

### Alert__c Permissions
- ✅ Read: Yes
- ❌ Create: No
- ✅ Edit: **Yes** (limited to acknowledgment fields only)
- ❌ Delete: No
- ✅ View All Records: Yes
- ❌ Modify All Records: No

### Field-Level Permissions (Smart Design)
**Read-only fields** (5):
- AlertType__c, Severity__c, Title__c, Description__c, RecordId__c

**Editable fields** (3):
- ✅ Acknowledged__c (can mark as acknowledged)
- ✅ AcknowledgedBy__c (auto-populated with their user ID)
- ✅ AcknowledgedAt__c (auto-populated with timestamp)

### Use Cases
- External auditors during SOC2/HIPAA audits
- Compliance consultants reviewing org configuration
- Third-party security assessors
- Internal audit teams that need evidence but shouldn't modify platform

---

## Security Best Practices ✅

### 1. Least Privilege Principle
- ✅ Each permission set grants minimum access needed for role
- ✅ Viewer has no write access
- ✅ Auditor has limited edit (acknowledgment only)
- ✅ Admin has full control

### 2. Field-Level Security
- ✅ All 8 Alert__c fields have explicit permissions
- ✅ Auditor can only edit acknowledgment-related fields
- ✅ Viewer has read-only on all fields

### 3. Object-Level Security
- ✅ CRUD permissions properly set for each role
- ✅ View All Records granted for dashboard visibility
- ✅ Modify All Records only for Admin

### 4. Apex Class Security
- ✅ All classes use `with sharing` keyword
- ✅ FLS/CRUD checks in SentinelEvidenceEngine
- ✅ AuraHandledException for user-friendly errors
- ✅ Only necessary classes exposed to each role

### 5. Separation of Duties
- ✅ Evidence generation separate from alert management
- ✅ Viewers can't modify data they see
- ✅ Auditors can acknowledge but not delete
- ✅ Admins have full control for platform management

---

## Deployment Instructions

### 1. Deploy Permission Sets
```bash
sfdx force:source:deploy -p force-app/main/default/permissionsets -u <target-org>
```

### 2. Assign to Users

**Assign Admin Permission Set**:
```bash
sfdx force:user:permset:assign -n SentinelAdmin -u admin@example.com
```

**Assign Viewer Permission Set**:
```bash
sfdx force:user:permset:assign -n SentinelViewer -u developer@example.com
```

**Assign Auditor Permission Set**:
```bash
sfdx force:user:permset:assign -n SentinelAuditor -u auditor@example.com
```

### 3. Verify Assignments
```bash
sfdx force:user:permset:list -u <target-org>
```

---

## Testing Scenarios

### Test 1: Admin Can Do Everything
1. Assign SentinelAdmin to test user
2. Login as test user
3. ✅ Navigate to Sentinel components (should load)
4. ✅ Create new Alert__c record (should succeed)
5. ✅ Edit alert fields (should succeed)
6. ✅ Delete alert (should succeed)
7. ✅ Run evidence generation (should succeed)

### Test 2: Viewer Is Read-Only
1. Assign SentinelViewer to test user
2. Login as test user
3. ✅ Navigate to Sentinel components (should load)
4. ✅ View alerts (should succeed)
5. ❌ Try to create alert (should fail with permission error)
6. ❌ Try to edit alert (should fail)
7. ❌ Try to delete alert (should fail)

### Test 3: Auditor Can Acknowledge
1. Assign SentinelAuditor to test user
2. Login as test user
3. ✅ Navigate to Sentinel components (should load)
4. ✅ View alerts (should succeed)
5. ✅ Click "Acknowledge" on alert (should succeed)
6. ✅ Verify Acknowledged__c = true, AcknowledgedBy__c = current user
7. ❌ Try to edit Severity__c (should fail)
8. ❌ Try to delete alert (should fail)
9. ✅ Generate evidence pack (should succeed)

---

## Compliance Alignment

### SOC2 Requirements
- ✅ **CC6.1**: Logical access controls restrict access to authorized users
- ✅ **CC6.2**: Access is removed when no longer required
- ✅ **CC6.3**: Role-based access based on job responsibilities

### HIPAA Requirements
- ✅ **164.308(a)(3)**: Workforce security (role-based access)
- ✅ **164.308(a)(4)**: Information access management
- ✅ **164.312(a)(1)**: Unique user identification

### FedRAMP Requirements
- ✅ **AC-2**: Account Management (separate roles)
- ✅ **AC-3**: Access Enforcement (least privilege)
- ✅ **AC-6**: Least Privilege principle

---

## Validation Checklist

- [x] 3 permission sets created (Admin, Viewer, Auditor)
- [x] All 5 Apex classes have correct access per role
- [x] Alert__c object permissions set correctly
- [x] All 8 Alert__c fields have field-level security
- [x] Least privilege principle enforced
- [x] Separation of duties implemented
- [x] View All Records granted for dashboard access
- [x] Modify All Records only for Admin
- [x] Auditor can acknowledge but not delete
- [x] Viewer has no write access
- [x] hasActivationRequired = false (immediate access)
- [x] Descriptive labels and descriptions
- [x] XML syntax valid

---

## Conclusion

✅ **All 3 permission sets are correctly configured** and ready for production deployment.

- **SentinelAdmin**: Full control (5 classes, full CRUD)
- **SentinelViewer**: Read-only (2 classes, no edits)
- **SentinelAuditor**: Evidence + Acknowledge (3 classes, limited edit)

The permission model follows security best practices, SOC2/HIPAA/FedRAMP requirements, and enables proper separation of duties for Sentinel platform users.

---

**Last Updated**: 2025-12-01
**Validated By**: Sentinel Security Team
