#!/bin/bash
# iOS 静态库交叉编译脚本
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR"
IOS_DIR="$PROJECT_DIR/../ios"

echo "编译 iOS arm64 静态库..."

cmake -B build/ios \
  -S "$PROJECT_DIR" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_SYSTEM_NAME=iOS \
  -DCMAKE_OSX_ARCHITECTURES=arm64 \
  -DCMAKE_OSX_DEPLOYMENT_TARGET=15.0 \
  -DCMAKE_XCODE_ATTRIBUTE_CODE_SIGNING_REQUIRED=NO

cmake --build build/ios --config Release

# 复制静态库到 ios/ 目录
cp build/ios/libhdr_converter.a "$IOS_DIR/"

echo "iOS 编译完成"
