# elaro-sf-toolkit

Claude Code plugin packaging the Elaro Salesforce 2GP development workflow: review agents, slash commands, and the standards from `CLAUDE.md` (Spring '26, API v66.0).

## Status

**v0.1.0 — Phase 1 (Bootstrap).** Verbatim migration of the existing `/home/user/Elaro/.claude/` extensions into an installable plugin layout. Behavior is identical to the loose `.claude/` files; this release exists so the team can install side-by-side and verify parity before later phases add hooks, fix agents, MCP, and skills.

See `CHANGELOG.md` for the full release history and `docs/team2-build-plan.md` (in the parent repo) for upstream module context.

## What ships in v0.1.0

| Asset | Path | Source |
|---|---|---|
| 5 review agents | `agents/review/` | migrated from `.claude/agents/` |
| 1 integration QA agent | `agents/agent-8-integration-qa-launch.md` | migrated from `.claude/agents/` |
| 7 slash commands | `commands/` | migrated from `.claude/commands/` |
| Settings template | `settings/settings.template.json` | derived from `.claude/settings.json`, with `Write` narrowed |

The empty `agents/fix/`, `skills/`, `hooks/`, and `mcp/` directories are placeholders for Phases 3–6.

## Install (local, side-by-side with `.claude/`)

From the repo root:

```bash
# Coexistence period: plugin loads alongside .claude/ loose files.
# Resolve any name collisions during validation; commands/agents in this
# plugin will be promoted to canonical names in Phase 8.
claude plugin install ./elaro-sf-toolkit
```

Phase 8 (rollout) replaces the loose `.claude/agents/` and `.claude/commands/` entirely.

## Standards source of truth

Every agent, command, and template in this plugin must align with `/home/user/Elaro/CLAUDE.md`. When the standards in `CLAUDE.md` change, bump this plugin's minor version and update the affected files in lockstep. CI (added in Phase 8) will fail the build if forbidden patterns reappear in plugin templates.

Key non-negotiables (full list in `CLAUDE.md`):

- SOQL: `WITH USER_MODE` (never `WITH SECURITY_ENFORCED`)
- DML: `as user` or `AccessLevel.USER_MODE`
- Dynamic SOQL: `Database.queryWithBinds()` only
- Tests: `Assert` class (never `System.assertEquals`)
- Async: Queueable + Cursors (never `@future`)
- Sharing: explicit on every class
- ApexDoc: `@author`, `@since`, `@group` required
- API: v66.0 for new code
- LWC: `lwc:if` (never `if:true`), Custom Labels for all strings
- CLI: `sf` (never `sfdx`)

## Roadmap

| Phase | Goal | Status |
|---|---|---|
| 1 | Bootstrap + verbatim migration | this release |
| 2 | Rewrite `/newclass` to match `CLAUDE.md` | planned |
| 3 | Edit-time hooks (opt-in via `ELARO_STRICT_HOOKS=1`) | planned |
| 4 | `sf` CLI MCP server (community spike first) | planned |
| 5 | Fix agents (security, test, async, ApexDoc) | planned |
| 6 | Skills (compliance, 2GP, Spring '26, schema) | planned |
| 7 | Slash command improvements | planned |
| 8 | Migration and rollout | planned |

## Contributing

This plugin is internal to the Elaro team. Public marketplace release is deferred until v1.0.0 pending SME review of compliance content and namespace hardening.
