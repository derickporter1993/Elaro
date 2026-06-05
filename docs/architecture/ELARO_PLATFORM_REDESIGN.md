# Elaro Platform Redesign — Core Platform + Vertical Packs

**Issue:** #211 — Define core platform + vertical pack architecture (replaces healthcare-only scope)
**Status:** Phase 1 (foundation) — implemented additively in the `elaro` package
**Author:** Elaro Team · **Since:** v3.2.0 (Spring '26)

---

## 1. Vision

Elaro is a **domain-agnostic compliance platform** with **pluggable vertical packs**. Healthcare
(HIPAA) is the first mature pack — the initial wedge — not the product's whole identity. The same
core engines serve every regulated industry; verticals add industry-specific frameworks, objects,
and engines on top.

> Healthcare remains the first wedge, not the full product identity.

## 2. Layer model

```
┌──────────────────────────── CORE PLATFORM (horizontal) ────────────────────────────┐
│ policy engine · control registry · drift engine · evidence engine · audit-package   │
│ generation · alerting & escalation · remediation orchestration · integration        │
│ framework · dashboard shell · PackRegistry (Core/Pack classification)               │
│                                                                                     │
│ Core frameworks: SOC2 · ISO 27001 · GDPR · CCPA · NIST · PCI-DSS · FedRAMP          │
└───────────────▲────────────────────────▲────────────────────────▲──────────────────┘
                │ packs register via Framework_Config__mdt + flag    │
     ┌──────────┴────────┐    ┌───────────┴─────────┐    ┌───────────┴─────────┐
     │  HIPAA PACK (now) │    │ FINANCIAL SERVICES  │    │ AI GOVERNANCE PACK  │
     │  HIPAA + #212 PHI │    │ (later): GLBA, SOX, │    │ (later): EU AI Act, │
     │  #213 access,     │    │ FINRA, SEC          │    │ NIST AI RMF         │
     │  #214 breach      │    │                     │    │                     │
     └───────────────────┘    └─────────────────────┘    └─────────────────────┘
```

A **Core** framework is broadly applicable across industries. A **Pack** framework is specific to a
vertical and ships (logically) as part of that pack, gated by a pack-level kill switch.

## 3. How a pack is defined (logical packs — Phase 1)

A pack is a **logical grouping**, not yet a separate package/namespace:

1. **Classification metadata** — each framework has a `Framework_Config__mdt` record tagged with
   `Layer__c` (`Core` | `Pack`) and `Pack__c` (`None` | `HIPAA` | `FinancialServices` | `AIGovernance`).
2. **Per-pack kill switch** — `Elaro_Feature_Flags__c` carries `HIPAA_Pack_Enabled__c`,
   `Financial_Services_Pack_Enabled__c`, and `AI_Governance_Pack_Enabled__c` (all default `true`).
3. **`PackRegistry`** — the single read API over the classification. It answers "is this framework
   Core or Pack?", "which frameworks are in pack X?", and "is this framework active?" (active =
   `Is_Active__c` AND its pack is enabled). Core frameworks are always enabled.

This makes the architecture real and queryable **without** a risky physical repackage. A pack can be
promoted to a physical 2GP later with no change to its classification contract.

## 4. Core-vs-Pack classification (every framework categorized)

