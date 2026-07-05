# HDR↔SDR 视频转换工具实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 构建一个 Flutter + C++ FFmpeg 的全平台 HDR↔SDR 视频转换桌面工具

**架构:** Flutter Material 3 UI + dart:ffi 桥接 C++ 动态库 + FFmpeg libav* 核心引擎

**Tech Stack:** Flutter 3, dart:ffi, C++17, FFmpeg (libavformat/libavcodec/libswscale), CMake

---

## Global Constraints

- 所有代码注释必须用中文
- 变量/函数名使用英文合法命名
- dart:ffi 和 C++ API 签名必须完全匹配
- FFmpeg 使用动态链接，不静态编译
- 支持 HDR10 和 HLG 格式
- 转换管线必须支持取消操作
- 预览帧格式为 BGRA 32bit

---

## 文件结构

```
hdr2sdr/
├── lib/
│   ├── main.dart                          # 应用入口
│   ├── app.dart                           # MaterialApp 配置
│   ├── ffi/
│   │   ├── native_bridge.dart             # dart:ffi 绑定层
│   │   └── types.dart                     # FFI 结构体/枚举定义
│   ├── models/
│   │   ├── video_file.dart                # 视频文件模型
│   │   ├── convert_params.dart            # 转换参数模型
│   │   └── video_info.dart                # 视频信息模型
│   ├── providers/
│   │   └── convert_provider.dart          # ChangeNotifier 状态管理
│   ├── pages/
│   │   ├── home_page.dart                 # 主页面
│   │   ├── preview_panel.dart             # 预览面板
│   │   ├── param_panel.dart               # 参数面板
│   │   └── progress_panel.dart            # 进度面板
│   └── widgets/
│       ├── drop_zone.dart                 # 拖拽区
│       ├── file_list_tile.dart            # 文件列表项
│       ├── slider_row.dart                # 滑块行组件
│       └── preset_selector.dart           # 预设选择器
├── native/
│   ├── CMakeLists.txt                     # CMake 构建配置
│   ├── include/
│   │   └── hdr_converter.h                # C 公共 API 头文件
│   └── src/
│       ├── decoder.cpp/h                  # 视频解码器
│       ├── hdr_analyzer.cpp/h             # HDR 元数据分析器
│       ├── tone_mapper.cpp/h              # Tone mapping (HDR→SDR)
│       ├── inverse_tone_mapper.cpp/h      # 逆 Tone mapping (SDR→HDR)
│       ├── color_converter.cpp/h          # 色彩空间转换
│       ├── hdr_metadata_injector.cpp/h    # HDR 元数据注入
│       ├── encoder.cpp/h                  # 视频编码器
│       ├── pipeline.cpp/h                 # 管线编排
│       └── utils.h                        # 工具函数
├── pubspec.yaml
```

---

### Task 1: Flutter 项目脚手架

**Files:**
- Create: `pubspec.yaml`
- Create: `lib/main.dart`
- Create: `lib/app.dart`

**Interfaces:**
- Produces: 可运行的 Flutter 空壳应用

- [ ] **Step 1: 创建 pubspec.yaml**

```yaml
name: hdr2sdr
description: HDR↔SDR 视频转换工具
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: '>=3.0.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
  ffi: ^2.1.0
  path_provider: ^2.1.0
  file_picker: ^6.1.0
  provider: ^6.1.0
  desktop_drop: ^0.4.0
  intl: ^0.19.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0

flutter:
  uses-material-design: true
```

- [ ] **Step 2: 创建 lib/app.dart**

```dart
import 'package:flutter/material.dart';
import 'pages/home_page.dart';

class Hdr2SdrApp extends StatelessWidget {
  const Hdr2SdrApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HDR↔SDR Converter',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      home: const HomePage(),
    );
  }
}
```

- [ ] **Step 3: 创建 lib/main.dart**

```dart
import 'package:flutter/material.dart';
import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const Hdr2SdrApp());
}
```

- [ ] **Step 4: 验证项目结构**

Run:
```bash
Set-Location -LiteralPath "E:\ai\hdr2sdr"
flutter pub get
```
Expected: 依赖下载成功，无错误

- [ ] **Step 5: 提交**

```bash
git init
git add pubspec.yaml lib/
git commit -m "feat: 初始化 Flutter 项目脚手架"
```

---

### Task 2: 数据模型定义

**Files:**
- Create: `lib/models/video_file.dart`
- Create: `lib/models/convert_params.dart`
- Create: `lib/models/video_info.dart`

**Interfaces:**
- Produces: `VideoFile`, `ConvertParams`, `VideoInfo` 数据类

- [ ] **Step 1: 创建 lib/models/video_file.dart**

```dart
enum HdrType {
  sdr,
  hdr10,
  hlg,
  dolbyVision,
}

enum ConvertDirection {
  hdrToSdr,
  sdrToHdr,
}

enum FileStatus {
  pending,
  analyzing,
  ready,
  converting,
  completed,
  failed,
}

class VideoFile {
  final String filePath;
  final String fileName;
  HdrType hdrType;
  FileStatus status;
  String? errorMessage;

  VideoFile({
    required this.filePath,
    required this.fileName,
    this.hdrType = HdrType.sdr,
    this.status = FileStatus.pending,
    this.errorMessage,
  });
}
```

- [ ] **Step 2: 创建 lib/models/convert_params.dart**

```dart
enum PresetStyle { standard, vivid, cinematic, custom }

enum ColorSpace { bt709, bt2020, dciP3 }

enum EncoderType { h264, h265, av1 }

class ConvertParams {
  final ConvertDirection direction;
  final bool autoMode;
  final PresetStyle presetStyle;
  final double peakLuminance;
  final double exposure;
  final double saturation;
  final ColorSpace targetColorSpace;
  final EncoderType encoder;
  final int crf;
  final int targetWidth;
  final int targetHeight;
  final int cropLeft;
  final int cropRight;
  final int cropTop;
  final int cropBottom;

  const ConvertParams({
    this.direction = ConvertDirection.hdrToSdr,
    this.autoMode = true,
    this.presetStyle = PresetStyle.standard,
    this.peakLuminance = 1000.0,
    this.exposure = 0.0,
    this.saturation = 1.0,
    this.targetColorSpace = ColorSpace.bt709,
    this.encoder = EncoderType.h265,
    this.crf = 23,
    this.targetWidth = 0,
    this.targetHeight = 0,
    this.cropLeft = 0,
    this.cropRight = 0,
    this.cropTop = 0,
    this.cropBottom = 0,
  });

  ConvertParams copyWith({
    ConvertDirection? direction,
    bool? autoMode,
    PresetStyle? presetStyle,
    double? peakLuminance,
    double? exposure,
    double? saturation,
    ColorSpace? targetColorSpace,
    EncoderType? encoder,
    int? crf,
    int? targetWidth,
    int? targetHeight,
    int? cropLeft,
    int? cropRight,
    int? cropTop,
    int? cropBottom,
  }) {
    return ConvertParams(
      direction: direction ?? this.direction,
      autoMode: autoMode ?? this.autoMode,
      presetStyle: presetStyle ?? this.presetStyle,
      peakLuminance: peakLuminance ?? this.peakLuminance,
      exposure: exposure ?? this.exposure,
      saturation: saturation ?? this.saturation,
      targetColorSpace: targetColorSpace ?? this.targetColorSpace,
      encoder: encoder ?? this.encoder,
      crf: crf ?? this.crf,
      targetWidth: targetWidth ?? this.targetWidth,
      targetHeight: targetHeight ?? this.targetHeight,
      cropLeft: cropLeft ?? this.cropLeft,
      cropRight: cropRight ?? this.cropRight,
      cropTop: cropTop ?? this.cropTop,
      cropBottom: cropBottom ?? this.cropBottom,
    );
  }
}
```

- [ ] **Step 3: 创建 lib/models/video_info.dart**

```dart
import 'video_file.dart';

class VideoInfo {
  final int width;
  final int height;
  final double fps;
  final int frameCount;
  final double durationSec;
  final bool isHdr;
  final int hdrType; // 0=SDR, 1=HDR10, 2=HLG, 3=DolbyVision
  final double maxLuminance;
  final int pixelFormat;

  const VideoInfo({
    required this.width,
    required this.height,
    required this.fps,
    required this.frameCount,
    required this.durationSec,
    required this.isHdr,
    required this.hdrType,
    this.maxLuminance = 0.0,
    this.pixelFormat = 0,
  });
}
```

- [ ] **Step 4: 提交**

```bash
git add lib/models/
git commit -m "feat: 添加数据模型定义"
```

---

### Task 3: dart:ffi 绑定层

**Files:**
- Create: `lib/ffi/types.dart`
- Create: `lib/ffi/native_bridge.dart`

**Interfaces:**
- Consumes: `ConvertParams`, `VideoInfo` (from Task 2)
- Produces: `NativeBridge` 单例类封装所有 FFI 调用

- [ ] **Step 1: 创建 lib/ffi/types.dart**

```dart
import 'dart:ffi';
import 'package:ffi/ffi.dart';

final class VideoInfoNative extends Struct {
  @Int32()
  external int width;

  @Int32()
  external int height;

  @Double()
  external double fps;

  @Int64()
  external int frameCount;

  @Double()
  external double durationSec;

  @Int32()
  external int isHdr;

  @Double()
  external double maxLuminance;

  @Int32()
  external int pixelFormat;
}

final class ConvertParamsNative extends Struct {
  @Int32()
  external int direction;

  @Int32()
  external int autoMode;

  @Int32()
  external int presetStyle;

  @Double()
  external double peakLuminance;

  @Double()
  external double exposure;

  @Double()
  external double saturation;

  @Int32()
  external int targetColorSpace;

  @Int32()
  external int encoder;

  @Int32()
  external int crf;

  @Int32()
  external int targetWidth;

  @Int32()
  external int targetHeight;

  @Int32()
  external int cropLeft;

  @Int32()
  external int cropRight;

  @Int32()
  external int cropTop;

  @Int32()
  external int cropBottom;
}

typedef ProgressCallbackNative = Void Function(
  Int32 percent,
  Int64 currentFrame,
  Int64 totalFrames,
  Pointer<Void> userData,
);

typedef CompletionCallbackNative = Void Function(
  Int32 success,
  Pointer<Utf8> errorMsg,
  Pointer<Void> userData,
);

typedef ConverterHandle = Pointer<Void>;
```

