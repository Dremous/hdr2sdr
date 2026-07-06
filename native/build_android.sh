#!/bin/bash
# Android NDK 交叉编译脚本
# 用法: ./build_android.sh [--compile-only]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR"
JNILIBS_DIR="$PROJECT_DIR/../android/app/src/main/jniLibs"

# ── 解析参数 ──
COMPILE_ONLY=false
while [[ $# -gt 0 ]]; do
    case "$1" in
        --compile-only) COMPILE_ONLY=true; shift ;;
        *) echo "未知参数: $1"; exit 1 ;;
    esac
done

# 需要 Android NDK 环境变量
NDK_PATH="${ANDROID_NDK_HOME:-$ANDROID_NDK}"
if [ -z "$NDK_PATH" ]; then
  echo "错误: 请设置 ANDROID_NDK_HOME 环境变量"
  exit 1
fi

CMAKE_EXTRA_ARGS=""
if $COMPILE_ONLY; then
  # ── 交叉编译模式：隔离 FFmpeg 头文件 ──
  # 宿主 pkg-config 的 include 路径包含系统头文件（/usr/include），会与 NDK 的 bionic 冲突
  # 因此单独提取 FFmpeg 子目录头文件到临时位置
  FFMPEG_TEMP_INC=$(mktemp -d)
  trap "rm -rf $FFMPEG_TEMP_INC" EXIT
  
  # 从 pkg-config 获取宿主 FFmpeg 的 include 路径
  FFMPEG_HOST_INC=$(pkg-config --cflags-only-I libavcodec libavformat libavutil libswresample libswscale | sed 's/-I//g' | tr ' ' '\n' | head -1)
  echo "宿主 FFmpeg 头文件路径: $FFMPEG_HOST_INC"
  
  # 只复制 FFmpeg 相关的子目录（不复制系统头文件如 sys/ cdefs.h）
  for subdir in libavcodec libavformat libavutil libswresample libswscale; do
    if [ -d "$FFMPEG_HOST_INC/$subdir" ]; then
      cp -r "$FFMPEG_HOST_INC/$subdir" "$FFMPEG_TEMP_INC/"
    fi
  done
  echo "隔离头文件目录: $FFMPEG_TEMP_INC"
  ls "$FFMPEG_TEMP_INC"/ 2>/dev/null || echo "(空)"
  
  CMAKE_EXTRA_ARGS="-DCOMPILE_ONLY=ON -DFFMPEG_INCLUDE_DIR=$FFMPEG_TEMP_INC"
fi

ABIS=("arm64-v8a" "x86_64")
for ABI in "${ABIS[@]}"; do
  echo "编译 $ABI..."
  cmake -B "build/android/$ABI" \
    -S "$PROJECT_DIR" \
    -DCMAKE_TOOLCHAIN_FILE="$PROJECT_DIR/toolchain-android.cmake" \
    -DANDROID_ABI="$ABI" \
    -DCMAKE_BUILD_TYPE=Release \
    $CMAKE_EXTRA_ARGS

  cmake --build "build/android/$ABI" --config Release

  if ! $COMPILE_ONLY; then
    # 复制 .so 到 jniLibs
    mkdir -p "$JNILIBS_DIR/$ABI"
    cp "build/android/$ABI/libhdr_converter.so" "$JNILIBS_DIR/$ABI/"
  fi
done

echo "Android 编译完成"
