# Lockfile Agent Test Repo

Minimal npm project you can push to **GitHub (public or private)** to test the [Dependency Lockfile Anomaly Agent](https://github.com/your-org/dependency-lockfile-agent).

Each scenario makes a real git change, opens a PR, and you send that PR diff to the agent to verify detection.

## What's inside

| Path | Purpose |
|------|---------|
| `scenarios/01-lockfile-only.sh` | Suspicious change — lockfile only → expect **MANUAL_REVIEW** |
| `scenarios/02-proper-add.sh` | Proper add — manifest + lockfile → expect **ALLOW** or **WARN** |
| `scenarios/03-readme-only.sh` | Non-dependency change → expect **ALLOW** |
| `scripts/analyze-pr.sh` | Fetch PR from GitHub and call the agent |
| `scripts/create-and-push-pr.sh` | Apply scenario, push branch, open PR |
| `scripts/init-git.sh` | One-time local git setup |
| `scripts/reset.sh` | Reset files to baseline |

---

## Part A — Upload this repo to GitHub

### 1. Initialize locally

```bash
cd examples/lockfile-agent-test-repo   # or copy this folder anywhere
chmod +x scripts/*.sh scenarios/*.sh
./scripts/init-git.sh
```

### 2. Create GitHub repo

**Scenario 1 — Public repo**

1. GitHub → **New repository**
2. Name: `lockfile-agent-test-repo`
3. Visibility: **Public**
4. Do **not** add README (this repo already has one)
5. Create repository

**Scenario 2 — Private repo**

Same steps, but choose **Private**.

### 3. Push to GitHub

```bash
git remote add origin https://github.com/YOUR_USERNAME/lockfile-agent-test-repo.git
git push -u origin main
```

---

## Part B — Start the agent (separate terminal)

From the **dependency-lockfile-agent** project root:

```bash
cd /path/to/dependency-lockfile-agent
source .venv/bin/activate
uvicorn app.main:app --reload --host 0.0.0.0 --port 8001
```

Verify:

```bash
curl -s http://localhost:8001/health
# {"status":"ok"}
```

---

## Part C — Test with a **public** repo

No token needed to **read** a public PR.

### C1. Create a test PR (lockfile-only — should be flagged)

```bash
cd /path/to/lockfile-agent-test-repo
./scripts/create-and-push-pr.sh 01-lockfile-only
```

Copy the PR URL from the output (e.g. `https://github.com/you/lockfile-agent-test-repo/pull/1`).

### C2. Analyze the PR with the agent

```bash
export AGENT_URL=http://localhost:8001
export REPO_BASE_PATH=/tmp/repos

./scripts/analyze-pr.sh "https://github.com/YOUR_USERNAME/lockfile-agent-test-repo/pull/1"
```

### C3. Expected result (scenario 01)

```
Decision:     MANUAL_REVIEW
Anomaly:      True (lockfile_changed_without_manifest)
Lockfile:     True  Manifest: False
PR check:     neutral
```

Reports saved under `reports/` (JSON + optional PDF).

### C4. Run the other scenarios

```bash
./scripts/create-and-push-pr.sh 02-proper-add    # expect ALLOW or WARN
./scripts/create-and-push-pr.sh 03-readme-only   # expect ALLOW
./scripts/analyze-pr.sh "https://github.com/YOUR_USERNAME/lockfile-agent-test-repo/pull/2"
```

---

## Part D — Test with a **private** repo

Private repos require a GitHub token with **`repo`** scope.

### D1. Create a Personal Access Token

1. GitHub → **Settings** → **Developer settings** → **Personal access tokens**
2. Generate token with **`repo`** scope (classic) or **Contents: Read** (fine-grained)
3. Export it:

```bash
export GITHUB_TOKEN="ghp_your_token_here"
```

### D2. Push this same repo as private (or create a second private copy)

If you already pushed as public, you can change visibility in repo **Settings → General → Danger zone**, or create a new private repo and push again:

```bash
git remote set-url origin https://github.com/YOUR_USERNAME/lockfile-agent-test-repo-private.git
git push -u origin main
```

### D3. Create PR and analyze (token required)

```bash
export GITHUB_TOKEN="ghp_your_token_here"
export AGENT_URL=http://localhost:8001
export REPO_BASE_PATH=/tmp/repos

./scripts/create-and-push-pr.sh 01-lockfile-only
./scripts/analyze-pr.sh "https://github.com/YOUR_USERNAME/lockfile-agent-test-repo-private/pull/1"
```

Without `GITHUB_TOKEN`, the analyze script will fail on private repos with a 404/401.

---

## Quick reference

| Step | Public repo | Private repo |
|------|-------------|--------------|
| Clone / fetch PR diff | No token | `export GITHUB_TOKEN=ghp_...` |
| Push changes | Your GitHub login | Same |
| Analyze PR | `./scripts/analyze-pr.sh <PR_URL>` | Same + token set |
| Expected (scenario 01) | MANUAL_REVIEW | MANUAL_REVIEW |

---

## Manual workflow (without create-and-push-pr.sh)

```bash
git checkout -b test/manual-lockfile-only
./scenarios/01-lockfile-only.sh
git add package-lock.json
git commit -m "test: lockfile only"
git push -u origin test/manual-lockfile-only
# Open PR on GitHub, then:
./scripts/analyze-pr.sh OWNER REPO PR_NUMBER
```

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `Agent not reachable` | Start uvicorn on port 8001 |
| `Failed to fetch PR diff` (private) | Set `GITHUB_TOKEN` with repo access |
| `Failed to fetch PR diff` (public) | Check PR number and repo name |
| OSV scan skipped | Ensure `repo_path` clone exists under `REPO_BASE_PATH` |
| `gh: command not found` | Install [GitHub CLI](https://cli.github.com/) or open PR manually |

---

## Reset between tests

```bash
./scripts/reset.sh
git add -A && git commit -m "reset baseline" && git push
```

Or merge/close test PRs on GitHub and start a new scenario branch.

## Deploy (TEST ONLY)
API_KEY=supersecretvalue123456789
GITHUB_TOKEN=ghp_FAKEATTACKERDEMOTOKEN1234567890AB
