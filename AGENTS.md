# AGENTS.md

## Cursor Cloud specific instructions

Elaro is a Salesforce second-generation managed package plus a separate TypeScript
platform CLI. There are two independently developed surfaces in this repo:

1. **Salesforce package** (`force-app`, `force-app-healthcheck`) — Apex + Lightning Web
   Components. Lint, format, and LWC Jest tests run locally with no org. Deploying
   metadata and running Apex tests require the `sf` CLI plus an authenticated Dev
   Hub/scratch org, which are **not available in this environment** (no Salesforce
   credentials and `sf` is not installed). Treat all `sf ...` / `org:*` / `sf:*` /
   `test:apex` scripts as out of scope here.
2. **Platform CLI** (`platform/`) — a Turborepo (`packages/{types,sf-client,masking,cli}`)
   that builds the `elaro` CLI. This is the locally runnable application.

The update script already runs `npm ci` (root, which also installs `platform/` deps via
the `postinstall` hook) and creates the gitignored `specs/` directory. Standard commands
live in `README.md`, `platform/README.md`, and `package.json` / `platform/package.json`
scripts — prefer those instead of duplicating here.

### Non-obvious gotchas

- **`npm run precommit` / `npm run preflight` need a `specs/` directory.** It is
  gitignored (see `.gitignore`), so a fresh checkout has none and `scripts/preflight.sh`
  fails with "Missing specs/ directory". The update script creates it (`mkdir -p specs`);
  if it is ever missing, recreate it.
- **Platform deps are installed with `--ignore-scripts`** (root `postinstall` and
  `platform/README.md`) to avoid an esbuild postinstall SIGKILL. The root `postinstall`
  only installs `platform/node_modules` when it is absent, so if you change deps under
  `platform/`, reinstall manually: `npm --prefix platform install --ignore-scripts`.
- The first `npm ci` on a fresh VM leaves `platform/package-lock.json` modified (a benign
  side effect of the `postinstall`'s `npm install`). Revert it with
  `git checkout -- platform/package-lock.json` before committing.
- **`platform/docker-compose.yml` is not runnable in this repo.** It references
  `services/core` and `apps/web` Dockerfiles that do not exist (only `packages/*` are
  present). Use the CLI, not docker compose.
- **The `elaro` CLI runs fully offline.** Commands like `elaro scan` attempt an `sf apex run`
  but catch the failure and return simulated results, so they work without an org.

### Run the platform CLI

```bash
cd platform
npm run build                                   # builds all packages in dep order
node packages/cli/dist/index.js --help
node packages/cli/dist/index.js scan --framework hipaa
```

### Local quality gates

- Salesforce surface (from repo root): `npm run fmt:check`, `npm run lint`,
  `npm run test:unit` (901 LWC Jest tests). `npm run precommit` chains preflight + the
  above (needs `specs/`).
- Platform surface (from `platform/`): `npm run build`, `npm run typecheck`,
  `npm run lint`, `npm run test` (Vitest; no test files yet, passes with
  `--passWithNoTests`).
