# AGENTS.md — hdr2sdr 项目开发指南

## 项目概述

HDR↔SDR 双向视频转换工具。Flutter 3 + C++17 FFmpeg 核心，dart:ffi 桥接，全平台（Windows/macOS/Linux/Android/iOS）。

## 构建命令

### 本地桌面开发（Windows 用 MSYS2/MinGW，非 Visual Studio）

```bash
# 1. 先编译 C++ 原生库
cmake -B build -S native
cmake --build build --config Release

# 2. 再 Flutter 构建
flutter pub get
flutter analyze
flutter test
flutter build windows --release     # 然后手动复制 FFmpeg .dll 到 exe 同目录
flutter build linux --release       # 同需复制 .so
flutter build macos --release       # 同需复制 .dylib + install_name_tool
```

### Android APK（需要 NDK 27.0.12077973）

```bash
# 第 1 步：交叉编译 x265 + FFmpeg 6.1.2 + libhdr_converter.so，复制到 jniLibs
# 耗时 ~20 分钟（x265 ~2min + FFmpeg ~18min），CI 有缓存可跳过
bash native/build_android.sh
# 第 2 步：构建 APK
flutter build apk --release
```

### iOS（仅编译验证，未实际链接 FFmpeg）

```bash
bash native/build_ios.sh --compile-only
cd ios && pod install
flutter build ios --no-codesign --release
```

## 项目架构

```
Dart UI (provider + Material 3)
  └── NativeBridge (dart:ffi, 单例) → libhdr_converter.{dll,so,dylib}
       └── FFmpeg (avcodec/avformat/avutil/swresample/swscale)
```

**所有平台统一走 NativeBridge FFI 直接调用 C++**。`BackgroundService` 仅保留用于 Android 后台服务通知（不参与转换逻辑）。

## 关键文件

| 文件 | 作用 |
|------|------|
| `lib/ffi/native_bridge.dart` | 9 个 C API 的 FFI 绑定（create/open/start/getInfo 等） |
| `lib/ffi/types.dart` | FFI 结构体定义、回调签名 |
| `lib/providers/convert_provider.dart` | 转换队列/状态/进度管理，统一调用 NativeBridge |
| `lib/pages/home_page.dart` | 自适应主页面（宽屏左右栏、移动端 Tab） |
| `native/include/hdr_converter.h` | C API 接口定义（9 函数 + 4 结构体） |
| `native/CMakeLists.txt` | 3 种编译模式：默认(pkg-config)/FFMPEG_ROOT(Android)/COMPILE_ONLY(iOS) |
| `native/build_ffmpeg_android.sh` | NDK 交叉编译 x265 + FFmpeg 6.1.2（arm64-v8a + x86_64） |
| `native/build_android.sh` | Android 总控：先编译 x265/FFmpeg，再 cmake，最后复制 .so |
| `native/toolchain-android.cmake` | Android NDK 工具链配置（c++_static，minSdk 24） |
| `.github/workflows/ci.yml` | 3 job：desktop-build×3 + android-build + ios-build |

## 非显而易见的注意事项

### Android x265 交叉编译陷阱（NDK r27 + cmake ≥3.31）

| 问题 | 表现 | 解决方案 |
|------|------|----------|
| cmake 3.31 ARM64 汇编检测 | `-mcpu=armv8-a` 不被 NDK clang 识别 | `-DENABLE_ASSEMBLY=OFF -DCMAKE_ASM_COMPILER=...`（必须两个一起设） |
| x265 不生成 `.pc` 文件 | FFmpeg configure 找不到 x265 | **必须完整 git clone**（不能 `--depth 1`），cmake 需要 git tag 才能生成 x265.pc |
| FFmpeg 的 pkg-config 被覆盖 | configure 使用不存在的 `aarch64-linux-android24-pkg-config` | 在 `./configure` 前 `export PKG_CONFIG=pkg-config` 强制使用系统 pkg-config |
| CROSS_PREFIX 未绑定变量 | `build_ffmpeg_android.sh` 报 `unbound variable` | 在循环内补上 `CROSS_PREFIX=...` 定义（`set -euo pipefail` 下必须） |

### AGP 9 + Gradle 9 兼容性
- `file_picker` 和 `flutter_plugin_android_lifecycle` 的 `compileSdk` 需强制设为 36（见 `android/app/build.gradle.kts` 第 49-54 行）
- Kotlin 增量编译与 AGP 9 不兼容，需 `kotlin.incremental=false`（见 `android/gradle.properties`）

### FFmpeg API 版本
- 头文件统一在 `native/src/encoder.h` 的 `extern "C"` 块中 include
- FFmpeg 7+ API 变更：`av_get_pix_fmt_name` → `av_pix_fmt_desc_get`；`av_opt_set` → `AVDictionary`
- `av_stream_new_side_data` 返回 `uint8_t*` 缓冲区指针（非 AVFrameSideData*）

### CI 特殊行为
- **Android/iOS job 设置了 `continue-on-error: true`**，CI 不会因移动端构建失败而红灯
- FFmpeg Android 编译产物有缓存（101MB），命中后省 ~13 分钟
- iOS 仅 `--compile-only`，未真正链接 FFmpeg，Podfile 无 FFmpeg 引用
- 桌面 job 会手工用 ldd/otool/vcpkg 复制 FFmpeg 依赖到 artifact

### 平台版本下限
- Android `minSdk: 24`（需要 HEVC Main10 硬件解码支持）
- iOS `min: 15.0`
- 仅编译 `arm64-v8a` + `x86_64`，无 `armeabi-v7a`

### 其他
- `pubspec.lock` 被 `.gitignore` 排除（`*.lock`），非标准 Flutter 做法
- 测试仅一个 `widget_test.dart`（25 行），无单元/集成测试
- 桌面本地构建后需手动复制 FFmpeg 动态库到可执行文件目录
