1. native_bridge.dart:106-108 calloc.free → malloc.free (内存管理不匹配)
2. pipeline.cpp:221-223 detach后无法join (线程竞争)
3. tone_mapper.cpp/inverse_tone_mapper.cpp float*假设AVFrame为float32 (实际是YUV420P uint8)
4. color_converter.cpp sws_setColorspaceDetails可能不生效
5. encoder.cpp 硬编码AV_PIX_FMT_YUV420P
6. pipeline.cpp:177 seekAndDecode(0)可能死锁
7. native_bridge.dart getInfo缺少错误处理
8. app.dart 缺少ChangeNotifierProvider包裹
9. progress_panel.dart 隐藏条件导致闪烁
10. encoder.cpp finalize中EAGAIN死循环