- [ ] **Step 2: 创建 lib/ffi/native_bridge.dart**

```dart
import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import '../models/convert_params.dart';
import '../models/video_info.dart';
import 'types.dart';

class NativeBridge {
  static NativeBridge? _instance;
  late final DynamicLibrary _lib;
  late final Pointer<Void> Function() _create;
  late final void Function(Pointer<Void>) _destroy;
  late final int Function(Pointer<Void>, Pointer<Utf8>) _open;
  late final void Function(Pointer<Void>) _close;
  late final int Function(Pointer<Void>) _getFrameCount;
  late final void Function(Pointer<Void>, Pointer<VideoInfoNative>) _getInfo;
  late final void Function(Pointer<Void>, Pointer<ConvertParamsNative>) _setParams;
  late final int Function(
    Pointer<Void>,
    Pointer<Uint8>,
    Int64,
    Pointer<Int32>,
    Pointer<Int32>,
  ) _getFrame;
  late final int Function(
    Pointer<Void>,
    Pointer<Utf8>,
    Pointer<NativeFunction<ProgressCallbackNative>>,
    Pointer<NativeFunction<CompletionCallbackNative>>,
    Pointer<Void>,
  ) _start;
  late final void Function(Pointer<Void>) _cancel;

  NativeBridge._() {
    if (Platform.isWindows) {
      _lib = DynamicLibrary.open('hdr_converter.dll');
    } else if (Platform.isMacOS) {
      _lib = DynamicLibrary.open('libhdr_converter.dylib');
    } else if (Platform.isLinux) {
      _lib = DynamicLibrary.open('libhdr_converter.so');
    } else {
      throw UnsupportedError('不支持的平台');
    }

    _create = _lib
        .lookupFunction<Pointer<Void> Function(), Pointer<Void> Function()>(
            'converter_create');
    _destroy = _lib
        .lookupFunction<Void Function(Pointer<Void>), void Function(Pointer<Void>)>(
            'converter_destroy');
    _open = _lib.lookupFunction<
        Int32 Function(Pointer<Void>, Pointer<Utf8>),
        int Function(Pointer<Void>, Pointer<Utf8>)>('converter_open');
    _close = _lib
        .lookupFunction<Void Function(Pointer<Void>), void Function(Pointer<Void>)>(
            'converter_close');
    _getFrameCount = _lib.lookupFunction<
        Int32 Function(Pointer<Void>),
        int Function(Pointer<Void>)>('converter_get_frame_count');
    _getInfo = _lib.lookupFunction<
        Void Function(Pointer<Void>, Pointer<VideoInfoNative>),
        void Function(Pointer<Void>, Pointer<VideoInfoNative>)>(
        'converter_get_info');
    _setParams = _lib.lookupFunction<
        Void Function(Pointer<Void>, Pointer<ConvertParamsNative>),
        void Function(Pointer<Void>, Pointer<ConvertParamsNative>)>(
        'converter_set_params');
    _getFrame = _lib.lookupFunction<
        Int32 Function(Pointer<Void>, Pointer<Uint8>, Int64, Pointer<Int32>,
            Pointer<Int32>),
        int Function(Pointer<Void>, Pointer<Uint8>, int, Pointer<Int32>,
            Pointer<Int32>)>('converter_get_frame');
    _start = _lib.lookupFunction<
        Int32 Function(
            Pointer<Void>,
            Pointer<Utf8>,
            Pointer<NativeFunction<ProgressCallbackNative>>,
            Pointer<NativeFunction<CompletionCallbackNative>>,
            Pointer<Void>),
        int Function(
            Pointer<Void>,
            Pointer<Utf8>,
            Pointer<NativeFunction<ProgressCallbackNative>>,
            Pointer<NativeFunction<CompletionCallbackNative>>,
            Pointer<Void>)>('converter_start');
    _cancel = _lib
        .lookupFunction<Void Function(Pointer<Void>), void Function(Pointer<Void>)>(
            'converter_cancel');
  }

  static NativeBridge get instance {
    _instance ??= NativeBridge._();
    return _instance!;
  }

  ConverterHandle create() => _create();

  void destroy(ConverterHandle handle) => _destroy(handle);

  int open(ConverterHandle handle, String path) {
    final ptr = path.toNativeUtf8();
    final result = _open(handle, ptr);
    calloc.free(ptr);
    return result;
  }

  void close(ConverterHandle handle) => _close(handle);

  int getFrameCount(ConverterHandle handle) => _getFrameCount(handle);

  VideoInfo? getInfo(ConverterHandle handle) {
    final nativeInfo = calloc<VideoInfoNative>();
    _getInfo(handle, nativeInfo);
    final info = VideoInfo(
      width: nativeInfo.ref.width,
      height: nativeInfo.ref.height,
      fps: nativeInfo.ref.fps,
      frameCount: nativeInfo.ref.frameCount,
      durationSec: nativeInfo.ref.durationSec,
      isHdr: nativeInfo.ref.isHdr != 0,
      hdrType: nativeInfo.ref.isHdr,
      maxLuminance: nativeInfo.ref.maxLuminance,
      pixelFormat: nativeInfo.ref.pixelFormat,
    );
    calloc.free(nativeInfo);
    return info;
  }

  void setParams(ConverterHandle handle, ConvertParams params) {
    final nativeParams = calloc<ConvertParamsNative>();
    nativeParams.ref.direction = params.direction.index;
    nativeParams.ref.autoMode = params.autoMode ? 1 : 0;
    nativeParams.ref.presetStyle = params.presetStyle.index;
    nativeParams.ref.peakLuminance = params.peakLuminance;
    nativeParams.ref.exposure = params.exposure;
    nativeParams.ref.saturation = params.saturation;
    nativeParams.ref.targetColorSpace = params.targetColorSpace.index;
    nativeParams.ref.encoder = params.encoder.index;
    nativeParams.ref.crf = params.crf;
    nativeParams.ref.targetWidth = params.targetWidth;
    nativeParams.ref.targetHeight = params.targetHeight;
    nativeParams.ref.cropLeft = params.cropLeft;
    nativeParams.ref.cropRight = params.cropRight;
    nativeParams.ref.cropTop = params.cropTop;
    nativeParams.ref.cropBottom = params.cropBottom;
    _setParams(handle, nativeParams);
    calloc.free(nativeParams);
  }

  int getFrame(ConverterHandle handle, Pointer<Uint8> buffer, int timestampUs,
      Pointer<Int32> outWidth, Pointer<Int32> outHeight) {
    return _getFrame(handle, buffer, timestampUs, outWidth, outHeight);
  }

  int start(
    ConverterHandle handle,
    String outputPath,
    Pointer<NativeFunction<ProgressCallbackNative>> progressCb,
    Pointer<NativeFunction<CompletionCallbackNative>> completeCb,
    Pointer<Void> userData,
  ) {
    final ptr = outputPath.toNativeUtf8();
    final result = _start(handle, ptr, progressCb, completeCb, userData);
    calloc.free(ptr);
    return result;
  }

  void cancel(ConverterHandle handle) => _cancel(handle);
}
```

- [ ] **Step 3: 提交**

```bash
git add lib/ffi/
git commit -m "feat: 添加 dart:ffi 绑定层"
```

---

### Task 4: C++ 公共 API 头文件

**Files:**
- Create: `native/include/hdr_converter.h`
- Create: `native/CMakeLists.txt`

**Interfaces:**
- Produces: C 风格 API 声明，与 dart:ffi 绑定对应

- [ ] **Step 1: 创建 native/include/hdr_converter.h**

```c
#ifndef HDR_CONVERTER_H
#define HDR_CONVERTER_H

#include <stdint.h>

#ifdef _WIN32
#define EXPORT __declspec(dllexport)
#else
#define EXPORT __attribute__((visibility("default")))
#endif

typedef struct {
    int width;
    int height;
    double fps;
    int64_t frame_count;
    double duration_sec;
    int is_hdr;              // 0=SDR, 1=HDR10, 2=HLG, 3=DolbyVision
    double max_luminance;
    int pixel_format;
} VideoInfo;

typedef struct {
    int direction;           // 0=HDR→SDR, 1=SDR→HDR
    int auto_mode;
    int preset_style;        // 0=standard, 1=vivid, 2=cinematic, 3=custom
    double peak_luminance;
    double exposure;
    double saturation;
    int target_color_space;  // 0=BT.709, 1=BT.2020, 2=DCI-P3
    int encoder;             // 0=H.264, 1=H.265, 2=AV1
    int crf;
    int target_width;
    int target_height;
    int crop_left;
    int crop_right;
    int crop_top;
    int crop_bottom;
} ConvertParams;

typedef void (*ProgressCallback)(int percent, int64_t current_frame,
                                  int64_t total_frames, void* user_data);
typedef void (*CompletionCallback)(int success, const char* error_msg,
                                    void* user_data);

EXPORT void* converter_create();
EXPORT void  converter_destroy(void* handle);
EXPORT int   converter_open(void* handle, const char* input_path);
EXPORT void  converter_close(void* handle);
EXPORT int   converter_get_frame_count(void* handle);
EXPORT void  converter_get_info(void* handle, VideoInfo* out_info);
EXPORT void  converter_set_params(void* handle, ConvertParams params);
EXPORT int   converter_get_frame(void* handle, uint8_t* out_buffer,
                                  int64_t timestamp_us, int* out_width,
                                  int* out_height);
EXPORT int   converter_start(void* handle, const char* output_path,
                              ProgressCallback progress_cb,
                              CompletionCallback complete_cb,
                              void* user_data);
EXPORT void  converter_cancel(void* handle);

#endif
```

- [ ] **Step 2: 创建 native/CMakeLists.txt**

