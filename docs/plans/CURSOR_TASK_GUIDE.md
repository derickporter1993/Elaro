# CURSOR TASK MANAGEMENT GUIDE

## Overview
This guide defines the structured approach for managing AI-assisted development tasks in Cursor IDE for the Prometheion compliance automation platform.

## Core Principles

### 1. Single-Task Focus
- One READY task active at a time
- Complete before moving to next
- Prevents context-switching overhead

### 2. Priority-Driven Execution
- **EMERGENCY** (🔴): Production issues, security vulnerabilities, compliance violations
- **ACTIVE** (🟡): Current sprint commitments, client deliverables
- **BACKLOG** (🟢): Future enhancements, technical debt

### 3. Explicit Readiness Gates
- Tasks must be marked "READY TO IMPLEMENT" before execution
- All dependencies resolved
- Acceptance criteria defined
- Technical context documented

## Task Structure Template

```markdown
## TASK-XXX: [Brief Title]

**Status**: [🔴 EMERGENCY | 🟡 ACTIVE | 🟢 BACKLOG]  
**State**: [BLOCKED | PLANNING | READY TO IMPLEMENT | IN PROGRESS | TESTING | COMPLETE]  
**Owner**: [Name]  
**Created**: YYYY-MM-DD  
**Target**: YYYY-MM-DD  

### Context
[Why this task exists, business impact, user story]

### Technical Context
**Current State**: [What exists now]  
**Desired State**: [What should exist after completion]  
**System Components**: [Affected modules/classes/objects]  
**Dependencies**: [TASK-XXX, TASK-YYY]  
**Blockers**: [What prevents starting]  

### Acceptance Criteria
- [ ] Criterion 1 (testable, specific)
- [ ] Criterion 2 (testable, specific)
- [ ] Criterion 3 (testable, specific)

### Compliance Checkpoints
- [ ] HIPAA/SOC 2/FINRA controls validated
- [ ] Audit trail requirements met
- [ ] Shield Event Monitoring coverage verified
- [ ] Security review completed

### Implementation Notes
**Approach**: [High-level strategy]  
**Files to Modify**: 
- `path/to/file1.cls`
- `path/to/file2.trigger`

**Risks**: [Potential issues, mitigation strategies]

### Testing Strategy
- [ ] Unit tests written (>85% coverage)
- [ ] Integration tests passed
- [ ] Manual UAT completed
- [ ] Performance validated

### Rollback Plan
**If implementation fails**:
1. `git revert [commit-hash]`
2. Restore from backup: [specific steps]
3. Notify stakeholders: [communication plan]

### Success Criteria Met
- [ ] All acceptance criteria passed
- [ ] Code reviewed and approved
- [ ] Documentation updated
- [ ] Deployed to production
```

## Workflow States

### BLOCKED
**Cannot start due to external dependency**
- Document blocker clearly
- Identify blocker owner
- Set follow-up date
- Move to PLANNING when unblocked

### PLANNING
**Requirements gathering and design**
- Research technical approach
- Define acceptance criteria
- Estimate effort (story points/hours)
- Identify risks and dependencies

### READY TO IMPLEMENT
**All prerequisites met, ready for development**
- Technical approach approved
- Dependencies resolved
- Test strategy defined
- AI context primer complete

### IN PROGRESS
**Active development underway**
- Update daily in task comments
- Document decisions and blockers
- Commit frequently with descriptive messages
- Run tests continuously

### TESTING
**Implementation complete, validation in progress**
- All acceptance criteria under test
- Manual and automated tests running
- Bug fixes tracked separately
- Staging environment validated

### COMPLETE
**Shipped to production, monitoring active**
- All success criteria met
- Documentation published
- Stakeholders notified
- Post-mortem scheduled (if needed)

## Priority Escalation Rules

### Auto-Promote to EMERGENCY
- Production outage affecting users
- Security vulnerability discovered
- Compliance audit finding (critical)
- Data integrity issue detected

### Auto-Promote to ACTIVE
- Client deadline within 48 hours
- Dependency for another ACTIVE task
- Executive-requested feature
- Regulatory deadline approaching

## Git Integration Standards

### Branch Naming
```
feature/TASK-XXX-brief-description
bugfix/TASK-XXX-brief-description
hotfix/TASK-XXX-brief-description
```

### Commit Message Format
```
TASK-XXX: [action] - [component]

- Detailed change 1
- Detailed change 2

Refs: #XXX
```

