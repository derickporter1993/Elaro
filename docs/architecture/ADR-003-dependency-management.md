# ADR-003: Dependency Management

**Status**: Accepted
**Date**: 2026-02-02
**Deciders**: Derick Porter, Claude Code (Sentinel Architecture)

## Context

The dual-architecture pattern (ADR-001) creates two distinct dependency contexts:

**Root Context** (`/Users/derickporter/Elaro/package.json`):
- Purpose: Salesforce development (LWC testing, linting, formatting)
- Dependencies: Jest, ESLint, Prettier, Salesforce CLI
- Scope: `force-app/` directory only

**Platform Context** (`/Users/derickporter/Elaro/platform/package.json`):
- Purpose: Node.js CLI and tooling
- Dependencies: Turbo, TypeScript, Commander, Chalk
- Scope: `platform/packages/*` directories

**The Problem**:
- New developers don't know which `npm install` to run
- Root scripts reference platform but don't ensure it's ready
- Build failures when platform dependencies missing
- No automatic synchronization between contexts
- Violates "State Over History" (Law 2) - can't trust if deps are installed

**The Question**: How do we manage dependencies across two package.json files reliably?

## Decision

**We will use automatic initialization with explicit verification.**

### Strategy

1. **Root postinstall hook**: Automatically install platform deps after root install
2. **Pre-flight checks**: Validate workspace state before critical operations
3. **Explicit setup commands**: Provide manual control for advanced workflows
4. **Fail fast**: Commands error with helpful messages if workspace invalid

### Implementation

**Root `package.json`**:
```json
{
  "scripts": {
    "postinstall": "test -d platform/node_modules || (cd platform && npm install)",
    "cli:setup": "cd platform && npm install && npm run build",
    "cli:build": "npm run cli:setup && cd platform && npm run build --filter @platform/cli",
    "preflight": "bash scripts/preflight.sh",
    "precommit": "npm run preflight && npm run fmt:check && npm run lint && npm run test:unit"
  }
}
```

**`scripts/preflight.sh`**:
```bash
#!/bin/bash
set -e

# Validate workspace state
test -d node_modules || { echo "❌ Missing root deps: npm install"; exit 1; }
test -d platform/node_modules || { echo "❌ Missing platform deps: cd platform && npm install"; exit 1; }
test -d specs || { echo "❌ Missing specs/ (Law 1)"; exit 1; }

echo "✅ Workspace valid"
```

## Consequences

### Positive ✅

