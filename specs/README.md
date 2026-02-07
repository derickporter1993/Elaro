# Specification Directory

This directory contains feature specifications for Elora (Compliance Platform).

## Law 1: Specs Before Code

**No spec = no code**

Every feature must have a specification before implementation begins.

## Specification Template

Use this structure for new specs:

```markdown
# [Feature Name]

## Overview
Brief description of the feature and its purpose.

## Business Context
- Why is this needed?
- What problem does it solve?
- Who requested it?

## Requirements

### Functional Requirements
1. The system shall...
2. Users must be able to...

### Non-Functional Requirements
- Performance: Response time < X ms
- Security: Authentication/authorization requirements
- Compliance: Regulatory requirements (HIPAA, SOC 2, etc.)

## Technical Design

### Salesforce Components
- **Apex Classes**: List classes to create/modify
- **LWC Components**: List components needed
- **Custom Objects/Fields**: Schema changes
- **Permissions**: Permission sets/profiles affected

### Architecture
- Integration points
- Data flow
- API contracts

## Test Plan
- Unit test coverage requirements (95%+)
- Integration test scenarios
- UAT acceptance criteria

## Acceptance Criteria
- [ ] Criterion 1
- [ ] Criterion 2
- [ ] All tests pass
- [ ] Code review approved
- [ ] Security review passed

## Implementation Checklist
- [ ] Spec approved
- [ ] Branch created: `feature/[TICKET]-[description]`
- [ ] Apex classes implemented
- [ ] LWC components implemented
- [ ] Tests written (95%+ coverage)
- [ ] Security review completed
- [ ] Code review completed
- [ ] Deployed to scratch org
- [ ] UAT completed
- [ ] Merged to main
```

## Naming Convention

Spec files should be named: `[feature-name].spec.md`

Examples:
- `compliance-dashboard.spec.md`
- `ai-copilot.spec.md`
- `api-monitoring.spec.md`

## Status

Specs can have status markers:
- `DRAFT` - Work in progress
- `REVIEW` - Ready for review
- `APPROVED` - Approved, ready for implementation
- `IMPLEMENTED` - Feature completed
- `DEPRECATED` - No longer relevant
