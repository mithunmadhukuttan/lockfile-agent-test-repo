#!/usr/bin/env bash
# Scenario 3: non-dependency change (expect ALLOW)
set -euo pipefail
cd "$(dirname "$0")/.."

echo "# Test edit $(date -u +%Y-%m-%dT%H:%M:%SZ)" >> README.md

echo ""
echo "Expected agent result: ALLOW (no lockfile change)"
echo "Next: git add README.md && git commit && git push, then run scripts/analyze-pr.sh"
