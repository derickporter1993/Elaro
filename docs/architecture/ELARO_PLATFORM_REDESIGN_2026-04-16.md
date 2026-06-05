# Elaro Platform Redesign

Date: 2026-04-16
Status: Proposed
Owner: Product / Architecture

## Executive Summary

Elaro should not become a healthcare-only product.
Elaro should become a domain-agnostic compliance platform with a narrow, disciplined core and pluggable vertical packs.

This redesign separates platform concerns from regulatory-domain concerns.
It preserves long-term market upside while reducing implementation sprawl.

## Core Decision

Design Elaro as:

- a domain-agnostic core platform
- vertical packs for domain-specific frameworks and workflows
- a staged release model where one vertical can mature first without forcing the whole product to become domain-specific

## Why This Redesign

The current product has two problems:

1. The implementation surface is too broad.
2. The market positioning is trying to mature every vertical at once.

Making the whole app healthcare-specific would reduce scope, but it would also unnecessarily reduce platform value.
Keeping everything equally first-class would preserve upside, but it would continue to create execution drag.

The correct middle path is a stable core plus modular packs.

## Product Shape

### Core Platform

The core platform contains capabilities that should remain domain-agnostic:

- policy engine
- control registry
- framework registry
- metadata drift engine
- evidence collection engine
- audit package generation
- alert orchestration
- escalation and notification routing
- access analysis framework
- remediation orchestration
- scheduler framework
- integration framework
- dashboard shell and navigation
- shared logging and observability
- package configuration and feature flags

These capabilities should not encode domain-specific assumptions.

### Vertical Packs

Vertical packs contain domain-specific logic, controls, workflows, dashboards, and language.

Initial pack model:

- HIPAA Pack
- Financial Services Pack
- Public Sector Pack
- AI Governance Pack

Each pack can provide:

- framework-specific control mappings
- scoring logic
- domain workflows
- specialized objects where needed
- domain dashboard cards and reports
- domain-specific evidence templates
- domain-specific alert rules
- guided setup and readiness flows

## Architectural Principles

### 1. Keep the core thin

The core should provide execution primitives, not every domain rule.
If a feature only matters to one vertical, it belongs in a pack.

### 2. Separate platform services from domain services

Examples:

- `EvidenceService` is core
- `HIPAAEvidenceTemplateService` is pack-specific

- `AccessRiskEngine` is core
- `HIPAAMinimumNecessaryPolicyService` is pack-specific

### 3. Prefer metadata-driven extension over hardcoded branching

Do not scatter `if framework == 'HIPAA'` logic across the platform.
Use registries, interfaces, and configuration binding.

### 4. Release one wedge vertical first

The platform may support multiple packs conceptually, but only one pack needs to be mature first.
That does not require rewriting the platform identity around that vertical.

### 5. Keep GTM narrower than architecture

Architecture can support multiple industries.
Marketing and early sales should focus on one wedge until execution quality is proven.

## Proposed Module Map

### Keep in Core

- ComplianceServiceFactory, reworked as a registry-driven module resolver
- shared logging
- evidence model and audit package generation
- notification and escalation engine
- drift monitoring engine
- integration abstractions
- framework registry and control metadata
- remediation orchestration base
- dashboard shell, shared filters, shared timeline views

### Move to HIPAA Pack

- HIPAA breach workflows
- PHI-specific control mappings
- minimum necessary access workflows
- HIPAA evidence templates
- healthcare-specific dashboards and wording

### Move to Financial Services Pack

- SEC cybersecurity workflows
- GLBA workflows
- FINRA-specific evidence and controls

### Move to AI Governance Pack

- AI system registry
- AI risk classification
- AI-specific dashboards and setup

### Defer or Remove from Near-Term Scope

- public trust center unless directly tied to a vertical pack use case
- blockchain anchoring unless a real buyer requires it
- broad benchmarking until core scoring and evidence are stable
- duplicate dashboards that do not add pack-specific value

## UI Redesign

### Replace generic dashboard sprawl with a shell + pack panels

Core shell:

- global scorecard
- alerts
- recent drift
- evidence packages
- tasks / remediations

Pack panels:

- HIPAA panel
- Financial Services panel
- AI Governance panel

The shell owns navigation and shared data primitives.
Packs own domain cards, copy, and workflows.

## Data Model Strategy

### Core Objects

Keep common objects generic where possible:

- Compliance_Score__c
- Compliance_Gap__c
- Compliance_Evidence__c
- Alert__c
- Metadata_Change__c
- Remediation_Suggestion__c
- Elaro_Audit_Package__c

### Pack-Owned Objects

Only create pack-specific objects when the lifecycle is truly domain-specific:

- HIPAA_Breach__c
- Materiality_Assessment__c
- AI_System_Registry__c

Do not create pack-specific objects for concepts that can live in the core model.

## Packaging Strategy

Target packaging model:

- Elaro Core
- Elaro HIPAA Pack
- Elaro Financial Services Pack
- Elaro AI Governance Pack

Do not force every pack into the first submission.
The first submission should prove:

- core quality
- one mature pack
- clean extension model

## Delivery Phases

### Phase 1: Core Stabilization

- remove AppExchange blockers
- clean package metadata
- harden security and governor compliance
- consolidate duplicated UI surfaces
- create module registry abstraction

### Phase 2: First Mature Pack

Recommended first pack:
- HIPAA Pack

Reason:
- clear pain
- strong differentiation
- concrete workflows
- high urgency in regulated Salesforce orgs

### Phase 3: Second Pack

Recommended:
- Financial Services Pack

### Phase 4: Expansion

- AI Governance Pack
- Public sector / sovereign pack if justified

## Ticketing Model

All implementation tickets should be categorized under one of three buckets:

- Core Platform
- HIPAA Pack
- Future Packs

No ticket should be accepted unless it clearly belongs to one bucket.
This prevents scope bleed.

## Decisions

### Decision 1
Elaro remains a platform, not a healthcare-only app.

### Decision 2
HIPAA becomes the first mature wedge, not the whole product identity.

### Decision 3
Core services must be domain-agnostic.

### Decision 4
Pack-specific workflows, language, and controls move out of the core.

## Immediate Next Steps

1. Rewrite scope and roadmap issues to reflect Core Platform plus vertical packs.
2. Create ticket hierarchy:
   - Core Platform
   - HIPAA Pack
   - Future Packs
3. Freeze new features that do not fit the redesigned module map.
4. Refactor packaging plan around core plus pack boundaries.

## Non-Goals

- making every industry equally complete in v1
- preserving every current feature surface
- keeping duplicate dashboards and redundant modules
- shipping broad platform ambitions before hardening the base

## Final Position

Elaro should be simpler than it is now, but not smaller than it needs to be.
The right answer is not to collapse into one domain.
The right answer is to separate shared infrastructure from domain implementation and mature one wedge at a time.
