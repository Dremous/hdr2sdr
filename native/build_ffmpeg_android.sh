#!/bin/bash
# FFmpeg + x264 Android 交叉编译脚本（在 GitHub Actions CI 中运行）
# 产出: build/ffmpeg-android/{abi}/lib/*.so
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/build/ffmpeg-android"

# ── 环境检查 ──
NDK="${ANDROID_NDK_HOME:?请设置 ANDROID_NDK_HOME}"
FFMPEG_VERSION="6.1.2"
X264_VERSION="stable"
HOST_PLATFORM="linux-x86_64"

ABIS=("arm64-v8a" "x86_64")
# 每个 ABI 的编译参数
declare -A ARCH=( ["arm64-v8a"]="aarch64"   ["x86_64"]="x86_64")
declare -A CPU=(  ["arm64-v8a"]="armv8-a"   ["x86_64"]="x86-64")
declare -A API=(  ["arm64-v8a"]="24"        ["x86_64"]="24")

TOOLCHAIN="$NDK/toolchains/llvm/prebuilt/$HOST_PLATFORM"

# ── 下载 FFmpeg ──
FFMPEG_DIR="$BUILD_DIR/ffmpeg-$FFMPEG_VERSION"
if [ ! -d "$FFMPEG_DIR" ]; then
  echo "下载 FFmpeg $FFMPEG_VERSION..."
  mkdir -p "$BUILD_DIR"
  wget -q "https://ffmpeg.org/releases/ffmpeg-$FFMPEG_VERSION.tar.bz2" -O "$BUILD_DIR/ffmpeg.tar.bz2"
  tar -xjf "$BUILD_DIR/ffmpeg.tar.bz2" -C "$BUILD_DIR"
fi

# ── 下载 x264 ──
X264_DIR="$BUILD_DIR/x264"
if [ ! -d "$X264_DIR" ]; then
  echo "克隆 x264..."
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

  CC="$TOOLCHAIN/bin/${ARCH_NAME}-linux-android${API_LEVEL}-clang"
  CXX="$TOOLCHAIN/bin/${ARCH_NAME}-linux-android${API_LEVEL}-clang++"
  SYSROOT="$TOOLCHAIN/sysroot"

  # ── 创建 NDK 工具链符号链接（ar/ranlib/strip/nm 供 FFmpeg configure 使用） ──
  WRAPPER_DIR="$BUILD_DIR/wrappers-$ABI"
  mkdir -p "$WRAPPER_DIR"
  ln -sf "$TOOLCHAIN/bin/llvm-ar"     "$WRAPPER_DIR/${ARCH_NAME}-linux-android${API_LEVEL}-ar"
  ln -sf "$TOOLCHAIN/bin/llvm-ranlib" "$WRAPPER_DIR/${ARCH_NAME}-linux-android${API_LEVEL}-ranlib"
  ln -sf "$TOOLCHAIN/bin/llvm-strip"  "$WRAPPER_DIR/${ARCH_NAME}-linux-android${API_LEVEL}-strip"
  ln -sf "$TOOLCHAIN/bin/llvm-nm"     "$WRAPPER_DIR/${ARCH_NAME}-linux-android${API_LEVEL}-nm"
  export PATH="$WRAPPER_DIR:$PATH"

  # ── 编译 x264 ──
  if [ ! -f "$PREFIX/lib/libx264.so" ]; then
    echo "  编译 x264..."
    mkdir -p "$BUILD_DIR/build-x264-$ABI"
    cd "$BUILD_DIR/build-x264-$ABI"
    CC="$CC" AR="$TOOLCHAIN/bin/llvm-ar" RANLIB="$TOOLCHAIN/bin/llvm-ranlib" \
    "$X264_DIR/configure" \
      --prefix="$PREFIX" \
      --host="${ARCH_NAME}-linux-android" \
      --sysroot="$SYSROOT" \
      --extra-cflags="-fPIC" \
      --disable-cli \
      --enable-shared \
      --enable-static
    make -j$(nproc)
    make install
    cd "$SCRIPT_DIR"
  else
    echo "  x264 已存在，跳过"
  fi

  # ── 编译 FFmpeg ──
  if [ -f "$PREFIX/lib/libavcodec.so" ]; then
    echo "  FFmpeg 已存在，跳过"
    continue
  fi

  echo "  配置 FFmpeg..."
  cd "$FFMPEG_DIR"

  # 清理上次编译
  make clean > /dev/null 2>&1 || true

  ./configure \
    --prefix="$PREFIX" \
    --enable-cross-compile \
    --target-os=android \
    --arch="$ARCH_NAME" \
    --cpu="$CPU_NAME" \
    --cc="$CC" \
    --cxx="$CXX" \
    --cross-prefix="${ARCH_NAME}-linux-android${API_LEVEL}-" \
    --sysroot="$SYSROOT" \
    --pkg-config-flags="--static" \
    --extra-cflags="-I$PREFIX/include -fPIC" \
    --extra-ldflags="-L$PREFIX/lib" \
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
    --enable-libx264 \
    --enable-encoder=libx264 \
    --enable-decoder=h264,hevc,vp8,vp9 \
    --enable-parser=h264,hevc,vp8,vp9 \
    --enable-demuxer=mov,matroska,mp4,mpegts,avi \
    --enable-muxer=mp4,matroska,mpegts \
    --enable-protocol=file \
    --enable-filter=scale,format,colorspace

  echo "  编译 FFmpeg ($(nproc) 核)..."
  make -j$(nproc)
  make install

  cd "$SCRIPT_DIR"
  echo "  $ABI 完成: $PREFIX/lib/"
  ls "$PREFIX/lib/"*.so 2>/dev/null | while read f; do echo "    $(basename $f)"; done
done

echo "全部 ABI 编译完成"
