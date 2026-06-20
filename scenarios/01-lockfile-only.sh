#!/usr/bin/env bash
# Scenario 1: lockfile-only change (suspicious — expect MANUAL_REVIEW)
set -euo pipefail
cd "$(dirname "$0")/.."

git checkout -- package.json package-lock.json 2>/dev/null || true

echo "Adding lodash to package-lock.json ONLY (package.json unchanged)..."
python3 <<'PY'
import json

with open("package-lock.json") as f:
    data = json.load(f)
data.setdefault("packages", {})["node_modules/lodash"] = {
    "version": "4.17.21",
    "resolved": "https://registry.npmjs.org/lodash/-/lodash-4.17.21.tgz",
    "integrity": "sha512-v2kDEe57cuTQF9656XV9lNCWlv9b0+2cX5t1lusZe4KXnl0BoN6PjOkE4C/bb5f1AZSccDUps4dJYV+kH+xkw==",
}
with open("package-lock.json", "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
PY

echo ""
echo "Expected agent result: MANUAL_REVIEW (lockfile_changed_without_manifest)"
echo "Next: git add package-lock.json && git commit && git push, then run scripts/analyze-pr.sh"
