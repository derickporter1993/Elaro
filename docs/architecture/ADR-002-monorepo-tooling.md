# ADR-002: Monorepo Tooling

**Status**: Accepted
**Date**: 2026-02-02
**Deciders**: Derick Porter, Claude Code (Sentinel Architecture)

## Context

The `platform/` directory contains 4 interconnected Node.js packages:
- `@platform/cli` - Command-line interface (depends on: types, sf-client)
- `@platform/sf-client` - Salesforce API client (depends on: types)
- `@platform/masking` - Data masking engine (depends on: types)
- `@platform/types` - Shared TypeScript types (no dependencies)

**Requirements**:
1. Build packages in dependency order (types → clients → cli)
2. Run commands across multiple packages (test, lint, typecheck)
3. Cache build outputs to avoid redundant work
4. Support incremental development (watch mode)
5. Simple developer experience (`npm run build` just works)

**Constraints**:
- Team size: 1-2 developers (can't maintain complex tooling)
- TypeScript native (ESM modules with NodeNext resolution)
- npm as package manager (already in use at root)
- Must work on macOS (primary development environment)

## Decision

**We will use Turborepo for monorepo orchestration with npm workspaces.**

### Tooling Stack

| Tool | Purpose | Why |
|------|---------|-----|
| **npm workspaces** | Package linking | Built into npm, zero config |
| **Turborepo** | Build orchestration | Caching, parallelization, task pipelines |
| **TypeScript** | Compilation | Project references for incremental builds |
| **ESLint** | Linting | Shared config across packages |
| **Prettier** | Formatting | Unified code style |

### Configuration

**`platform/package.json`**:
```json
{
  "workspaces": ["packages/*"],
  "scripts": {
    "build": "turbo run build",
    "dev": "turbo run dev",
    "test": "turbo run test",
    "typecheck": "turbo run typecheck",
    "lint": "turbo run lint"
  }
}
```

**`platform/turbo.json`**:
```json
{
  "tasks": {
    "build": {
      "dependsOn": ["^build"],      // Build deps first
      "outputs": ["dist/**"],        // Cache dist/ folders
      "cache": true
    },
    "dev": {
      "cache": false,
      "persistent": true
    },
    "typecheck": {
      "dependsOn": ["^build"],
      "cache": true
    }
  }
}
```

**`platform/tsconfig.base.json`**:
```json
{
  "compilerOptions": {
    "module": "NodeNext",
    "moduleResolution": "NodeNext",
    "composite": true,              // Enable project references
    "declarationMap": true          // Enable jump-to-source
  }
}
```

## Consequences

### Positive ✅

- **Correct build order**: Turbo respects `dependsOn`, builds types before CLI
- **Fast incremental builds**: Caches unchanged packages
- **Simple commands**: `npm run build` builds everything
- **Parallel execution**: Independent packages build simultaneously
- **Watch mode**: `npm run dev` rebuilds on file changes
- **Filtering**: `npm run build --filter @platform/cli` builds only CLI
- **Zero configuration**: Turbo auto-discovers packages via workspaces

### Negative ⚠️

- **Additional dependency**: Turbo adds 20MB to node_modules
- **Learning curve**: Developers must understand Turbo concepts (tasks, caching)
- **Debugging complexity**: Build failures span multiple packages
- **Cache invalidation**: Occasionally need `turbo run build --force`
- **esbuild issue**: Turbo uses esbuild, which has SIGKILL issues (mitigated via `--ignore-scripts`)

### Neutral 🔵

- **Not the only option**: Could use Lerna, Nx, or plain npm workspaces
- **Overkill for 4 packages**: Benefits increase with more packages
- **Caching mostly local**: Remote caching (Vercel) not needed yet

## Alternatives Considered

### Alternative A: Lerna

**Pros**:
- Mature, battle-tested
- Independent versioning/publishing built-in
- Used by Babel, Jest, React

**Cons**:
- Heavier than Turbo (more features we don't need)
- Slower builds (no caching by default)
- More complex configuration
- Publishing focus (we're not publishing yet)

**Rejected**: Too much tooling for our needs

### Alternative B: Nx

**Pros**:
- Most powerful (computation caching, affected commands, code generation)
- Excellent for large monorepos (100+ packages)
- Strong TypeScript integration

**Cons**:
- Overkill for 4 packages
- Steep learning curve
- Heavy tooling investment
- Complex configuration

**Rejected**: Over-engineering for current scale

### Alternative C: Plain npm Workspaces

**Pros**:
- Zero dependencies
- Simple mental model
- Works everywhere npm works

**Cons**:
- No caching (rebuild everything every time)
- No parallelization (manual with `npm run build --workspaces`)
- No dependency ordering (must specify manually)
- No watch mode across packages

**Rejected**: Too manual, slow builds

### Alternative D: pnpm Workspaces

**Pros**:
- Faster installs than npm
- Stricter dependency management (phantom deps)
- Better disk space efficiency

**Cons**:
- Requires switching package manager
- Some tools have npm-specific assumptions
- Migration effort
- Team must learn pnpm quirks

**Rejected**: Not enough benefit to justify migration

## Implementation Details

### Build Process

```bash
# Developer runs:
cd platform/
npm install        # Sets up workspaces
npm run build      # Turbo builds all packages

# Turbo executes:
1. Analyze dependencies (types → sf-client, masking → cli)
2. Build types first (no deps)
3. Build sf-client + masking in parallel
4. Build cli last
5. Cache all dist/ outputs
```

### Development Workflow

```bash
# Watch mode for active development
npm run dev

# Build single package
npm run build --filter @platform/cli

# Type checking
npm run typecheck

# Lint
npm run lint
```

### CI/CD Integration

```yaml
# .github/workflows/platform.yml
- name: Build Platform
  run: |
    cd platform
    npm ci
    npm run build
    npm run typecheck
    npm run lint
```

## Migration Path

### Completed
- [x] Turbo installed as devDependency
- [x] `turbo.json` configured with task pipeline
- [x] Package scripts updated to use `turbo run`
- [x] TypeScript project references configured

### Remaining
- [ ] Document Turbo cache behavior in platform README
- [ ] Add cache clearing instructions to troubleshooting
- [ ] Test remote caching (defer until team grows)
- [ ] Set up Turbo telemetry opt-out (privacy)

## Success Criteria

- [x] `npm run build` completes without errors
- [x] Packages build in correct order (types first)
- [x] Subsequent builds use cache (2-5x faster)
- [ ] CI builds complete in <2 minutes
- [ ] Developers understand when to use `--force`

## References

- Turborepo Documentation: https://turbo.build/repo/docs
- npm Workspaces: https://docs.npmjs.com/cli/v10/using-npm/workspaces
- TypeScript Project References: https://www.typescriptlang.org/docs/handbook/project-references.html
- Monorepo Tools Comparison: https://monorepo.tools/

## Review History

- 2026-02-02: Proposed by Claude Code (Sentinel Architecture)
- 2026-02-02: Accepted by Derick Porter
- 2026-02-02: Updated with `--ignore-scripts` workaround for esbuild issue
