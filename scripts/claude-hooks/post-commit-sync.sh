#!/usr/bin/env bash
#
# Claude Code PostToolUse hook (Bash matcher) -- post-commit branch sync prompt.
#
# Fires after every Bash tool call. When the command was a `git commit`, it
# emits hook context that asks Claude to prompt the user (via AskUserQuestion)
# for how to synchronize their branches -- current branch, local main, and the
# remote -- before continuing.
#
# IMPORTANT: this script never runs git itself. It only injects a prompt for
# Claude. The actual push / fetch / merge is performed by Claude *after the
# user explicitly chooses an option*, which preserves the project rule
# "never push to a branch other than the feature branch without permission."
#
# Input : PostToolUse hook JSON on stdin; .tool_input.command holds the command.
# Output: optional JSON on stdout (hookSpecificOutput.additionalContext).

set -uo pipefail

payload="$(cat)"
cmd="$(printf '%s' "$payload" | jq -r '.tool_input.command // ""' 2>/dev/null || true)"

# Match a real `git commit` invocation: at the start of the command or right
# after a shell separator (;, &, &&, |, ||), and not a dry-run or help call.
is_commit_re='(^|[;&|])[[:space:]]*git[[:space:]]+commit([[:space:]]|$)'

if printf '%s' "$cmd" | grep -Eq "$is_commit_re" \
  && ! printf '%s' "$cmd" | grep -Eq -- '(--dry-run|--help)'; then

  read -r -d '' ctx <<'CTX' || true
A git commit just completed. The user configured a post-commit sync workflow:
before doing anything else, ASK them how to synchronize their branches using
the AskUserQuestion tool. Present these options:

1. "Push current branch" -> run: git push -u origin HEAD
   (keeps the local branch and its remote copy in sync; does NOT touch main).
2. "Update local main" -> run: git fetch origin main, then fast-forward the
   local main ref to origin/main (e.g. git fetch origin main:main when main is
   not checked out, otherwise git merge --ff-only origin/main). Never pushes
   to main.
3. "Push current + push main" -> push the current branch, then merge it into
   main and push main. WARN that this conflicts with the project's
   branch-protection rule ("never push to a branch other than the feature
   branch without permission") and only proceed on explicit confirmation.
4. "Skip" -> do nothing.

After the user chooses, run ONLY the git commands for that option. Never push
to main without an explicit confirmation in this same turn.
CTX

  jq -n --arg ctx "$ctx" '{
    hookSpecificOutput: {
      hookEventName: "PostToolUse",
      additionalContext: $ctx
    }
  }'
fi
