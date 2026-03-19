#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────
# Prompt Architect — GitHub Pages deploy script
# Usage: bash deploy-to-github.sh <YOUR_GITHUB_TOKEN>
# ─────────────────────────────────────────────────────────────────
set -e

TOKEN="$1"
REPO_NAME="prompt-architect"

if [ -z "$TOKEN" ]; then
  echo "Usage: bash deploy-to-github.sh <YOUR_GITHUB_TOKEN>"
  echo ""
  echo "Get a token at: https://github.com/settings/tokens/new"
  echo "Required scope: repo (Full control of private repositories)"
  exit 1
fi

echo "→ Fetching your GitHub username..."
USERNAME=$(curl -sf -H "Authorization: token $TOKEN" https://api.github.com/user | python3 -c "import sys,json; print(json.load(sys.stdin)['login'])")

if [ -z "$USERNAME" ]; then
  echo "✗ Could not fetch GitHub user. Check your token has 'repo' scope."
  exit 1
fi

echo "→ Logged in as: $USERNAME"

echo "→ Creating GitHub repository '$REPO_NAME'..."
HTTP_CODE=$(curl -s -o /tmp/gh_create.json -w "%{http_code}" \
  -X POST \
  -H "Authorization: token $TOKEN" \
  -H "Accept: application/vnd.github+json" \
  https://api.github.com/user/repos \
  -d "{\"name\":\"$REPO_NAME\",\"description\":\"Prompt Architect — Claude prompt generator\",\"homepage\":\"https://$USERNAME.github.io/$REPO_NAME\",\"auto_init\":false,\"private\":false}")

if [ "$HTTP_CODE" = "422" ]; then
  echo "⚠ Repo already exists — using existing repo."
elif [ "$HTTP_CODE" != "201" ]; then
  echo "✗ Failed to create repo (HTTP $HTTP_CODE):"
  cat /tmp/gh_create.json
  exit 1
else
  echo "✓ Repository created."
fi

echo "→ Configuring git remote..."
cd "$(dirname "$0")"
git remote remove origin 2>/dev/null || true
git remote add origin "https://$USERNAME:$TOKEN@github.com/$USERNAME/$REPO_NAME.git"
git branch -M main

echo "→ Pushing code..."
git add -A
git diff --cached --quiet || git commit -m "Deploy Prompt Architect"
git push -u origin main --force

echo "→ Enabling GitHub Pages..."
curl -sf \
  -X POST \
  -H "Authorization: token $TOKEN" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/$USERNAME/$REPO_NAME/pages" \
  -d '{"source":{"branch":"main","path":"/"}}' > /dev/null 2>&1 || true

echo ""
echo "✓ Done! Your app will be live in ~30 seconds at:"
echo ""
echo "   https://$USERNAME.github.io/$REPO_NAME"
echo ""
echo "→ Repo: https://github.com/$USERNAME/$REPO_NAME"
