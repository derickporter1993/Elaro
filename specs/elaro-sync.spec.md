# Elaro Sync Module Specification

> **Status**: DRAFT
> **Version**: 1.0
> **Author**: Claude Code (Sentinel Mode)
> **Date**: 2026-02-05

---

## Executive Summary

Elaro Sync integrates Prometheion's DevOps data synchronization capabilities into the existing Elaro compliance platform, creating a unified governance solution that provides **compliant sandbox refresh with data masking**.

**Single Value Prop**: Safe, fast sandbox refresh from production with automatic PII/PHI masking - the feature Salesforce native refresh doesn't provide.

---

## Strategic Rationale

### Why Combine (Not Separate Products)

| Factor | Combined (Chosen) | Separate |
|--------|-------------------|----------|
| AppExchange reviews | 1 | 2 |
| Codebase maintenance | 1 | 2 |
| Sales motion | "Elaro with DevOps" | "Which product?" |
| Shared infrastructure | Direct reuse | Duplicate or import |
| Customer confusion | None | High |

### Existing Elaro Components → Sync Reuse

| Elaro Component | Sync Usage |
|-----------------|------------|
| `ElaroSecurityUtils` | CRUD/FLS for sync operations |
| `ElaroPCIDataMaskingService` | Data masking engine foundation |
| `Elaro_Audit_Log__c` | Sync audit trail |
| `ElaroComplianceScorer` | Pre-sync compliance validation |
| `ComplianceServiceFactory` | Pattern for Sync service creation |
| HIPAA/SOC2/GDPR services | Masking rule derivation |

---

## Module Architecture

### Architectural Position

```
Elaro (Compliance Platform)
├── Core (existing - unchanged)
│   ├── Compliance Scoring
│   ├── Audit Trail
│   ├── Framework Engine (HIPAA, SOC2, GDPR, etc.)
│   ├── Security Utils
│   └── AI Copilot
│
└── Sync Module (NEW - Prometheion integrated)
    ├── Connection Manager (org OAuth)
    ├── Compatibility Analyzer (pre-sync checks)
    ├── Sync Engine (extract → transform → load)
    ├── Masking Engine (extends existing)
    ├── Checkpoint Manager (resume capability)
    └── Limits Dashboard (governor limit tracking)
```

### Naming Convention

All new classes use `ElaroSync*` prefix to:
- Maintain Elaro naming consistency
- Clearly identify sync module components
- Avoid confusion with existing `Elaro*` classes

---

## Core Components

### 1. Connection Manager

**Purpose**: Manage OAuth connections to source/target orgs.

**Classes**:
- `ElaroSyncConnectionService` - OAuth flow handling
- `ElaroSyncConnectionController` - LWC controller

**Custom Objects**:
- `Elaro_Sync_Connection__c` - Stores org connection metadata
  - `Instance_URL__c` (URL)
  - `Org_Type__c` (Picklist: Production, Sandbox, Scratch, Developer)
  - `Is_Source__c` (Boolean)
  - `Last_Connected__c` (DateTime)
  - `Health_Status__c` (Picklist: Connected, Expired, Error)

**Security**:
- OAuth tokens stored in External Credentials (never in custom objects)
- Connection metadata is non-sensitive

### 2. Compatibility Analyzer

**Purpose**: Pre-sync validation to prevent "sync breaks everything" disasters.

**Classes**:
- `ElaroSyncCompatibilityService` - Main analyzer service
- `ElaroSyncRecordTypeAnalyzer` - Record Type comparison
- `ElaroSyncPicklistAnalyzer` - Picklist value validation
- `ElaroSyncFieldAnalyzer` - Field existence/type checks
- `ElaroSyncOwnerAnalyzer` - User availability checks

**Custom Objects**:
- `Elaro_Sync_Compatibility_Issue__c` - Stores found issues
  - `Issue_Type__c` (Picklist: RecordType, Picklist, Field, Owner, Currency)
  - `Severity__c` (Picklist: Fatal, Error, Warning, Info)
  - `Object_Name__c` (Text)
  - `Field_Name__c` (Text)
  - `Source_Value__c` (Text)
  - `Remediation__c` (Long Text)
  - `Is_Auto_Resolvable__c` (Boolean)

