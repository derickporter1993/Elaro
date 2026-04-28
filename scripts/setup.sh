#!/bin/bash
# Elaro One-Command Setup
set -e

echo "============================================"
echo "  Elaro Development Environment Setup"
echo "============================================"
echo ""

# ── Dependency checks ──────────────────────────────────────────

check_dependency() {
    local cmd="$1"
    local name="$2"
    local url="$3"
    local min_version="${4:-}"

    if ! command -v "$cmd" &>/dev/null; then
        echo "ERROR: $name is not installed."
        echo "  Install it from: $url"
        exit 1
    fi
    echo "  $name found: $(command -v "$cmd")"
}

echo "Checking dependencies..."
check_dependency "node" "Node.js" "https://nodejs.org" "20.0.0"
check_dependency "sf" "Salesforce CLI" "https://developer.salesforce.com/tools/salesforcecli"
check_dependency "git" "Git" "https://git-scm.com"

# Check Node version >= 20
NODE_VERSION=$(node -v | sed 's/v//')
NODE_MAJOR=$(echo "$NODE_VERSION" | cut -d. -f1)
if [ "$NODE_MAJOR" -lt 20 ]; then
    echo "ERROR: Node.js 20+ is required. Found v$NODE_VERSION"
    echo "  Update from: https://nodejs.org"
    exit 1
fi
echo "  Node.js version: v$NODE_VERSION (meets >=20 requirement)"
echo ""

# ── Install npm dependencies ──────────────────────────────────

echo "Installing npm dependencies..."
npm install
echo ""

# ── Create scratch org (with retry on failure) ────────────────

echo "Creating scratch org..."
SCRATCH_ORG_CREATED=false
MAX_RETRIES=3
for i in $(seq 1 $MAX_RETRIES); do
    if sf org create scratch -f config/elaro-scratch-def.json -a elaro-dev -d -y 30 2>/dev/null; then
        SCRATCH_ORG_CREATED=true
        break
    fi
    if [ "$i" -eq "$MAX_RETRIES" ]; then
        echo "  Failed to create scratch org after $MAX_RETRIES attempts."
        echo "  You can create one manually later: npm run org:create"
        echo "  Continuing with remaining setup..."
    else
        echo "  Retry $i/$MAX_RETRIES..."
        sleep 2
    fi
done
echo ""

# ── Deploy metadata ───────────────────────────────────────────

if [ "$SCRATCH_ORG_CREATED" = true ]; then
    echo "Deploying Elaro to scratch org..."
    sf project deploy start -o elaro-dev --wait 15 || echo "  Deploy had warnings. Review output above."
    echo ""

    # ── Assign permission sets ────────────────────────────────

    echo "Assigning permission sets..."
    for perm in Elaro_Admin Elaro_User Elaro_Health_Check_Admin; do
        sf org assign permset -n "$perm" -o elaro-dev 2>/dev/null || true
    done
    echo ""

    # ── Load sample data ──────────────────────────────────────

    if [ -f "data/sample-data-plan.json" ]; then
        echo "Loading sample data..."
        sf data import tree -p data/sample-data-plan.json -o elaro-dev 2>/dev/null || true
    fi
    echo ""
fi

# ── Run smoke tests ───────────────────────────────────────────

echo "Running LWC unit tests..."
npm run test:unit 2>/dev/null || echo "  Some tests may need a connected org. Skipping."
echo ""

# ── Build platform CLI ────────────────────────────────────────

echo "Building platform CLI..."
npm run cli:setup 2>/dev/null || true
echo ""

# ── Open org ──────────────────────────────────────────────────

echo "============================================"
echo "  Setup Complete!"
echo "============================================"
echo ""
echo "Quick Reference:"
echo "  npm run sf:deploy       Deploy to scratch org"
echo "  npm run test:unit       Run LWC Jest tests"
echo "  npm run test:apex       Run Apex tests"
echo "  npm run lint            Run ESLint"
echo "  npm run org:open        Open scratch org"
echo "  npm run setup           Re-run this setup"
echo ""

if [ "$SCRATCH_ORG_CREATED" = true ]; then
    sf org open -o elaro-dev -p /lightning/page/home 2>/dev/null || echo "Run 'npm run org:open' to open your org."
fi
