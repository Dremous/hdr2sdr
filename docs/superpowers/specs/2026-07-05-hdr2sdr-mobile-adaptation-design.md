# HDR↔SDR 转换工具 — iOS/Android 移动端适配设计

## 概述

在现有 Flutter + C++ FFmpeg 项目基础上，增加完整的 iOS 和 Android 移动端支持。C++ 原生库交叉编译到移动端运行，UI 自适应三态布局（桌面宽/桌面窄/移动 Tab），编码器优先使用硬件加速。

## 需求

- 完整移动端支持：C++ 库在手机上实际运行 HDR↔SDR 转换
- iOS：通过 `DynamicLibrary.process()` 静态链接 `libhdr_converter.a`
- Android：通过 `DynamicLibrary.open('libhdr_converter.so')` 加载 NDK 编译产物
- UI：底部 NavigationBar 四 Tab 切换（文件/参数/预览/进度）
- 编码：硬件编码器优先（MediaCodec/VideoToolbox），自动回退软件编码
- 后台：iOS BGTaskScheduler + Android Foreground Service
- 最低版本：iOS 15+，Android 12+（minSdk 24）
- 单代码仓库，自适应布局

## 架构

```
┌────────────────────────────────────────────────────┐
│                 Flutter UI (Dart)                  │
│  ┌─ DesktopWide (width>900)  ──────────────────┐  │
│  │  Row: [文件+参数 | 预览+进度]               │  │
│  ├─ DesktopNarrow (600<w≤900) ────────────────┤  │
│  │  Column: 文件→预览→参数→进度              │  │
│  ├─ Mobile (width≤600) ───────────────────────┤  │
│  │  NavigationBar(文件/参数/预览/进度)+Indexed│  │
│  └─────────────────────────────────────────────┘  │
├────────────────────────────────────────────────────┤
│              dart:ffi NativeBridge                 │
│  Platform分支: iOS→process / Android→.so / 桌面→.dll│
├────────────────────────────────────────────────────┤
│           C++ Core (libhdr_converter)              │
│  Decoder · ToneMapper · Encoder · Pipeline ...     │
├────────────────────────────────────────────────────┤
│  平台原生层                                        │
│  iOS: hdr_converter.a + FFmpegKit CocoaPod        │
│  Android: .so + jniLibs + Foreground Service       │
└────────────────────────────────────────────────────┘
```

## 设计细节

### 1. 原生库移动端编译

| 平台 | 库格式 | 架构 | FFmpeg 获取 |
|------|--------|------|-------------|
| iOS | `.a`（静态库） | arm64 | FFmpegKit CocoaPod (`ffmpeg-kit-ios-full`) |
| Android | `.so`（动态库） | arm64-v8a, x86_64 | NDK 交叉编译 + FFmpeg Android 预编译包 |

#### iOS
- C++ 编译为 `libhdr_converter.a`
- 创建 `hdr_converter.podspec`，依赖 `ffmpeg-kit-ios-full` Pod
- 链接到 Flutter Xcode project (Podfile 中追加)
- `NativeBridge` 用 `DynamicLibrary.process()` 访问静态链接符号

#### Android
- `native/toolchain-android.cmake` NDK 交叉编译工具链
- `native/build_android.sh` 遍历 ABI: arm64-v8a, x86_64
- `.so` 输出到 `android/app/src/main/jniLibs/<abi>/libhdr_converter.so`
- FFmpeg 使用 `media_kit` 或 `FFmpegKit-Android` 预编译 AAR

#### NativeBridge 加载策略 (native_bridge.dart)

```dart
if (Platform.isIOS) {
  _lib = DynamicLibrary.process();
} else if (Platform.isAndroid) {
  _lib = DynamicLibrary.open('libhdr_converter.so');
} else if (Platform.isWindows) {
  _lib = DynamicLibrary.open('hdr_converter.dll');
} else if (Platform.isMacOS) {
  _lib = DynamicLibrary.open('libhdr_converter.dylib');
} else if (Platform.isLinux) {
  _lib = DynamicLibrary.open('libhdr_converter.so');
}
```

### 2. UI 三态自适应布局

| 状态 | 触发条件 | 布局 |
|------|----------|------|
| DesktopWide | `width > 900` | 现有左右分栏（file+params | preview+progress） |
| DesktopNarrow | `600 < width ≤ 900` | 现有纵向滚动 |
| Mobile | `width ≤ 600` | `NavigationBar` + `IndexedStack` 四 Tab |

#### Mobile Tab 分配

| Tab | 标题 | 图标 | 内容 |
|-----|------|------|------|
| 1 | 文件 | `Icons.folder` | DropZone/文件列表/输出目录选择（仅 file_picker，无 desktop_drop） |
| 2 | 参数 | `Icons.tune` | ParamPanel（可滚动，编码器默认硬件选项） |
| 3 | 预览 | `Icons.visibility` | PreviewPanel |
| 4 | 进度 | `Icons.bar_chart` | ProgressPanel + 开始转换按钮 |

#### 实施要点
- `home_page.dart` 中 `LayoutBuilder` 分支扩展为三态
- 移动端隐藏 AppBar，改为 Tab 标题
- `desktop_drop` 仅在桌面端条件导入（`import if dart.library.io` 或运行时检查）
- Provider 逻辑完全复用

### 3. 平台目录初始化

用 `flutter create --project-name hdr2sdr --platforms ios,android .` 补全。

