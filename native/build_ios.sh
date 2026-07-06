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
  CMAKE_EXTRA_ARGS="-DCOMPILE_ONLY=ON"
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
