# Spec: apexdoc-compliance

**Tier**: Full | **Domain**: SOFTWARE | **Priority**: P1 — High
**Findings**: ARCH-001 to ARCH-003, ARCH-024 (3 high + 1 medium)
**Scope**: 142 files missing @since, 18 files missing @author, 1 file missing all ApexDoc, 1 file with @description

## Problem
142 production classes missing `@since` tag, 18 missing `@author`, 1 (ApiUsageSnapshot) missing complete ApexDoc header. CLAUDE.md requires @author, @since, @group on every class for AppExchange compliance and Agentforce parsing.

## Acceptance Criteria

- **AC-001**: Every production class in force-app/main/default/classes/ (non-test) has `@since v3.1.0 (Spring '26)` or appropriate version tag
- **AC-002**: Every production class has `@author Elaro Team`
- **AC-003**: ApiUsageSnapshot.cls has complete ApexDoc header with @author, @since, @group, class description
- **AC-004**: NaturalLanguageQueryService.cls: `@description` tag removed, description moved to first paragraph
- **AC-005**: Every production class has a `@group` tag using one of: Compliance Framework, Security, Event Monitoring, Health Check, AI Governance, SEC Module, Trust Center, Assessment, Integration, System Monitoring, Data Structures, Interfaces, Logging, Utilities
- **AC-006**: No `@description` tags remain in any production class (description is first text in comment block per CLAUDE.md)

## Scope Fence
- **IN**: All production Apex classes in force-app/main/default/classes/ (non-test)
- **OUT**: Test classes, Health Check classes (separate package), LWC files, method-level ApexDoc

## Checkpoints
1. STOP after scanning all classes to determine current ApexDoc state — present counts
2. Batch process in groups of 20-30 files

## Approach
Use grep to identify classes missing tags, then batch-edit with appropriate values based on class name/purpose. Group assignment based on naming conventions:
- *Controller → group matches module
- *Service → group matches module
- *Scanner → Security or Health Check
- *Engine → Compliance Framework
- Elaro* prefix → Infrastructure
