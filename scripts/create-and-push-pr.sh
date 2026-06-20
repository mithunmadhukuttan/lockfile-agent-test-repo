#!/usr/bin/env bash
# Create a branch, apply a scenario, commit, push, and open a PR on GitHub.
#
# Usage:
#   ./scripts/create-and-push-pr.sh 01-lockfile-only
#   ./scripts/create-and-push-pr.sh 02-proper-add
#   ./scripts/create-and-push-pr.sh 03-readme-only
#
# Requires: git remote origin pointing to your GitHub repo, gh CLI (optional for PR URL)

set -euo pipefail

SCENARIO="${1:-}"
if [[ -z "$SCENARIO" ]]; then
  echo "Usage: $0 <01-lockfile-only|02-proper-add|03-readme-only>"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$SCRIPT_DIR/.."
SCENARIO_SCRIPT="$ROOT/scenarios/${SCENARIO}.sh"

if [[ ! -f "$SCENARIO_SCRIPT" ]]; then
  echo "Unknown scenario: $SCENARIO"
  exit 1
fi

cd "$ROOT"

if ! git remote get-url origin >/dev/null 2>&1; then
  echo "No git remote 'origin'. Create a GitHub repo first, then:"
  echo "  git remote add origin https://github.com/YOUR_USER/lockfile-agent-test-repo.git"
  exit 1
fi

BRANCH="test/${SCENARIO}-$(date -u +%Y%m%d%H%M%S)"
BASE_BRANCH="${BASE_BRANCH:-main}"

git checkout "$BASE_BRANCH" 2>/dev/null || git checkout master
git pull origin "$BASE_BRANCH" 2>/dev/null || git pull origin master 2>/dev/null || true

git checkout -b "$BRANCH"
chmod +x "$SCENARIO_SCRIPT"
"$SCENARIO_SCRIPT"

git add -A
git status
git commit -m "test: $SCENARIO scenario for lockfile agent"

echo ""
echo "Pushing branch $BRANCH ..."
git push -u origin "$BRANCH"

if command -v gh >/dev/null 2>&1; then
  gh pr create --title "Test: $SCENARIO" --body "Automated test PR for Dependency Lockfile Anomaly Agent" --base "$BASE_BRANCH" || true
  PR_URL="$(gh pr view --json url -q .url 2>/dev/null || true)"
  if [[ -n "$PR_URL" ]]; then
    echo ""
    echo "PR opened: $PR_URL"
    echo ""
    echo "Analyze with the agent:"
    echo "  AGENT_URL=http://localhost:8001 ./scripts/analyze-pr.sh \"$PR_URL\""
  fi
else
  echo ""
  echo "Install GitHub CLI (gh) to auto-open a PR, or open one manually on GitHub."
  echo "Then run: ./scripts/analyze-pr.sh OWNER REPO PR_NUMBER"
fi
