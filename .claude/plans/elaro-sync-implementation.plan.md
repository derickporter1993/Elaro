# Elaro Sync Implementation Plan

> **Branch**: `feature/elaro-sync-module`
> **Spec**: `specs/elaro-sync.spec.md`
> **Status**: ACTIVE
> **Created**: 2026-02-05

---

## Phase 1: Foundation (Week 1-2)

### Task 1.1: Custom Objects
**Priority**: P0 | **Effort**: 2 hours

Create 5 custom objects:

```
force-app/main/default/objects/
├── Elaro_Sync_Connection__c/
│   ├── Elaro_Sync_Connection__c.object-meta.xml
│   └── fields/
│       ├── Instance_URL__c.field-meta.xml
│       ├── Org_Type__c.field-meta.xml
│       ├── Is_Source__c.field-meta.xml
│       ├── Last_Connected__c.field-meta.xml
│       └── Health_Status__c.field-meta.xml
├── Elaro_Sync_Job__c/
├── Elaro_Sync_Checkpoint__c/
├── Elaro_Sync_Error__c/
└── Elaro_Sync_Compatibility_Issue__c/
```

**Acceptance**:
- [ ] All objects deploy successfully
- [ ] Relationships configured correctly
- [ ] Field-level help text populated

### Task 1.2: Custom Metadata Type
**Priority**: P0 | **Effort**: 1 hour

Create masking rules metadata:

```
force-app/main/default/customMetadata/
├── Elaro_Sync_Masking_Rule__mdt/
└── records/
    ├── Contact_Email.md-meta.xml (Fake)
    ├── Contact_Phone.md-meta.xml (Fake)
    ├── Contact_Birthdate.md-meta.xml (Redact)
    └── ... (HIPAA defaults)
```

### Task 1.3: Permission Sets
**Priority**: P1 | **Effort**: 1 hour

```
force-app/main/default/permissionsets/
├── Elaro_Sync_Admin.permissionset-meta.xml
└── Elaro_Sync_User.permissionset-meta.xml
```

### Task 1.4: Connection Service
**Priority**: P0 | **Effort**: 4 hours

```apex
// Classes to create:
ElaroSyncConnectionService.cls      // OAuth handling
ElaroSyncConnectionServiceTest.cls  // Test class
ElaroSyncConnectionController.cls   // LWC controller
```

**Acceptance**:
- [ ] Can initiate OAuth flow
- [ ] Can store connection metadata
- [ ] Can validate connection health
- [ ] 95%+ test coverage

---

## Phase 2: Compatibility Analyzer (Week 3-4)

### Task 2.1: Analyzer Services
**Priority**: P0 | **Effort**: 8 hours

```apex
ElaroSyncCompatibilityService.cls      // Main orchestrator
ElaroSyncRecordTypeAnalyzer.cls        // RT comparison
ElaroSyncPicklistAnalyzer.cls          // Picklist validation
ElaroSyncFieldAnalyzer.cls             // Field checks
ElaroSyncOwnerAnalyzer.cls             // User availability
// + 5 test classes
```

**Acceptance**:
- [ ] Detects missing Record Types
- [ ] Detects missing Picklist values
- [ ] Detects missing Fields
- [ ] Detects inactive Owners
- [ ] Returns actionable remediation

### Task 2.2: Limits Service
**Priority**: P1 | **Effort**: 2 hours

```apex
ElaroSyncLimitsService.cls
ElaroSyncLimitsServiceTest.cls
ElaroSyncLimitsController.cls
```

**Acceptance**:
- [ ] Queries org limits API
- [ ] Calculates sync impact projection
- [ ] Returns formatted limit data

---

## Phase 3: Sync Engine (Week 5-6)

### Task 3.1: Core Engine
**Priority**: P0 | **Effort**: 12 hours

```apex
ElaroSyncEngine.cls              // Queueable orchestrator
ElaroSyncExtractor.cls           // Bulk API 2.0 extraction
ElaroSyncTransformer.cls         // Masking + mapping
ElaroSyncLoader.cls              // Multi-pass loading
ElaroSyncCheckpointService.cls   // Resume capability
ElaroSyncErrorService.cls        // Error catalog
// + 6 test classes
```

