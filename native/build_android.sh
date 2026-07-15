#!/bin/bash
# Android FFmpeg 二进制编译脚本
# 1. 交叉编译 x265 + z.lib + FFmpeg（调用 build_ffmpeg_android.sh）
# 2. 复制 ffmpeg 二进制到 Flutter assets
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR"
ASSETS_DIR="$PROJECT_DIR/../android/app/src/main/assets"
FFMPEG_BUILD_DIR="$PROJECT_DIR/build/ffmpeg-android"

# ── 第 1 步：编译 FFmpeg 二进制 ──
echo "=== 第 1 步：编译 FFmpeg for Android ==="
bash "$PROJECT_DIR/build_ffmpeg_android.sh"

# ── 第 2 步：复制 ffmpeg 二进制到 assets ──
echo "=== 第 2 步：复制 ffmpeg 到 assets ==="

mkdir -p "$ASSETS_DIR"

for ABI in arm64-v8a x86_64; do
  SRC="$FFMPEG_BUILD_DIR/$ABI/bin/ffmpeg"
  if [ -f "$SRC" ]; then
    # 按 ABI 命名的子目录，Dart 层根据设备架构选择
    DST_DIR="$ASSETS_DIR/ffmpeg/$ABI"
    mkdir -p "$DST_DIR"
    cp "$SRC" "$DST_DIR/ffmpeg"
    echo "  $ABI: $(ls -lh "$DST_DIR/ffmpeg" | awk '{print $5}')"
  else
    echo "  [警告] $ABI 的 ffmpeg 未找到: $SRC"
  fi
done

echo "=== Android FFmpeg 编译完成 ==="
echo "assets/ffmpeg/:"
find "$ASSETS_DIR/ffmpeg" -type f 2>/dev/null || echo "  (无文件)"
