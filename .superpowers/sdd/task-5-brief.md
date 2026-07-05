# Task 5: Android 后台转换 Service

## 包名
com.example.hdr2sdr（plan 里写的 com.dremous.hdr2sdr 不对，用 com.example.hdr2sdr）

**Files:**
- Create: android/app/src/main/kotlin/com/example/hdr2sdr/HdrConversionService.kt
- Create: lib/services/background_service.dart
- Modify: android/app/src/main/kotlin/com/example/hdr2sdr/MainActivity.kt
- Modify: android/app/src/main/AndroidManifest.xml
- Modify: lib/providers/convert_provider.dart

**Interfaces:**
- MethodChannel 'hdr2sdr/background' 双向通信
- Android: HdrConversionService extends Service + startForeground 通知
- Dart: BackgroundService 静态类封装 channel 调用

- [ ] Step 1: 创建 Dart 侧 BackgroundService (lib/services/background_service.dart)
- [ ] Step 2: 创建 HdrConversionService.kt
- [ ] Step 3: AndroidManifest.xml 添加 service 声明（foregroundServiceType="dataSync"）
- [ ] Step 4: MainActivity.kt 注册 'hdr2sdr/background' MethodChannel
- [ ] Step 5: ConvertProvider 中 startConversion/cancelConversion 调用 BackgroundService
- [ ] Step 6: flutter analyze (0 errors)
- [ ] Step 7: git add + commit
