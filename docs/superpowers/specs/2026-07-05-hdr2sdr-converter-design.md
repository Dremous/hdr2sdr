# HDR↔SDR 视频转换工具设计文档

## 概述

一个基于 Flutter + FFmpeg 库（libav*）的全平台桌面/移动端工具，实现 HDR 与 SDR 视频的双向转换，提供图形化参数调节和实时预览能力。

## 技术栈

| 层 | 技术 | 说明 |
|----|------|------|
| UI | Flutter 3 (Material 3) | 全平台（Windows/macOS/Linux/iOS/Android） |
| 桥接 | dart:ffi | 调用 C++ 动态库 |
| 核心引擎 | C++ + FFmpeg libav* | libavformat/libavcodec/libswscale/libswresample |
| 构建 | CMake (C++) + flutter build | 各平台交叉编译 |

## 架构

```
┌──────────────────────────────────────┐
│          Flutter UI (Dart)           │
│  MainPage · PreviewPanel · ParamPanel│
│  QueuePanel · ProgressPanel          │
├──────────────────────────────────────┤
│      dart:ffi bridge layer           │
│  libhdr_converter.h  →  dart:ffi     │
├──────────────────────────────────────┤
│     C++ Core (libhdr_converter)      │
│  Decoder · HDRAnalyzer · ToneMapper  │
│  InverseToneMapper · ColorConverter  │
│  HDRMetadataInjector · Encoder       │
│  Pipeline (管线编排)                 │
└──────────────────────────────────────┘
```

## 功能需求

### 页面结构

1. **主页面**
   - 文件拖拽区（支持 .mp4/.mkv/.mov/.mxf 等常见格式）
   - 文件列表（批量队列）：文件名、格式、分辨率、HDR 类型、状态
   - 转换方向切换按钮：HDR→SDR / SDR→HDR

2. **预览面板**
   - 视频播放器（基于 FFmpeg 解码帧渲染到 Flutter Texture）
   - 播放/暂停/拖动进度
   - 参数调整后实时刷新预览帧

3. **参数面板**
   - 自动模式开关（自动检测 HDR 类型并设置最佳参数）
   - 预设风格下拉：标准 / 鲜艳 / 电影感 / 自定义
   - 峰值亮度滑块：100 ~ 10000 nit，步进 100
   - 曝光补偿滑块：-2.0 ~ +2.0 EV，步进 0.1
   - 饱和度滑块：0 ~ 200%，步进 1
   - 色彩空间选择：BT.709 / BT.2020 / DCI-P3
   - 编码器选择：H.264 / H.265 / AV1
   - CRF 滑块：0~51，步进 1
   - 分辨率选择：原始 / 4K / 1080p / 720p / 自定义宽高
   - 裁切设置：左/右/上/下 像素裁切

4. **进度面板**
   - 当前文件进度条 + 百分比
   - 队列总进度
   - ETA 预估
   - 当前帧/总帧数
   - 取消按钮

5. **导出设置**
   - 输出目录选择（文件对话框）
   - 输出文件名模板（可选）

## C++ 核心模块设计

### 模块职责

| 模块 | 类名 | 职责 |
|------|------|------|
| 解码 | `Decoder` | 打开文件、解封装、解码视频帧到 AVFrame |
| HDR 分析 | `HDRAnalyzer` | 解析 HDR10 静态元数据/HLG/杜比视界 RPU |
| Tone mapping | `ToneMapper` | HDR→SDR：BT.2390/Reinhard/Mobius 算法 |
| 逆 Tone mapping | `InverseToneMapper` | SDR→HDR：基于亮度扩展+色彩扩大的逆映射 |
| 色彩转换 | `ColorSpaceConverter` | 色彩空间矩阵变换（BT.2020↔BT.709↔P3） |
| HDR 元数据注入 | `HDRMetadataInjector` | 为 SDR→HDR 输出写入 HDR10/HLG 元数据 |
| 编码 | `Encoder` | 将处理后的帧编码为指定格式输出 |
| 管线 | `Pipeline` | 串联上述模块，管理转换流程 |

### FFI API

