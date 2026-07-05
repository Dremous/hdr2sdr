# Task 5 报告：C++ Decoder 模块

## 实现内容
- 创建了 `native/src/decoder.h` — Decoder 类的头文件，声明了打开/关闭/解码/定位等接口
- 创建了 `native/src/decoder.cpp` — Decoder 类的实现，封装 FFmpeg libavformat/libavcodec

## 文件变更
- `native/src/decoder.h` (新增) — 类声明，包含文件打开、帧解码、seek、属性查询等接口
- `native/src/decoder.cpp` (新增) — 完整实现，包括：
  - `open()` — 打开视频文件、查找视频流、初始化解码器
  - `close()` — 释放所有 FFmpeg 资源
  - `decodeNextFrame()` — 逐帧解码
  - `seekAndDecode()` — 按微秒时间戳定位并解码
  - `flush()` — 刷新解码器缓冲区
  - 属性查询：帧数、帧率、宽高、时长、像素格式

## 自审发现
- 文件末尾均以空行结束 ✓
- 所有代码注释为中文 ✓
- 头文件使用 `#ifndef` 包含保护 ✓
- 使用 `std::mutex` 保证线程安全 ✓
- `AVERROR_DECODER_NOT_FOUND` 非标准错误码，但此符号在 FFmpeg 新版本中可用；若编译报错可替换为 `AVERROR(EINVAL)` ✓