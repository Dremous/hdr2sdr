#!/bin/bash
# FFmpeg Android 交叉编译脚本（含 libx265 + z.lib）
# 产出: build/ffmpeg-android/{abi}/bin/ffmpeg（静态链接的二进制）
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/build/ffmpeg-android"

NDK="${ANDROID_NDK_HOME:?请设置 ANDROID_NDK_HOME}"
FFMPEG_VERSION="6.1.2"
ZIMG_VERSION="3.0.5"
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

# ── 下载 z.lib 源码 ──
ZIMG_DIR="$BUILD_DIR/zimg-$ZIMG_VERSION"
if [ ! -f "$ZIMG_DIR/configure" ] && [ ! -f "$ZIMG_DIR/CMakeLists.txt" ]; then
  echo "下载 z.lib $ZIMG_VERSION..."
  rm -rf "$ZIMG_DIR"
  git clone --depth 1 --branch "release-$ZIMG_VERSION" \
    https://github.com/sekrit-twc/zimg.git "$ZIMG_DIR"
fi

# ── 下载并编译 x265（静态库，每个 ABI）──
X265_DIR="$BUILD_DIR/x265"
if [ ! -d "$X265_DIR/.git" ]; then
  echo "下载 x265..."
  rm -rf "$X265_DIR"
  git clone https://bitbucket.org/multicoreware/x265_git.git "$X265_DIR"
fi

for ABI in "${ABIS[@]}"; do
  PREFIX="$BUILD_DIR/$ABI"
  ARCH_NAME="${ARCH[$ABI]}"
  API_LEVEL="${API[$ABI]}"
  CROSS_PREFIX="${ARCH_NAME}-linux-android${API_LEVEL}-"

  # ── x265 ──
  if [ -f "$PREFIX/lib/libx265.a" ] && [ -f "$PREFIX/lib/.x265_10bit" ]; then
    echo "  x265 $ABI 已存在(10-bit)，跳过"
  else
    echo "  编译 x265 for $ABI..."
    rm -rf "$X265_DIR/build/$ABI"
    mkdir -p "$X265_DIR/build/$ABI"
    cd "$X265_DIR/build/$ABI"

    cmake "$X265_DIR/source" \
      -DCMAKE_TOOLCHAIN_FILE="$NDK/build/cmake/android.toolchain.cmake" \
      -DANDROID_ABI="$ABI" \
      -DANDROID_PLATFORM="android-${API_LEVEL}" \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_ASM_COMPILER="$TOOLCHAIN/bin/${CROSS_PREFIX}clang" \
      -DHIGH_BIT_DEPTH=ON \
      -DENABLE_SHARED=OFF \
      -DENABLE_CLI=OFF \
      -DENABLE_ASSEMBLY=OFF \
      -DCMAKE_INSTALL_PREFIX="$PREFIX"

    cmake --build . --config Release -- -j$(nproc)
    cmake --install .
    touch "$PREFIX/lib/.x265_10bit"

    mkdir -p "$PREFIX/lib/pkgconfig"
    cat > "$PREFIX/lib/pkgconfig/x265.pc" <<EOF
prefix=$PREFIX
exec_prefix=\${prefix}
libdir=\${exec_prefix}/lib
includedir=\${prefix}/include

Name: x265
Description: H.265/HEVC video encoder
Version: 3.6
Libs: -L\${libdir} -lx265 -lc++_static -lc++abi -lm
Cflags: -I\${includedir}
EOF

    echo "  x265 $ABI 完成"
    cd "$SCRIPT_DIR"
  fi

  # ── z.lib（autotools 交叉编译）──
  if [ -f "$PREFIX/lib/libzimg.a" ]; then
    echo "  z.lib $ABI 已存在，跳过"
  else
    echo "  编译 z.lib for $ABI..."
    # 首 ABI 时生成 configure（源码不含 pre-generated configure）
    if [ ! -f "$ZIMG_DIR/configure" ]; then
      cd "$ZIMG_DIR"
      ./autogen.sh
      cd "$SCRIPT_DIR"
    fi

    rm -rf "$ZIMG_DIR/build-$ABI"
    mkdir -p "$ZIMG_DIR/build-$ABI"
    cd "$ZIMG_DIR/build-$ABI"

    CC="$TOOLCHAIN/bin/${CROSS_PREFIX}clang" \
    CXX="$TOOLCHAIN/bin/${CROSS_PREFIX}clang++" \
    AR="$TOOLCHAIN/bin/llvm-ar" \
    RANLIB="$TOOLCHAIN/bin/llvm-ranlib" \
    STRIP="$TOOLCHAIN/bin/llvm-strip" \
    "$ZIMG_DIR/configure" \
      --host="${ARCH_NAME}-linux-android" \
      --prefix="$PREFIX" \
      --enable-static \
      --disable-shared \
      --disable-test

    make -j$(nproc)
    make install

    mkdir -p "$PREFIX/lib/pkgconfig"
    cat > "$PREFIX/lib/pkgconfig/zimg.pc" <<EOF
