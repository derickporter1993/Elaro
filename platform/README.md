# Platform Monorepo

Node.js tooling and utilities for the Elaro compliance platform.

## Overview

This is a **Turborepo monorepo** containing CLI tools, Salesforce API clients, and data masking utilities for Prometheion/Elaro.

**Architecture**: This platform is independent from the Salesforce codebase (`../force-app/`). See [ADR-001: Dual-Repo Strategy](../docs/architecture/ADR-001-dual-repo-strategy.md).

## Package Structure

```
platform/
├── packages/
│   ├── cli/           # Prometheion CLI (elaro command)
│   ├── types/         # Shared TypeScript types
│   ├── sf-client/     # Salesforce API client library
│   └── masking/       # Data masking engine
├── package.json       # Monorepo orchestration
├── turbo.json         # Turborepo configuration
└── tsconfig.base.json # Shared TypeScript config
```

### Package Dependencies

```
types (no dependencies)
  ↑
  ├─── sf-client
  ├─── masking
  └─── cli
```

Build order: `types` → `sf-client` & `masking` (parallel) → `cli`

## Packages

### @platform/cli

**Command-line interface** for Prometheion operations.

**Commands**:
- `elaro status` - Show Salesforce org status and metrics
- `elaro scan` - Scan codebase for compliance issues
- `elaro validate` - Run pre-deployment validation
- `elaro mask` - Mask sensitive data in exports
- `elaro deploy` - Guided deployment workflow

**Entry point**: `packages/cli/src/index.ts`

### @platform/types

**Shared TypeScript types** used across all packages.

**Key types**:
- `MaskingStrategy`, `MaskingPolicy` - Data masking types
- Salesforce API types (org, metadata, limits)
- CLI command types

**Entry point**: `packages/types/src/index.ts`

### @platform/sf-client

**Salesforce API client library** for authentication and API calls.

**Features**:
- JWT and OAuth authentication
- REST API client
- Tooling API client
- Bulk API client

**Entry point**: `packages/sf-client/src/index.ts`

### @platform/masking

**Data masking engine** for transforming sensitive data.

**Strategies**:
- `redact` - Replace with placeholder (e.g., `[REDACTED]`)
- `hash` - One-way hash (SHA-256, MurmurHash)
- `fake` - Generate realistic fake data (Faker.js)
- `fpe` - Format-preserving encryption (reversible)
- `tokenize` - Replace with tokens (reversible via vault)

**Policy templates**:
- `PII_STANDARD` - Standard PII masking
- `PCI_DSS` - Payment card data compliance
- `HIPAA` - Protected health information
- `DETERMINISTIC` - Same input → same output

**Entry point**: `packages/masking/src/index.ts`

## Setup

### Prerequisites

- Node.js 20+ (`node --version`)
- npm 10+ (`npm --version`)

### Installation

```bash
# From platform/ directory
npm install --ignore-scripts

# Verify installation
ls node_modules/.bin/turbo  # Should exist
```

**Note**: We use `--ignore-scripts` to avoid esbuild postinstall issues (SIGKILL on macOS).

### Build

```bash
# Build all packages (types → clients → cli)
npm run build

# Verify builds
ls packages/*/dist/  # Each should have dist/ folder
```

## Development

### Watch Mode

```bash
# Rebuild on file changes
npm run dev
```

### Build Single Package

```bash
# Build only CLI (and its dependencies)
npm run build -- --filter @platform/cli

# Build only types
npm run build -- --filter @platform/types
```

### Type Checking

```bash
npm run typecheck
```

### Linting

```bash
npm run lint
```

### Formatting

```bash
npm run format        # Fix formatting
npm run format:check  # Check formatting
```

## CLI Usage

### Install CLI Globally

```bash
# From platform directory
cd packages/cli && npm link

# Test installation
elaro --version  # Should show 0.1.0
```

### Run CLI Without Installing

```bash
node packages/cli/dist/index.js --version
```

### From Root

```bash
# From elaro/ root
npm run cli:build    # Build CLI
npm run cli:install  # Link globally
npm run cli          # Run elaro command
```