```cmake
cmake_minimum_required(VERSION 3.16)
project(hdr_converter VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

find_package(PkgConfig REQUIRED)
pkg_check_modules(AVCODEC REQUIRED libavcodec)
pkg_check_modules(AVFORMAT REQUIRED libavformat)
pkg_check_modules(AVUTIL REQUIRED libavutil)
pkg_check_modules(SWRESAMPLE REQUIRED libswresample)
pkg_check_modules(SWSCALE REQUIRED libswscale)

add_library(hdr_converter SHARED
    src/decoder.cpp
    src/hdr_analyzer.cpp
    src/tone_mapper.cpp
    src/inverse_tone_mapper.cpp
    src/color_converter.cpp
    src/hdr_metadata_injector.cpp
    src/encoder.cpp
    src/pipeline.cpp
)

target_include_directories(hdr_converter
    PUBLIC include
    PRIVATE src
    ${AVCODEC_INCLUDE_DIRS}
    ${AVFORMAT_INCLUDE_DIRS}
    ${AVUTIL_INCLUDE_DIRS}
    ${SWRESAMPLE_INCLUDE_DIRS}
    ${SWSCALE_INCLUDE_DIRS}
)

target_link_libraries(hdr_converter
    ${AVCODEC_LIBRARIES}
    ${AVFORMAT_LIBRARIES}
    ${AVUTIL_LIBRARIES}
    ${SWRESAMPLE_LIBRARIES}
    ${SWSCALE_LIBRARIES}
)

if(WIN32)
    set_target_properties(hdr_converter PROPERTIES PREFIX "")
endif()
```

- [ ] **Step 3: 创建 native/src/utils.h**

```cpp
#ifndef UTILS_H
#define UTILS_H

#include <string>

inline std::string avErrorToString(int errnum) {
    char buf[256];
    av_strerror(errnum, buf, sizeof(buf));
    return std::string(buf);
}

#endif
```

- [ ] **Step 4: 提交**

```bash
git add native/include/ native/CMakeLists.txt native/src/utils.h
git commit -m "feat: 添加 C++ 公共 API 头文件和 CMake 构建配置"
```

---

### Task 5: C++ Decoder 模块

**Files:**
- Create: `native/src/decoder.h`
- Create: `native/src/decoder.cpp`

**Interfaces:**
- Consumes: `hdr_converter.h`
- Produces: `class Decoder` — 打开文件，解码帧到 AVFrame

- [ ] **Step 1: 创建 native/src/decoder.h**

```cpp
#ifndef DECODER_H
#define DECODER_H

#include <string>
#include <mutex>
#include <atomic>
extern "C" {
#include <libavformat/avformat.h>
#include <libavcodec/avcodec.h>
#include <libavutil/imgutils.h>
}

class Decoder {
public:
    Decoder();
    ~Decoder();

    int open(const std::string& filename);
    void close();
    bool isOpen() const;

    int getFrameCount() const;
    double getFps() const;
    int getWidth() const;
    int getHeight() const;
    double getDurationSec() const;
    int getPixelFormat() const;

    AVFrame* decodeNextFrame();
    AVFrame* seekAndDecode(int64_t timestamp_us);
    void flush();

    AVFormatContext* getFormatContext() const { return fmt_ctx_; }
    AVCodecContext* getCodecContext() const { return codec_ctx_; }
    int getVideoStreamIndex() const { return video_stream_index_; }

private:
    AVFormatContext* fmt_ctx_;
    AVCodecContext* codec_ctx_;
    int video_stream_index_;
    std::mutex mutex_;
};

#endif
```

- [ ] **Step 2: 创建 native/src/decoder.cpp**

```cpp
#include "decoder.h"
#include <iostream>

Decoder::Decoder()
    : fmt_ctx_(nullptr), codec_ctx_(nullptr), video_stream_index_(-1) {}

Decoder::~Decoder() {
    close();
}

int Decoder::open(const std::string& filename) {
    std::lock_guard<std::mutex> lock(mutex_);

    int ret = avformat_open_input(&fmt_ctx_, filename.c_str(), nullptr, nullptr);
    if (ret < 0) return ret;

    ret = avformat_find_stream_info(fmt_ctx_, nullptr);
    if (ret < 0) return ret;

    for (unsigned int i = 0; i < fmt_ctx_->nb_streams; ++i) {
        if (fmt_ctx_->streams[i]->codecpar->codec_type == AVMEDIA_TYPE_VIDEO) {
            video_stream_index_ = i;
            break;
        }
    }
    if (video_stream_index_ < 0) return AVERROR_DECODER_NOT_FOUND;

    AVCodecParameters* codecpar = fmt_ctx_->streams[video_stream_index_]->codecpar;
    const AVCodec* codec = avcodec_find_decoder(codecpar->codec_id);
    if (!codec) return AVERROR_DECODER_NOT_FOUND;

    codec_ctx_ = avcodec_alloc_context3(codec);
    if (!codec_ctx_) return AVERROR(ENOMEM);

    ret = avcodec_parameters_to_context(codec_ctx_, codecpar);
    if (ret < 0) return ret;

    ret = avcodec_open2(codec_ctx_, codec, nullptr);
    return ret;
}

void Decoder::close() {
    std::lock_guard<std::mutex> lock(mutex_);
    if (codec_ctx_) {
        avcodec_free_context(&codec_ctx_);
    }
    if (fmt_ctx_) {
        avformat_close_input(&fmt_ctx_);
    }
    video_stream_index_ = -1;
}

bool Decoder::isOpen() const {
    return fmt_ctx_ != nullptr && codec_ctx_ != nullptr;
}

int Decoder::getFrameCount() const {
    if (!isOpen()) return 0;
    return fmt_ctx_->streams[video_stream_index_]->nb_frames;
}

double Decoder::getFps() const {
    if (!isOpen()) return 0.0;
    AVRational r = fmt_ctx_->streams[video_stream_index_]->avg_frame_rate;
    return av_q2d(r);
}

int Decoder::getWidth() const {
    return codec_ctx_ ? codec_ctx_->width : 0;
}

int Decoder::getHeight() const {
    return codec_ctx_ ? codec_ctx_->height : 0;
}

double Decoder::getDurationSec() const {
    if (!fmt_ctx_) return 0.0;
    return fmt_ctx_->duration / (double)AV_TIME_BASE;
}

int Decoder::getPixelFormat() const {
    return codec_ctx_ ? codec_ctx_->pix_fmt : AV_PIX_FMT_NONE;
}

AVFrame* Decoder::decodeNextFrame() {
    std::lock_guard<std::mutex> lock(mutex_);
    if (!isOpen()) return nullptr;

    AVPacket* pkt = av_packet_alloc();
    AVFrame* frame = av_frame_alloc();

    while (av_read_frame(fmt_ctx_, pkt) >= 0) {
        if (pkt->stream_index == video_stream_index_) {
            int ret = avcodec_send_packet(codec_ctx_, pkt);
            if (ret < 0) break;

            ret = avcodec_receive_frame(codec_ctx_, frame);
            if (ret == 0) {
                av_packet_free(&pkt);
                return frame;
            }
        }
        av_packet_unref(pkt);
    }

    av_packet_free(&pkt);
    av_frame_free(&frame);
    return nullptr;
}

AVFrame* Decoder::seekAndDecode(int64_t timestamp_us) {
    std::lock_guard<std::mutex> lock(mutex_);
    if (!isOpen()) return nullptr;

    int64_t ts = av_rescale_q(timestamp_us, AV_TIME_BASE_Q,
        fmt_ctx_->streams[video_stream_index_]->time_base);
    av_seek_frame(fmt_ctx_, video_stream_index_, ts, AVSEEK_FLAG_BACKWARD);
    avcodec_flush_buffers(codec_ctx_);

    AVPacket* pkt = av_packet_alloc();
    AVFrame* frame = av_frame_alloc();

    while (av_read_frame(fmt_ctx_, pkt) >= 0) {
        if (pkt->stream_index == video_stream_index_) {
            int ret = avcodec_send_packet(codec_ctx_, pkt);
            if (ret < 0) break;

            ret = avcodec_receive_frame(codec_ctx_, frame);
            if (ret == 0) {
                av_packet_free(&pkt);
                return frame;
            }
        }
        av_packet_unref(pkt);
    }

    av_packet_free(&pkt);
    av_frame_free(&frame);
    return nullptr;
}

void Decoder::flush() {
    std::lock_guard<std::mutex> lock(mutex_);
    if (codec_ctx_) {
        avcodec_flush_buffers(codec_ctx_);
    }
}
```

- [ ] **Step 3: 提交**

```bash
git add native/src/decoder.h native/src/decoder.cpp
git commit -m "feat: 添加视频解码器模块"
```

---

### Task 6: C++ HDRAnalyzer 模块

**Files:**
- Create: `native/src/hdr_analyzer.h`
- Create: `native/src/hdr_analyzer.cpp`

**Interfaces:**
- Consumes: `Decoder` (video_stream_index_, codec_ctx_, fmt_ctx_)
- Produces: `class HDRAnalyzer` — 分析 HDR 类型和元数据

- [ ] **Step 1: 创建 native/src/hdr_analyzer.h**

```cpp
#ifndef HDR_ANALYZER_H
#define HDR_ANALYZER_H

#include <string>
extern "C" {
#include <libavformat/avformat.h>
#include <libavcodec/avcodec.h>
}

struct HDRMetadata {
    int hdr_type;           // 0=SDR, 1=HDR10, 2=HLG, 3=DolbyVision
    double max_luminance;   // nit
    double min_luminance;
    double avg_luminance;
    double max_cll;         // MaxCLL
    double max_fall;        // MaxFALL
    double primaries[8];    // display primaries (x,y for R,G,B,W)
};

class HDRAnalyzer {
public:
    static HDRMetadata analyze(AVFormatContext* fmt_ctx,
                                AVCodecContext* codec_ctx,
                                int video_stream_index);
    static int detectHdrType(AVFormatContext* fmt_ctx, int video_stream_index);
};

#endif
```

- [ ] **Step 2: 创建 native/src/hdr_analyzer.cpp**