| Framework | Layer | Pack | Notes |
|-----------|-------|------|-------|
| SOC 2 | Core | — | Horizontal security/ops trust criteria |
| ISO 27001 | Core | — | Horizontal ISMS |
| GDPR | Core | — | Privacy, geography-agnostic |
| CCPA | Core | — | Privacy, horizontal |
| NIST | Core | — | Broadly applicable US standard |
| FedRAMP | Core | — | US gov cloud baseline |
| **PCI-DSS** | **Core** | — | Treated as core security framework (#211 decision) |
| HIPAA | Pack | **HIPAA** | Healthcare; first mature pack |
| SOX | Pack | FinancialServices | Public-company finance |
| GLBA | Pack | FinancialServices | US finance/privacy |
| FINRA | Pack | FinancialServices | Securities (module exists; record TBD) |
| SEC Cybersecurity | Pack | FinancialServices | Public-company disclosure (service suite exists; record TBD) |
| **AI Governance** | Pack | **AIGovernance** | EU AI Act / NIST AI RMF — its own pack (#211 decision) |

> Edge-case rulings (#211): **PCI-DSS = Core** (security framework, broadly applicable);
> **AI Governance = its own Pack** (distinct emerging-regulation vertical).

Classification records ship for the ten `ElaroConstants` frameworks plus AI Governance. FINRA and
SEC are classified here in the doc; their `Framework_Config__mdt` records can be added when their
framework codes are finalized.

## 5. What Phase 1 (#211) delivers

Additive, managed-package-safe, no behavior change to existing engines:

- **This document** — architecture, classification, roadmap, taxonomy.
- **`Framework_Config__mdt.Layer__c` / `.Pack__c`** classification fields + 11 records.
- **Per-pack feature flags** on `Elaro_Feature_Flags__c` + `FeatureFlags.isHipaaPackEnabled()` /
  `isFinancialServicesPackEnabled()` / `isAIGovernancePackEnabled()`.
- **`PackRegistry`** read API (+ tests) — the single source of truth for classification, pack-flag
  aware.

### Deliberately deferred (follow-on issues)

- **De-hardcode framework lists** — make `ElaroConstants.ALL_FRAMEWORKS` /
  `ComplianceServiceFactory.SUPPORTED_FRAMEWORKS` derive from `PackRegistry`. Deferred because
  `ElaroConstantsTest` hard-asserts `ALL_FRAMEWORKS.size() == 10`; this needs org validation to
  re-baseline safely.
- **De-couple hardcoded HIPAA refs** in `ElaroChangeAdvisor` and `RuleEngineEventBridge`.
- **Physical package separation** — separate 2GP/namespace per vertical (only if distribution
  requires it).
- **Implement missing frameworks** — CMMC 2.0, NIS2, DORA.

## 6. Phased roadmap

| Phase | Scope | Risk |
|-------|-------|------|
| **1 — Foundation (this)** | Architecture + classification metadata + pack flags + `PackRegistry` | Low (additive) |
| **2 — Decouple** | Route `ElaroConstants`/factory and HIPAA-hardcoded refs through `PackRegistry`; reconcile the 14-vs-10 framework drift | Medium (needs org tests) |
| **3 — HIPAA pack maturity** | #212 PHI classification · #213 workforce access risk · #214 breach detection — built as HIPAA-pack engines behind `isHipaaPackEnabled()` | Medium |
| **4 — New verticals** | Financial Services pack (FINRA/SEC/GLBA/SOX), AI Governance pack hardening | Medium |
| **5 — Physical packaging (optional)** | Extract verticals into separate 2GPs if distribution demands | High |

## 7. Ticket taxonomy

Label every compliance ticket by **component type** and, where applicable, **pack**:

- `core/policy-engine`, `core/control-registry`, `core/drift`, `core/evidence`,
  `core/audit-package`, `core/alerting`, `core/remediation`, `core/integration`, `core/dashboard`
- `pack/hipaa`, `pack/financial-services`, `pack/ai-governance`
- Acceptance gate: **no feature merges without a Core/Pack designation.**

Examples: #212/#213/#214 → `pack/hipaa`; a new evidence-export capability → `core/evidence`.

## 8. Usage

```apex
// Is a framework horizontal Core or part of a vertical pack?
String layer = PackRegistry.getLayer('HIPAA');          // 'Pack'
String pack  = PackRegistry.getPack('HIPAA');           // 'HIPAA'
Boolean core = PackRegistry.isCore('PCI_DSS');          // true

// Which frameworks belong to a pack?
Set<String> hipaa = PackRegistry.getFrameworksInPack('HIPAA');

// Respect per-pack kill switches (active = Is_Active AND pack enabled)
if (PackRegistry.isFrameworkActive('HIPAA')) {
    // run HIPAA-pack logic
}
Set<String> active = PackRegistry.getActiveFrameworks();
```