**Analysis Output**:
```apex
public class CompatibilityResult {
    public Integer fatalCount;
    public Integer errorCount;
    public Integer warningCount;
    public List<CompatibilityIssue> issues;
    public Boolean canProceed; // fatalCount == 0
}
```

### 3. Sync Engine

**Purpose**: Orchestrate extract → transform → load with checkpoint support.

**Classes**:
- `ElaroSyncEngine` - Main orchestrator (Queueable chain)
- `ElaroSyncExtractor` - Bulk API 2.0 extraction
- `ElaroSyncTransformer` - Masking + field mapping
- `ElaroSyncLoader` - Multi-pass loading with deferred references
- `ElaroSyncCheckpointService` - Progress tracking + resume

**Custom Objects**:
- `Elaro_Sync_Job__c` - Job tracking
  - `Status__c` (Picklist: Pending, Compatibility, Extracting, Transforming, Loading, Verifying, Completed, Failed, Cancelled)
  - `Source_Org__c` (Lookup: Elaro_Sync_Connection__c)
  - `Target_Org__c` (Lookup: Elaro_Sync_Connection__c)
  - `Total_Records__c` (Number)
  - `Processed_Records__c` (Number)
  - `Error_Count__c` (Number)
  - `Started_At__c` (DateTime)
  - `Completed_At__c` (DateTime)

- `Elaro_Sync_Checkpoint__c` - Resume points
  - `Job__c` (Lookup: Elaro_Sync_Job__c)
  - `SObject_Name__c` (Text)
  - `Phase__c` (Picklist: Extract, Transform, LoadPass1, LoadPass2, LoadPass3, Verify)
  - `Total_Records__c` (Number)
  - `Processed_Records__c` (Number)
  - `Last_Record_Id__c` (Text)
  - `State_JSON__c` (Long Text)

- `Elaro_Sync_Error__c` - Error tracking with remediation
  - `Job__c` (Lookup: Elaro_Sync_Job__c)
  - `Error_Code__c` (Text) - e.g., SCHEMA_PICKLIST_001
  - `Category__c` (Picklist: Auth, Schema, Data, Limits, Network, System, Automation)
  - `Severity__c` (Picklist: Info, Warning, Error, Fatal)
  - `SObject_Name__c` (Text)
  - `Field_Name__c` (Text)
  - `Occurrence_Count__c` (Number)
  - `Sample_Record_Ids__c` (Long Text)
  - `Remediation__c` (Long Text)
  - `Is_Resolved__c` (Boolean)

**Sync Phases**:
1. **Extract**: Bulk API 2.0 from source org
2. **Transform**: Apply masking rules + field mapping
3. **Load Pass 1**: Insert records without self-references
4. **Load Pass 2**: Update deferred self-references
5. **Load Pass 3**: Verify referential integrity
6. **Verify**: Spot-check data integrity

### 4. Masking Engine

**Purpose**: Extend existing `ElaroPCIDataMaskingService` with sync-specific masking.

**Classes**:
- `ElaroSyncMaskingService` - Sync-specific masking orchestrator
- `ElaroSyncMaskingStrategy` - Interface for masking strategies
- `ElaroSyncFakeMasker` - Deterministic fake data (names, emails)
- `ElaroSyncHashMasker` - One-way cryptographic hash
- `ElaroSyncRedactMasker` - Full data removal

**Custom Metadata**:
- `Elaro_Sync_Masking_Rule__mdt` - Pre-configured masking rules
  - `SObject_API_Name__c` (Text)
  - `Field_API_Name__c` (Text)
  - `Strategy__c` (Picklist: Fake, Hash, Redact, Preserve)
  - `Compliance_Framework__c` (Text) - HIPAA, SOC2, GDPR, PCI-DSS
  - `Is_Active__c` (Checkbox)

**HIPAA Default Rules** (pre-configured):
- `Contact.Email` → Fake
- `Contact.Phone` → Fake
- `Contact.Birthdate` → Redact
- `Account.BillingAddress` → Fake
- Custom PHI fields detected by naming convention (`*_PHI__c`, `*_SSN__c`)