### PR Template Checklist
- [ ] Links to TASK-XXX
- [ ] All acceptance criteria met
- [ ] Tests passing (>85% coverage)
- [ ] Compliance checkpoints verified
- [ ] Documentation updated
- [ ] Breaking changes documented

## AI Context Priming Template

**Use this to accelerate AI comprehension for complex tasks:**

```markdown
## AI Context Primer for TASK-XXX

### System State
**Architecture**: [Current platform design]  
**Data Model**: [Relevant objects and relationships]  
**Integration Points**: [External systems, APIs]  

### Previous Attempts
**What Didn't Work**: [Failed approaches and why]  
**Lessons Learned**: [Key insights from failures]  

### Constraints
**Technical**: [Governor limits, API limits, platform restrictions]  
**Business**: [Budget, timeline, scope]  
**Compliance**: [Regulatory requirements, audit needs]  

### Success Patterns
**Similar Tasks**: [Reference implementations]  
**Proven Approaches**: [What works in this codebase]  
```

## Task Estimation Framework

### Impact Score (1-10)
- **10**: Platform-wide transformation, major revenue impact
- **7-9**: Multi-module feature, significant efficiency gain
- **4-6**: Single-module enhancement, measurable improvement
- **1-3**: Minor fix, quality-of-life update

### Effort Score (1-10)
- **10**: Multi-sprint epic, architectural change
- **7-9**: Full sprint, complex implementation
- **4-6**: 2-3 days, moderate complexity
- **1-3**: <1 day, straightforward task

### ROI Calculation
```
ROI Ratio = Impact Score / Effort Score

> 2.0: High-priority (do first)
1.0-2.0: Medium-priority (schedule)
< 1.0: Low-priority (backlog)
```

## SLA Definitions by Priority

| Priority | Response Time | Resolution Target |
|----------|--------------|------------------|
| 🔴 EMERGENCY | Immediate | < 4 hours |
| 🟡 ACTIVE | < 2 hours | < 48 hours |
| 🟢 BACKLOG | < 24 hours | < 1 week |

## Recurring Task Templates

### Salesforce Health Check
```markdown
## TASK-HCK-XXX: [Org Name] Health Check

**Scope**: Security review, data model audit, automation assessment

### Standard Checklist
- [ ] Profile/permission set review
- [ ] Sharing model validation
- [ ] Process builder/flow optimization
- [ ] Data quality assessment
- [ ] API usage analysis
- [ ] Governor limit review
- [ ] Shield Event Monitoring setup

### Deliverable
Comprehensive health check report with prioritized remediation roadmap
```

### Compliance Feature Implementation
```markdown
## TASK-CMP-XXX: [Feature Name] Compliance Automation

**Framework**: [HIPAA | SOC 2 | FINRA | 21 CFR Part 11]

### Compliance Checkpoints
- [ ] Controls mapped to framework requirements
- [ ] Audit trail configured
- [ ] Evidence generation automated
- [ ] Reporting dashboard created
- [ ] Documentation package complete

### Deliverable
Production-ready compliance feature with audit-ready evidence
```

### Client RFP Response
```markdown
## TASK-RFP-XXX: [Client Name] Proposal

**Deadline**: YYYY-MM-DD  
**Budget**: $XX,XXX  

### Components
- [ ] Technical approach documented
- [ ] Timeline and milestones defined
- [ ] Pricing model finalized
- [ ] Case studies selected
- [ ] Executive summary written

### Deliverable
Compelling RFP response package with win themes aligned to client needs
```

## Review Cadence

### Daily Standup (Self)
- Review IN PROGRESS tasks
- Unblock BLOCKED tasks
- Promote READY tasks to IN PROGRESS

### Weekly Planning
- Review BACKLOG for promotion
- Re-estimate ACTIVE tasks
- Archive COMPLETE tasks
- Update roadmap priorities

### Monthly Retrospective
- Analyze completion velocity
- Identify process bottlenecks
- Refine estimation accuracy
- Update task templates

## Success Metrics

### Velocity Tracking
```
Story Points Completed / Sprint
Target: 20-30 points per 2-week sprint
```

### Quality Metrics
```
Bugs per Release / Total Stories
Target: < 0.1 (1 bug per 10 stories)
```

### Estimation Accuracy
```
Actual Effort / Estimated Effort
Target: 0.8-1.2 (±20% variance)
```

---

**Version**: 1.0.0  
**Last Updated**: 2025-01-10  
**Owner**: Derick Porter  
**Review Cycle**: Quarterly
