#!/usr/bin/env bash
# =============================================================================
# elaro-finish-loop.sh  —  Elaro submission-readiness engine
# -----------------------------------------------------------------------------
# Spans the LOOP segment of the Elaro pipeline:  deploy -> coverage -> promote.
# Auth is a PRECONDITION (a loop cannot log in). External AppExchange review
# and listing are ESCALATE outputs, not loop steps.
#
# DESIGN PRINCIPLE (non-negotiable):
#   Deterministic gate FIRST. Agent verifier SECOND.
#   - A red deterministic gate is never overridden by an agent.
#   - The agent verifier runs ONLY on a green build, to catch what the number
#     cannot: hollow tests, swallowed exceptions, wrong-root-cause-but-passing.
#   - LLM tokens are spent only at the maker (on failure) or checkers (on green).
#
# Decision Layer routing:  RETRY (maker) | ESCALATE | MERGE (promote)
#
# This runs in YOUR repo with YOUR auth. Point the AGENT_* vars at your actual
# maker/checker invocation (Claude Code headless, Codex, etc.). Syntax-checked,
# but not executed here — no org/auth/repo in this session.
# =============================================================================
set -uo pipefail   # NOT -e: we own every exit path

# ---- Config (override via env) ----------------------------------------------
THRESHOLD_COVERAGE="${ELARO_COVERAGE_MIN:-75}"
MAX_ITERATIONS="${ELARO_MAX_ITER:-8}"
ORG_ALIAS="${ELARO_ORG:-elaro-validation}"
PACKAGE="${ELARO_PACKAGE:-Elaro}"
VERSION_ID="${ELARO_VERSION_ID:?set ELARO_VERSION_ID to the 04t package version to promote}"
WORK=".elaro-loop"
EV="$WORK/evidence"

# Agent contract:
#   MAKER : reads $EV/state.json, edits files in the repo IN PLACE, exits 0.
#   CHECK : reads $EV/state.json, writes verdict JSON {"pass":bool,"reason":str} to stdout.
AGENT_MAKER="${ELARO_AGENT_MAKER:?set ELARO_AGENT_MAKER to your maker agent command}"
AGENT_CHECK_TESTS="${ELARO_AGENT_CHECK_TESTS:?set ELARO_AGENT_CHECK_TESTS to your test-honesty checker}"
AGENT_CHECK_SEC="${ELARO_AGENT_CHECK_SEC:?set ELARO_AGENT_CHECK_SEC to your security checker}"

mkdir -p "$EV"
LAST_FAIL_SIG=""        # for oscillation detection
HACK_COUNT=0            # reward-hack escalation counter

log()      { printf '%s  %s\n' "$(date +%H:%M:%S)" "$*"; }
escalate() { log "ESCALATE → $1"; write_report "ESCALATED" "$1"; exit 2; }

# ---- Evidence assembly ------------------------------------------------------
# Captures which gate failed + the artifacts the maker needs to act.
write_state() {  # $1=failed_gate  $2=detail
  jq -n --arg gate "$1" --arg detail "$2" \
        --arg cov "$(get_coverage 2>/dev/null || echo 0)" \
        --arg iter "$ITER" \
        --slurpfile tests "$EV/test-result.json" 2>/dev/null \
        '{failed_gate:$gate, detail:$detail, coverage:$cov, iteration:$iter}' \
        > "$EV/state.json" 2>/dev/null \
    || jq -n --arg gate "$1" --arg detail "$2" --arg iter "$ITER" \
        '{failed_gate:$gate, detail:$detail, iteration:$iter}' > "$EV/state.json"
}

write_report() {  # $1=status $2=note
  jq -n --arg status "$1" --arg note "$2" --arg pkg "$PACKAGE" \
        --arg ver "$VERSION_ID" --arg cov "$(get_coverage 2>/dev/null || echo n/a)" \
        --arg iter "${ITER:-0}" \
    '{status:$status, note:$note, package:$pkg, version_id:$ver,
      coverage:$cov, iterations:$iter, ts:now|todate}' \
    > "$EV/readiness-report.json"
  log "report → $EV/readiness-report.json"
}

# ---- Deterministic gates (no LLM) -------------------------------------------
gate_auth() {   # PRECONDITION — the auth fork resolves itself right here
  local status
  status=$(sf org display --target-org "$ORG_ALIAS" --json 2>/dev/null \
           | jq -r '.result.connectedStatus // empty')
  [ "$status" = "Connected" ]
}

gate_deploy() {
  sf project deploy start --target-org "$ORG_ALIAS" --json \
    > "$EV/deploy.json" 2>"$EV/deploy.err"
}

gate_static() {  # 0 critical/high findings (SARIF level "error")
  sf code-analyzer run --workspace . \
     --output-file "$EV/analyzer.sarif" >/dev/null 2>"$EV/analyzer.err" || true
  local high
  high=$(jq '[.runs[].results[] | select(.level=="error")] | length' \
         "$EV/analyzer.sarif" 2>/dev/null || echo 999)
  [ "$high" -eq 0 ]
}

run_tests() {
  sf apex run test --target-org "$ORG_ALIAS" --code-coverage \
     --result-format json --wait 30 \
     > "$EV/test-result.json" 2>"$EV/test-result.err"
  return $?   # sf returns nonzero on any test failure
}

get_coverage() {  # NOTE: confirm this path against your CLI version
  jq -r '.result.summary.testRunCoverage // "0"' "$EV/test-result.json" \
    | tr -d '% ' | cut -d. -f1
}

