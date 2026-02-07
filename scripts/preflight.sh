#!/bin/bash
# Pre-flight checks for Elaro workspace
# Validates workspace state per Sentinel Architecture v2.0

set -e

echo "🔍 Running Elaro workspace pre-flight checks..."
echo ""

# Track failures
FAILED=0

# Check 1: Root node_modules
if [ ! -d "node_modules" ]; then
  echo "❌ Missing root node_modules/"
  echo "   Fix: npm install"
  FAILED=1
else
  echo "✅ Root dependencies installed"
fi

# Check 2: Platform node_modules
if [ ! -d "platform/node_modules" ]; then
  echo "❌ Missing platform/node_modules/"
  echo "   Fix: cd platform && npm install --ignore-scripts"
  FAILED=1
else
  echo "✅ Platform dependencies installed"
fi

# Check 3: Specs directory (Law 1: Specs Before Code)
if [ ! -d "specs" ]; then
  echo "⚠️  Missing specs/ directory (violates Law 1)"
  echo "   Fix: mkdir specs && touch specs/.gitkeep"
  FAILED=1
else
  echo "✅ Specs directory exists (Law 1)"
fi

# Check 4: Platform build outputs (optional warning)
if [ ! -d "platform/packages/cli/dist" ]; then
  echo "⚠️  CLI not built (platform/packages/cli/dist/ missing)"
  echo "   Fix: cd platform && npm run build"
  echo "   Note: This is optional for Salesforce-only development"
fi

# Check 5: Git status (optional info)
if command -v git &> /dev/null; then
  UNCOMMITTED=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
  if [ "$UNCOMMITTED" -gt 0 ]; then
    echo "ℹ️  You have $UNCOMMITTED uncommitted changes"
  fi
fi

echo ""

# Exit with failure if any critical checks failed
if [ $FAILED -eq 1 ]; then
  echo "❌ Pre-flight checks FAILED"
  echo ""
  echo "Run the suggested fixes above, then try again."
  exit 1
fi

echo "✅ All pre-flight checks PASSED"
echo ""
echo "Workspace ready for development!"
exit 0
