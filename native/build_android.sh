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
  BIN_DIR="$FFMPEG_BUILD_DIR/$ABI/bin"
  DST_DIR="$ASSETS_DIR/ffmpeg/$ABI"
  mkdir -p "$DST_DIR"
  for name in ffmpeg ffprobe; do
    SRC="$BIN_DIR/$name"
    if [ -f "$SRC" ]; then
      cp "$SRC" "$DST_DIR/$name"
      echo "  $ABI/$name: $(ls -lh "$DST_DIR/$name" | awk '{print $5}')"
    else
      echo "  [警告] $ABI/$name 未找到: $SRC"
    fi
  done
done

echo "=== Android FFmpeg 编译完成 ==="
echo "assets/ffmpeg/:"
find "$ASSETS_DIR/ffmpeg" -type f 2>/dev/null || echo "  (无文件)"
