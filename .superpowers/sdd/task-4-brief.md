# Task 4: 移动端文件输出路径处理

## 包名
Android: com.example.hdr2sdr

**Files:**
- Create: lib/services/path_service.dart
- Create: android/app/src/main/kotlin/com/example/hdr2sdr/PathPlugin.kt
- Create: ios/Runner/PathPlugin.swift

**Interfaces:**
- PathService.getOutputDirectory() → Future<String> 通过 MethodChannel 'hdr2sdr/path'
- Android 返回: Environment.getExternalStoragePublicDirectory(DIRECTORY_DOWNLOADS).absolutePath
- iOS 返回: NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, true).first

- [ ] Step 1: Dart PathService (lib/services/path_service.dart)
- [ ] Step 2: Android PathPlugin.kt + 注册到 MainActivity.kt
- [ ] Step 3: iOS PathPlugin.swift + 注册到 AppDelegate.swift
- [ ] Step 4: ConvertProvider 初始化时自动调用 PathService.getOutputDirectory()
- [ ] Step 5: flutter analyze 验证
- [ ] Step 6: git add + commit