```cpp
#include "hdr_analyzer.h"

int HDRAnalyzer::detectHdrType(AVFormatContext* fmt_ctx, int video_stream_index) {
    if (video_stream_index < 0) return 0;

    AVStream* stream = fmt_ctx->streams[video_stream_index];

    // 检查 Dolby Vision
    for (int i = 0; i < stream->codecpar->nb_coded_side_data; ++i) {
        auto side_data = stream->codecpar->coded_side_data[i];
        if (side_data.type == AV_PKT_DATA_DOVI_CONF) return 3;
    }

    // 检查 HDR10 / HLG
    for (int i = 0; i < stream->codecpar->nb_coded_side_data; ++i) {
        auto side_data = stream->codecpar->coded_side_data[i];
        if (side_data.type == AV_PKT_DATA_MASTERING_DISPLAY_METADATA) return 1;
    }

    // 检查 AVFrame side data
    // 先通过 codec context 的 side data 查 HLG transfer
    if (stream->codecpar->color_trc == AVCOL_TRC_ARIB_STD_B67) return 2;
    if (stream->codecpar->color_trc == AVCOL_TRC_SMPTE2084) return 1;

    return 0;
}

HDRMetadata HDRAnalyzer::analyze(AVFormatContext* fmt_ctx,
                                  AVCodecContext* codec_ctx,
                                  int video_stream_index) {
    HDRMetadata meta = {};
    meta.hdr_type = detectHdrType(fmt_ctx, video_stream_index);

    AVStream* stream = fmt_ctx->streams[video_stream_index];

    // 读取 Mastering Display Metadata
    AVMasteringDisplayMetadata* mastering = nullptr;
    AVContentLightMetadata* light = nullptr;

    for (int i = 0; i < stream->codecpar->nb_coded_side_data; ++i) {
        auto* sd = &stream->codecpar->coded_side_data[i];
        if (sd->type == AV_PKT_DATA_MASTERING_DISPLAY_METADATA) {
            mastering = (AVMasteringDisplayMetadata*)sd->data;
        }
        if (sd->type == AV_PKT_DATA_CONTENT_LIGHT_LEVEL) {
            light = (AVContentLightMetadata*)sd->data;
        }
    }

    if (mastering) {
        if (mastering->has_luminance) {
            meta.max_luminance = av_q2d(mastering->max_luminance);
            meta.min_luminance = av_q2d(mastering->min_luminance);
        }
        if (mastering->has_primaries) {
            meta.primaries[0] = av_q2d(mastering->display_primaries[0][0]);
            meta.primaries[1] = av_q2d(mastering->display_primaries[0][1]);
            meta.primaries[2] = av_q2d(mastering->display_primaries[1][0]);
            meta.primaries[3] = av_q2d(mastering->display_primaries[1][1]);
            meta.primaries[4] = av_q2d(mastering->display_primaries[2][0]);
            meta.primaries[5] = av_q2d(mastering->display_primaries[2][1]);
            meta.primaries[6] = av_q2d(mastering->white_point[0]);
            meta.primaries[7] = av_q2d(mastering->white_point[1]);
        }
    }

    if (light) {
        meta.max_cll = light->MaxCLL;
        meta.max_fall = light->MaxFALL;
    }

    if (meta.max_luminance <= 0) {
        meta.max_luminance = meta.hdr_type == 2 ? 1000.0 : 203.0;
    }

    meta.avg_luminance = meta.max_luminance * 0.2;

    return meta;
}
```

- [ ] **Step 3: 提交**

```bash
git add native/src/hdr_analyzer.h native/src/hdr_analyzer.cpp
git commit -m "feat: 添加 HDR 元数据分析器模块"
```

---

### Task 7: C++ ToneMapper 和 InverseToneMapper

**Files:**
- Create: `native/src/tone_mapper.h`
- Create: `native/src/tone_mapper.cpp`
- Create: `native/src/inverse_tone_mapper.h`
- Create: `native/src/inverse_tone_mapper.cpp`

**Interfaces:**
- Consumes: `AVFrame`, `HDRMetadata`
- Produces: tone-mapped AVFrame

- [ ] **Step 1: 创建 native/src/tone_mapper.h**

```cpp
#ifndef TONE_MAPPER_H
#define TONE_MAPPER_H

extern "C" {
#include <libavutil/frame.h>
}

struct ToneMapParams {
    double peak_luminance;
    double exposure;
    double saturation;
};

class ToneMapper {
public:
    ToneMapper();
    void apply(AVFrame* frame, const ToneMapParams& params);
    void setAlgorithm(int algo); // 0=BT.2390, 1=Reinhard, 2=Mobius
private:
    void applyBt2390(AVFrame* frame, const ToneMapParams& params);
    int algorithm_;
};

#endif
```

- [ ] **Step 2: 创建 native/src/tone_mapper.cpp**

```cpp
#include "tone_mapper.h"
#include <cmath>
#include <cstring>

ToneMapper::ToneMapper() : algorithm_(0) {}

void ToneMapper::setAlgorithm(int algo) {
    algorithm_ = algo;
}

void ToneMapper::apply(AVFrame* frame, const ToneMapParams& params) {
    if (!frame) return;
    applyBt2390(frame, params);
}

void ToneMapper::applyBt2390(AVFrame* frame, const ToneMapParams& params) {
    int width = frame->width;
    int height = frame->height;
    float peak = params.peak_luminance > 0 ? params.peak_luminance : 1000.0f;
    float ev = powf(2.0f, params.exposure);
    float sat = params.saturation;

    // 对每个像素应用 BT.2390 tone mapping
    for (int y = 0; y < height; ++y) {
        for (int x = 0; x < width; ++x) {
            // 获取 RGB 值（假设 frame 数据为 float32 平面格式）
            float* r = (float*)(frame->data[0] + y * frame->linesize[0]) + x;
            float* g = (float*)(frame->data[1] + y * frame->linesize[1]) + x;
            float* b = (float*)(frame->data[2] + y * frame->linesize[2]) + x;

            float rv = *r * ev;
            float gv = *g * ev;
            float bv = *b * ev;

            // BT.2390 tone mapping curve
            float max_rgb = fmaxf(rv, fmaxf(gv, bv));
            if (max_rgb > 0.0f) {
                float mapped = (max_rgb * (1.0f + max_rgb / peak)) /
                               (1.0f + max_rgb);
                float scale = mapped / max_rgb;
                *r = rv * scale;
                *g = gv * scale;
                *b = bv * scale;
            }

            // 饱和度调整
            float lum = 0.2126f * (*r) + 0.7152f * (*g) + 0.0722f * (*b);
            *r = lum + sat * (*r - lum);
            *g = lum + sat * (*g - lum);
            *b = lum + sat * (*b - lum);
        }
    }
}
```

- [ ] **Step 3: 创建 native/src/inverse_tone_mapper.h**

```cpp
#ifndef INVERSE_TONE_MAPPER_H
#define INVERSE_TONE_MAPPER_H

extern "C" {
#include <libavutil/frame.h>
}

struct InvToneMapParams {
    double target_peak;     // 目标峰值亮度 nit
    double exposure;
    double saturation;
};

class InverseToneMapper {
public:
    InverseToneMapper();
    void apply(AVFrame* frame, const InvToneMapParams& params);
private:
    void applyExpansion(AVFrame* frame, const InvToneMapParams& params);
};

#endif
```

- [ ] **Step 4: 创建 native/src/inverse_tone_mapper.cpp**

```cpp
#include "inverse_tone_mapper.h"
#include <cmath>

InverseToneMapper::InverseToneMapper() {}

void InverseToneMapper::apply(AVFrame* frame, const InvToneMapParams& params) {
    applyExpansion(frame, params);
}

void InverseToneMapper::applyExpansion(AVFrame* frame, const InvToneMapParams& params) {
    int width = frame->width;
    int height = frame->height;
    float target_peak = params.target_peak > 0 ? params.target_peak : 1000.0f;
    float ev = powf(2.0f, params.exposure);
    float sat = params.saturation;

    for (int y = 0; y < height; ++y) {
        for (int x = 0; x < width; ++x) {
            float* r = (float*)(frame->data[0] + y * frame->linesize[0]) + x;
            float* g = (float*)(frame->data[1] + y * frame->linesize[1]) + x;
            float* b = (float*)(frame->data[2] + y * frame->linesize[2]) + x;

            // SDR (0-1) -> HDR (0-target_peak) 扩展
            float rv = *r * ev;
            float gv = *g * ev;
            float bv = *b * ev;

            // 简单的线性扩展 + roll-off
            float max_rgb = fmaxf(rv, fmaxf(gv, bv));
            if (max_rgb > 0.0f) {
                float expanded = max_rgb * (target_peak / 203.0f);
                float scale = expanded / max_rgb;
                *r = rv * scale;
                *g = gv * scale;
                *b = bv * scale;
            }

            // 饱和度调整
            float lum = 0.2126f * (*r) + 0.7152f * (*g) + 0.0722f * (*b);
            *r = lum + sat * (*r - lum);
            *g = lum + sat * (*g - lum);
            *b = lum + sat * (*b - lum);
        }
    }
}
```

- [ ] **Step 5: 提交**

```bash
git add native/src/tone_mapper.h native/src/tone_mapper.cpp
git add native/src/inverse_tone_mapper.h native/src/inverse_tone_mapper.cpp
git commit -m "feat: 添加 ToneMapper 和 InverseToneMapper 模块"
```

---

### Task 8: C++ ColorConverter 和 HDRMetadataInjector

**Files:**
- Create: `native/src/color_converter.h`
- Create: `native/src/color_converter.cpp`
- Create: `native/src/hdr_metadata_injector.h`
- Create: `native/src/hdr_metadata_injector.cpp`

- [ ] **Step 1: 创建 native/src/color_converter.h**

```cpp
#ifndef COLOR_CONVERTER_H
#define COLOR_CONVERTER_H

extern "C" {
#include <libavutil/frame.h>
#include <libswscale/swscale.h>
}

class ColorConverter {
public:
    ColorConverter();
    ~ColorConverter();
    int convert(AVFrame* src, AVFrame* dst, int src_csp, int dst_csp);
private:
    SwsContext* sws_ctx_;
};

#endif
```

- [ ] **Step 2: 创建 native/src/color_converter.cpp**