关键文件：

| 文件 | 修改内容 |
|------|----------|
| `ios/Podfile` | 添加 `pod 'ffmpeg-kit-ios-full', '~> 6.0'` |
| `ios/Runner/Runner-Bridging-Header.h` | ObjC 桥接头 |
| `ios/hdr_converter.podspec` | 静态库包装 |
| `android/app/build.gradle` | `minSdk 24`, `ndk { abiFilters "arm64-v8a","x86_64" }` |
| `android/app/src/main/jniLibs/` | .so 放置目录 |

### 4. 移动端文件处理

- Android `content://` URI：FFmpeg 原生支持 `avformat_open_input` 直接打开 content URI
- iOS 安全域：`file_picker` 已自动处理 `startAccessingSecurityScopedResource`
- 输出路径：Android → `Downloads` 目录；iOS → `NSDocumentDirectory`
- 格式限制：移动端检测编码器支持情况，不支持时提示用户

### 5. 后台转换

#### iOS (BGTaskScheduler)
- 注册 `ProcessingTaskRequest`（`requiresExternalPower=false`, `requiresNetworkConnectivity=false`）
- `Info.plist` 声明 `Permitted background task scheduler identifiers`
- App 进入后台 → 序列化当前转换任务 → 提交 BGTask → 前台恢复时同步状态
- 通过 MethodChannel 在 Dart 与原生层间通信

#### Android (Foreground Service)
- `HdrConversionService extends Service` 持续运行
- `startForeground()` 显示通知：文件名 + 进度 + 取消按钮
- MethodChannel 双向通信：Dart 传入参数，Service 回传进度
- 完成后 `stopSelf()`

#### Flutter 层
- `BackgroundService` 抽象类，iOS/Android 各实现
- `ConvertProvider` 增加后台状态管理
- 移动端转换前启动原生后台服务

### 6. CI 扩展

在 `ci.yml` 中新增：

```yaml
android-build:
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@v4
    - run: native/build_android.sh
    - uses: subosito/flutter-action@v2
    - run: flutter build apk --release
    - uses: actions/upload-artifact@v4
      with:
        name: hdr2sdr-apk
        path: build/app/outputs/flutter-apk/*.apk

ios-build:
  runs-on: macos-latest
  steps:
    - uses: actions/checkout@v4
    - run: native/build_ios.sh
    - uses: subosito/flutter-action@v2
    - run: flutter build ios --no-codesign --release
    - uses: actions/upload-artifact@v4
      with:
        name: hdr2sdr-ipa
        path: build/ios/iphoneos/*.app
```

新增脚本：
- `native/build_android.sh` — NDK 交叉编译 + 复制到 jniLibs
- `native/build_ios.sh` — Xcode 编译静态库 + 复制到 ios/ 目录

### 7. 移动端编码策略

| 平台 | 硬件编码器 | 软件编码器 |
|------|-----------|-----------|
| Android | `h264_mediacodec` / `hevc_mediacodec` | `libx264` / `libx265` |
| iOS | `h264_videotoolbox` / `hevc_videotoolbox` | `libx264` / `libx265` |

- FFmpeg 编译时启用 `--enable-mediacodec` / `--enable-videotoolbox`
- `EncoderType` 增加 `h264Hardware` / `h265Hardware`（仅移动端 Tab 显示）
- 默认选中硬件编码，ParamPanel 提示"推荐使用硬件编码提升速度，兼容性不足时自动切换软件编码"
- 编码器 `open` 失败时自动降级（Pipeline 中 fallback 逻辑）

## 变更文件清单

| 文件 | 操作 | 说明 |
|------|------|------|
| `lib/ffi/native_bridge.dart` | 修改 | 增加 iOS/Android 平台加载分支 |
| `lib/pages/home_page.dart` | 修改 | 三态布局 + 移动端 Tab 导航 |
| `lib/models/convert_params.dart` | 修改 | `EncoderType` 增加 `h264Hardware` / `h265Hardware`（值 3/4） |
| `native/include/hdr_converter.h` | 修改 | `encoder` 字段新增值 3=H264_HW / 4=H265_HW（注释更新） |
| `lib/pages/param_panel.dart` | 修改 | 移动端显示硬件编码选项 |
| `lib/providers/convert_provider.dart` | 修改 | 增加后台状态管理 |
| `lib/widgets/drop_zone.dart` | 修改 | 条件编译 desktop_drop |
| `native/build_android.sh` | 新增 | NDK 交叉编译脚本 |
| `native/build_ios.sh` | 新增 | iOS 静态库编译脚本 |
| `native/toolchain-android.cmake` | 新增 | NDK CMake 工具链 |
| `ios/hdr_converter.podspec` | 新增 | iOS 静态库 CocoaPod |
| `ios/Podfile` | 修改 | 添加 FFmpegKit Pod 依赖 |
| `android/app/build.gradle` | 修改 | minSdk/ndkFilters |
| `.github/workflows/ci.yml` | 修改 | 增加 android-build/ios-build |
| `ios/`, `android/` | 新增 | flutter create 生成 |

## 不变的部分

- C++ 核心实现代码（decoder / tone_mapper / encoder / pipeline）不修改
- dart:ffi Struct 定义 `types.dart` 中已有部分不修改
- ConvertProvider 核心逻辑不动，只追加后台状态字段
- 桌面端 UI 和交互行为完全不变
