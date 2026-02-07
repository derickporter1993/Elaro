# Architecture Decision Records (ADRs)

This directory contains Architecture Decision Records documenting significant architectural decisions made in the Elaro platform.

## What is an ADR?

An Architecture Decision Record captures:
- **Context**: What forces led to this decision?
- **Decision**: What did we decide?
- **Consequences**: What are the trade-offs?
- **Status**: Proposed, Accepted, Deprecated, Superseded

## Index

| ADR | Title | Status | Date |
|-----|-------|--------|------|
| [001](./ADR-001-dual-repo-strategy.md) | Dual-Repo Strategy | Accepted | 2026-02-02 |
| [002](./ADR-002-monorepo-tooling.md) | Monorepo Tooling | Accepted | 2026-02-02 |
| [003](./ADR-003-dependency-management.md) | Dependency Management | Accepted | 2026-02-02 |

## Template

```markdown
# ADR-XXX: [Title]

**Status**: [Proposed | Accepted | Deprecated | Superseded]
**Date**: YYYY-MM-DD
**Deciders**: [Names]

## Context

What is the issue we're trying to solve? What are the forces at play?

## Decision

What did we decide to do?

## Consequences

What becomes easier or harder as a result of this decision?

### Positive
- [List benefits]

### Negative
- [List drawbacks]

### Neutral
- [List side effects]

## Alternatives Considered

What other options did we evaluate?

## References

Links to relevant docs, discussions, or tickets.
```

## How to Create an ADR

1. Copy the template above
2. Number sequentially (ADR-XXX)
3. Fill in all sections
4. Submit for review
5. Update this index when accepted

## Guidelines

- **One decision per ADR**: Keep focused
- **Immutable once accepted**: New ADR supersedes old one
- **Context is crucial**: Explain WHY, not just WHAT
- **Document alternatives**: Show what was considered
- **Keep concise**: 1-2 pages maximum