**Acceptance**:
- [ ] Extract records via Bulk API
- [ ] Apply masking rules
- [ ] Load with deferred references
- [ ] Create checkpoints at intervals
- [ ] Resume from checkpoint
- [ ] Log errors with remediation

### Task 3.2: Masking Strategies
**Priority**: P0 | **Effort**: 4 hours

```apex
ElaroSyncMaskingStrategy.cls     // Interface
ElaroSyncMaskingService.cls      // Orchestrator
ElaroSyncFakeMasker.cls          // Deterministic fake
ElaroSyncHashMasker.cls          // Cryptographic hash
ElaroSyncRedactMasker.cls        // Full removal
// + test classes
```

**Acceptance**:
- [ ] Fake: Deterministic (same input → same output)
- [ ] Hash: One-way, consistent
- [ ] Redact: Nullifies or blanks
- [ ] Configurable per field

---

## Phase 4: UI & Polish (Week 7-8)

### Task 4.1: LWC Components
**Priority**: P0 | **Effort**: 16 hours

```
force-app/main/default/lwc/
├── elaroSyncDashboard/          // Main entry
├── elaroSyncConnectionWizard/   // OAuth setup
├── elaroSyncCompatibilityReport/
├── elaroSyncJobProgress/        // Real-time progress
├── elaroSyncErrorDisplay/       // Error + remediation
├── elaroSyncMaskingConfig/      // Rule configuration
├── elaroSyncLimitsPanel/        // Limits visualization
└── elaroSyncPlanReview/         // Pre-execution review
```

**Acceptance**:
- [ ] Responsive design (desktop + mobile)
- [ ] Accessible (WCAG 2.1)
- [ ] No quoted template bindings
- [ ] Jest tests for each component

### Task 4.2: Integration Testing
**Priority**: P0 | **Effort**: 8 hours

- [ ] End-to-end: Connect → Analyze → Sync → Complete
- [ ] Failure scenarios: Network, limits, validation
- [ ] Resume from checkpoint
- [ ] Large data volume (10k+ records)

### Task 4.3: Documentation
**Priority**: P1 | **Effort**: 4 hours

- [ ] Update README with Sync module
- [ ] Add Sync section to CLAUDE.md
- [ ] Error code reference
- [ ] Masking rules guide

---

## Task Execution Order

```
Week 1:
├── Task 1.1: Custom Objects ◄─ START HERE
├── Task 1.2: Custom Metadata
└── Task 1.3: Permission Sets

Week 2:
└── Task 1.4: Connection Service

Week 3-4:
├── Task 2.1: Analyzer Services
└── Task 2.2: Limits Service

Week 5-6:
├── Task 3.1: Core Engine
└── Task 3.2: Masking Strategies

Week 7-8:
├── Task 4.1: LWC Components
├── Task 4.2: Integration Testing
└── Task 4.3: Documentation
```

---

## Dependencies

```
Custom Objects ──► Services ──► Controllers ──► LWC Components
                     │
                     ▼
              Test Classes
```

---

## Definition of Done

For each task:
- [ ] Code complete
- [ ] Test coverage ≥ 95%
- [ ] Code Analyzer: 0 Critical/High
- [ ] `npm run precommit` passes
- [ ] PR reviewed and merged

For module complete:
- [ ] All tasks done
- [ ] Integration tests pass
- [ ] Documentation updated
- [ ] Demo script validated

---

## Current Progress

| Task | Status | Notes |
|------|--------|-------|
| 1.1 Custom Objects | Pending | Next up |
| 1.2 Custom Metadata | Pending | |
| 1.3 Permission Sets | Pending | |
| 1.4 Connection Service | Pending | |
| 2.1 Analyzer Services | Pending | |
| 2.2 Limits Service | Pending | |
| 3.1 Core Engine | Pending | |
| 3.2 Masking Strategies | Pending | |
| 4.1 LWC Components | Pending | |
| 4.2 Integration Testing | Pending | |
| 4.3 Documentation | Pending | |

---

*Plan Version: 1.0 | Updated: 2026-02-05*
