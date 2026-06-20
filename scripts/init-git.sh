#!/usr/bin/env bash
# One-time local git init (run before first push to GitHub).
set -euo pipefail
cd "$(dirname "$0")/.."

if git rev-parse --git-dir >/dev/null 2>&1; then
  echo "Git already initialized."
  exit 0
fi

git init -b main
git config user.name "${GIT_USER_NAME:-Test User}"
git config user.email "${GIT_USER_EMAIL:-test@example.com}"
chmod +x scripts/*.sh scenarios/*.sh
git add .
git commit -m "baseline: empty npm project for lockfile agent testing"
echo ""
echo "Next steps:"
echo "  1. Create repo on GitHub (public OR private)"
echo "  2. git remote add origin https://github.com/YOUR_USER/lockfile-agent-test-repo.git"
echo "  3. git push -u origin main"
