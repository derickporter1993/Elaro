# Changelog

All notable changes to `elaro-sf-toolkit` will be documented in this file.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] — 2026-05-10

Phase 1: Bootstrap. Verbatim migration of `/home/user/Elaro/.claude/` into an installable plugin. No behavior changes.

### Added
- `.claude-plugin/plugin.json` manifest (name, version, Salesforce API v66.0, ClaudeMd tracking field).
- 5 review agents under `agents/review/`: `sf-security-reviewer`, `sf-governor-analyst`, `sf-test-auditor`, `sf-architecture-reviewer`, `sf-appexchange-checker`.
- Integration QA agent at `agents/agent-8-integration-qa-launch.md`.
- 7 slash commands under `commands/`: `/review`, `/deploy`, `/test`, `/newclass`, `/sfcontext`, `/scratchorg`, `/elaro-status`.
- `settings/settings.template.json` with `Write` permission narrowed from `~/Elaro/**` to `~/Elaro/force-app/**` and `~/Elaro/force-app-healthcheck/**`.
- `README.md`, `LICENSE`.

### Known issues (deferred to later phases)
- `commands/newclass.md` still teaches `WITH SECURITY_ENFORCED`, `JSDoc`, `System.assert`, and API v65.0. **Phase 2** rewrites this command to align with `CLAUDE.md`.
- `commands/review.md` resume protocol has no schema validation, so corrupt state files fail silently. **Phase 6** adds JSON Schema for `.review-state/*.json`.
- No edit-time hooks: standards are checked only at PR review. **Phase 3** adds opt-in PostToolUse warnings via `ELARO_STRICT_HOOKS=1`.
- No fix agents: review is read-only. **Phase 5** adds write-capable counterparts (security-fixer, test-modernizer, async-modernizer, apexdoc-generator).
- No `sf` MCP server: org operations still go through Bash with a 26-entry allowlist. **Phase 4** spikes a community MCP before deciding to build.

### Migration notes
- Settings derived from `.claude/settings.json`. The `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` env var is preserved as-is; confirm with the team whether to keep before Phase 8 cutover.
- The loose `.claude/agents/` and `.claude/commands/` files in the repo remain in place during the coexistence period. Phase 8 archives then deletes them.
