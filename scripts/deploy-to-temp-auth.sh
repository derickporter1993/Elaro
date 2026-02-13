#!/bin/bash
# =============================================================================
# Elaro Full Deployment to temp-auth
#
# Phased deployment with dependency ordering to avoid "missing deps" failures.
# Deploys both the main Elaro package and the Health Check package.
#
# Usage:
#   ./scripts/deploy-to-temp-auth.sh                   # Full deploy + tests
#   ./scripts/deploy-to-temp-auth.sh --dry-run          # Validate only
#   ./scripts/deploy-to-temp-auth.sh --skip-tests       # Deploy without tests
#   ./scripts/deploy-to-temp-auth.sh --skip-healthcheck  # Skip Health Check pkg
#
# =============================================================================

set -uo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
ORG_ALIAS="temp-auth"
WAIT_TIME=30
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FORCE_APP="$PROJECT_ROOT/force-app/main/default"
FORCE_APP_HC="$PROJECT_ROOT/force-app-healthcheck/main/default"

# ---------------------------------------------------------------------------
# Parse arguments
# ---------------------------------------------------------------------------
DRY_RUN=false
SKIP_TESTS=false
SKIP_HC=false

for arg in "$@"; do
    case $arg in
        --dry-run)          DRY_RUN=true ;;
        --skip-tests)       SKIP_TESTS=true ;;
        --skip-healthcheck) SKIP_HC=true ;;
        --help|-h)
            echo "Usage: $0 [--dry-run] [--skip-tests] [--skip-healthcheck]"
            exit 0
            ;;
        *)
            echo "Unknown argument: $arg"
            echo "Usage: $0 [--dry-run] [--skip-tests] [--skip-healthcheck]"
            exit 1
            ;;
    esac
done

# ---------------------------------------------------------------------------
# Color helpers
# ---------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ---------------------------------------------------------------------------
# Phase tracking
# ---------------------------------------------------------------------------
declare -a PHASE_RESULTS=()
FAILED=false

log_header() {
    echo ""
    echo -e "${BLUE}==========================================${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}==========================================${NC}"
}

# ---------------------------------------------------------------------------
# deploy_phase <phase_name> <source_dir> [<source_dir> ...]
#
# Deploys one or more source directories as a single deployment unit.
# Skips directories that don't exist. Tracks pass/fail in PHASE_RESULTS.
# ---------------------------------------------------------------------------
deploy_phase() {
    local phase_name="$1"
    shift
    local source_dirs=("$@")

    log_header "Phase $phase_name"

    # Build the command with only existing directories
    local cmd="sf project deploy start --target-org $ORG_ALIAS --wait $WAIT_TIME"
    if [ "$DRY_RUN" = true ]; then
        cmd="$cmd --dry-run"
    fi

    local has_dirs=false
    for dir in "${source_dirs[@]}"; do
        if [ -d "$dir" ]; then
            cmd="$cmd --source-dir $dir"
            has_dirs=true
            echo -e "  Source: ${dir#$PROJECT_ROOT/}"
        else
            echo -e "  ${YELLOW}SKIP (not found): ${dir#$PROJECT_ROOT/}${NC}"
        fi
    done

    if [ "$has_dirs" = false ]; then
        echo -e "  ${YELLOW}No directories to deploy, skipping phase${NC}"
        PHASE_RESULTS+=("SKIP: $phase_name (no source directories)")
        return 0
    fi

    echo ""
    if eval "$cmd"; then
        echo -e "  ${GREEN}PASSED: $phase_name${NC}"
        PHASE_RESULTS+=("PASS: $phase_name")
        return 0
    else
        echo -e "  ${RED}FAILED: $phase_name${NC}"
        PHASE_RESULTS+=("FAIL: $phase_name")
        FAILED=true
        return 1
    fi
}

# ===========================================================================
# PHASE 0: Pre-flight validation
# ===========================================================================
log_header "Phase 0: Pre-flight Validation"

