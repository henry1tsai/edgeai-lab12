"""
Lab 12 smoke tests — 僅使用 CPU 的基本檢查，不需要 GPU。
這些測試會在 GitHub 的免費 runner (Ubuntu x86) 上執行，
因此不能匯入 CUDA 版的 torch、不能載入 TensorRT，也不需要 IMX219 相機。
目的：在 ARM64 Docker build 花 10 分鐘編譯前，先抓出明顯的錯誤，
例如 import graph 損壞或 YOLO 權重檔案損壞。
本地執行方式：pytest -v tests/
"""

# 標準庫
from pathlib import Path

# 第三方套件
import pytest


def test_best_pt_exists():
    """檢查 fine-tuned 權重檔 best.pt 是否存在且大小合理。"""
    p = Path(__file__).parent.parent / "best.pt"
    assert p.exists(), f"{p} 缺失 — 是否忘了 commit best.pt？"
    assert p.stat().st_size > 1_000_000, "best.pt 檔案過小 (<1 MB)，可能有問題"


def test_requirements_pinned():
    """requirements.txt 中的依賴必須固定版本 (== 或 ~= 或 >=)。"""
    req = (Path(__file__).parent.parent / "requirements.txt").read_text()
    for line in req.splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        # 允許 -e/-r/-c/-- 等特殊指令
        if line.startswith(("-e", "-r", "-c", "--")):
            continue
        assert any(op in line for op in ["==", "~=", ">="]), \
            f"requirements.txt 中有未固定版本的依賴: {line!r}"


def test_dockerfile_uses_arm64_base():
    """Dockerfile.ci 必須使用 Jetson 相容的 ARM64 基底映像。"""
    df = (Path(__file__).parent.parent / "Dockerfile.ci").read_text()
    # dustynv 與 l4t-base 映像皆為 aarch64 專用
    assert any(base in df for base in ["dustynv/", "l4t-", "nvcr.io/nvidia/l4t"]), \
        "Dockerfile.ci 必須 FROM Jetson ARM64 基底 (dustynv/* 或 l4t-*)"


@pytest.mark.parametrize("name", ["inference_node.py", "best.pt", "requirements.txt"])
def test_required_files(name):
    """檢查 Docker COPY 需要的檔案是否存在。"""
    path = Path(__file__).parent.parent / name
    assert path.exists(), f"{name} 缺失"
