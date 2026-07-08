#!/bin/bash
# FFmpeg Android 交叉编译脚本（含 libx265）
# 产出: build/ffmpeg-android/{abi}/lib/*.so
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/build/ffmpeg-android"

NDK="${ANDROID_NDK_HOME:?请设置 ANDROID_NDK_HOME}"
FFMPEG_VERSION="6.1.2"
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

# ── 下载并编译 x265（静态库，每个 ABI）──
X265_DIR="$BUILD_DIR/x265"
if [ ! -d "$X265_DIR/.git" ]; then
  echo "下载 x265..."
  rm -rf "$X265_DIR"
  git clone https://bitbucket.org/multicoreware/x265_git.git "$X265_DIR"
fi

# 编译 x265 静态库到每个 ABI 的 FFmpeg prefix 中
for ABI in "${ABIS[@]}"; do
  PREFIX="$BUILD_DIR/$ABI"
  ARCH_NAME="${ARCH[$ABI]}"
  API_LEVEL="${API[$ABI]}"
  CROSS_PREFIX="${ARCH_NAME}-linux-android${API_LEVEL}-"

  # 只编一次 x265（不重复编，用 git 判断）
  if [ -f "$PREFIX/lib/libx265.a" ]; then
    echo "  x265 $ABI 已存在，跳过"
    continue
  fi

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
    -DENABLE_SHARED=OFF \
    -DENABLE_CLI=OFF \
    -DENABLE_ASSEMBLY=OFF \
    -DCMAKE_INSTALL_PREFIX="$PREFIX"

  cmake --build . --config Release -- -j$(nproc)
  cmake --install .

  # cmake 已生成 x265.pc，但缺少 C++ 运行时依赖，手动补充 -lc++_static -lm
  mkdir -p "$PREFIX/lib/pkgconfig"
  cat > "$PREFIX/lib/pkgconfig/x265.pc" <<EOF
prefix=$PREFIX
exec_prefix=\${prefix}
libdir=\${exec_prefix}/lib
includedir=\${prefix}/include

Name: x265
Description: H.265/HEVC video encoder
Version: 3.6
Libs: -L\${libdir} -lx265 -lc++_static -lm
Cflags: -I\${includedir}
EOF

  echo "  x265 $ABI 完成"
  cd "$SCRIPT_DIR"
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

  if [ -f "$PREFIX/lib/libavcodec.so" ]; then
    echo "  FFmpeg 已存在，跳过"
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

  # pkg-config 包装器：自动追加 C++ 运行时库，确保无论 FFmpeg configure 如何调用都生效
  cat > "$WRAPPER_DIR/pkg-config" <<'PKGBODY'
#!/bin/bash
# 调用真实 pkg-config，对 x265 额外追加 -lc++_static -lm
args=("$@")
result=$(/usr/bin/pkg-config "${args[@]}" 2>&1) || exit $?
# 如果查询中有 x265（--exists、--cflags、--libs 等），追加 C++ 运行时库
for arg in "${args[@]}"; do
  if [ "$arg" = "x265" ]; then
    result="$result -lc++_static -lm"
    break
  fi
done
echo "$result"
PKGBODY
  chmod +x "$WRAPPER_DIR/pkg-config"

  export PATH="$WRAPPER_DIR:$PATH"

  echo "  配置 FFmpeg（含 libx265）..."
  cd "$FFMPEG_DIR"
  make clean > /dev/null 2>&1 || true

  export PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"

  # 诊断：检查手动写入的 x265.pc（cmake 生成的版本不含 -lc++_static -lm）
  echo "  [DIAG] x265.pc Libs: $(grep '^Libs:' "$PREFIX/lib/pkgconfig/x265.pc" 2>/dev/null || echo NOT_FOUND)"

  if ! ./configure \
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
    --enable-libx265 \
    --enable-encoder=libx265 \
    --enable-decoder=h264,hevc,vp8,vp9 \
    --enable-parser=h264,hevc,vp8,vp9 \
    --enable-demuxer=mov,matroska,mp4,mpegts,avi \
    --enable-muxer=mp4,matroska \
    --enable-protocol=file \
    --enable-filter=scale,format \
    --extra-cflags="-I$PREFIX/include" \
    --extra-ldflags="-L$PREFIX/lib" \
    --extra-libs="-lc++_static -lm"; then
    echo "  [ERROR] configure failed, config.log tail:"
    tail -50 ffbuild/config.log 2>/dev/null || echo "(no config.log)"
    exit 1
  fi

  echo "  编译 FFmpeg ($(nproc) 核)..."
  make -j$(nproc)
  make install

  echo "  $ABI 完成:"
  ls -la "$PREFIX/lib/"*.so 2>/dev/null || echo "  无 .so 文件"

  cd "$SCRIPT_DIR"
done

echo "全部 ABI 编译完成"