```cpp
#include "color_converter.h"
#include <cstring>

ColorConverter::ColorConverter() : sws_ctx_(nullptr) {}

ColorConverter::~ColorConverter() {
    if (sws_ctx_) {
        sws_freeContext(sws_ctx_);
    }
}

int ColorConverter::convert(AVFrame* src, AVFrame* dst, int src_csp, int dst_csp) {
    if (!src || !dst) return -1;

    int src_colorspace = AVCOL_SPC_BT2020_NCL;
    int dst_colorspace = AVCOL_SPC_BT709;
    int src_color_trc = AVCOL_TRC_SMPTE2084;
    int dst_color_trc = AVCOL_TRC_BT709;

    if (src_csp == 0) { // BT.709
        src_colorspace = AVCOL_SPC_BT709;
        src_color_trc = AVCOL_TRC_BT709;
    } else if (src_csp == 2) { // DCI-P3
        src_colorspace = AVCOL_SPC_SMPTE170M;
    }

    if (dst_csp == 0) { // BT.709
        dst_colorspace = AVCOL_SPC_BT709;
        dst_color_trc = AVCOL_TRC_BT709;
    } else if (dst_csp == 2) { // DCI-P3
        dst_colorspace = AVCOL_SPC_SMPTE170M;
    }

    sws_ctx_ = sws_getContext(
        src->width, src->height, (AVPixelFormat)src->format,
        dst->width, dst->height, (AVPixelFormat)dst->format,
        SWS_BILINEAR, nullptr, nullptr, nullptr);

    if (!sws_ctx_) return -1;

    sws_setColorspaceDetails(sws_ctx_,
        sws_getCoefficients(src_colorspace), src_color_trc,
        sws_getCoefficients(dst_colorspace), dst_color_trc,
        0, 1 << 16, 1 << 16);

    sws_scale(sws_ctx_, src->data, src->linesize, 0, src->height,
              dst->data, dst->linesize);

    return 0;
}
```

- [ ] **Step 3: 创建 native/src/hdr_metadata_injector.h**

```cpp
#ifndef HDR_METADATA_INJECTOR_H
#define HDR_METADATA_INJECTOR_H

extern "C" {
#include <libavformat/avformat.h>
#include <libavcodec/avcodec.h>
}

struct HDRInjectParams {
    double max_luminance;
    double min_luminance;
    double max_cll;
    double max_fall;
    int hdr_type; // 1=HDR10, 2=HLG
};

class HDRMetadataInjector {
public:
    static void injectSideData(AVCodecContext* codec_ctx,
                                AVFormatContext* fmt_ctx,
                                const HDRInjectParams& params);
};

#endif
```

- [ ] **Step 4: 创建 native/src/hdr_metadata_injector.cpp**

```cpp
#include "hdr_metadata_injector.h"
#include <cstring>

void HDRMetadataInjector::injectSideData(AVCodecContext* codec_ctx,
                                          AVFormatContext* fmt_ctx,
                                          const HDRInjectParams& params) {
    if (!codec_ctx) return;

    // 设置色彩参数
    codec_ctx->color_primaries = AVCOL_PRI_BT2020;
    codec_ctx->color_trc = (params.hdr_type == 2)
        ? AVCOL_TRC_ARIB_STD_B67
        : AVCOL_TRC_SMPTE2084;
    codec_ctx->colorspace = AVCOL_SPC_BT2020_NCL;

    // HDR10 需要注入 Mastering Display Metadata
    if (params.hdr_type == 1) {
        auto* mastering = (AVMasteringDisplayMetadata*)
            av_mallocz(sizeof(AVMasteringDisplayMetadata));
        if (!mastering) return;

        // BT.2020 基色
        mastering->display_primaries[0][0] = av_d2q(0.708, 100000);
        mastering->display_primaries[0][1] = av_d2q(0.292, 100000);
        mastering->display_primaries[1][0] = av_d2q(0.170, 100000);
        mastering->display_primaries[1][1] = av_d2q(0.797, 100000);
        mastering->display_primaries[2][0] = av_d2q(0.131, 100000);
        mastering->display_primaries[2][1] = av_d2q(0.046, 100000);
        mastering->white_point[0] = av_d2q(0.3127, 100000);
        mastering->white_point[1] = av_d2q(0.3290, 100000);
        mastering->max_luminance = av_d2q(params.max_luminance, 10000);
        mastering->min_luminance = av_d2q(params.min_luminance > 0
            ? params.min_luminance : 0.005, 10000);
        mastering->has_luminance = 1;
        mastering->has_primaries = 1;

        av_stream_add_side_data(fmt_ctx->streams[0],
            AV_PKT_DATA_MASTERING_DISPLAY_METADATA,
            (uint8_t*)mastering,
            sizeof(AVMasteringDisplayMetadata));
    }
}
```

- [ ] **Step 5: 提交**

```bash
git add native/src/color_converter.h native/src/color_converter.cpp
git add native/src/hdr_metadata_injector.h native/src/hdr_metadata_injector.cpp
git commit -m "feat: 添加 ColorConverter 和 HDRMetadataInjector 模块"
```

---

### Task 9: C++ Encoder 模块

**Files:**
- Create: `native/src/encoder.h`
- Create: `native/src/encoder.cpp`

- [ ] **Step 1: 创建 native/src/encoder.h**

```cpp
#ifndef ENCODER_H
#define ENCODER_H

#include <string>
#include <atomic>
#include <functional>
extern "C" {
#include <libavformat/avformat.h>
#include <libavcodec/avcodec.h>
#include <libavutil/frame.h>
}

using ProgressCb = std::function<void(int percent, int64_t current, int64_t total)>;

class Encoder {
public:
    Encoder();
    ~Encoder();

    int open(const std::string& filename, AVCodecContext* dec_ctx,
             int encoder_type, int crf,
             int target_width, int target_height,
             int crop_left, int crop_right, int crop_top, int crop_bottom);
    void close();
    int encodeFrame(AVFrame* frame);
    int finalize();
    void cancel();

private:
    AVFormatContext* fmt_ctx_;
    AVCodecContext* enc_ctx_;
    AVStream* stream_;
    bool initialized_;
    std::atomic<bool> cancelled_;
    int frame_count_;
};

#endif
```

- [ ] **Step 2: 创建 native/src/encoder.cpp**

```cpp
#include "encoder.h"
#include <iostream>

Encoder::Encoder()
    : fmt_ctx_(nullptr), enc_ctx_(nullptr), stream_(nullptr),
      initialized_(false), cancelled_(false), frame_count_(0) {}

Encoder::~Encoder() {
    close();
}

int Encoder::open(const std::string& filename, AVCodecContext* dec_ctx,
                   int encoder_type, int crf,
                   int target_width, int target_height,
                   int crop_left, int crop_right, int crop_top, int crop_bottom) {
    int ret;

    ret = avformat_alloc_output_context2(&fmt_ctx_, nullptr, nullptr, filename.c_str());
    if (ret < 0) return ret;

    // 选择编码器
    const AVCodec* codec = nullptr;
    const char* codec_name = nullptr;
    switch (encoder_type) {
        case 0: codec_name = "libx264"; break;
        case 1: codec_name = "libx265"; break;
        case 2: codec_name = "libaom-av1"; break;
        default: codec_name = "libx265";
    }
    codec = avcodec_find_encoder_by_name(codec_name);
    if (!codec) return AVERROR_ENCODER_NOT_FOUND;

    enc_ctx_ = avcodec_alloc_context3(codec);
    if (!enc_ctx_) return AVERROR(ENOMEM);

    int out_w = target_width > 0 ? target_width : (dec_ctx->width - crop_left - crop_right);
    int out_h = target_height > 0 ? target_height : (dec_ctx->height - crop_top - crop_bottom);

    enc_ctx_->width = out_w;
    enc_ctx_->height = out_h;
    enc_ctx_->time_base = dec_ctx->time_base;
    enc_ctx_->pix_fmt = AV_PIX_FMT_YUV420P;
    enc_ctx_->color_primaries = dec_ctx->color_primaries;
    enc_ctx_->color_trc = dec_ctx->color_trc;
    enc_ctx_->colorspace = dec_ctx->colorspace;
    enc_ctx_->flags |= AV_CODEC_FLAG_GLOBAL_HEADER;

    if (codec->id == AV_CODEC_ID_H264 || codec->id == AV_CODEC_ID_H265) {
        av_opt_set(enc_ctx_->priv_data, "crf", std::to_string(crf).c_str(), 0);
        av_opt_set(enc_ctx_->priv_data, "preset", "medium", 0);
    }

    ret = avcodec_open2(enc_ctx_, codec, nullptr);
    if (ret < 0) return ret;

    stream_ = avformat_new_stream(fmt_ctx_, codec);
    if (!stream_) return AVERROR(ENOMEM);

    ret = avcodec_parameters_from_context(stream_->codecpar, enc_ctx_);
    if (ret < 0) return ret;
    stream_->time_base = enc_ctx_->time_base;

    if (!(fmt_ctx_->oformat->flags & AVFMT_NOFILE)) {
        ret = avio_open(&fmt_ctx_->pb, filename.c_str(), AVIO_FLAG_WRITE);
        if (ret < 0) return ret;
    }

    ret = avformat_write_header(fmt_ctx_, nullptr);
    if (ret < 0) return ret;

    initialized_ = true;
    return 0;
}

void Encoder::close() {
    if (enc_ctx_) {
        avcodec_free_context(&enc_ctx_);
    }
    if (fmt_ctx_ && !(fmt_ctx_->oformat->flags & AVFMT_NOFILE)) {
        avio_closep(&fmt_ctx_->pb);
    }
    if (fmt_ctx_) {
        avformat_free_context(fmt_ctx_);
    }
    initialized_ = false;
}

int Encoder::encodeFrame(AVFrame* frame) {
    if (!initialized_ || cancelled_) return -1;

    int ret = avcodec_send_frame(enc_ctx_, frame);
    if (ret < 0) return ret;

    AVPacket* pkt = av_packet_alloc();
    ret = avcodec_receive_packet(enc_ctx_, pkt);
    if (ret >= 0) {
        pkt->stream_index = 0;
        av_interleaved_write_frame(fmt_ctx_, pkt);
        frame_count_++;
    }
    av_packet_free(&pkt);
    return ret;
}

int Encoder::finalize() {
    if (!initialized_) return -1;

    // flush encoder
    int ret = avcodec_send_frame(enc_ctx_, nullptr);
    if (ret < 0) return ret;

    AVPacket* pkt = av_packet_alloc();
    while (true) {
        ret = avcodec_receive_packet(enc_ctx_, pkt);
        if (ret < 0) break;
        pkt->stream_index = 0;
        av_interleaved_write_frame(fmt_ctx_, pkt);
    }
    av_packet_free(&pkt);

    av_write_trailer(fmt_ctx_);
    return 0;
}

void Encoder::cancel() {
    cancelled_ = true;
}
```

