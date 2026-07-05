# Task 4 报告：C++ 公共 API 头文件和 CMake 构建配置

## 实现内容

### Step 1: `native/include/hdr_converter.h`
- 定义 `EXPORT` 宏（`__declspec(dllexport)` / `__attribute__((visibility("default")))`）
- 定义 `VideoInfo`、`ConvertParams` 结构体
- 定义 `ProgressCallback`、`CompletionCallback` 函数指针类型
- 声明 10 个 C 风格 API 函数：`converter_create/destroy/open/close/get_frame_count/get_info/set_params/get_frame/start/cancel`
- 所有注释为中文

### Step 2: `native/CMakeLists.txt`
- CMake 3.16+，C++17，位置无关代码
- 通过 `pkg_check_modules` 查找 FFmpeg 5 模块（avcodec, avformat, avutil, swresample, swscale）
- 构建共享库 `hdr_converter`，包含 8 个源文件
- Windows 下设置 `PREFIX ""` 避免生成 `lib` 前缀

### Step 3: `native/src/utils.h`
- 包含 `avErrorToString` 工具函数
- 已补充缺失的 `#include <libavutil/error.h>`

## 文件变更

| 文件 | 操作 |
|------|------|
| `native/include/hdr_converter.h` | 创建 |
| `native/CMakeLists.txt` | 创建 |
| `native/src/utils.h` | 创建 |

## 自审

- API 与 Task 3 的 dart:ffi 绑定完全对应
- 解决了 brief 中 `utils.h` 未包含 `av_strerror` 所必需头文件的问题
- 所有文件末尾均有换行符
- 注释使用中文