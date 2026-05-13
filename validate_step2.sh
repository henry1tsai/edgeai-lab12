#!/usr/bin/env bash
# validate_step2.sh — 驗證 Dockerfile 與 entrypoint.sh 是否符合 Step 2 要求
# 檢查項目：
# 1. entrypoint.sh 存在且可執行
# 2. entrypoint.sh 有正確的 shebang
# 3. Dockerfile.ci 的 ENTRYPOINT 指向 entrypoint.sh
# 4. Dockerfile.ci 不再包含 build-time 的 YOLO engine 編譯
# 全部通過則回傳 0，否則回傳 1。

set -e

echo "=== Step 2 validator: Dockerfile refactored ==="

# 1. 檢查 entrypoint.sh 是否存在且可執行
if [ ! -x entrypoint.sh ]; then
  echo "FAIL: entrypoint.sh 缺失或不可執行"
  exit 1
fi
echo "PASS: entrypoint.sh 存在且可執行"

# 2. 檢查 shebang
if ! head -1 entrypoint.sh | grep -q '^#!/usr/bin/env bash'; then
  echo "FAIL: entrypoint.sh 缺少正確的 shebang"
  exit 1
fi
echo "PASS: shebang OK"

# 3. 檢查 Dockerfile.ci 是否有 ENTRYPOINT 指向 entrypoint.sh
if ! grep -q 'ENTRYPOINT.*entrypoint.sh' Dockerfile.ci; then
  echo "FAIL: Dockerfile.ci 沒有 ENTRYPOINT 指向 entrypoint.sh"
  exit 1
fi
echo "PASS: Dockerfile.ci wires ENTRYPOINT"

# 4. 確認 Dockerfile.ci 沒有 build-time engine 編譯
if BAD=$(grep -nE "RUN.*format=['\"]?engine['\"]?" Dockerfile.ci); then
  echo "FAIL: Dockerfile.ci 仍有 RUN 編譯 engine 的指令："
  echo " $BAD"
  echo " 請依 Step 2.1 將該步驟移到 entrypoint.sh"
  exit 1
fi
echo "PASS: Dockerfile.ci 沒有 build-time engine 編譯"

echo "=== Step 2 PASS ==="