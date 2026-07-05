#!/bin/bash
# Android NDK 交叉编译脚本
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR"
JNILIBS_DIR="$PROJECT_DIR/../android/app/src/main/jniLibs"

# 需要 Android NDK 环境变量
NDK_PATH="${ANDROID_NDK_HOME:-$ANDROID_NDK}"
if [ -z "$NDK_PATH" ]; then
  echo "错误: 请设置 ANDROID_NDK_HOME 环境变量"
  exit 1
fi

ABIS=("arm64-v8a" "x86_64")
for ABI in "${ABIS[@]}"; do
  echo "编译 $ABI..."
  cmake -B "build/android/$ABI" \
    -S "$PROJECT_DIR" \
    -DCMAKE_TOOLCHAIN_FILE="$PROJECT_DIR/toolchain-android.cmake" \
    -DANDROID_ABI="$ABI" \
    -DCMAKE_BUILD_TYPE=Release

  cmake --build "build/android/$ABI" --config Release

  # 复制 .so 到 jniLibs
  mkdir -p "$JNILIBS_DIR/$ABI"
  cp "build/android/$ABI/libhdr_converter.so" "$JNILIBS_DIR/$ABI/"
done

echo "Android 编译完成"