- **Automatic setup**: `npm install` at root sets up everything
- **Clear errors**: Preflight checks tell developers exactly what's missing
- **Law 2 compliance**: File system is truth (check node_modules, don't assume)
- **Graceful degradation**: Platform commands work even if root has issues
- **Developer experience**: New devs run `npm install` once and are ready

### Negative ⚠️

- **Slower root install**: Adds 10-20 seconds to run platform install
- **Two lock files**: `package-lock.json` at root AND in platform/
- **Dependency drift**: Root and platform can have different versions of shared deps (prettier, typescript)
- **Cache invalidation**: Clearing node_modules must be done in both places

### Neutral 🔵

- **Not a monorepo**: True monorepo would hoist shared deps to root
- **Explicit is better**: Verbose commands better than implicit failures
- **Can opt out**: Advanced users can skip postinstall with `npm install --ignore-scripts`

## Alternatives Considered

### Alternative A: Full Workspace Hoisting

**Structure**:
```
elaro/
├── package.json (workspaces: ["force-app", "platform/packages/*"])
├── node_modules/ (all deps here)
└── ...
```

**Pros**:
- Single `npm install`
- Shared dependency versions
- One lock file

**Cons**:
- Salesforce CLI expects standard structure
- `force-app/` is not a real package
- Would need to restructure significantly

**Rejected**: See ADR-001 (rejected full monorepo)

### Alternative B: Manual Setup Only

**No postinstall hook, just documentation**:
```bash
# Setup
npm install           # Root deps
cd platform && npm install  # Platform deps
```

**Pros**:
- Explicit control
- No automatic behavior

**Cons**:
- Easy to forget platform install
- Build failures with unclear errors
- Violates "fail fast" principle

**Rejected**: Too error-prone

### Alternative C: Git Submodule

**Move platform to separate repo, include as submodule**

**Pros**:
- True independence
- Separate version control

**Cons**:
- Submodule complexity (developers hate them)
- Coordination overhead
- Premature optimization

**Rejected**: Overkill for current team size

### Alternative D: Docker Dev Container

**Provide devcontainer.json with pre-installed deps**

**Pros**:
- Consistent environment
- Pre-configured everything

**Cons**:
- Requires Docker knowledge
- Slower development (volume mounts)
- Overkill for Node.js project

**Rejected**: Too heavy for current needs

## Dependency Version Strategy

### Shared Dependencies

Some dependencies exist in both contexts with potentially different versions:

| Package | Root Version | Platform Version | Strategy |
|---------|--------------|------------------|----------|
| **prettier** | ^3.1.0 | ^3.1.0 | Keep in sync (formatting consistency) |
| **typescript** | ^5.3.0 | ^5.3.0 | Keep in sync (type compatibility) |
| **eslint** | ^8.x | - | Root only (LWC linting) |
| **jest** | ^29.x | - | Root only (LWC testing) |
| **turbo** | - | ^2.0.0 | Platform only (monorepo orchestration) |

**Rule**: If a package exists in both, root version is source of truth. Update platform to match.

### Platform-Specific Dependencies

CLI packages have their own runtime dependencies:

```json
// @platform/cli
{
  "dependencies": {
    "commander": "^11.0.0",    // CLI framework
    "chalk": "^5.3.0",         // Terminal colors
    "ora": "^7.0.0"            // Spinners
  }
}

// @platform/sf-client
{
  "dependencies": {
    "jsonwebtoken": "^9.0.0",  // JWT auth
    "axios": "^1.6.0"          // HTTP client
  }
}

// @platform/masking
{
  "dependencies": {
    "@faker-js/faker": "^8.3.0",  // Fake data generation
    "crypto": "^1.0.1"           // FPE encryption
  }
}
```

These are installed in `platform/node_modules/` only (not hoisted to root).

## Troubleshooting

### Issue: "Cannot find module 'turbo'"

**Cause**: Platform dependencies not installed
**Fix**:
```bash
cd platform && npm install
```

### Issue: "Cannot find module '@platform/types'"

**Cause**: Platform not built
**Fix**:
```bash
cd platform && npm run build
```

### Issue: "Different versions of prettier"

**Cause**: Dependency drift between root and platform
**Fix**:
```bash
# Update platform to match root
cd platform
npm install prettier@$(cd .. && node -p "require('./package.json').devDependencies.prettier")
```

### Issue: "Disk space full"

**Cause**: Two node_modules directories
**Fix**:
```bash
# Clean and reinstall
rm -rf node_modules platform/node_modules
npm install  # Postinstall will set up platform
```

## Setup Workflow

### New Developer Setup
```bash
git clone https://github.com/solentra/elaro.git
cd elaro
npm install           # Installs root + platform (via postinstall)
npm run preflight     # Verify workspace
npm run org:create    # Create Salesforce scratch org
```

### Existing Developer Updates
```bash
git pull
npm install           # Re-runs postinstall if package.json changed
npm run preflight     # Verify workspace still valid
```

### CI/CD Setup
```yaml
- name: Install Dependencies
  run: npm ci         # postinstall runs automatically

- name: Verify Workspace
  run: npm run preflight

- name: Build Platform
  run: cd platform && npm run build

- name: Run Tests
  run: npm run test:all
```

## Success Criteria

- [x] Postinstall hook implemented in root package.json
- [ ] Preflight script created and validated
- [ ] Documentation updated with setup workflow
- [ ] New developer can set up in <5 commands
- [ ] Zero "Cannot find module" errors after fresh clone

## References

- npm postinstall hooks: https://docs.npmjs.com/cli/v10/using-npm/scripts
- Law 2: State Over History (Sentinel Architecture v2.0)
- ADR-001: Dual-Repo Strategy
- ADR-002: Monorepo Tooling

## Review History

- 2026-02-02: Proposed by Claude Code (Sentinel Architecture)
- 2026-02-02: Accepted by Derick Porter