### 5. Limits Dashboard

**Purpose**: Show org governor limits before and after sync impact.

**Classes**:
- `ElaroSyncLimitsService` - Query org limits API
- `ElaroSyncLimitsController` - LWC controller

**Displayed Metrics**:
- API calls (REST, Bulk)
- Data storage (used/available)
- File storage
- Streaming API events
- **Projected impact** of planned sync

### 6. LWC Components

**New Components** (in `force-app/main/default/lwc/`):

| Component | Purpose |
|-----------|---------|
| `elaroSyncDashboard` | Main sync module entry point |
| `elaroSyncConnectionWizard` | OAuth connection setup |
| `elaroSyncCompatibilityReport` | Display compatibility issues |
| `elaroSyncJobProgress` | Real-time job progress |
| `elaroSyncErrorDisplay` | Error list with remediation |
| `elaroSyncMaskingConfig` | Configure masking rules |
| `elaroSyncLimitsPanel` | Org limits visualization |
| `elaroSyncPlanReview` | Pre-execution plan review |

---

## Error Taxonomy

Adopt Prometheion's error catalog (25+ error codes) for consistent user experience:

### Error Code Categories

| Prefix | Category | Example |
|--------|----------|---------|
| `SCHEMA_` | Schema mismatches | `SCHEMA_PICKLIST_001` |
| `DATA_` | Data quality | `DATA_VALIDATION_RULE_001` |
| `LIMITS_` | Governor limits | `LIMITS_API_DAILY_001` |
| `AUTH_` | Authentication | `AUTH_TOKEN_EXPIRED` |
| `AUTOMATION_` | Trigger/Flow failures | `AUTOMATION_TRIGGER_FAILURE` |
| `NETWORK_` | Connectivity | `NETWORK_TIMEOUT` |
| `SYSTEM_` | Internal errors | `SYSTEM_INTERNAL_ERROR` |

Each error includes:
- Human-readable title
- Detailed description
- Remediation steps (actionable)
- `canRetry` flag
- `autoResolvable` flag

---

## Security Model

### Permission Sets

**Elaro_Sync_Admin** (extends Elaro_Admin):
- Full CRUD on all `Elaro_Sync_*__c` objects
- Access to `ElaroSyncConnectionService`
- Access to `ElaroSyncEngine`
- Can configure masking rules

**Elaro_Sync_User** (extends Elaro_User):
- Read on `Elaro_Sync_Job__c`
- Read on `Elaro_Sync_Error__c`
- Can view job progress
- Cannot initiate syncs

### Apex Security

All sync classes follow Elaro security standards:
- `with sharing` keyword mandatory
- `WITH USER_MODE` for all SOQL
- `Security.stripInaccessible()` for bulk operations
- `ElaroSecurityUtils` for CRUD/FLS checks

### External Credentials

OAuth connections to source/target orgs use External Credentials:
- `Elaro_Sync_Source_Org` - Source org OAuth
- `Elaro_Sync_Target_Org` - Target org OAuth

No credentials stored in custom objects.

---

## Phase 1 MVP Scope (8 Weeks)

### In Scope

| Feature | Priority | Why Essential |
|---------|----------|---------------|
| Connection Manager | P0 | Can't sync without connections |
| Compatibility Analyzer | P0 | Kills "will this break?" objection |
| Sync Engine (basic) | P0 | Core value prop |
| Masking (fake, hash, redact) | P0 | Compliance differentiation |
| Checkpoint/Resume | P0 | Long-running sync reliability |
| Error Taxonomy | P0 | Actionable remediation |
| Limits Dashboard | P1 | Prevents "broke our org" blame |
| HIPAA Preset | P1 | Healthcare vertical |
| Sales Cloud Preset | P1 | Common use case |

### Out of Scope (Phase 2)

| Feature | Reason for Deferral |
|---------|---------------------|
| Scheduling | Manual runs sufficient |
| Approval Workflows | Manual process acceptable |
| Delta Sync | Full sync covers 90% of use cases |
| Format-Preserving Encryption | Basic masking sufficient |
| Scratch Org Pools | Enterprise feature |
| CLI | Web-first approach |

