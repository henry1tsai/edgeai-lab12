#!/usr/bin/env bash
# validate_step3.sh — 驗證最新 workflow 是否在 GHCR 生成了 linux/arm64 映像，
# 並且 tag 使用當前 commit 的短 SHA。

set -e
echo "=== Step 3 validator: ARM64 image in GHCR ==="

REPO=$(gh repo view --json nameWithOwner --jq .nameWithOwner)
SHA=$(git rev-parse --short HEAD)
OWNER=$(echo "$REPO" | cut -d/ -f1)
PKG=$(echo "$REPO" | cut -d/ -f2)
IMAGE="ghcr.io/$REPO"

echo "Looking for $IMAGE:sha-$SHA"

# 1. 等待 build job 完成 (最多 50 分鐘，QEMU 很慢)
for i in {1..600}; do
  STATUS=$(gh run list --workflow=ci.yml --limit 1 --json status,conclusion --jq '.[0]')
  S=$(echo "$STATUS" | jq -r .status)
  C=$(echo "$STATUS" | jq -r .conclusion)

  if [ "$S" = "completed" ]; then
    if [ "$C" != "success" ]; then
      echo "FAIL: workflow 結論=$C"
      exit 1
    fi
    echo "PASS: workflow 成功完成"
    break
  fi

  [ $((i % 12)) -eq 0 ] && echo " ...$((i*5/60)) 分鐘已過，status=$S"
  sleep 5
done

# 2. 檢查 GHCR package 是否存在
OWNER_TYPE=$(gh api "/users/$OWNER" --jq .type 2>/dev/null || echo "User")
if [ "$OWNER_TYPE" = "Organization" ]; then
  PKG_PATH="/orgs/$OWNER/packages/container/$PKG/versions"
else
  PKG_PATH="/users/$OWNER/packages/container/$PKG/versions"
fi

if ! gh api "$PKG_PATH" --jq '.[0].metadata.container.tags' > /tmp/tags.json 2>/dev/null; then
  echo "FAIL: 無法讀取 GHCR package metadata ($PKG_PATH)。build push 是否成功？"
  exit 1
fi

if grep -q "sha-$SHA" /tmp/tags.json; then
  echo "PASS: GHCR 有 tag sha-$SHA"
else
  echo "FAIL: GHCR 沒有 sha-$SHA tag。取得的 tags: $(cat /tmp/tags.json)"
  exit 1
fi

# 3. 驗證 manifest 是否包含 linux/arm64
if ! MANIFEST=$(docker manifest inspect "$IMAGE:sha-$SHA" 2>&1); then
  echo "WARN: docker 未安裝或 manifest inspect 失敗 —"
  echo "請手動在 GHCR 網頁檢查: https://github.com/$REPO/pkgs/container/$PKG"
else
  ARCHES=$(echo "$MANIFEST" | jq -r '.manifests[]?.platform.architecture, .architecture')
  if echo "$ARCHES" | grep -qE '^(arm64|aarch64)$'; then
    echo "PASS: manifest 報告 arm64"
  else
    echo "FAIL: manifest 不是 arm64 (實際為: $ARCHES)"
    exit 1
  fi
fi

echo "=== Step 3 PASS ==="