fail_signature() {  # hash of failing tests + first error → detect oscillation
  jq -r '[.result.tests[]? | select(.Outcome=="Fail") | .FullName] | sort | @csv' \
     "$EV/test-result.json" 2>/dev/null | md5sum | cut -d' ' -f1
}

# ---- Reward-hack tripwire (DETERMINISTIC, runs before the checker agents) ----
# Inspects ONLY added lines in changed *Test.cls files. Cheap; no tokens.
reward_hack_tripwire() {
  local changed hits=0 f
  changed=$(git diff --name-only HEAD -- '*Test.cls' 2>/dev/null)
  [ -z "$changed" ] && return 0
  for f in $changed; do
    if git diff HEAD -- "$f" | grep -E '^\+' | grep -qE '@isTest|testMethod'; then
      git diff HEAD -- "$f" | grep -E '^\+' | grep -qE 'System\.assert|Assert\.' \
        || { log "  tripwire: $f adds test code with no assertion"; hits=$((hits+1)); }
    fi
    if git diff HEAD -- "$f" | grep -E '^\+' | grep -qE 'catch *\([A-Za-z]+ +[A-Za-z]+\) *\{ *\}'; then
      log "  tripwire: $f adds empty catch (swallows failures)"; hits=$((hits+1))
    fi
  done
  [ "$hits" -eq 0 ]
}

# ---- Agent verifier (LLM — green builds only) -------------------------------
agent_pass() {  # $1=command  → echoes reason on fail, returns 0/1
  local verdict reason
  verdict=$("$1" "$EV/state.json" 2>/dev/null)
  if [ "$(echo "$verdict" | jq -r '.pass // false')" = "true" ]; then
    return 0
  fi
  reason=$(echo "$verdict" | jq -r '.reason // "no reason given"')
  log "  checker verdict: FAIL — $reason"
  return 1
}

# ---- Preflight: the binding constraint --------------------------------------
ITER=0
log "preflight: auth"
gate_auth || escalate "CLI auth not connected for org '$ORG_ALIAS' — run: sf org login web --alias $ORG_ALIAS"

# =============================================================================
# Main loop
# =============================================================================
for ITER in $(seq 1 "$MAX_ITERATIONS"); do
  log "── iteration $ITER/$MAX_ITERATIONS ──"

  # 1. DEPLOY (cheap, no LLM)
  if ! gate_deploy; then
    log "GATE deploy: FAIL"
    write_state "deploy" "$(tail -c 4000 "$EV/deploy.err" 2>/dev/null)"
    "$AGENT_MAKER" "$EV/state.json"; continue          # RETRY
  fi

  # 2. STATIC ANALYSIS (no LLM)
  if ! gate_static; then
    log "GATE static: FAIL (critical/high findings)"
    write_state "static" "see analyzer.sarif"
    "$AGENT_MAKER" "$EV/state.json"; continue          # RETRY
  fi

  # 3. TESTS + COVERAGE (no LLM — the real promotion gate)
  TESTS_OK=true; run_tests || TESTS_OK=false
  COV=$(get_coverage)
  if [ "$TESTS_OK" = false ] || [ "${COV:-0}" -lt "$THRESHOLD_COVERAGE" ]; then
    SIG=$(fail_signature)
    if [ -n "$SIG" ] && [ "$SIG" = "$LAST_FAIL_SIG" ]; then
      escalate "oscillation — identical test failures two iterations running; maker is stuck"
    fi
    LAST_FAIL_SIG="$SIG"
    log "GATE tests/coverage: FAIL (tests_ok=$TESTS_OK coverage=${COV}% < ${THRESHOLD_COVERAGE}%)"
    write_state "coverage" "tests_ok=$TESTS_OK coverage=${COV}"
    "$AGENT_MAKER" "$EV/state.json"; continue          # RETRY
  fi
  log "deterministic gates GREEN (coverage ${COV}%)"

  # 4. REWARD-HACK TRIPWIRE (deterministic, before any agent spend)
  if ! reward_hack_tripwire; then
    HACK_COUNT=$((HACK_COUNT+1))
    [ "$HACK_COUNT" -ge 2 ] && escalate "maker gamed coverage twice (hollow tests / swallowed errors)"
    log "tripwire FAIL — routing maker to write REAL assertions"
    write_state "reward_hack" "added tests lack assertions or swallow exceptions; write real System.assert checks"
    "$AGENT_MAKER" "$EV/state.json"; continue          # RETRY (targeted)
  fi

  # 5. AGENT VERIFIERS (LLM — catch what a green number cannot)
  write_state "verify" "green build; confirm quality"
  if ! agent_pass "$AGENT_CHECK_TESTS"; then            # test-honesty
    "$AGENT_MAKER" "$EV/state.json"; continue           # RETRY
  fi
  if ! agent_pass "$AGENT_CHECK_SEC"; then              # Link_Token__c / ProtectSensitiveData
    "$AGENT_MAKER" "$EV/state.json"; continue           # RETRY
  fi

  # 6. MERGE — promote the version, then ESCALATE for the human submit
  log "ALL GATES + AGENTS PASS — promoting $VERSION_ID"
  if sf package version promote --package "$VERSION_ID" --no-prompt --json \
       > "$EV/promote.json" 2>"$EV/promote.err"; then
    write_report "READY" "released version + coverage ${COV}% + 0 crit/high + agents passed"
    log "MERGE complete. Engine done."
    escalate "SUBMISSION-READY — submit to Salesforce AppExchange security review (external, unbounded). See readiness-report.json"
  else
    escalate "promote failed — $(tail -c 2000 "$EV/promote.err")"
  fi
done

escalate "hit MAX_ITERATIONS=$MAX_ITERATIONS without reaching the gate — review evidence/ and tune"
