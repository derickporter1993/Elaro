# settings/

`settings.template.json` is the recommended Claude Code settings shape for projects using `elaro-sf-toolkit`. It is **not** automatically merged into a project's `.claude/settings.json` — it's a reference. Phase 8 of the rollout plan introduces a thin lockfile pointer (`/home/user/Elaro/.claude/plugin-lock.json`) and shrinks the project-level settings file.

## What changed from the original `/home/user/Elaro/.claude/settings.json`

| Field | Before | After | Why |
|---|---|---|---|
| `permissions.allow` includes `Write(~/Elaro/**)` | broad | replaced with scoped writes to `force-app/**`, `force-app-healthcheck/**`, `elaro-sf-toolkit/**`, and `.review-state/**` | Avoid accidental writes to `node_modules/`, `platform/dist/`, or git internals |
| `permissions.deny` | 11 entries | 12 entries; added `Bash(git push --force-with-lease*)` and `Bash(sfdx*)` | Block deprecated `sfdx` CLI globally; force-with-lease is still rewriting history |
| `customInstructions` | references `agent_docs/` | references `elaro-sf-toolkit/` | Plugin is the new source of agent/command definitions |
| `rules[3].description` | "JSDoc" | "ApexDoc (@author, @since, @group, @param, @return, @throws)" | Match `CLAUDE.md` line 211 — Apex uses ApexDoc, not JSDoc |
| `includePatterns` | force-app only | adds `force-app-healthcheck/**` and `elaro-sf-toolkit/**` | Health Check is a separate 2GP namespace; toolkit needs to be searchable |

## What stayed the same

- `customInstructions` overall structure
- `rules[0..2]` unchanged
- `env` block unchanged (including `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` — confirm with team before Phase 8 cutover whether this experimental flag is still desired)
- All `Bash(sf …)`, `Bash(npm …)`, `Bash(git …)` allow entries
- `ignorePatterns` unchanged
- `experimental` block unchanged

## How to use during the coexistence period

1. Keep `/home/user/Elaro/.claude/settings.json` as it is (the team's existing settings continue to work).
2. Optionally `diff` it against this template to see what will change at cutover.
3. At Phase 8 cutover, replace `.claude/settings.json` with a slim file that points to this template plus per-developer overrides.