```c
// 生命周期
void* converter_create();
void converter_destroy(void* handle);

// 文件操作
int converter_open(void* handle, const char* input_path);
void converter_close(void* handle);
int converter_get_frame_count(void* handle);

// 视频信息
typedef struct {
    int width, height;
    double fps;
    int64_t frame_count;
    double duration_sec;
    int is_hdr;              // 0=SDR, 1=HDR10, 2=HLG, 3=DolbyVision
    double max_luminance;    // 峰值亮度 nit
    int pixel_format;        // AVPixelFormat
} VideoInfo;
VideoInfo converter_get_info(void* handle);

// 参数设置
typedef struct {
    int direction;           // 0=HDR→SDR, 1=SDR→HDR
    int auto_mode;
    int preset_style;        // 0=标准, 1=鲜艳, 2=电影感, 3=自定义
    double peak_luminance;   // nit
    double exposure;         // EV
    double saturation;       // 0-2.0
    int target_color_space;  // 0=BT.709, 1=BT.2020, 2=DCI-P3
    int encoder;             // 0=H.264, 1=H.265, 2=AV1
    int crf;
    int target_width;
    int target_height;
    int crop_left, crop_right, crop_top, crop_bottom;
} ConvertParams;
void converter_set_params(void* handle, ConvertParams params);

// 预览帧获取（返回 BGRA 数据）
int converter_get_frame(void* handle, uint8_t* out_buffer,
                        int64_t timestamp_us, int* out_width, int* out_height);

// 异步转换回调
typedef void (*ProgressCallback)(int percent, int64_t current_frame,
                                 int64_t total_frames, void* user_data);
typedef void (*CompletionCallback)(int success, const char* error_msg,
                                   void* user_data);

// 开始转换
int converter_start(void* handle, const char* output_path,
                    ProgressCallback progress_cb,
                    CompletionCallback complete_cb,
                    void* user_data);

// 取消转换
void converter_cancel(void* handle);
```

## 转换管线

### HDR→SDR 管线

```
输入文件 → Decoder (AVFrame) → HDRAnalyzer (提取元数据)
        → ToneMapper (HDR→SDR) → ColorSpaceConverter (BT.2020→BT.709)
        → Encoder → 输出文件
```

### SDR→HDR 管线

```
输入文件 → Decoder (AVFrame) → InverseToneMapper (SDR→HDR)
        → ColorSpaceConverter (BT.709→BT.2020)
        → HDRMetadataInjector (写入 MaxFALL/MaxCLL/CTAs)
        → Encoder → 输出文件
```

## 编码格式支持

| 编码器 | HDR→SDR | SDR→HDR |
|--------|---------|---------|
| H.264 (libx264) | ✓ | ✗（不支持 HDR 元数据） |
| H.265 (libx265) | ✓ | ✓（支持 HDR10 元数据） |
| AV1 (libaom-av1) | ✓ | ✓（支持 HDR10 元数据） |

## 数据流

```
用户操作 → Dart 状态管理 (Riverpod/Provider)
         → dart:ffi 调用 C++ API
         → C++ 管线处理帧
         → 进度回调解码回 Dart
         → Dart 更新 UI
```

预览帧流：C++ 解码 AVFrame → swscale 转 BGRA → 拷贝到 dart:ffi Pointer → Flutter Texture widget 渲染。

## 错误处理

- C++ 层所有 API 返回 int 错误码，非零表示错误
- 错误信息通过 `completion_callback` 携带
- Dart 层封装错误码为用户可读的中文/英文消息
- 文件不存在/格式不支持/编码器不可用 等常见错误分类处理

## 项目结构

```
hdr2sdr/
├── lib/                          # Flutter Dart 代码
│   ├── main.dart
│   ├── app.dart
│   ├── ffi/
│   │   ├── native_bridge.dart    # dart:ffi 绑定
│   │   └── types.dart            # 结构体/枚举定义
│   ├── models/
│   │   ├── video_file.dart       # 视频文件模型
│   │   ├── convert_params.dart   # 转换参数模型
│   │   └── video_info.dart       # 视频信息模型
│   ├── providers/
│   │   └── convert_provider.dart # 状态管理
│   ├── pages/
│   │   ├── home_page.dart        # 主页面
│   │   ├── preview_panel.dart    # 预览面板
│   │   ├── param_panel.dart      # 参数面板
│   │   └── progress_panel.dart   # 进度面板
│   └── widgets/
│       ├── drop_zone.dart        # 拖拽区
│       ├── file_list_tile.dart   # 文件列表项
│       ├── slider_row.dart       # 滑块行
│       └── preset_selector.dart  # 预设选择器
├── native/                       # C++ 核心库
│   ├── CMakeLists.txt
│   ├── include/
│   │   └── hdr_converter.h       # 公共 API 头文件
│   └── src/
│       ├── decoder.cpp
│       ├── hdr_analyzer.cpp
│       ├── tone_mapper.cpp
│       ├── inverse_tone_mapper.cpp
│       ├── color_converter.cpp
│       ├── hdr_metadata_injector.cpp
│       ├── encoder.cpp
│       ├── pipeline.cpp
│       └── utils.h
├── windows/                      # Windows 平台配置
├── linux/                        # Linux 平台配置
├── macos/                        # macOS 平台配置
├── ios/                          # iOS 平台配置
├── android/                      # Android 平台配置
└── pubspec.yaml
```