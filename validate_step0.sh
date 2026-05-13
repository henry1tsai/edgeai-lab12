#!/usr/bin/env bash
# validate_step0.sh — confirm repo exists on GitHub with all four required files
# What this validates:
# - gh CLI is installed and authenticated
# - origin remote points to a github.com repo
# - The repo is public (private repos burn Actions minutes from your quota)
# - All four required files are present in the latest commit on main
# Exits 0 if all checks pass, 1 otherwise.

set -e

echo "=== Step 0 validator: repo plumbing ==="

# 1. gh installed + authenticated
if ! gh auth status >/dev/null 2>&1; then
  echo "FAIL: gh not authenticated. Run 'gh auth login'."
  exit 1
fi
echo "PASS: gh authenticated"

# 2. origin is on github.com
ORIGIN=$(git remote get-url origin)
if [[ "$ORIGIN" != *github.com* ]]; then
  echo "FAIL: origin is not github.com: $ORIGIN"
  exit 1
fi
echo "PASS: origin = $ORIGIN"

# 3. Repo is public
VIS=$(gh repo view --json isPrivate --jq .isPrivate)
if [[ "$VIS" == "true" ]]; then
  echo "FAIL: repo is PRIVATE, must be PUBLIC"
  exit 1
else
  echo "PASS: repo is PUBLIC"
fi
echo "PASS: repo is PUBLIC"

# 4. Required files present in the latest commit
for f in Dockerfile.ci inference_node.py requirements.txt best.pt; do
  if ! git cat-file -e "HEAD:$f" 2>/dev/null; then
    echo "FAIL: $f missing from HEAD"
    exit 1
  fi
  echo "PASS: $f present"
done

# 5. (Optional) If you did Step 0.4, verify pyproject.toml + pdm.lock are committed.
# Skipped silently for non-PDM teams.
for f in pyproject.toml pdm.lock; do
  if [ -f "$f" ]; then
    if git cat-file -e "HEAD:$f" 2>/dev/null; then
      echo "PASS: $f present (PDM)"
    else
      echo "WARN: $f exists locally but is not committed — git add $f"
    fi
  fi
done

echo "=== Step 0 PASS ==="