- [ ] **Step 3: 提交**

```bash
git add native/src/encoder.h native/src/encoder.cpp
git commit -m "feat: 添加视频编码器模块"
```

---

### Task 10: C++ Pipeline 管线编排

**Files:**
- Create: `native/src/pipeline.h`
- Create: `native/src/pipeline.cpp`
- Modify: `native/include/hdr_converter.h` (已经创建)

**Interfaces:**
- Consumes: 所有以上 C++ 模块
- Produces: `Pipeline` 类，实现完整的转换管线

- [ ] **Step 1: 创建 native/src/pipeline.h**

```cpp
#ifndef PIPELINE_H
#define PIPELINE_H

#include <string>
#include <atomic>
#include <thread>
#include "hdr_converter.h"
#include "decoder.h"
#include "hdr_analyzer.h"
#include "tone_mapper.h"
#include "inverse_tone_mapper.h"
#include "color_converter.h"
#include "hdr_metadata_injector.h"
#include "encoder.h"

class Pipeline {
public:
    Pipeline();
    ~Pipeline();

    int open(const std::string& input_path);
    void close();
    int getFrameCount() const;
    VideoInfo getInfo() const;
    void setParams(ConvertParams params);
    int getFrame(uint8_t* out_buffer, int64_t timestamp_us,
                 int* out_width, int* out_height);
    int start(const std::string& output_path,
              ProgressCallback progress_cb,
              CompletionCallback complete_cb,
              void* user_data);
    void cancel();

private:
    void conversionThread(const std::string& output_path,
                          ProgressCallback progress_cb,
                          CompletionCallback complete_cb,
                          void* user_data);
    int processHdrToSdr(AVFrame* frame);
    int processSdrToHdr(AVFrame* frame);
    int swFrameToBgra(AVFrame* frame, uint8_t* out_buffer, int* w, int* h);

    Decoder decoder_;
    HDRAnalyzer analyzer_;
    ToneMapper tone_mapper_;
    InverseToneMapper inv_tone_mapper_;
    ColorConverter color_converter_;
    HDRMetadataInjector metadata_injector_;
    Encoder encoder_;

    ConvertParams params_;
    HDRMetadata hdr_meta_;
    std::atomic<bool> cancelled_;
    std::thread worker_thread_;
    bool initialized_;
};

#endif
```

- [ ] **Step 2: 创建 native/src/pipeline.cpp**

```cpp
#include "pipeline.h"
#include <cstring>
#include <iostream>
extern "C" {
#include <libswscale/swscale.h>
#include <libavutil/imgutils.h>
}

Pipeline::Pipeline()
    : cancelled_(false), initialized_(false) {
    memset(&params_, 0, sizeof(params_));
    memset(&hdr_meta_, 0, sizeof(hdr_meta_));
    params_.peak_luminance = 1000.0;
    params_.saturation = 1.0;
    params_.crf = 23;
}

Pipeline::~Pipeline() {
    cancel();
    if (worker_thread_.joinable()) worker_thread_.join();
}

int Pipeline::open(const std::string& input_path) {
    int ret = decoder_.open(input_path);
    if (ret < 0) return ret;

    hdr_meta_ = HDRAnalyzer::analyze(
        decoder_.getFormatContext(),
        decoder_.getCodecContext(),
        decoder_.getVideoStreamIndex());

    initialized_ = true;
    return 0;
}

void Pipeline::close() {
    cancel();
    if (worker_thread_.joinable()) worker_thread_.join();
    decoder_.close();
    initialized_ = false;
}

int Pipeline::getFrameCount() const {
    return decoder_.getFrameCount();
}

VideoInfo Pipeline::getInfo() const {
    VideoInfo info = {};
    info.width = decoder_.getWidth();
    info.height = decoder_.getHeight();
    info.fps = decoder_.getFps();
    info.frame_count = getFrameCount();
    info.duration_sec = decoder_.getDurationSec();
    info.is_hdr = hdr_meta_.hdr_type;
    info.max_luminance = hdr_meta_.max_luminance;
    info.pixel_format = decoder_.getPixelFormat();
    return info;
}

void Pipeline::setParams(ConvertParams params) {
    params_ = params;
}

int Pipeline::swFrameToBgra(AVFrame* frame, uint8_t* out_buffer, int* w, int* h) {
    int out_w = frame->width;
    int out_h = frame->height;
    *w = out_w;
    *h = out_h;

    uint8_t* dst_data[4] = {nullptr};
    int dst_linesize[4] = {0};
    av_image_alloc(dst_data, dst_linesize, out_w, out_h,
                   AV_PIX_FMT_BGRA, 1);

    SwsContext* sws = sws_getContext(
        frame->width, frame->height, (AVPixelFormat)frame->format,
        out_w, out_h, AV_PIX_FMT_BGRA,
        SWS_BILINEAR, nullptr, nullptr, nullptr);

    if (!sws) return -1;

    sws_scale(sws, frame->data, frame->linesize, 0, frame->height,
              dst_data, dst_linesize);

    int size = dst_linesize[0] * out_h;
    memcpy(out_buffer, dst_data[0], size);

    sws_freeContext(sws);
    av_freep(&dst_data[0]);
    return 0;
}

int Pipeline::getFrame(uint8_t* out_buffer, int64_t timestamp_us,
                        int* out_width, int* out_height) {
    if (!initialized_) return -1;

    AVFrame* frame = decoder_.seekAndDecode(timestamp_us);
    if (!frame) return -1;

    int ret = 0;
    if (hdr_meta_.hdr_type > 0) {
        ret = processHdrToSdr(frame);
    }

    if (ret == 0) {
        ret = swFrameToBgra(frame, out_buffer, out_width, out_height);
    }

    av_frame_free(&frame);
    return ret;
}

int Pipeline::processHdrToSdr(AVFrame* frame) {
    ToneMapParams tmp = {};
    tmp.peak_luminance = params_.peak_luminance > 0
        ? params_.peak_luminance : hdr_meta_.max_luminance;
    tmp.exposure = params_.exposure;
    tmp.saturation = params_.saturation;
    tone_mapper_.apply(frame, tmp);

    // 转换到 BT.709
    AVFrame* dst = av_frame_alloc();
    dst->format = AV_PIX_FMT_YUV420P;
    dst->width = frame->width;
    dst->height = frame->height;
    av_frame_get_buffer(dst, 32);

    color_converter_.convert(frame, dst, 1, 0);

    av_frame_unref(frame);
    av_frame_move_ref(frame, dst);
    av_frame_free(&dst);
    return 0;
}

int Pipeline::processSdrToHdr(AVFrame* frame) {
    InvToneMapParams itmp = {};
    itmp.target_peak = params_.peak_luminance > 0
        ? params_.peak_luminance : 1000.0;
    itmp.exposure = params_.exposure;
    itmp.saturation = params_.saturation;
    inv_tone_mapper_.apply(frame, itmp);

    AVFrame* dst = av_frame_alloc();
    dst->format = AV_PIX_FMT_YUV420P;
    dst->width = frame->width;
    dst->height = frame->height;
    av_frame_get_buffer(dst, 32);

    color_converter_.convert(frame, dst, 0, 1);

    av_frame_unref(frame);
    av_frame_move_ref(frame, dst);
    av_frame_free(&dst);
    return 0;
}

void Pipeline::conversionThread(const std::string& output_path,
                                 ProgressCallback progress_cb,
                                 CompletionCallback complete_cb,
                                 void* user_data) {
    int ret = encoder_.open(output_path,
        decoder_.getCodecContext(),
        params_.encoder, params_.crf,
        params_.target_width, params_.target_height,
        params_.crop_left, params_.crop_right,
        params_.crop_top, params_.crop_bottom);
    if (ret < 0) {
        if (complete_cb) complete_cb(0, "编码器初始化失败", user_data);
        return;
    }

    int total_frames = getFrameCount();
    int frame_idx = 0;

    // 先 seek 到开头
    decoder_.seekAndDecode(0);

    while (!cancelled_) {
        AVFrame* frame = decoder_.decodeNextFrame();
        if (!frame) break;

        if (params_.direction == 0) {
            ret = processHdrToSdr(frame);
        } else {
            ret = processSdrToHdr(frame);
        }

        if (ret == 0) {
            ret = encoder_.encodeFrame(frame);
        }

        av_frame_free(&frame);

        if (ret < 0 && ret != AVERROR(EAGAIN)) break;

        frame_idx++;
        if (progress_cb && total_frames > 0) {
            int pct = (int)(frame_idx * 100 / total_frames);
            progress_cb(pct, frame_idx, total_frames, user_data);
        }
    }

    encoder_.finalize();

    if (cancelled_) {
        if (complete_cb) complete_cb(0, "用户取消", user_data);
    } else {
        if (complete_cb) complete_cb(1, nullptr, user_data);
    }
}

int Pipeline::start(const std::string& output_path,
                     ProgressCallback progress_cb,
                     CompletionCallback complete_cb,
                     void* user_data) {
    if (!initialized_) return -1;

    cancelled_ = false;
    try {
        worker_thread_ = std::thread(&Pipeline::conversionThread, this,
                                      output_path, progress_cb, complete_cb, user_data);
        worker_thread_.detach();
    } catch (...) {
        return -1;
    }
    return 0;
}

void Pipeline::cancel() {
    cancelled_ = true;
    encoder_.cancel();
}
```

- [ ] **Step 3: 提交**

```bash
git add native/src/pipeline.h native/src/pipeline.cpp
git commit -m "feat: 添加管线编排模块"
```

---

### Task 11: C++ 导出函数实现（converter.cpp）

**Files:**
- Create: `native/src/converter.cpp`

- [ ] **Step 1: 创建 native/src/converter.cpp**

