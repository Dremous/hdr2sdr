# Task 6: iOS 后台转换 (BGTaskScheduler)

## 重要: AppDelegate 使用 FlutterImplicitEngineDelegate
当前 AppDelegate 不是传统的 FlutterAppDelegate，而是使用 FlutterImplicitEngineDelegate。
需要在 didInitializeImplicitFlutterEngine(_ engineBridge:) 中注册 channel，不能用 registrar(forPlugin:)。

**Files:**
- Create: ios/Runner/BackgroundService.swift
- Modify: ios/Runner/Info.plist
- Modify: lib/services/background_service.dart
- Modify: ios/Runner/AppDelegate.swift

**Interfaces:**
- Dart → iOS: MethodChannel 'hdr2sdr/background' (startConversion / cancelConversion)
- BGTaskScheduler identifier: "com.example.hdr2sdr.conversion"

- [ ] Step 1: Create BackgroundService.swift — BGTaskScheduler 注册和 MethodChannel handler
- [ ] Step 2: AppDelegate.swift — 在 didInitializeImplicitFlutterEngine 中注册 BackgroundService 和 BGTaskScheduler
- [ ] Step 3: Info.plist — 添加 BGTaskSchedulerPermittedIdentifiers
- [ ] Step 4: Dart BackgroundService — 增加 Platform.isIOS 分支 (startConversion)
- [ ] Step 5: flutter analyze (0 errors)
- [ ] Step 6: git add + commit
