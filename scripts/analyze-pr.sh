#!/usr/bin/env bash
# Fetch a GitHub PR diff and send it to the Dependency Lockfile Anomaly Agent.
#
# Usage:
#   ./scripts/analyze-pr.sh https://github.com/OWNER/REPO/pull/42
#   ./scripts/analyze-pr.sh OWNER REPO 42
#   PR_URL=... ./scripts/analyze-pr.sh
#
# Environment:
#   AGENT_URL=http://localhost:8001
#   REPO_BASE_PATH=/tmp/repos
#   GITHUB_TOKEN=ghp_...          # required for private repos
#   GENERATE_PDF=true             # optional PDF report

set -euo pipefail

AGENT_URL="${AGENT_URL:-http://localhost:8001}"
REPO_BASE_PATH="${REPO_BASE_PATH:-/tmp/repos}"
GENERATE_PDF="${GENERATE_PDF:-true}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPORTS_DIR="$SCRIPT_DIR/../reports"
mkdir -p "$REPORTS_DIR"

parse_pr_ref() {
  if [[ $# -eq 1 && "$1" =~ ^https?://github\.com/([^/]+)/([^/]+)/pull/([0-9]+) ]]; then
    OWNER="${BASH_REMATCH[1]}"
    REPO="${BASH_REMATCH[2]}"
    PR_NUMBER="${BASH_REMATCH[3]}"
  elif [[ $# -eq 3 ]]; then
    OWNER="$1"
    REPO="$2"
    PR_NUMBER="$3"
  elif [[ -n "${PR_URL:-}" && "$PR_URL" =~ ^https?://github\.com/([^/]+)/([^/]+)/pull/([0-9]+) ]]; then
    OWNER="${BASH_REMATCH[1]}"
    REPO="${BASH_REMATCH[2]}"
    PR_NUMBER="${BASH_REMATCH[3]}"
  elif [[ -n "${OWNER:-}" && -n "${REPO:-}" && -n "${PR_NUMBER:-}" ]]; then
    :
  else
    echo "Usage: $0 <github-pr-url>"
    echo "   or: $0 OWNER REPO PR_NUMBER"
    echo "   or: PR_URL=https://github.com/OWNER/REPO/pull/N $0"
    exit 1
  fi
}

auth_header() {
  if [[ -n "${GITHUB_TOKEN:-}" ]]; then
    printf 'Authorization: Bearer %s' "$GITHUB_TOKEN"
  fi
}

api_get() {
  local url="$1"
  if [[ -n "${GITHUB_TOKEN:-}" ]]; then
    curl -sf -H "$(auth_header)" "$url"
  else
    curl -sf "$url"
  fi
}

api_get_diff() {
  local url="$1"
  if [[ -n "${GITHUB_TOKEN:-}" ]]; then
    curl -sf -H "$(auth_header)" -H "Accept: application/vnd.github.v3.diff" "$url"
  else
    curl -sf -H "Accept: application/vnd.github.v3.diff" "$url"
  fi
}

ensure_clone() {
  local clone_dir="$REPO_BASE_PATH/$REPO"
  local clone_url="https://github.com/${OWNER}/${REPO}.git"

  if [[ -n "${GITHUB_TOKEN:-}" ]]; then
    clone_url="https://x-access-token:${GITHUB_TOKEN}@github.com/${OWNER}/${REPO}.git"
  fi

  if [[ -d "$clone_dir/.git" ]]; then
    echo "Using existing clone: $clone_dir"
    git -C "$clone_dir" fetch --all --prune >/dev/null 2>&1 || true
  else
    echo "Cloning $OWNER/$REPO -> $clone_dir"
    mkdir -p "$REPO_BASE_PATH"
    git clone "$clone_url" "$clone_dir"
  fi

  CLONE_DIR="$clone_dir"
}

parse_pr_ref "$@"

PR_API="https://api.github.com/repos/${OWNER}/${REPO}/pulls/${PR_NUMBER}"
FILES_API="${PR_API}/files"

echo "=== PR: $OWNER/$REPO #$PR_NUMBER ==="
echo "=== Agent: $AGENT_URL ==="

if ! curl -sf "$AGENT_URL/health" >/dev/null; then
  echo "Agent not reachable at $AGENT_URL"
  echo "Start it: uvicorn app.main:app --host 0.0.0.0 --port 8001"
  exit 1
fi

ensure_clone

echo "Fetching PR diff..."
DIFF_FILE="$(mktemp)"
CHANGED_FILE="$(mktemp)"
trap 'rm -f "$DIFF_FILE" "$CHANGED_FILE"' EXIT

if ! api_get_diff "$PR_API" > "$DIFF_FILE"; then
  echo "Failed to fetch PR diff."
  echo "For private repos set: export GITHUB_TOKEN=ghp_..."
  exit 1
fi

if ! api_get "$FILES_API" | python3 -c "
import json, sys
files = json.load(sys.stdin)
for f in files:
    print(f['filename'])
" > "$CHANGED_FILE"; then
  echo "Failed to fetch changed files list."
  exit 1
fi

if [[ ! -s "$DIFF_FILE" ]]; then
  echo "PR diff is empty."
  exit 1
fi

echo "Changed files:"
cat "$CHANGED_FILE" | sed 's/^/  - /'
echo ""

PAYLOAD_FILE="$(mktemp)"
trap 'rm -f "$DIFF_FILE" "$CHANGED_FILE" "$PAYLOAD_FILE"' EXIT

python3 <<PY
import json
import os
from pathlib import Path

diff = Path("$DIFF_FILE").read_text()
changed = [l.strip() for l in Path("$CHANGED_FILE").read_text().splitlines() if l.strip()]
payload = {
    "repository": "$OWNER/$REPO",
    "pull_request_id": "$PR_NUMBER",
    "repo_path": "$CLONE_DIR",
    "pr_diff_text": diff,
    "changed_files": changed,
    "generate_pdf": os.environ.get("GENERATE_PDF", "true").lower() == "true",
    "pdf_output_dir": "$REPORTS_DIR",
}
Path("$PAYLOAD_FILE").write_text(json.dumps(payload))
PY

echo "=== Sending to $AGENT_URL/analyze-pr-diff ==="
HTTP_CODE="$(curl -s -w "%{http_code}" -o /tmp/analyze_pr_response.json \
  -X POST "$AGENT_URL/analyze-pr-diff" \
  -H "Content-Type: application/json" \
  -d @"$PAYLOAD_FILE")"

if [[ "$HTTP_CODE" != "200" ]]; then
  echo "HTTP $HTTP_CODE"
  cat /tmp/analyze_pr_response.json
  exit 1
fi

TS="$(date -u +%Y%m%d_%H%M%S)"
JSON_OUT="$REPORTS_DIR/pr${PR_NUMBER}_${TS}.json"
cp /tmp/analyze_pr_response.json "$JSON_OUT"

python3 -m json.tool /tmp/analyze_pr_response.json

python3 <<'PY'
import json
r = json.load(open("/tmp/analyze_pr_response.json"))["report"]
print()
print("=" * 50)
print(f"  Decision:     {r['decision']} ({r['suspicion_level']}/100)")
print(f"  Anomaly:      {r['anomaly_detected']} ({r.get('anomaly_type') or 'none'})")
print(f"  Lockfile:     {r['lockfile_changed']}  Manifest: {r['manifest_changed']}")
print(f"  PR check:     {r['pr_check_status']}")
pdf = r.get("pdf_report_path") or ""
if pdf:
    print(f"  PDF report:   {pdf}")
print("=" * 50)
PY

echo "JSON saved: $JSON_OUT"