## Package Scripts

| Script | Description |
|--------|-------------|
| `npm run build` | Build all packages in dependency order |
| `npm run dev` | Watch mode (rebuild on changes) |
| `npm run typecheck` | Check TypeScript types |
| `npm run lint` | Lint all packages |
| `npm run test` | Run tests (future) |
| `npm run format` | Format code with Prettier |
| `npm run format:check` | Check formatting |

## Turborepo Cache

Turborepo caches build outputs for faster rebuilds.

### Clear Cache

```bash
# Force rebuild everything
npm run build -- --force

# Clear Turbo cache directory
rm -rf .turbo
```

### Cache Behavior

- **Cached**: `build`, `typecheck`, `lint`
- **Not cached**: `dev` (watch mode)

## Project References

TypeScript uses [project references](https://www.typescriptlang.org/docs/handbook/project-references.html) for incremental builds.

Each package has:
- `tsconfig.json` (extends `../tsconfig.base.json`)
- References to dependencies in `references` array

**Example** (`packages/cli/tsconfig.json`):
```json
{
  "extends": "../../tsconfig.base.json",
  "references": [
    { "path": "../types" },
    { "path": "../sf-client" }
  ]
}
```

## Adding a New Package

1. Create directory: `packages/new-package/`
2. Add `package.json`:
   ```json
   {
     "name": "@platform/new-package",
     "version": "0.1.0",
     "type": "module",
     "main": "./dist/index.js",
     "types": "./dist/index.d.ts",
     "scripts": {
       "build": "tsc",
       "dev": "tsc --watch"
     }
   }
   ```
3. Add `tsconfig.json` (extend base, add references)
4. Add `src/index.ts` (entry point)
5. Run `npm install` from platform root
6. Build: `npm run build`

## Troubleshooting

### "Cannot find module 'turbo'"

**Cause**: Platform dependencies not installed
**Fix**:
```bash
npm install --ignore-scripts
```

### "Cannot find module '@platform/types'"

**Cause**: Packages not built
**Fix**:
```bash
npm run build
```

### Build hangs or gets SIGKILL

**Cause**: esbuild postinstall script issue
**Fix**: Always use `--ignore-scripts` when installing:
```bash
npm install --ignore-scripts
```

### Different prettier/typescript versions than root

**Cause**: Dependency drift
**Fix**: Sync versions with root:
```bash
# From platform/
npm install prettier@$(cd .. && node -p "require('./package.json').devDependencies.prettier")
npm install typescript@$(cd .. && node -p "require('./package.json').devDependencies.typescript")
```

## Architecture

See architecture documentation in `../docs/architecture/`:

- [ADR-001: Dual-Repo Strategy](../docs/architecture/ADR-001-dual-repo-strategy.md)
- [ADR-002: Monorepo Tooling](../docs/architecture/ADR-002-monorepo-tooling.md)
- [ADR-003: Dependency Management](../docs/architecture/ADR-003-dependency-management.md)

## Contributing

### Code Style

- **TypeScript**: ESM modules with `.js` extensions in imports
- **Formatting**: Prettier (config in `../prettier.config.js`)
- **Linting**: ESLint (future)

### Commit Convention

Follow root repository commit conventions:
```
type(scope): description

Types: feat, fix, docs, refactor, test, chore
Scope: cli, sf-client, masking, types
```

### Testing

(Tests not yet implemented - see roadmap)

## Roadmap

- [ ] Unit tests (Jest or Vitest)
- [ ] Integration tests for sf-client
- [ ] CLI command tests
- [ ] ESLint configuration
- [ ] Publish packages to npm (private registry)
- [ ] Remote Turborepo cache (Vercel)
- [ ] GitHub Actions CI integration

## References

- [Turborepo Documentation](https://turbo.build/repo/docs)
- [TypeScript Project References](https://www.typescriptlang.org/docs/handbook/project-references.html)
- [npm Workspaces](https://docs.npmjs.com/cli/v10/using-npm/workspaces)

---

**Last Updated**: 2026-02-02
**Maintainer**: Derick Porter (@derickporter)
