#!/usr/bin/env bash
# Reset dependency files to clean baseline.
set -euo pipefail
cd "$(dirname "$0")/.."

python3 <<'PY'
import json

with open("package.json", "w") as f:
    json.dump({
        "name": "lockfile-agent-test-repo",
        "version": "1.0.0",
        "description": "Minimal Node project for testing the Dependency Lockfile Anomaly Agent",
        "private": True,
        "dependencies": {},
    }, f, indent=2)
    f.write("\n")

with open("package-lock.json", "w") as f:
    json.dump({
        "name": "lockfile-agent-test-repo",
        "version": "1.0.0",
        "lockfileVersion": 2,
        "requires": True,
        "packages": {"": {"name": "lockfile-agent-test-repo", "version": "1.0.0"}},
    }, f, indent=2)
    f.write("\n")
PY

git checkout -- package.json package-lock.json README.md 2>/dev/null || true
echo "Reset to baseline."
