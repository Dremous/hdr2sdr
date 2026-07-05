# Task 2: 模型枚举扩展 + NativeBridge 适配 + DropZone 条件编译

**Files:**
- Modify: lib/models/convert_params.dart
- Modify: native/include/hdr_converter.h
- Modify: lib/ffi/native_bridge.dart
- Modify: lib/widgets/drop_zone.dart

**Interfaces:**
- EncoderType 新增 h264Hardware (=3), h265Hardware (=4)
- NativeBridge._() 增加 Platform.isIOS / Platform.isAndroid 分支
- DropZone.build() 移动端不使用 desktop_drop 包

- [ ] Step 1: 扩展 EncoderType 枚举 — 在 lib/models/convert_params.dart 增加 h264Hardware, h265Hardware
- [ ] Step 2: 更新 C 头文件 encoder 值注释 — native/include/hdr_converter.h 增加注释 (0=H.264, 1=H.265, 2=AV1, 3=H.264_HW, 4=H.265_HW)
- [ ] Step 3: 更新 NativeBridge 平台加载分支 — lib/ffi/native_bridge.dart: 增加 Platform.isAndroid 和 Platform.isIOS 分支
- [ ] Step 4: DropZone 条件编译 — lib/widgets/drop_zone.dart: 移动端不用 desktop_drop，用运行时判断
- [ ] Step 5: 验证: flutter analyze (0 errors)
- [ ] Step 6: git add + commit
