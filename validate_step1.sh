#!/usr/bin/env bash
# validate_step1.sh — 驗證 main 分支最新的 workflow 是否成功
# 每 5 秒輪詢一次，最多 3 分鐘。
# 若 workflow 失敗/取消或沒有觸發，則回傳失敗。

set -e

echo "=== Step 1 validator: workflow green ==="

REPO=$(gh repo view --json nameWithOwner --jq .nameWithOwner)
echo "Repo: $REPO"

# 最多等候 3 分鐘 (36 次 * 5 秒)
for i in {1..36}; do
  STATUS=$(gh run list --workflow=ci.yml --limit 1 --json status,conclusion --jq '.[0]')
  S=$(echo "$STATUS" | jq -r .status)
  C=$(echo "$STATUS" | jq -r .conclusion)

  if [ "$S" = "completed" ]; then
    if [ "$C" = "success" ]; then
      echo "PASS: workflow conclusion = success"
      echo "=== Step 1 PASS ==="
      exit 0
    else
      echo "FAIL: workflow conclusion = $C"
      echo "提示：可用 'gh run view --web' 在瀏覽器查看詳細紀錄"
      exit 1
    fi
  fi

  echo "嘗試 $i/36: status=$S，等待 5 秒..."
  sleep 5
done

echo "FAIL: workflow 在 3 分鐘內未完成"
exit 1