echo "  Target org: $ORG_ALIAS"
echo "  Mode: $([ "$DRY_RUN" = true ] && echo 'DRY RUN (validate only)' || echo 'LIVE DEPLOY')"
echo "  Tests: $([ "$SKIP_TESTS" = true ] && echo 'SKIPPED' || echo 'Will run after deploy')"
echo "  Health Check pkg: $([ "$SKIP_HC" = true ] && echo 'SKIPPED' || echo 'Included')"
echo ""

echo "  Verifying org connection..."
if ! sf org display --target-org "$ORG_ALIAS" 2>&1 | head -20; then
    echo ""
    echo -e "  ${RED}ERROR: Cannot connect to $ORG_ALIAS${NC}"
    echo -e "  ${RED}Run: sf org login web -a $ORG_ALIAS${NC}"
    exit 1
fi
echo -e "  ${GREEN}Org connection verified${NC}"
PHASE_RESULTS+=("PASS: 0 - Pre-flight")

# ===========================================================================
# PHASE 1: Foundation — Objects, Labels, Cache, Notifications
#
# Custom objects, custom metadata type definitions, platform events, big
# objects, standard object field extensions, custom labels, cache partitions,
# and notification types. These must exist before any Apex code references them.
# ===========================================================================
deploy_phase "1 - Foundation (Objects, Labels, Cache)" \
    "$FORCE_APP/objects" \
    "$FORCE_APP/labels" \
    "$FORCE_APP/cachePartitions" \
    "$FORCE_APP/notificationtypes" \
    || { echo -e "${RED}Phase 1 failed. Cannot continue without foundation objects.${NC}"; exit 1; }

# ===========================================================================
# PHASE 2: Custom Metadata Records
#
# 139 CMT records that depend on the type definitions deployed in Phase 1.
# ===========================================================================
deploy_phase "2 - Custom Metadata Records" \
    "$FORCE_APP/customMetadata" \
    || { echo -e "${RED}Phase 2 failed. CMT records could not be deployed.${NC}"; exit 1; }

# ===========================================================================
# PHASE 3: Apex Classes
#
# All 349 Apex classes (production + test). SF CLI resolves intra-class
# dependencies internally as long as all referenced objects exist.
# ===========================================================================
deploy_phase "3 - Apex Classes" \
    "$FORCE_APP/classes" \
    || { echo -e "${RED}Phase 3 failed. Apex classes could not compile.${NC}"; exit 1; }

# ===========================================================================
# PHASE 4: Apex Triggers
#
# Depend on objects (Phase 1) and handler classes (Phase 3).
# ===========================================================================
deploy_phase "4 - Apex Triggers" \
    "$FORCE_APP/triggers" \
    || { echo -e "${YELLOW}Phase 4 failed. Triggers could not deploy. Continuing...${NC}"; }

# ===========================================================================
# PHASE 5: LWC Components + Visualforce Pages
#
# LWC components call @AuraEnabled Apex controllers from Phase 3.
# ===========================================================================
deploy_phase "5 - LWC + Visualforce Pages" \
    "$FORCE_APP/lwc" \
    "$FORCE_APP/pages" \
    || { echo -e "${RED}Phase 5 failed. UI components could not deploy.${NC}"; exit 1; }

# ===========================================================================
# PHASE 6: UI Metadata — Tabs, FlexiPages, Applications
#
# Tabs reference objects, flexipages reference LWC components, apps tie
# everything together.
# ===========================================================================
deploy_phase "6 - UI Metadata (Tabs, FlexiPages, Apps)" \
    "$FORCE_APP/tabs" \
    "$FORCE_APP/flexipages" \
    "$FORCE_APP/applications" \
    || { echo -e "${YELLOW}Phase 6 failed. UI metadata could not deploy. Continuing...${NC}"; }

# ===========================================================================
# PHASE 7: Permission Sets + Named Credentials
#
# Permission sets reference objects, fields, classes, tabs, and VF pages
# from all prior phases. Named credentials have placeholder URLs.
# ===========================================================================
deploy_phase "7 - Permission Sets + Named Credentials" \
    "$FORCE_APP/permissionsets" \
    "$FORCE_APP/namedCredentials" \
    || { echo -e "${YELLOW}Phase 7 failed. Permissions/credentials could not deploy. Continuing...${NC}"; }