prefix=$PREFIX
exec_prefix=\${prefix}
libdir=\${exec_prefix}/lib
includedir=\${prefix}/include

Name: zimg
Description: Scaling, colorspace, depth conversion library
Version: $ZIMG_VERSION
Libs: -L\${libdir} -lzimg
Cflags: -I\${includedir}
EOF

    echo "  z.lib $ABI 完成"
    cd "$SCRIPT_DIR"
  fi
done

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

  if [ -f "$PREFIX/bin/ffmpeg" ]; then
    echo "  ffmpeg 二进制已存在，跳过"
    continue
  fi

  SYSROOT="$TOOLCHAIN/sysroot"
  CC="$TOOLCHAIN/bin/${CROSS_PREFIX}clang"
  CXX="$TOOLCHAIN/bin/${CROSS_PREFIX}clang++"

  WRAPPER_DIR="$BUILD_DIR/wrappers-$ABI"
  mkdir -p "$WRAPPER_DIR"
  ln -sf "$TOOLCHAIN/bin/llvm-ar"     "$WRAPPER_DIR/${CROSS_PREFIX}ar"
  ln -sf "$TOOLCHAIN/bin/llvm-ranlib" "$WRAPPER_DIR/${CROSS_PREFIX}ranlib"
  ln -sf "$TOOLCHAIN/bin/llvm-strip"  "$WRAPPER_DIR/${CROSS_PREFIX}strip"
  ln -sf "$TOOLCHAIN/bin/llvm-nm"     "$WRAPPER_DIR/${CROSS_PREFIX}nm"

  cat > "$WRAPPER_DIR/pkg-config" <<'PKGBODY'
#!/bin/bash
/usr/bin/pkg-config "$@"
PKGBODY
  chmod +x "$WRAPPER_DIR/pkg-config"

  export PATH="$WRAPPER_DIR:$PATH"

  echo "  配置 FFmpeg（含 libx265 + z.lib）..."
  cd "$FFMPEG_DIR"
  make clean > /dev/null 2>&1 || true

  export PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"

  echo "  [DIAG] x265.pc Libs: $(grep '^Libs:' "$PREFIX/lib/pkgconfig/x265.pc" 2>/dev/null || echo NOT_FOUND)"
  echo "  [DIAG] zimg.pc: $(test -f "$PREFIX/lib/pkgconfig/zimg.pc" && echo OK || echo NOT_FOUND)"

  if ! ./configure \
    --prefix="$PREFIX" \
    --enable-cross-compile \
    --target-os=android \
    --arch="$ARCH_NAME" \
    --cpu="$CPU_NAME" \
    --cc="$CC" \
    --cxx="$CXX" \
    --cross-prefix="$CROSS_PREFIX" \
    --pkg-config="$WRAPPER_DIR/pkg-config" \
    --sysroot="$SYSROOT" \
    --enable-static \
    --disable-shared \
    --disable-doc \
    --disable-avdevice \
    --disable-postproc \
    --disable-network \
    --disable-ffplay \
    --enable-ffmpeg \
    --enable-ffprobe \
    --enable-avcodec \
    --enable-avformat \
    --enable-avutil \
    --enable-swresample \
    --enable-swscale \
    --enable-avfilter \
    --enable-gpl \
    --enable-libx265 \
    --enable-libzimg \
    --enable-encoder=libx265 \
    --enable-decoder=h264,hevc,vp8,vp9 \
    --enable-parser=h264,hevc,vp8,vp9 \
    --enable-demuxer=mov,matroska,mp4,mpegts,avi,webm \
    --enable-muxer=mp4,matroska \
    --enable-protocol=file \
    --enable-filter=scale,format,tonemap,zscale \
    --extra-cflags="-I$PREFIX/include" \
    --extra-ldflags="-L$PREFIX/lib" \
    --extra-libs="-lm -lc++_static -lc++abi"; then
    echo "  [ERROR] configure failed, config.log tail:"
    tail -50 ffbuild/config.log 2>/dev/null || echo "(no config.log)"
    exit 1
  fi

  echo "  编译 FFmpeg ($(nproc) 核)..."
  make -j$(nproc)
  make install

  echo "  $ABI 完成:"
  ls -la "$PREFIX/bin/" 2>/dev/null || echo "  无 bin 目录"
  ls -la "$PREFIX/lib/"*.a 2>/dev/null | head -10

  cd "$SCRIPT_DIR"
done

echo "全部 ABI 编译完成"