```cpp
#include "hdr_converter.h"
#include "pipeline.h"
#include <cstring>

extern "C" {

EXPORT void* converter_create() {
    return new Pipeline();
}

EXPORT void converter_destroy(void* handle) {
    delete static_cast<Pipeline*>(handle);
}

EXPORT int converter_open(void* handle, const char* input_path) {
    return static_cast<Pipeline*>(handle)->open(input_path);
}

EXPORT void converter_close(void* handle) {
    static_cast<Pipeline*>(handle)->close();
}

EXPORT int converter_get_frame_count(void* handle) {
    return static_cast<Pipeline*>(handle)->getFrameCount();
}

EXPORT void converter_get_info(void* handle, VideoInfo* out_info) {
    *out_info = static_cast<Pipeline*>(handle)->getInfo();
}

EXPORT void converter_set_params(void* handle, ConvertParams params) {
    static_cast<Pipeline*>(handle)->setParams(params);
}

EXPORT int converter_get_frame(void* handle, uint8_t* out_buffer,
                                int64_t timestamp_us, int* out_width,
                                int* out_height) {
    return static_cast<Pipeline*>(handle)->getFrame(
        out_buffer, timestamp_us, out_width, out_height);
}

EXPORT int converter_start(void* handle, const char* output_path,
                            ProgressCallback progress_cb,
                            CompletionCallback complete_cb,
                            void* user_data) {
    return static_cast<Pipeline*>(handle)->start(
        output_path, progress_cb, complete_cb, user_data);
}

EXPORT void converter_cancel(void* handle) {
    static_cast<Pipeline*>(handle)->cancel();
}

}
```

- [ ] **Step 2: 提交**

```bash
git add native/src/converter.cpp
git commit -m "feat: 添加 C 导出函数实现，完成核心库"
```

---

### Task 12: Flutter UI — Provider 状态管理

**Files:**
- Create: `lib/providers/convert_provider.dart`

**Interfaces:**
- Consumes: `NativeBridge`, `ConvertParams`, `VideoFile`, `VideoInfo` (Tasks 2, 3)
- Produces: `ConvertProvider` ChangeNotifier

- [ ] **Step 1: 创建 lib/providers/convert_provider.dart**

```dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/video_file.dart';
import '../models/convert_params.dart';
import '../models/video_info.dart';

class ConvertProvider extends ChangeNotifier {
  final List<VideoFile> _queue = [];
  ConvertParams _params = const ConvertParams();
  VideoFile? _currentFile;
  VideoInfo? _currentInfo;
  double _progress = 0.0;
  int _currentFrame = 0;
  int _totalFrames = 0;
  bool _isConverting = false;
  String? _outputDirectory;
  String? _errorMessage;
  Uint8List? _previewFrame;

  List<VideoFile> get queue => List.unmodifiable(_queue);
  ConvertParams get params => _params;
  VideoFile? get currentFile => _currentFile;
  VideoInfo? get currentInfo => _currentInfo;
  double get progress => _progress;
  int get currentFrame => _currentFrame;
  int get totalFrames => _totalFrames;
  bool get isConverting => _isConverting;
  String? get outputDirectory => _outputDirectory;
  String? get errorMessage => _errorMessage;
  Uint8List? get previewFrame => _previewFrame;

  void addFiles(List<String> paths) {
    for (final path in paths) {
      final name = path.split(RegExp(r'[/\\]')).last;
      _queue.add(VideoFile(filePath: path, fileName: name));
    }
    notifyListeners();
  }

  void removeFile(int index) {
    if (index >= 0 && index < _queue.length) {
      _queue.removeAt(index);
      notifyListeners();
    }
  }

  void setOutputDirectory(String dir) {
    _outputDirectory = dir;
    notifyListeners();
  }

  void updateParams(ConvertParams newParams) {
    _params = newParams;
    notifyListeners();
  }

  void updatePreviewFrame(Uint8List? frame) {
    _previewFrame = frame;
    notifyListeners();
  }

  void startConversion() {
    if (_queue.isEmpty || _isConverting) return;
    _isConverting = true;
    _errorMessage = null;
    _progress = 0.0;
    _currentFrame = 0;
    _currentFile = _queue.firstWhere((f) => f.status == FileStatus.pending);
    _currentFile!.status = FileStatus.converting;
    notifyListeners();
    // 实际的转换调用将在 NativeBridge 实现后完成
  }

  void updateProgress(double p, int current, int total) {
    _progress = p;
    _currentFrame = current;
    _totalFrames = total;
    notifyListeners();
  }

  void onConversionComplete(bool success, String? error) {
    _isConverting = false;
    if (_currentFile != null) {
      _currentFile!.status = success ? FileStatus.completed : FileStatus.failed;
      _currentFile!.errorMessage = error;
    }
    _currentFile = null;
    if (!success) _errorMessage = error;
    notifyListeners();
  }

  void cancelConversion() {
    _isConverting = false;
    notifyListeners();
  }
}
```

- [ ] **Step 2: 提交**

```bash
git add lib/providers/
git commit -m "feat: 添加 Provider 状态管理"
```

---

### Task 13: Flutter UI — Widget 组件

**Files:**
- Create: `lib/widgets/drop_zone.dart`
- Create: `lib/widgets/file_list_tile.dart`
- Create: `lib/widgets/slider_row.dart`
- Create: `lib/widgets/preset_selector.dart`

- [ ] **Step 1: 创建 lib/widgets/drop_zone.dart**

```dart
import 'package:flutter/material.dart';
import 'package:desktop_drop/desktop_drop.dart';

class DropZone extends StatelessWidget {
  final void Function(List<String> paths) onFilesDropped;
  final void Function() onPickFiles;

  const DropZone({
    super.key,
    required this.onFilesDropped,
    required this.onPickFiles,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DropTarget(
      onDragDone: (detail) {
        final paths = detail.files.map((f) => f.path).toList();
        onFilesDropped(paths);
      },
      child: InkWell(
        onTap: onPickFiles,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 180,
          decoration: BoxDecoration(
            border: Border.all(
              color: theme.colorScheme.outline.withOpacity(0.5),
              width: 2,
              strokeAlign: BorderSide.strokeAlignInside,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.cloud_upload_outlined,
                    size: 48, color: theme.colorScheme.primary),
                const SizedBox(height: 12),
                Text('拖拽视频文件到此处',
                    style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text('或点击选择文件',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.primary)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: 创建 lib/widgets/file_list_tile.dart**

```dart
import 'package:flutter/material.dart';
import '../models/video_file.dart';

class FileListTile extends StatelessWidget {
  final VideoFile file;
  final int index;
  final VoidCallback onRemove;

  const FileListTile({
    super.key,
    required this.file,
    required this.index,
    required this.onRemove,
  });

  Color _statusColor(FileStatus status) {
    switch (status) {
      case FileStatus.pending:
        return Colors.grey;
      case FileStatus.analyzing:
        return Colors.blue;
      case FileStatus.ready:
        return Colors.green;
      case FileStatus.converting:
        return Colors.orange;
      case FileStatus.completed:
        return Colors.green;
      case FileStatus.failed:
        return Colors.red;
    }
  }

