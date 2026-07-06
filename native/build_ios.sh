#!/bin/bash
# iOS 静态库交叉编译脚本
# 用法: ./build_ios.sh [--compile-only]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR"
IOS_DIR="$PROJECT_DIR/../ios"

# ── 解析参数 ──
COMPILE_ONLY=false
while [[ $# -gt 0 ]]; do
    case "$1" in
        --compile-only) COMPILE_ONLY=true; shift ;;
        *) echo "未知参数: $1"; exit 1 ;;
    esac
done

CMAKE_EXTRA_ARGS=""
if $COMPILE_ONLY; then
  # ── 交叉编译模式：隔离 FFmpeg 头文件 ──
  # macOS 宿主 include 路径可能包含与 iOS SDK 冲突的系统头文件
  FFMPEG_TEMP_INC=$(mktemp -d)
  trap "rm -rf $FFMPEG_TEMP_INC" EXIT
  
  # 从 pkg-config 获取宿主 FFmpeg 的 include 路径
  FFMPEG_HOST_INC=$(pkg-config --cflags-only-I libavcodec | sed 's/-I//g' | tr ' ' '\n' | head -1)
  echo "宿主 FFmpeg 头文件路径: $FFMPEG_HOST_INC"
  
  # 只复制 FFmpeg 相关的子目录
  for subdir in libavcodec libavformat libavutil libswresample libswscale; do
    if [ -d "$FFMPEG_HOST_INC/$subdir" ]; then
      cp -r "$FFMPEG_HOST_INC/$subdir" "$FFMPEG_TEMP_INC/"
    fi
  done
  echo "隔离头文件目录: $FFMPEG_TEMP_INC"
  ls "$FFMPEG_TEMP_INC"/ 2>/dev/null || echo "(空)"
  
  CMAKE_EXTRA_ARGS="-DCOMPILE_ONLY=ON -DFFMPEG_INCLUDE_DIR=$FFMPEG_TEMP_INC"
fi

echo "编译 iOS arm64..."

cmake -B build/ios \
  -S "$PROJECT_DIR" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_SYSTEM_NAME=iOS \
  -DCMAKE_OSX_ARCHITECTURES=arm64 \
  -DCMAKE_OSX_DEPLOYMENT_TARGET=15.0 \
  -DCMAKE_XCODE_ATTRIBUTE_CODE_SIGNING_REQUIRED=NO \
  $CMAKE_EXTRA_ARGS

cmake --build build/ios --config Release

if ! $COMPILE_ONLY; then
  # 复制静态库到 ios/ 目录
  cp build/ios/libhdr_converter.a "$IOS_DIR/"
fi

echo "iOS 编译完成"
