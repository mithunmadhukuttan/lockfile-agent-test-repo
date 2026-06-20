#!/usr/bin/env bash
# Scenario 2: manifest + lockfile together (proper add — expect ALLOW or WARN)
set -euo pipefail
cd "$(dirname "$0")/.."

git checkout -- package.json package-lock.json 2>/dev/null || true

echo "Adding lodash to BOTH package.json and package-lock.json..."
python3 <<'PY'
import json

with open("package.json") as f:
    pkg = json.load(f)
pkg["dependencies"] = {"lodash": "^4.17.21"}
with open("package.json", "w") as f:
    json.dump(pkg, f, indent=2)
    f.write("\n")

with open("package-lock.json") as f:
    lock = json.load(f)
lock.setdefault("packages", {})["node_modules/lodash"] = {
    "version": "4.17.21",
    "resolved": "https://registry.npmjs.org/lodash/-/lodash-4.17.21.tgz",
    "integrity": "sha512-v2kDEe57cuTQF9656XV9lNCWlv9b0+2cX5t1lusZe4KXnl0BoN6PjOkE4C/bb5f1AZSccDUps4dJYV+kH+xkw==",
}
with open("package-lock.json", "w") as f:
    json.dump(lock, f, indent=2)
    f.write("\n")
PY

echo ""
echo "Expected agent result: ALLOW or WARN (if OSV reports lodash vulnerabilities)"
echo "Next: git add package.json package-lock.json && git commit && git push, then run scripts/analyze-pr.sh"
