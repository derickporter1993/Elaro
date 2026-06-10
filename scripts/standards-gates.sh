#!/usr/bin/env bash
#
# standards-gates.sh — mechanical enforcement of the CLAUDE.md standards added after the
# 2026-06-05 audit. Runs every grep gate across ALL package roots (the rule that the
# original audit and CI both violated by scoping to force-app/ only).
#
# Usage:
#   scripts/standards-gates.sh            # fail (exit 1) on any violation
#   scripts/standards-gates.sh --report   # report only, always exit 0 (for the rollout period)
#
# Wire into CI (.github/workflows/elaro-ci.yml) and `npm run precommit`. During the
# remediation backlog, run with --report; flip to blocking once gates 1/3/6/7 are clean.

set -uo pipefail

ROOTS=()
# Enumerate package roots from sfdx-project.json (never hardcode a single root).
while IFS= read -r p; do ROOTS+=("$p"); done < <(grep -oE '"path"\s*:\s*"[^"]+"' sfdx-project.json | sed -E 's/.*"path"\s*:\s*"([^"]+)".*/\1/' | sort -u)
[ ${#ROOTS[@]} -eq 0 ] && ROOTS=("force-app" "force-app-healthcheck")

REPORT_ONLY=0
[ "${1:-}" = "--report" ] && REPORT_ONLY=1

# Failure marker file — survives the subshells created by `grep ... | hit` pipelines
# (a plain FAIL=1 inside a piped function runs in a subshell and would not propagate).
FAILMARK="$(mktemp)"
trap 'rm -f "$FAILMARK"' EXIT

hit() { # $1 = gate name, $2 = explanation; reads matches from stdin
  local matches; matches="$(cat)"
  if [ -n "$matches" ]; then
    echo "::error::[standards-gate] $1"
    echo "  $2"
    echo "$matches" | sed 's/^/    /'
    echo "1" >> "$FAILMARK"
  else
    echo "  ok: $1"
  fi
}

echo "=== standards-gates.sh over roots: ${ROOTS[*]} ==="

# Gate 1: UserInfo.getSessionId() — AppExchange auto-fail (callout auth must be Named Credential)
grep -rn "getSessionId" "${ROOTS[@]}" --include="*.cls" 2>/dev/null | grep -v "Test\.cls" \
  | hit "no UserInfo.getSessionId()" "Use a Named/External Credential for callout auth (CLAUDE.md #5)."

# Gate 2: WITH SECURITY_ENFORCED — removed at v67, migrate to WITH USER_MODE
grep -rn "WITH SECURITY_ENFORCED" "${ROOTS[@]}" --include="*.cls" --include="*.trigger" 2>/dev/null \
  | hit "no WITH SECURITY_ENFORCED" "Migrate to WITH USER_MODE (removed in API v67)."

# Gate 3: System.debug( CALLS (not doc comments) in production classes/triggers — use ElaroLogger/HCLogger.
# Excludes lines that are comments (* or //) and the logger classes themselves (which wrap it, NOPMD-annotated).
grep -rnE "^[^*/]*System\.debug\s*\(" "${ROOTS[@]}" --include="*.cls" --include="*.trigger" 2>/dev/null \
  | grep -v "Test\.cls" | grep -v "NOPMD" \
  | grep -vE "/(ElaroLogger|HCLogger)\.cls:" \
  | hit "no System.debug() in production code" "Use ElaroLogger/HCLogger; annotate intentional ones with // NOPMD. (HCLogger needs the same NOPMD treatment as ElaroLogger.)"

# Gate 4: raw-string SOQL filter concatenation — push to SafeSoqlBuilder.
# Excludes String.join(...) (the sanctioned structured-predicate pattern) and SafeSoqlBuilder
# itself (the canonical builder); the target is `' WHERE ' + <rawStringVar>`.
grep -rnE "' (WHERE|AND|OR) ' \+|\+ ' (WHERE|AND|OR) '" "${ROOTS[@]}" --include="*.cls" 2>/dev/null \
  | grep -v "Test\.cls" | grep -v "String\.join" | grep -v "/SafeSoqlBuilder\.cls:" \
  | hit "no raw-string SOQL filter concatenation" "Use SafeSoqlBuilder (structured field+operator+bind) (CLAUDE.md #7)."

# Gate 5: fabricated compliance results — hardcoded pass / placeholder score in live code
grep -rnE "passed\s*=\s*true;\s*//\s*(Simplified|Placeholder|TODO|stub)|=\s*[0-9]+;\s*//\s*Placeholder" "${ROOTS[@]}" --include="*.cls" 2>/dev/null \
  | grep -v "Test\.cls" \
  | hit "no fabricated compliance results" "Compute from real signals or report NOT_EVALUATED (CLAUDE.md #1)."

# Gate 6: placeholder logic in shipped code
grep -rniE "in production, (this )?would|not recommended for production|for now, return" "${ROOTS[@]}" --include="*.cls" 2>/dev/null \
  | grep -v "Test\.cls" \
  | hit "no placeholder logic in shipped code" "Implement, or gate behind a flag defaulting OFF (CLAUDE.md #10)."

# Gate 7: fail-open auth — blank-secret returns true
grep -rn -A2 "isBlank.*Secret\|Secret.*isBlank" "${ROOTS[@]}" --include="*.cls" 2>/dev/null \
  | grep -iE "return true" \
  | hit "no fail-open auth gate" "A blank/missing secret must deny (return false / 401) (CLAUDE.md #3)."

# Gate 8: target="_blank" without rel
for r in "${ROOTS[@]}"; do
  grep -rln 'target="_blank"' "$r" --include="*.html" 2>/dev/null | while read -r f; do
    grep -q 'rel=' "$f" || echo "$f: target=\"_blank\" without rel=\"noopener noreferrer\""
  done
done | hit "target=_blank requires rel=noopener" "Add rel=\"noopener noreferrer\" (CLAUDE.md #12)."

# Gate 9: Public CMDT carrying executable content (SOQL/Apex class name)
for r in "${ROOTS[@]}"; do
  for obj in "$r"/main/default/objects/*__mdt; do
    [ -d "$obj" ] || continue
    meta="$obj/$(basename "$obj").object-meta.xml"
    grep -q "<visibility>Public</visibility>" "$meta" 2>/dev/null || continue
    if ls "$obj"/fields/ 2>/dev/null | grep -qiE "Query|SOQL|Service_Class|Expression|Apex"; then
      echo "$(basename "$obj"): Public CMDT carries executable content (SOQL/class-name field)"
    fi
  done
done | hit "executable CMDT must be Protected" "Set <visibility>Protected</visibility> (CLAUDE.md #6)."

# ============================================================================
# platform/ TypeScript gates (the monorepo shipped alongside the package).
# Added after the 2026-06-05 three-target sweep found weak crypto in the
# masking library and a command-injection pattern in the CLI.
# ============================================================================
if [ -d platform/packages ]; then
  TS_SRC=(platform/packages/*/src)

  # Gate 10: Math.random() for tokens/secrets/salts — not cryptographically secure.
  # Finding: masking tokenize.ts predictable vault tokens; hash.ts weak salt.
  grep -rnE "Math\.random\(\)" "${TS_SRC[@]}" 2>/dev/null \
    | grep -iE "token|salt|secret|key|nonce|iv|id|password" \
    | hit "no Math.random() for tokens/secrets/salts" "Use crypto.randomBytes/randomUUID (CLAUDE.md #10)."

  # Gate 11: non-cryptographic hash used where PII/de-identification is implied.
  # Finding: masking hash.ts offers murmur3 for PII hashing (reversible/brute-forceable).
  grep -rnE "murmur|md5|sha1[^0-9]" "${TS_SRC[@]}" 2>/dev/null \
    | grep -viE "//|comment|sha1[0-9]" \
    | hit "no weak hash (murmur3/md5/sha1) in masking/PII paths" "Use sha256+ for PII hashing (CLAUDE.md #10)."

  # Gate 12: home-rolled crypto in masking — admitted non-production ciphers.
  grep -rniE "simplified implementation|for production:|home-?rolled|not production" platform/packages/masking/src 2>/dev/null \
    | hit "no home-rolled/placeholder crypto in masking" "Use a vetted library (e.g. FF1/FF3-1) (CLAUDE.md #10)."

  # Gate 13: shell command built by string interpolation of a variable (injection).
  # Finding: cli/org.ts execSync(`sf org delete -o ${options.targetOrg} ...`) unsanitized.
  grep -rnE "(execSync|exec)\(\s*\`[^\`]*\\\$\{" platform/packages/cli/src 2>/dev/null \
    | hit "no shell command built from interpolated variables" "Use spawn(cmd, [args]) or validate the value first (CLAUDE.md #5-adjacent)."
fi

echo ""
if [ -s "$FAILMARK" ] && [ "$REPORT_ONLY" -eq 0 ]; then
  echo "standards-gates: FAIL ($(wc -l < "$FAILMARK") gate(s) tripped)"
  exit 1
fi
if [ -s "$FAILMARK" ]; then
  echo "standards-gates: $(wc -l < "$FAILMARK") gate(s) tripped (report-only — not failing the build)"
else
  echo "standards-gates: all gates clean"
fi
exit 0
