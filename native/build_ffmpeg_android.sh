#!/bin/bash
# FFmpeg + x264 Android 交叉编译脚本
# 产出: build/ffmpeg-android/{abi}/lib/*.so（含 libx264）
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/build/ffmpeg-android"

NDK="${ANDROID_NDK_HOME:?请设置 ANDROID_NDK_HOME}"
FFMPEG_VERSION="6.1.2"
X264_VERSION="stable"
HOST_PLATFORM="linux-x86_64"

ABIS=("arm64-v8a" "x86_64")
declare -A ARCH=( ["arm64-v8a"]="aarch64"   ["x86_64"]="x86_64")
declare -A CPU=(  ["arm64-v8a"]="armv8-a"   ["x86_64"]="x86-64")
declare -A API=(  ["arm64-v8a"]="24"        ["x86_64"]="24")

TOOLCHAIN="$NDK/toolchains/llvm/prebuilt/$HOST_PLATFORM"

# ── 下载 FFmpeg 源码 ──
FFMPEG_DIR="$BUILD_DIR/ffmpeg-$FFMPEG_VERSION"
if [ ! -d "$FFMPEG_DIR" ]; then
  echo "下载 FFmpeg $FFMPEG_VERSION..."
  mkdir -p "$BUILD_DIR"
  wget -q "https://ffmpeg.org/releases/ffmpeg-$FFMPEG_VERSION.tar.bz2" -O "$BUILD_DIR/ffmpeg.tar.bz2"
  tar -xjf "$BUILD_DIR/ffmpeg.tar.bz2" -C "$BUILD_DIR"
fi

# ── 下载 x264 源码 ──
X264_DIR="$BUILD_DIR/x264"
if [ ! -d "$X264_DIR" ]; then
  echo "下载 x264..."
  git clone --depth 1 --branch "$X264_VERSION" https://code.videolan.org/videolan/x264.git "$X264_DIR"
fi

# ── 循环编译每个 ABI ──
for ABI in "${ABIS[@]}"; do
  echo "========================================"
  echo "  编译 $ABI"
  echo "========================================"

  PREFIX="$BUILD_DIR/$ABI"
  ARCH_NAME="${ARCH[$ABI]}"
  CPU_NAME="${CPU[$ABI]}"
  API_LEVEL="${API[$ABI]}"
  CROSS_PREFIX="${ARCH_NAME}-linux-android${API_LEVEL}-"

  if [ -f "$PREFIX/lib/libavcodec.so" ]; then
    echo "  FFmpeg 已存在，跳过"
    continue
  fi

  SYSROOT="$TOOLCHAIN/sysroot"
  CC="$TOOLCHAIN/bin/${CROSS_PREFIX}clang"
  CXX="$TOOLCHAIN/bin/${CROSS_PREFIX}clang++"

  # 创建 NDK 工具链包装
  WRAPPER_DIR="$BUILD_DIR/wrappers-$ABI"
  mkdir -p "$WRAPPER_DIR"
  ln -sf "$TOOLCHAIN/bin/llvm-ar"     "$WRAPPER_DIR/${CROSS_PREFIX}ar"
  ln -sf "$TOOLCHAIN/bin/llvm-ranlib" "$WRAPPER_DIR/${CROSS_PREFIX}ranlib"
  ln -sf "$TOOLCHAIN/bin/llvm-strip"  "$WRAPPER_DIR/${CROSS_PREFIX}strip"
  ln -sf "$TOOLCHAIN/bin/llvm-nm"     "$WRAPPER_DIR/${CROSS_PREFIX}nm"
  # x264 的 configure 找 gcc，建符号链接指向 clang
  ln -sf "$TOOLCHAIN/bin/${CROSS_PREFIX}clang" "$WRAPPER_DIR/${CROSS_PREFIX}gcc"
  ln -sf "$TOOLCHAIN/bin/${CROSS_PREFIX}clang++" "$WRAPPER_DIR/${CROSS_PREFIX}g++"
  export PATH="$WRAPPER_DIR:$PATH"

  # ── 第 1 步：编译 x264 ──
  echo "  --- 编译 x264 ---"
  cd "$X264_DIR"
  make clean > /dev/null 2>&1 || true

  # 创建一个临时目录放 pkg-config .pc 文件
  PKG_DIR="$BUILD_DIR/pkgconfig-$ABI"
  mkdir -p "$PKG_DIR"

  ./configure \
    --prefix="$PREFIX" \
    --cross-prefix="$CROSS_PREFIX" \
    --sysroot="$SYSROOT" \
    --host="${ARCH_NAME}-linux-android" \
    --enable-pic \
    --enable-static \
    --disable-cli \
    --extra-cflags="-fPIC" 2>&1 | tail -3

  make -j$(nproc)
  make install

  echo "  x264 编译完成"

  # ── 第 2 步：编译 FFmpeg（链接 x264） ──
  echo "  --- 配置 FFmpeg（含 libx264） ---"
  cd "$FFMPEG_DIR"
  make clean > /dev/null 2>&1 || true

  PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig:$PKG_CONFIG_PATH"
  export PKG_CONFIG_PATH

  ./configure \
    --prefix="$PREFIX" \
    --enable-cross-compile \
    --target-os=android \
    --arch="$ARCH_NAME" \
    --cpu="$CPU_NAME" \
    --cc="$CC" \
    --cxx="$CXX" \
    --cross-prefix="$CROSS_PREFIX" \
    --sysroot="$SYSROOT" \
    --enable-shared \
    --disable-static \
    --disable-programs \
    --disable-doc \
    --disable-avdevice \
    --disable-postproc \
    --disable-avfilter \
    --disable-network \
    --enable-avcodec \
    --enable-avformat \
    --enable-avutil \
    --enable-swresample \
    --enable-swscale \
    --enable-gpl \
    --enable-libx264 \
    --enable-encoder=libx264,mpeg4 \
    --enable-decoder=h264,hevc,vp8,vp9 \
    --enable-parser=h264,hevc,vp8,vp9 \
    --enable-demuxer=mov,matroska,mp4,mpegts,avi \
    --enable-muxer=mp4,matroska \
    --enable-protocol=file \
    --enable-filter=scale,format \
    --extra-cflags="-I$PREFIX/include" \
    --extra-ldflags="-L$PREFIX/lib"

  echo "  编译 FFmpeg ($(nproc) 核)..."
  make -j$(nproc)
  make install

  echo "  $ABI 完成:"
  ls -la "$PREFIX/lib/"*.so 2>/dev/null || echo "  无 .so 文件"

  cd "$SCRIPT_DIR"
done

echo "全部 ABI 编译完成"
