#!/bin/bash
# Android 原生库完整编译脚本
# 1. 交叉编译 FFmpeg + x264（调用 build_ffmpeg_android.sh）
# 2. 编译 libhdr_converter.so 链接 FFmpeg
# 3. 复制所有 .so 到 jniLibs
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR"
JNILIBS_DIR="$PROJECT_DIR/../android/app/src/main/jniLibs"
FFMPEG_BUILD_DIR="$PROJECT_DIR/build/ffmpeg-android"

NDK="${ANDROID_NDK_HOME:?请设置 ANDROID_NDK_HOME}"

# ── 第 1 步：编译 FFmpeg ──
echo "=== 第 1 步：编译 FFmpeg for Android ==="
bash "$PROJECT_DIR/build_ffmpeg_android.sh"

# ── 第 2 步：编译 libhdr_converter.so ──
echo "=== 第 2 步：编译 libhdr_converter.so ==="

ABIS=("arm64-v8a" "x86_64")
for ABI in "${ABIS[@]}"; do
  echo "--- 编译 $ABI ---"
  FFMPEG_ROOT="$FFMPEG_BUILD_DIR/$ABI"

  # 配置 CMake（用 FFMPEG_ROOT 替代 pkg-config）
  cmake -B "build/android/$ABI" \
    -S "$PROJECT_DIR" \
    -DCMAKE_TOOLCHAIN_FILE="$PROJECT_DIR/toolchain-android.cmake" \
    -DANDROID_ABI="$ABI" \
    -DCMAKE_BUILD_TYPE=Release \
    -DFFMPEG_ROOT="$FFMPEG_ROOT"

  cmake --build "build/android/$ABI" --config Release

  # ── 第 3 步：复制所有 .so 到 jniLibs ──
  mkdir -p "$JNILIBS_DIR/$ABI"

  # 复制我们的 .so
  cp "build/android/$ABI/libhdr_converter.so" "$JNILIBS_DIR/$ABI/"

  # 复制 FFmpeg .so 依赖
  for lib in libavcodec libavformat libavutil libswresample libswscale libx264; do
    if [ -f "$FFMPEG_ROOT/lib/${lib}.so" ]; then
      cp "$FFMPEG_ROOT/lib/${lib}.so" "$JNILIBS_DIR/$ABI/"
    fi
  done

  echo "$ABI jniLibs:"
  ls -la "$JNILIBS_DIR/$ABI/"
done

echo "=== Android 原生编译完成 ==="