# ===========================================================================
# PHASE 8: Health Check Package (separate 2GP)
#
# Independent package with no dependencies on the main Elaro package.
# ===========================================================================
if [ "$SKIP_HC" = false ]; then
    deploy_phase "8 - Health Check Package" \
        "$FORCE_APP_HC" \
        || { echo -e "${YELLOW}Phase 8 failed. Health Check package could not deploy. Continuing...${NC}"; }
else
    echo ""
    echo -e "  ${YELLOW}Phase 8 - Health Check Package: SKIPPED (--skip-healthcheck)${NC}"
    PHASE_RESULTS+=("SKIP: 8 - Health Check Package")
fi

# ===========================================================================
# PHASE 9: Post-deploy — Tests + Permission Assignment
# ===========================================================================
if [ "$SKIP_TESTS" = false ] && [ "$DRY_RUN" = false ]; then
    log_header "Phase 9: Running Apex Tests"
    if sf apex run test --target-org "$ORG_ALIAS" --test-level RunLocalTests --wait 30; then
        echo -e "  ${GREEN}PASSED: Apex tests${NC}"
        PHASE_RESULTS+=("PASS: 9 - Apex Tests")
    else
        echo -e "  ${YELLOW}WARNING: Some Apex tests failed. Review output above.${NC}"
        PHASE_RESULTS+=("WARN: 9 - Apex Tests (some failures)")
    fi
else
    if [ "$DRY_RUN" = true ]; then
        PHASE_RESULTS+=("SKIP: 9 - Tests (dry-run mode)")
    else
        PHASE_RESULTS+=("SKIP: 9 - Tests (--skip-tests)")
    fi
fi

# Assign permission sets to current user
if [ "$DRY_RUN" = false ]; then
    log_header "Assigning Permission Sets"
    PERM_SETS=(
        "Elaro_Admin"
        "Elaro_Admin_Extended"
        "Elaro_User"
        "Elaro_Auditor"
        "Elaro_SEC_Admin"
        "Elaro_AI_Governance_Admin"
        "Elaro_AI_Governance_User"
        "TechDebt_Manager"
        "Elaro_Health_Check_Admin"
        "Elaro_Health_Check_User"
    )
    for ps in "${PERM_SETS[@]}"; do
        if sf org assign permset --name "$ps" --target-org "$ORG_ALIAS" 2>/dev/null; then
            echo -e "  ${GREEN}Assigned: $ps${NC}"
        else
            echo -e "  ${YELLOW}Could not assign: $ps (may not exist or already assigned)${NC}"
        fi
    done
fi

# ===========================================================================
# Summary
# ===========================================================================
log_header "DEPLOYMENT SUMMARY"

echo "  Org: $ORG_ALIAS"
echo "  Mode: $([ "$DRY_RUN" = true ] && echo 'DRY RUN' || echo 'LIVE DEPLOY')"
echo ""

for result in "${PHASE_RESULTS[@]}"; do
    if [[ "$result" == PASS* ]]; then
        echo -e "  ${GREEN}$result${NC}"
    elif [[ "$result" == FAIL* ]]; then
        echo -e "  ${RED}$result${NC}"
    elif [[ "$result" == WARN* ]]; then
        echo -e "  ${YELLOW}$result${NC}"
    else
        echo -e "  $result"
    fi
done

echo ""
if [ "$FAILED" = true ]; then
    echo -e "${RED}Deployment completed with failures. Review output above.${NC}"
    exit 1
elif [ "$DRY_RUN" = true ]; then
    echo -e "${GREEN}Dry-run validation complete. Run without --dry-run to deploy.${NC}"
else
    echo -e "${GREEN}Deployment to $ORG_ALIAS completed successfully.${NC}"
    echo ""
    echo "Post-deployment steps:"
    echo "  1. Configure named credentials in Setup (Slack, Teams, Jira, Claude API)"
    echo "  2. Verify Platform Cache partition 'ElaroCache' is active in Setup"
    echo "  3. Set up Elaro_Feature_Flags__c hierarchy custom setting if needed"
    echo "  4. Open the Elaro app and verify the Compliance Hub loads"
    echo "  5. Open the Health Check app and verify the dashboard loads"
fi
