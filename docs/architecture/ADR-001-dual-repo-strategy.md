# ADR-001: Dual-Repo Strategy

**Status**: Accepted
**Date**: 2026-02-02
**Deciders**: Derick Porter, Claude Code (Sentinel Architecture)

## Context

The Elaro project contains two distinct technical domains:

1. **Salesforce Application** (`force-app/`)
   - Apex classes (290 classes, 65K+ LOC)
   - Lightning Web Components (42 components)
   - Salesforce metadata (objects, fields, permissions)
   - Deployed via Salesforce CLI (`sf` commands)
   - Tested with Jest (LWC) and Apex test classes

2. **Platform Tooling** (`platform/`)
   - Node.js CLI for Prometheion operations
   - Salesforce API client libraries
   - Data masking utilities
   - TypeScript monorepo managed by Turborepo
   - Independent build pipeline

**The Problem**: Initial structure created confusion:
- Root scripts assumed platform was built
- Unclear dependency boundaries
- No documentation of architectural intent
- Build failures due to missing platform initialization
- Violation of "Documents Before Guessing" (Law 4)

**The Question**: Should we consolidate into a single monorepo, keep them separate, or collapse platform tooling?

## Decision

**We will maintain the dual-architecture pattern with formalized boundaries.**

```
elaro/
├── force-app/              # Salesforce domain (independent)
│   └── [Apex, LWC, metadata]
│
├── platform/               # Node.js domain (independent)
│   ├── package.json        # Own dependencies
│   ├── turbo.json          # Own build config
│   └── packages/           # CLI, sf-client, masking, types
│
├── package.json            # Orchestrator only (testing, linting)
├── specs/                  # Requirements (Law 1)
└── docs/architecture/      # Decisions (this ADR)
```

**Key Principles**:
1. **Independence**: Each domain can build/test/deploy without the other
2. **Orchestration**: Root provides convenience commands but guarantees nothing
3. **Clear Contracts**: No cross-dependencies (Salesforce never imports platform code)
4. **Documentation**: Architecture decisions captured in ADRs

## Consequences

### Positive ✅

- **Separation of concerns**: Salesforce and Node.js evolve independently
- **Clear mental model**: Developers know which "world" they're in
- **Flexible deployment**: Can deploy Salesforce without building CLI
- **Future-proof**: CLI can be extracted to npm package if needed
- **Minimal disruption**: Requires documentation, not restructuring

### Negative ⚠️

- **Two installation steps**: `npm install` at root AND in platform/
- **Duplicate tooling**: Both use prettier, typescript (managed via configs)
- **Cognitive overhead**: Developers must understand two package contexts
- **CI/CD complexity**: Must handle both domains in pipeline

### Neutral 🔵

- **Testing spans both**: Root runs LWC tests, platform runs own tests
- **Git remains unified**: Single repository, single branching strategy
- **Documentation critical**: Without docs, this pattern is confusing

## Alternatives Considered

### Alternative A: Full Monorepo Consolidation

**Structure**:
```
elaro/
└── packages/
    ├── salesforce/     # force-app/ moves here
    ├── cli/
    ├── sf-client/
    └── masking/
```

**Rejected because**:
- Major migration effort (2-3 days)
- Salesforce deployment tooling expects `force-app/` at root
- No immediate benefit (not shipping CLI as product yet)
- Violates "Revenue before systems" principle

### Alternative B: Collapse Platform into Scripts

**Structure**:
```
elaro/
├── force-app/
└── scripts/
    └── cli/           # Simplified CLI, no monorepo
```

**Rejected because**:
- Loses optionality (can't easily extract CLI to npm later)
- CLI has genuine complexity (sf-client, masking are real libraries)
- Would need to rebuild infrastructure if CLI becomes product
- Premature optimization (assumes CLI will never grow)

### Alternative C: Separate Git Repositories

**Structure**:
- `elaro/` (Salesforce only)
- `elaro-platform/` (Separate repo)

**Rejected because**:
- Coordination overhead (two repos, two CI/CD pipelines)
- Overkill for current team size (1-2 developers)
- Complicates feature work that touches both domains
- Can always split later if needed

## Implementation

### Phase 1: Documentation (Completed)
- [x] Create `docs/architecture/` with ADRs
- [x] Document dual-repo pattern (this ADR)
- [x] Update CLAUDE.md with architecture decisions

### Phase 2: Formalize Boundaries (In Progress)
- [ ] Update root `package.json` with postinstall hook
- [ ] Create `scripts/preflight.sh` validation
- [ ] Add platform `README.md` documenting independence
- [ ] Update CI/CD to handle both domains

### Phase 3: Developer Experience
- [ ] Create setup guide in docs/
- [ ] Add troubleshooting section
- [ ] Document common workflows (Salesforce dev, CLI dev, both)

## Success Criteria

- [ ] New developer can set up workspace in <15 minutes
- [ ] Platform builds independently: `cd platform && npm install && npm run build`
- [ ] Root commands degrade gracefully if platform not built
- [ ] Architecture pattern documented in 3 places (ADR, CLAUDE.md, README)
- [ ] Zero confusion about "which package.json do I use?"

## References

- Sentinel Architecture v2.0: Law 4 (Documents Before Guessing)
- Exploration Agent Report (2026-02-02): Identified structural issues
- Plan Agent Report (2026-02-02): Proposed Option B (this decision)
- Turborepo Documentation: https://turbo.build/repo/docs
- Salesforce DX Project Structure: https://developer.salesforce.com/docs/atlas.en-us.sfdx_dev.meta/sfdx_dev/sfdx_dev_source_file_format.htm

## Review History

- 2026-02-02: Proposed by Claude Code (Sentinel Architecture)
- 2026-02-02: Accepted by Derick Porter