---

## Integration Points

### Existing Elaro Features

| Feature | Integration |
|---------|-------------|
| Compliance Scoring | Pre-sync compliance check |
| Audit Trail | Log all sync operations |
| AI Copilot | "What should I mask for HIPAA?" |
| Framework Engine | Derive masking rules from framework |

### AppExchange Considerations

- Single package: Elaro v4.0 includes Sync module
- Feature flag: `Elaro_Sync_Enabled__c` custom setting
- Sync features hidden when flag disabled
- Pricing: Sync module as upsell tier

---

## File/Class Inventory

### New Apex Classes (28 classes)

**Services** (14):
- `ElaroSyncConnectionService.cls`
- `ElaroSyncCompatibilityService.cls`
- `ElaroSyncRecordTypeAnalyzer.cls`
- `ElaroSyncPicklistAnalyzer.cls`
- `ElaroSyncFieldAnalyzer.cls`
- `ElaroSyncOwnerAnalyzer.cls`
- `ElaroSyncEngine.cls`
- `ElaroSyncExtractor.cls`
- `ElaroSyncTransformer.cls`
- `ElaroSyncLoader.cls`
- `ElaroSyncCheckpointService.cls`
- `ElaroSyncMaskingService.cls`
- `ElaroSyncLimitsService.cls`
- `ElaroSyncErrorService.cls`

**Controllers** (4):
- `ElaroSyncConnectionController.cls`
- `ElaroSyncJobController.cls`
- `ElaroSyncMaskingController.cls`
- `ElaroSyncLimitsController.cls`

**Masking Strategies** (3):
- `ElaroSyncFakeMasker.cls`
- `ElaroSyncHashMasker.cls`
- `ElaroSyncRedactMasker.cls`

**Test Classes** (14):
- One test class per production class

**Interfaces** (1):
- `ElaroSyncMaskingStrategy.cls`

### New Custom Objects (5)

- `Elaro_Sync_Connection__c`
- `Elaro_Sync_Job__c`
- `Elaro_Sync_Checkpoint__c`
- `Elaro_Sync_Error__c`
- `Elaro_Sync_Compatibility_Issue__c`

### New Custom Metadata (1)

- `Elaro_Sync_Masking_Rule__mdt`

### New Permission Sets (2)

- `Elaro_Sync_Admin`
- `Elaro_Sync_User`

### New LWC Components (8)

- `elaroSyncDashboard/`
- `elaroSyncConnectionWizard/`
- `elaroSyncCompatibilityReport/`
- `elaroSyncJobProgress/`
- `elaroSyncErrorDisplay/`
- `elaroSyncMaskingConfig/`
- `elaroSyncLimitsPanel/`
- `elaroSyncPlanReview/`

---

## Success Criteria

### MVP Launch Criteria

- [ ] Connect source and target orgs via OAuth
- [ ] Run compatibility analysis before sync
- [ ] Execute full sync with masking (Prod → Sandbox)
- [ ] Resume from checkpoint after failure
- [ ] Display errors with actionable remediation
- [ ] Show org limits before and after sync
- [ ] 95%+ test coverage on new code
- [ ] Zero Critical/High Code Analyzer findings

### Business Metrics

- Sync completion rate: > 95%
- Average sync time vs native refresh: > 80% faster
- PII exposure incidents: 0
- Customer support tickets per sync: < 0.1

---

## Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Bulk API edge cases | High | High | Extensive testing with real orgs |
| Circular references | Medium | High | Limit to 3 passes, fail gracefully |
| OAuth token refresh | Medium | Medium | Proactive refresh, clear errors |
| Large org performance | Medium | High | Chunking, progress indicators |
| Existing Elaro regression | Low | High | Comprehensive test suite |

---

## Next Steps

1. **Approve this spec** - Review architecture decisions
2. **Create feature branch** - `feature/elaro-sync-module`
3. **Implement Phase 1** - Follow 8-week roadmap
4. **Test with real orgs** - Validate against production-like data
5. **AppExchange submission** - Update package for v4.0

---

*Spec Version: 1.0 | Created: 2026-02-05 | Approved By: [Pending]*