  String _statusText(FileStatus status) {
    switch (status) {
      case FileStatus.pending:
        return '等待中';
      case FileStatus.analyzing:
        return '分析中';
      case FileStatus.ready:
        return '就绪';
      case FileStatus.converting:
        return '转换中';
      case FileStatus.completed:
        return '已完成';
      case FileStatus.failed:
        return '失败';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
      child: ListTile(
        leading: Icon(Icons.video_file, color: theme.colorScheme.primary),
        title: Text(file.fileName, overflow: TextOverflow.ellipsis),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _statusColor(file.status).withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _statusText(file.status),
                style: TextStyle(
                  color: _statusColor(file.status),
                  fontSize: 12,
                ),
              ),
            ),
            if (file.status == FileStatus.pending)
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: onRemove,
              ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: 创建 lib/widgets/slider_row.dart**

```dart
import 'package:flutter/material.dart';

class SliderRow extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String Function(double value) formatValue;
  final ValueChanged<double> onChanged;

  const SliderRow({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.formatValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Expanded(
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              label: formatValue(value),
              onChanged: onChanged,
            ),
          ),
          SizedBox(
            width: 60,
            child: Text(
              formatValue(value),
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: 创建 lib/widgets/preset_selector.dart**

```dart
import 'package:flutter/material.dart';
import '../models/convert_params.dart';

class PresetSelector extends StatelessWidget {
  final PresetStyle current;
  final ValueChanged<PresetStyle> onChanged;

  const PresetSelector({
    super.key,
    required this.current,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<PresetStyle>(
      segments: const [
        ButtonSegment(value: PresetStyle.standard, label: Text('标准')),
        ButtonSegment(value: PresetStyle.vivid, label: Text('鲜艳')),
        ButtonSegment(value: PresetStyle.cinematic, label: Text('电影感')),
        ButtonSegment(value: PresetStyle.custom, label: Text('自定义')),
      ],
      selected: {current},
      onSelectionChanged: (set) => onChanged(set.first),
    );
  }
}
```

- [ ] **Step 5: 提交**

```bash
git add lib/widgets/
git commit -m "feat: 添加 UI 组件（拖拽区/文件列表/滑块/预设选择器）"
```

---

### Task 14: Flutter UI — 参数面板

**Files:**
- Create: `lib/pages/param_panel.dart`

- [ ] **Step 1: 创建 lib/pages/param_panel.dart**

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/convert_params.dart';
import '../providers/convert_provider.dart';
import '../widgets/slider_row.dart';
import '../widgets/preset_selector.dart';

class ParamPanel extends StatelessWidget {
  const ParamPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ConvertProvider>(
      builder: (context, provider, _) {
        final params = provider.params;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 转换方向
              Row(
                children: [
                  const Text('转换方向'),
                  const SizedBox(width: 12),
                  SegmentedButton<ConvertDirection>(
                    segments: const [
                      ButtonSegment(
                          value: ConvertDirection.hdrToSdr,
                          label: Text('HDR→SDR')),
                      ButtonSegment(
                          value: ConvertDirection.sdrToHdr,
                          label: Text('SDR→HDR')),
                    ],
                    selected: {params.direction},
                    onSelectionChanged: (set) {
                      provider.updateParams(
                          params.copyWith(direction: set.first));
                    },
                  ),
                ],
              ),
              const Divider(),
              // 自动模式
              SwitchListTile(
                title: const Text('自动模式'),
                subtitle: const Text('自动检测 HDR 类型并设置最佳参数'),
                value: params.autoMode,
                onChanged: (v) {
                  provider.updateParams(params.copyWith(autoMode: v));
                },
              ),
              const Divider(),
              const Text('预设风格', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              PresetSelector(
                current: params.presetStyle,
                onChanged: (style) {
                  provider.updateParams(params.copyWith(presetStyle: style));
                },
              ),
              const Divider(),
              if (!params.autoMode) ...[
                SliderRow(
                  label: '峰值亮度',
                  value: params.peakLuminance,
                  min: 100,
                  max: 10000,
                  divisions: 99,
                  formatValue: (v) => '${v.toInt()} nit',
                  onChanged: (v) {
                    provider.updateParams(
                        params.copyWith(peakLuminance: v));
                  },
                ),
                SliderRow(
                  label: '曝光补偿',
                  value: params.exposure,
                  min: -2.0,
                  max: 2.0,
                  divisions: 40,
                  formatValue: (v) => '${v.toStringAsFixed(1)} EV',
                  onChanged: (v) {
                    provider.updateParams(params.copyWith(exposure: v));
                  },
                ),
                SliderRow(
                  label: '饱和度',
                  value: params.saturation,
                  min: 0,
                  max: 2.0,
                  divisions: 200,
                  formatValue: (v) => '${(v * 100).toInt()}%',
                  onChanged: (v) {
                    provider.updateParams(params.copyWith(saturation: v));
                  },
                ),
                const Divider(),
                const Text('色彩空间', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                SegmentedButton<ColorSpace>(
                  segments: const [
                    ButtonSegment(value: ColorSpace.bt709, label: Text('BT.709')),
                    ButtonSegment(value: ColorSpace.bt2020, label: Text('BT.2020')),
                    ButtonSegment(value: ColorSpace.dciP3, label: Text('DCI-P3')),
                  ],
                  selected: {params.targetColorSpace},
                  onSelectionChanged: (set) {
                    provider.updateParams(
                        params.copyWith(targetColorSpace: set.first));
                  },
                ),
                const Divider(),
                const Text('编码设置',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                SegmentedButton<EncoderType>(
                  segments: const [
                    ButtonSegment(value: EncoderType.h264, label: Text('H.264')),
                    ButtonSegment(value: EncoderType.h265, label: Text('H.265')),
                    ButtonSegment(value: EncoderType.av1, label: Text('AV1')),
                  ],
                  selected: {params.encoder},
                  onSelectionChanged: (set) {
                    provider.updateParams(
                        params.copyWith(encoder: set.first));
                  },
                ),
                SliderRow(
                  label: 'CRF',
                  value: params.crf.toDouble(),
                  min: 0,
                  max: 51,
                  divisions: 51,
                  formatValue: (v) => v.toInt().toString(),
                  onChanged: (v) {
                    provider.updateParams(params.copyWith(crf: v.toInt()));
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
```

- [ ] **Step 2: 提交**

```bash
git add lib/pages/param_panel.dart
git commit -m "feat: 添加参数面板页面"
```

---

### Task 15: Flutter UI — 预览面板

**Files:**
- Create: `lib/pages/preview_panel.dart`

- [ ] **Step 1: 创建 lib/pages/preview_panel.dart`

```dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/convert_provider.dart';

class PreviewPanel extends StatelessWidget {
  const PreviewPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ConvertProvider>(
      builder: (context, provider, _) {
        final frame = provider.previewFrame;
        return Container(
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(8),
          ),
          child: frame != null
              ? Image.memory(
                  frame,
                  fit: BoxFit.contain,
                  gaplessPlayback: true,
                )
              : Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.movie_outlined,
                          size: 64, color: Colors.grey[600]),
                      const SizedBox(height: 12),
                      Text('选择文件后显示预览',
                          style: TextStyle(color: Colors.grey[500])),
                    ],
                  ),
                ),
        );
      },
    );
  }
}
```

- [ ] **Step 2: 提交**

```bash
git add lib/pages/preview_panel.dart
git commit -m "feat: 添加预览面板页面"
```

---

### Task 16: Flutter UI — 进度面板

**Files:**
- Create: `lib/pages/progress_panel.dart`

- [ ] **Step 1: 创建 lib/pages/progress_panel.dart`

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/convert_provider.dart';

class ProgressPanel extends StatelessWidget {
  const ProgressPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ConvertProvider>(
      builder: (context, provider, _) {
        if (!provider.isConverting && provider.currentFile == null) {
          return const SizedBox.shrink();
        }

        return Card(
          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '正在转换: ${provider.currentFile?.fileName ?? ""}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: provider.progress / 100.0,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${provider.progress.toStringAsFixed(1)}%'),
                    if (provider.totalFrames > 0)
                      Text('帧 ${provider.currentFrame}/${provider.totalFrames}'),
                  ],
                ),
                const SizedBox(height: 8),
                if (provider.isConverting)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: provider.cancelConversion,
                      icon: const Icon(Icons.stop),
                      label: const Text('取消'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                    ),
                  ),
                if (provider.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '错误: ${provider.errorMessage}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
```

- [ ] **Step 2: 提交**

```bash
git add lib/pages/progress_panel.dart
git commit -m "feat: 添加进度面板页面"
```

---

### Task 17: Flutter UI — 主页面（整合所有面板）

**Files:**
- Create: `lib/pages/home_page.dart`

- [ ] **Step 1: 创建 lib/pages/home_page.dart`

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/convert_provider.dart';
import '../widgets/drop_zone.dart';
import '../widgets/file_list_tile.dart';
import 'preview_panel.dart';
import 'param_panel.dart';
import 'progress_panel.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  Future<void> _pickFiles(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp4', 'mkv', 'mov', 'avi', 'mxf', 'webm'],
      allowMultiple: true,
    );
    if (result != null && context.mounted) {
      context.read<ConvertProvider>().addFiles(
            result.files.map((f) => f.path ?? '').where((p) => p.isNotEmpty).toList(),
          );
    }
  }

  Future<void> _pickOutputDir(BuildContext context) async {
    final dir = await FilePicker.platform.getDirectoryPath();
    if (dir != null && context.mounted) {
      context.read<ConvertProvider>().setOutputDirectory(dir);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('HDR↔SDR 视频转换工具'),
        centerTitle: true,
      ),
      body: Consumer<ConvertProvider>(
        builder: (context, provider, _) {
          return LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 900;
              if (isWide) {
                return _buildWideLayout(context, provider, theme);
              } else {
                return _buildNarrowLayout(context, provider, theme);
              }
            },
          );
        },
      ),
    );
  }

  Widget _buildWideLayout(
      BuildContext context, ConvertProvider provider, ThemeData theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 左侧: 文件管理和参数
        Expanded(
          flex: 2,
          child: Column(
            children: [
              Expanded(child: _buildFileSection(context, provider, theme)),
              const Divider(height: 1),
              Expanded(
                flex: 2,
                child: ParamPanel(),
              ),
            ],
          ),
        ),
        const VerticalDivider(width: 1),
        // 右侧: 预览和进度
        Expanded(
          flex: 3,
          child: Column(
            children: [
              const Expanded(flex: 3, child: PreviewPanel()),
              const ProgressPanel(),
              _buildActionBar(context, provider),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNarrowLayout(
      BuildContext context, ConvertProvider provider, ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          DropZone(
            onFilesDropped: (paths) => provider.addFiles(paths),
            onPickFiles: () => _pickFiles(context),
          ),
          const SizedBox(height: 12),
          _buildFileSection(context, provider, theme),
          const SizedBox(height: 16),
          const PreviewPanel(),
          const SizedBox(height: 16),
          const ParamPanel(),
          const ProgressPanel(),
          const SizedBox(height: 16),
          _buildActionBar(context, provider),
        ],
      ),
    );
  }

  Widget _buildFileSection(
      BuildContext context, ConvertProvider provider, ThemeData theme) {
    return Column(
      children: [
        if (provider.queue.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('文件列表 (${provider.queue.length})',
                    style: theme.textTheme.titleSmall),
                TextButton(
                  onPressed: () => _pickOutputDir(context),
                  child: Text(
                    provider.outputDirectory ?? '选择输出目录',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: provider.queue.length,
              itemBuilder: (context, index) {
                return FileListTile(
                  file: provider.queue[index],
                  index: index,
                  onRemove: () => provider.removeFile(index),
                );
              },
            ),
          ),
        ] else
          Expanded(
            child: DropZone(
              onFilesDropped: (paths) => provider.addFiles(paths),
              onPickFiles: () => _pickFiles(context),
            ),
          ),
      ],
    );
  }

  Widget _buildActionBar(BuildContext context, ConvertProvider provider) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: provider.isConverting || provider.queue.isEmpty
              ? null
              : () => provider.startConversion(),
          icon: const Icon(Icons.swap_horiz),
          label: Text(provider.isConverting ? '转换中...' : '开始转换'),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: 提交**

```bash
git add lib/pages/home_page.dart
git commit -m "feat: 添加主页面，整合所有面板"
```

---

### Task 18: 构建配置和收尾

**Files:**
- Modify: `pubspec.yaml` (已创建于 Task 1)
- Create: `.gitignore`

- [ ] **Step 1: 创建 .gitignore**

```
# Flutter
.dart_tool/
.packages
build/
*.iml
.idea/
.vscode/
*.lock

# Native
native/build/
*.o
*.obj
*.dll
*.dylib
*.so

# Misc
.DS_Store
Thumbs.db
```

- [ ] **Step 2: 检查 pubspec.yaml 完整性

验证 pubspec.yaml 已包含所有依赖

- [ ] **Step 3: 验证 Dart 代码无编译错误

```bash
Set-Location -LiteralPath "E:\ai\hdr2sdr"
flutter analyze
```
Expected: 无错误或仅少量分析警告

- [ ] **Step 4: 提交

```bash
git add .gitignore
git commit -m "chore: 添加 .gitignore 和构建配置"
```