#!/bin/bash
# iOS FFmpeg 交叉编译脚本
# 编译 arm64 架构的静态 FFmpeg 二进制（含 libx265 + z.lib + tonemap/zscale）
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/build/ios-ffmpeg"
IOS_DIR="$SCRIPT_DIR/../ios"

MIN_IOS="15.0"
XCODE_DEV="$(xcode-select -p)"
SDK="$XCODE_DEV/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk"

echo "编译 iOS arm64 FFmpeg..."
echo "SDK: $SDK"

# 下载 z.lib
ZIMG_DIR="$BUILD_DIR/zimg"
if [ ! -d "$ZIMG_DIR" ]; then
  mkdir -p "$BUILD_DIR"
  git clone --depth 1 https://github.com/sekrit-twc/zimg.git "$ZIMG_DIR"
fi

# 下载 FFmpeg
FFMPEG_DIR="$BUILD_DIR/ffmpeg-6.1.2"
if [ ! -d "$FFMPEG_DIR" ]; then
  wget -q "https://ffmpeg.org/releases/ffmpeg-6.1.2.tar.bz2" -O "$BUILD_DIR/ffmpeg.tar.bz2"
  tar -xjf "$BUILD_DIR/ffmpeg.tar.bz2" -C "$BUILD_DIR"
fi

# 编译 z.lib
if [ -f "$BUILD_DIR/ios/lib/libzimg.a" ]; then
  echo "  z.lib 已存在，跳过"
else
  echo "  编译 z.lib..."
  cd "$ZIMG_DIR"
  ./autogen.sh
  ./configure \
    --host=arm-apple-darwin \
    --prefix="$BUILD_DIR/ios" \
    --enable-static --disable-shared \
    CFLAGS="-arch arm64 -isysroot $SDK -mios-version-min=$MIN_IOS -fembed-bitcode" \
    LDFLAGS="-arch arm64 -isysroot $SDK"
  make -j$(sysctl -n hw.ncpu)
  make install
  cd "$SCRIPT_DIR"
fi

# 编译 FFmpeg
if [ -f "$BUILD_DIR/ios/bin/ffmpeg" ]; then
  echo "  ffmpeg 二进制已存在，跳过"
else
  echo "  配置 FFmpeg..."
  cd "$FFMPEG_DIR"
  make clean > /dev/null 2>&1 || true

  ./configure \
    --prefix="$BUILD_DIR/ios" \
    --enable-cross-compile \
    --target-os=darwin \
    --arch=arm64 \
    --cc="$(xcode-select -p)/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang" \
    --enable-static --disable-shared \
    --disable-doc --disable-avdevice --disable-postproc --disable-network \
    --disable-ffplay --enable-ffmpeg --enable-ffprobe \
    --enable-avcodec --enable-avformat --enable-avutil \
    --enable-swresample --enable-swscale \
    --enable-avfilter \
    --enable-gpl \
    --enable-libx265 --enable-libzimg \
    --enable-encoder=libx265 \
    --enable-decoder=h264,hevc,vp8,vp9 \
    --enable-parser=h264,hevc,vp8,vp9 \
    --enable-demuxer=mov,matroska,mp4,mpegts,avi,webm \
    --enable-muxer=mp4,matroska \
    --enable-protocol=file \
    --enable-filter=scale,format,tonemap,zscale \
    --extra-cflags="-arch arm64 -isysroot $SDK -mios-version-min=$MIN_IOS -I$BUILD_DIR/ios/include -fembed-bitcode" \
    --extra-ldflags="-arch arm64 -isysroot $SDK -L$BUILD_DIR/ios/lib" \
    --extra-libs="-lm -lc++" \
    --disable-symver

  echo "  编译 FFmpeg..."
  make -j$(sysctl -n hw.ncpu)
  make install

  echo "  iOS FFmpeg 完成:"
  ls -la "$BUILD_DIR/ios/bin/"
  cd "$SCRIPT_DIR"
fi
