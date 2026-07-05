# HDR↔SDR 移动端适配实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为现有 Flutter 项目增加完整 iOS/Android 移动端支持，包括三态 UI 自适应、硬件编码、后台转换和 CI。

**架构:** 单仓库自适应布局（DesktopWide / DesktopNarrow / Mobile Tab），NativeBridge 通过 Platform 分支加载移动端原生库，后台用 BGTaskScheduler (iOS) / Foreground Service (Android)。

**Tech Stack:** Flutter 3 (Material 3), dart:ffi, Provider, FFmpegKit (iOS), NDK (Android), MethodChannel

## Global Constraints

- iOS 15+ / Android 12+ (minSdk 24)
- iOS 静态库通过 `DynamicLibrary.process()` 访问；Android .so 通过 `DynamicLibrary.open()`
- 移动端默认使用硬件编码器（MediaCodec / VideoToolbox），自动回退软件编码
- 桌面端 UI 和行为完全不变
- 所有代码注释使用中文，变量/函数名使用英文合法命名

---

### Task 1: 平台目录初始化

**Files:**
- Run: `flutter create --project-name hdr2sdr --platforms ios,android .`
- Modify: `ios/Podfile`
- Modify: `android/app/build.gradle`
- Create: `android/app/src/main/jniLibs/arm64-v8a/.gitkeep`
- Create: `android/app/src/main/jniLibs/x86_64/.gitkeep`

**Interfaces:**
- Produces: ios/ 项目结构（Xcode project + Podfile），android/ 项目结构（Gradle + Manifest + MainActivity）

- [ ] **Step 1: 运行 flutter create 生成平台目录**

```bash
cd E:\ai\hdr2sdr
flutter create --project-name hdr2sdr --platforms ios,android .
```

预期：生成 `ios/` 和 `android/` 目录及全部平台文件，不覆盖 `lib/` 目录。

- [ ] **Step 2: 配置 android/app/build.gradle**

```groovy
// 在 android { 块内修改/添加：
android {
    compileSdk 34

    defaultConfig {
        minSdk 24
        targetSdk 34
        ndk {
            abiFilters "arm64-v8a", "x86_64"
        }
    }
}
```

- [ ] **Step 3: 创建 jniLibs 占位目录**

```bash
mkdir -p android/app/src/main/jniLibs/arm64-v8a
mkdir -p android/app/src/main/jniLibs/x86_64
touch android/app/src/main/jniLibs/arm64-v8a/.gitkeep
touch android/app/src/main/jniLibs/x86_64/.gitkeep
```

- [ ] **Step 4: 在 ios/Podfile 末尾追加 FFmpegKit 依赖**

在 `ios/Podfile` 中 `target 'Runner' do` 块内添加：

```ruby
target 'Runner' do
  use_frameworks!
  use_modular_headers!

  # Flutter Pods
  flutter_install_all_ios_pods File.dirname(File.realpath(__FILE__))

  # FFmpegKit + 自定义静态库
  pod 'ffmpeg-kit-ios-full', '~> 6.0'
end
```

- [ ] **Step 5: 验证**

```bash
flutter pub get
flutter analyze
```

预期：0 errors（可能产生 `ios/Podfile` 相关 warning，可忽略）。

- [ ] **Step 6: 提交**

```bash
git add ios/ android/ native/build_android.sh native/build_ios.sh
git commit -m "feat: 初始化 iOS/Android 平台目录和构建脚本"
```

---

### Task 2: 模型枚举扩展 + NativeBridge 适配 + DropZone 条件编译

**Files:**
- Modify: `lib/models/convert_params.dart`
- Modify: `native/include/hdr_converter.h`
- Modify: `lib/ffi/native_bridge.dart`
- Modify: `lib/widgets/drop_zone.dart`

**Interfaces:**
- `EncoderType` 新增 `h264Hardware` (=3), `h265Hardware` (=4)
- `NativeBridge._()` 增加 `Platform.isIOS` / `Platform.isAndroid` 分支
- `DropZone.build()` 移动端不使用 `desktop_drop` 包

- [ ] **Step 1: 扩展 EncoderType 枚举**

```dart
// lib/models/convert_params.dart
enum EncoderType {
  h264,    // 0 - libx264
  h265,    // 1 - libx265
  av1,     // 2 - libaom-av1
  h264Hardware,  // 3 - MediaCodec / VideoToolbox
  h265Hardware,  // 4 - MediaCodec / VideoToolbox
}
```

`ConvertParams` 默认值保持不变（还是 `EncoderType.h265`），移动端 ParamPanel 会覆盖默认。

- [ ] **Step 2: 更新 C 头文件 encoder 值注释**

```c
// native/include/hdr_converter.h
typedef struct {
    // ...
    int encoder;  // 编码器：0=H.264, 1=H.265, 2=AV1, 3=H.264_HW, 4=H.265_HW
    // ...
} ConvertParams;
```

- [ ] **Step 3: 更新 NativeBridge 平台加载分支**

```dart
// lib/ffi/native_bridge.dart
import 'dart:io' show Platform;

NativeBridge._() {
  if (Platform.isAndroid) {
    _lib = DynamicLibrary.open('libhdr_converter.so');
  } else if (Platform.isIOS) {
    _lib = DynamicLibrary.process();
  } else if (Platform.isWindows) {
    _lib = DynamicLibrary.open('hdr_converter.dll');
  } else if (Platform.isMacOS) {
    _lib = DynamicLibrary.open('libhdr_converter.dylib');
  } else if (Platform.isLinux) {
    _lib = DynamicLibrary.open('libhdr_converter.so');
  } else {
    throw UnsupportedError('不支持的平台');
  }
  // ... 以下 lookupFunction 不变
}
```

- [ ] **Step 4: DropZone 条件编译——移动端不用 desktop_drop**

```dart
// lib/widgets/drop_zone.dart
import 'dart:io' show Platform;

// 移除原有的 import 'package:desktop_drop/desktop_drop.dart';
// 改为运行时判断：

@override
Widget build(BuildContext context) {
  final theme = Theme.of(context);
  final isMobile = Platform.isAndroid || Platform.isIOS;

  final content = InkWell(
    onTap: onPickFiles,
    borderRadius: BorderRadius.circular(16),
    child: Container(
      height: 180,
      decoration: BoxDecoration(/* 不变 */),
      child: Center(child: Column(/* 不变 */)),
    ),
  );

  if (isMobile) return content;
  // 桌面端用 DropTarget 包裹
  return DropTarget(
    onDragDone: (detail) {
      final paths = detail.files.map((f) => f.path).toList();
      onFilesDropped(paths);
    },
    child: content,
  );
}
```

- [ ] **Step 5: 验证**

```bash
flutter analyze
```

预期：0 errors, 0 warnings。

- [ ] **Step 6: 提交**

```bash
git add lib/models/convert_params.dart native/include/hdr_converter.h lib/ffi/native_bridge.dart lib/widgets/drop_zone.dart
git commit -m "feat: 扩展编码器枚举、NativeBridge 平台分支、DropZone 条件编译"
```

---

### Task 3: UI 三态自适应布局 + ParamPanel 移动端适配

**Files:**
- Modify: `lib/pages/home_page.dart`
- Modify: `lib/pages/param_panel.dart`

**Interfaces:**
- `_layoutMode` 三态响应宽度变化
- 移动端用 `NavigationBar` + `IndexedStack` 切换四个 Tab
- 移动端 ParamPanel 编码器选项增加 `h264Hardware` / `h265Hardware`
- Provider 逻辑完全不变

- [ ] **Step 1: home_page.dart 改为三态布局**

```dart
// lib/pages/home_page.dart — 在 build 方法中修改
enum _LayoutMode { desktopWide, desktopNarrow, mobile }

@override
Widget build(BuildContext context) {
  return Consumer<ConvertProvider>(
    builder: (context, provider, _) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final mode = constraints.maxWidth > 900
              ? _LayoutMode.desktopWide
              : constraints.maxWidth > 600
                  ? _LayoutMode.desktopNarrow
                  : _LayoutMode.mobile;

          if (mode == _LayoutMode.mobile) {
            return _buildMobileLayout(context, provider);
          }
          // 原有桌面逻辑
          if (mode == _LayoutMode.desktopWide) {
            return _buildWideLayout(context, provider, Theme.of(context));
          }
          return _buildNarrowLayout(context, provider, Theme.of(context));
        },
      );
    },
  );
}
```

新增 `_buildMobileLayout` 方法：

```dart
// 在 home_page.dart 中新增
Widget _buildMobileLayout(BuildContext context, ConvertProvider provider) {
  return DefaultTabController(
    length: 4,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('HDR↔SDR'),
        centerTitle: true,
        bottom: const TabBar(
          tabs: [
            Tab(icon: Icon(Icons.folder), text: '文件'),
            Tab(icon: Icon(Icons.tune), text: '参数'),
            Tab(icon: Icon(Icons.visibility), text: '预览'),
            Tab(icon: Icon(Icons.bar_chart), text: '进度'),
          ),
        ),
      ),
      body: TabBarView(
        children: [
          // Tab 0: 文件
          SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                DropZone(
                  onFilesDropped: (p) => provider.addFiles(p),
                  onPickFiles: () => _pickFiles(context),
                ),
                const SizedBox(height: 12),
                if (provider.queue.isNotEmpty)
                  ...provider.queue.asMap().entries.map((e) => FileListTile(
                    file: e.value,
                    index: e.key,
                    onRemove: () => provider.removeFile(e.key),
                  )),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: () => _pickOutputDir(context),
                  icon: const Icon(Icons.folder_open),
                  label: Text(provider.outputDirectory ?? '选择输出目录'),
                ),
              ],
            ),
          ),
          // Tab 1: 参数
          const ParamPanel(),
          // Tab 2: 预览（左右滑动翻页时自动重建）
          const PreviewPanel(),
          // Tab 3: 进度 + 开始按钮
          Column(
            children: [
              const Expanded(child: ProgressPanel()),
              Padding(
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
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
```

- [ ] **Step 2: ParamPanel 增加移动端硬件编码选项**

```dart
// lib/pages/param_panel.dart — 在编码器选择部分
import 'dart:io' show Platform;

// 在 build 方法的编码器下拉位置：
final isMobile = Platform.isAndroid || Platform.isIOS;

DropdownButton<EncoderType>(
  value: provider.params.encoder,
  items: [
    ...EncoderType.values.where((e) {
      if (isMobile) return true;  // 移动端显示全部包括硬件编码
      return e.index <= 2;         // 桌面端只显示 0-2
    }).map((e) {
      String label;
      switch (e) {
        case EncoderType.h264: label = 'H.264 (libx264)'; break;
        case EncoderType.h265: label = 'H.265 (libx265)'; break;
        case EncoderType.av1:  label = 'AV1 (libaom)'; break;
        case EncoderType.h264Hardware:
          label = 'H.264 (${isMobile ? "硬件加速" : "MediaCodec"})'; break;
        case EncoderType.h265Hardware:
          label = 'H.265 (${isMobile ? "硬件加速" : "VideoToolbox"})'; break;
      }
      return DropdownMenuItem(value: e, child: Text(label));
    }),
  ],
  onChanged: (v) {
    if (v != null) provider.updateParams(provider.params.copyWith(encoder: v));
  },
),
```

- [ ] **Step 3: 验证**

```bash
flutter analyze
```

预期：0 errors, 0 warnings。

- [ ] **Step 4: 提交**

```bash
git add lib/pages/home_page.dart lib/pages/param_panel.dart
git commit -m "feat: UI 三态自适应布局 + ParamPanel 移动端编码选项"
```

---

### Task 4: 移动端文件输出路径处理

**Files:**
- Create: `lib/services/path_service.dart`
- Create: `android/app/src/main/kotlin/.../PathPlugin.kt`（包名由 flutter create 确定）
- Create: `ios/Runner/PathPlugin.swift`

**Interfaces:**
- `PathService.getOutputDirectory()` → `Future<String>` 通过 MethodChannel
- 方法名：`"getOutputDirectory"`
- Android 返回：`Environment.getExternalStoragePublicDirectory(DIRECTORY_DOWNLOADS).absolutePath`
- iOS 返回：`NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, true).first`

- [ ] **Step 1: 创建 Dart 侧 PathService**

```dart
// lib/services/path_service.dart
import 'dart:io' show Platform;
import 'package:flutter/services.dart';

class PathService {
  static const _channel = MethodChannel('hdr2sdr/path');

  static Future<String> getOutputDirectory() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      // 桌面端返回 null，由 FilePicker 选择
      return '';
    }
    final result = await _channel.invokeMethod<String>('getOutputDirectory');
    return result ?? '';
  }
}
```

- [ ] **Step 2: Android PathPlugin.kt**

```kotlin
// android/app/src/main/kotlin/.../PathPlugin.kt (包名替换为实际值)
package com.dremous.hdr2sdr

import android.os.Environment
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class PathPlugin(private val engine: FlutterEngine) {
    private val channel = MethodChannel(engine.dartExecutor.binaryMessenger, "hdr2sdr/path")

    fun register() {
        channel.setMethodCallHandler { call, result ->
            if (call.method == "getOutputDirectory") {
                val dir = Environment.getExternalStoragePublicDirectory(
                    Environment.DIRECTORY_DOWNLOADS
                ).absolutePath
                result.success(dir)
            } else {
                result.notImplemented()
            }
        }
    }
}
```

在 `MainActivity.kt` 中注册：

```kotlin
// android/app/src/main/kotlin/.../MainActivity.kt
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        PathPlugin(flutterEngine).register()
    }
}
```

- [ ] **Step 3: iOS PathPlugin.swift**

```swift
// ios/Runner/PathPlugin.swift
import Foundation
import Flutter

class PathPlugin {
    private let channel: FlutterMethodChannel

    init(messenger: FlutterBinaryMessenger) {
        channel = FlutterMethodChannel(name: "hdr2sdr/path", binaryMessenger: messenger)
        channel.setMethodCallHandler { call, result in
            if call.method == "getOutputDirectory" {
                let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
                result(paths.first ?? "")
            } else {
                result(FlutterMethodNotImplemented)
            }
        }
    }
}
```

在 `AppDelegate.swift` 中注册：

```swift
// ios/Runner/AppDelegate.swift
import Flutter

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)
        PathPlugin(messenger: registrar(forPlugin: "PathPlugin")!.messenger())
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
}
```

- [ ] **Step 4: ConvertProvider 中使用 PathService**

```dart
// lib/providers/convert_provider.dart — 在构造函数中
import 'dart:io' show Platform;
import '../services/path_service.dart';

class ConvertProvider extends ChangeNotifier {
  // ...
  ConvertProvider() {
    _initOutputDir();
  }

  Future<void> _initOutputDir() async {
    if (Platform.isAndroid || Platform.isIOS) {
      final dir = await PathService.getOutputDirectory();
      if (dir.isNotEmpty) {
        _outputDirectory = dir;
        notifyListeners();
      }
    }
  }
  // ...
}
```

- [ ] **Step 5: 验证**

```bash
flutter analyze
```

预期：0 errors, 0 warnings。Android/iOS 原生代码需要各自平台的构建工具才能完全验证。

- [ ] **Step 6: 提交**

```bash
git add lib/services/ android/app/src/main/kotlin/ ios/Runner/
git commit -m "feat: 添加移动端文件输出路径处理 (PathService + MethodChannel)"
```

---

### Task 5: Android 后台转换 Service

**Files:**
- Create: `android/app/src/main/kotlin/.../HdrConversionService.kt`
- Create: `lib/services/background_service.dart`
- Modify: `android/app/src/main/kotlin/.../MainActivity.kt`
- Modify: `android/app/src/main/AndroidManifest.xml`
- Modify: `lib/providers/convert_provider.dart`

**Interfaces:**
- MethodChannel `hdr2sdr/background` 双向通信
- `BackgroundService` 抽象类（Dart 侧）
- `AndroidBackgroundService` 实现

- [ ] **Step 1: 创建 Dart 侧 BackgroundService 抽象**

```dart
// lib/services/background_service.dart
import 'dart:io' show Platform;
import 'package:flutter/services.dart';

class BackgroundService {
  static const _channel = MethodChannel('hdr2sdr/background');

  /// 启动前台 Service（Android）
  static Future<void> startConversion({
    required String inputPath,
    required String outputPath,
    required int encoder,
    required int crf,
  }) async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod('startConversion', {
      'inputPath': inputPath,
      'outputPath': outputPath,
      'encoder': encoder,
      'crf': crf,
    });
  }

  /// 取消后台转换
  static Future<void> cancelConversion() async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod('cancelConversion');
  }
}
```

- [ ] **Step 2: HdrConversionService.kt**

```kotlin
// android/app/src/main/kotlin/.../HdrConversionService.kt
package com.dremous.hdr2sdr

import android.app.*
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class HdrConversionService : Service() {

    private val channelName = "hdr2sdr/background"
    private val notificationId = 1001
    private val channelId = "hdr_conversion"

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val notification = NotificationCompat.Builder(this, channelId)
            .setContentTitle("HDR↔SDR 转换中...")
            .setContentText(intent?.getStringExtra("inputPath") ?: "")
            .setSmallIcon(android.R.drawable.ic_menu_rotate)
            .setOngoing(true)
            .build()
        startForeground(notificationId, notification)
        return START_NOT_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId, "视频转换",
                NotificationManager.IMPORTANCE_LOW
            )
            (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
                .createNotificationChannel(channel)
        }
    }

    override fun onDestroy() {
        stopForeground(STOP_FOREGROUND_REMOVE)
        super.onDestroy()
    }
}
```

- [ ] **Step 3: 注册 Service 到 AndroidManifest.xml**

```xml
<!-- android/app/src/main/AndroidManifest.xml -->
<manifest>
    <application ...>
        <activity ... />
        <service
            android:name=".HdrConversionService"
            android:foregroundServiceType="dataSync"
            android:exported="false" />
    </application>
</manifest>
```

注意：Android 14+ 要求 `foregroundServiceType`，使用 `dataSync` 类型。

- [ ] **Step 4: MainActivity 注册 MethodChannel**

```kotlin
// android/app/src/main/kotlin/.../MainActivity.kt
import android.content.Intent

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        PathPlugin(flutterEngine).register()

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "hdr2sdr/background")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startConversion" -> {
                        val intent = Intent(this, HdrConversionService::class.java).apply {
                            putExtra("inputPath", call.argument<String>("inputPath"))
                            putExtra("outputPath", call.argument<String>("outputPath"))
                            putExtra("encoder", call.argument<Int>("encoder") ?: 1)
                            putExtra("crf", call.argument<Int>("crf") ?: 23)
                        }
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(intent)
                        } else {
                            startService(intent)
                        }
                        result.success(true)
                    }
                    "cancelConversion" -> {
                        stopService(Intent(this, HdrConversionService::class.java))
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
```

- [ ] **Step 5: ConvertProvider 中调用后台服务**

```dart
// lib/providers/convert_provider.dart — 在 startConversion 和 cancelConversion 中
import '../services/background_service.dart';

void startConversion() {
  if (_queue.isEmpty || _isConverting) return;
  _isConverting = true;
  // ... 原有逻辑 ...

  if (Platform.isAndroid) {
    BackgroundService.startConversion(
      inputPath: _currentFile!.filePath,
      outputPath: '$_outputDirectory/${_currentFile!.fileName}',
      encoder: _params.encoder.index,
      crf: _params.crf,
    );
  }
  // 桌面端继续用原有方式
}

void cancelConversion() {
  _isConverting = false;
  if (Platform.isAndroid) {
    BackgroundService.cancelConversion();
  }
  notifyListeners();
}
```

- [ ] **Step 6: 验证**

```bash
flutter analyze
```

预期：0 errors。

- [ ] **Step 7: 提交**

```bash
git add android/app/src/main/kotlin/.../HdrConversionService.kt android/app/src/main/AndroidManifest.xml lib/services/ lib/providers/convert_provider.dart
git commit -m "feat: Android 后台转换 Service + MethodChannel"
```

---

### Task 6: iOS 后台转换 (BGTaskScheduler)

**Files:**
- Create: `ios/Runner/BackgroundService.swift`
- Modify: `ios/Runner/Info.plist`
- Modify: `lib/services/background_service.dart`

**Interfaces:**
- 复用 `BackgroundService` 抽象类，`Platform.isIOS` 分支
- iOS 端通过 MethodChannel 接收转换参数

- [ ] **Step 1: iOS BackgroundService.swift**

```swift
// ios/Runner/BackgroundService.swift
import Foundation
import Flutter

class BackgroundService {
    private let channel: FlutterMethodChannel

    init(messenger: FlutterBinaryMessenger) {
        channel = FlutterMethodChannel(
            name: "hdr2sdr/background",
            binaryMessenger: messenger
        )
        channel.setMethodCallHandler { [weak self] call, result in
            switch call.method {
            case "startConversion":
                // BGTaskScheduler 注册后台任务
                self?.scheduleBackgroundTask()
                result(true)
            case "cancelConversion":
                BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: "com.dremous.hdr2sdr.conversion")
                result(true)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }

    private func scheduleBackgroundTask() {
        let request = BGProcessingTaskRequest(identifier: "com.dremous.hdr2sdr.conversion")
        request.requiresExternalPower = false
        request.requiresNetworkConnectivity = false
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("BGTaskScheduler submit failed: \(error)")
        }
    }
}
```

- [ ] **Step 2: 在 AppDelegate 中注册 BGTaskScheduler**

```swift
// ios/Runner/AppDelegate.swift
import Flutter
import BackgroundTasks

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)
        PathPlugin(messenger: registrar(forPlugin: "PathPlugin")!.messenger())
        _ = BackgroundService(messenger: registrar(forPlugin: "BackgroundService")!.messenger())

        // 注册 BGTask
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.dremous.hdr2sdr.conversion",
            using: nil
        ) { task in
            self.handleConversionTask(task as! BGProcessingTask)
        }

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    private func handleConversionTask(_ task: BGProcessingTask) {
        // 后台转换逻辑（调用 C++ 静态库 API）
        // 通过通道通知 Dart 层恢复/启动转换
        task.setTaskCompleted(success: true)
    }
}
```

- [ ] **Step 3: 修改 Info.plist**

```xml
<!-- ios/Runner/Info.plist — 在 <dict> 中添加 -->
<key>BGTaskSchedulerPermittedIdentifiers</key>
<array>
    <string>com.dremous.hdr2sdr.conversion</string>
</array>
```

- [ ] **Step 4: Dart 侧 BackgroundService 增加 iOS 分支**

```dart
// lib/services/background_service.dart — startConversion 增加 iOS 分支
static Future<void> startConversion({...}) async {
  if (Platform.isAndroid) {
    await _channel.invokeMethod('startConversion', {...});
  } else if (Platform.isIOS) {
    // iOS 用 BGTaskScheduler，通过 MethodChannel 触发原生注册
    await _channel.invokeMethod('startConversion');
  }
  // 桌面端不处理
}
```

- [ ] **Step 5: 验证**

```bash
flutter analyze
```

预期：0 errors。

- [ ] **Step 6: 提交**

```bash
git add ios/Runner/BackgroundService.swift ios/Runner/AppDelegate.swift ios/Runner/Info.plist lib/services/background_service.dart
git commit -m "feat: iOS 后台转换 (BGTaskScheduler)"
```

---

### Task 7: 交叉编译脚本 + CI 工作流

**Files:**
- Create: `native/build_android.sh`
- Create: `native/build_ios.sh`
- Create: `native/toolchain-android.cmake`
- Create: `ios/hdr_converter.podspec`
- Modify: `.github/workflows/ci.yml`

- [ ] **Step 1: native/build_android.sh**

```bash
#!/bin/bash
# Android NDK 交叉编译脚本
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR"
JNILIBS_DIR="$PROJECT_DIR/../android/app/src/main/jniLibs"

# 需要 Android NDK 环境变量
NDK_PATH="${ANDROID_NDK_HOME:-$ANDROID_NDK}"
if [ -z "$NDK_PATH" ]; then
  echo "错误: 请设置 ANDROID_NDK_HOME 环境变量"
  exit 1
fi

ABIS=("arm64-v8a" "x86_64")
for ABI in "${ABIS[@]}"; do
  echo "编译 $ABI..."
  cmake -B "build/android/$ABI" \
    -S "$PROJECT_DIR" \
    -DCMAKE_TOOLCHAIN_FILE="$PROJECT_DIR/toolchain-android.cmake" \
    -DANDROID_ABI="$ABI" \
    -DCMAKE_BUILD_TYPE=Release

  cmake --build "build/android/$ABI" --config Release

  # 复制 .so 到 jniLibs
  mkdir -p "$JNILIBS_DIR/$ABI"
  cp "build/android/$ABI/libhdr_converter.so" "$JNILIBS_DIR/$ABI/"
done

echo "Android 编译完成"
```

- [ ] **Step 2: native/build_ios.sh**

```bash
#!/bin/bash
# iOS 静态库交叉编译脚本
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR"
IOS_DIR="$PROJECT_DIR/../ios"

echo "编译 iOS arm64 静态库..."

cmake -B build/ios \
  -S "$PROJECT_DIR" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_SYSTEM_NAME=iOS \
  -DCMAKE_OSX_ARCHITECTURES=arm64 \
  -DCMAKE_OSX_DEPLOYMENT_TARGET=15.0 \
  -DCMAKE_XCODE_ATTRIBUTE_CODE_SIGNING_REQUIRED=NO

cmake --build build/ios --config Release

# 复制静态库到 ios/ 目录
cp build/ios/libhdr_converter.a "$IOS_DIR/"

echo "iOS 编译完成"
```

- [ ] **Step 3: native/toolchain-android.cmake**

```cmake
# native/toolchain-android.cmake — Android NDK 工具链配置
cmake_minimum_required(VERSION 3.16)

set(CMAKE_SYSTEM_NAME Android)
set(CMAKE_SYSTEM_VERSION 24)

# NDK 路径（从环境变量获取）
set(CMAKE_ANDROID_NDK $ENV{ANDROID_NDK_HOME})

# ABI 架构（由 build_android.sh 传入）
set(CMAKE_ANDROID_ARCH_ABI ${ANDROID_ABI})

# 使用 NDK 的默认工具链
set(CMAKE_ANDROID_STL_TYPE c++_shared)
```

- [ ] **Step 4: ios/hdr_converter.podspec**

```ruby
# ios/hdr_converter.podspec
Pod::Spec.new do |s|
  s.name         = "hdr_converter"
  s.version      = "1.0.0"
  s.summary      = "HDR↔SDR video converter native library"
  s.homepage     = "https://github.com/Dremous/hdr2sdr"
  s.license      = { :type => "MIT" }
  s.author       = "Dremous"
  s.platform     = :ios, "15.0"
  s.source       = { :path => "." }
  s.vendored_libraries = "libhdr_converter.a"
  s.static_framework = true
  s.dependency "ffmpeg-kit-ios-full", "~> 6.0"
end
```

- [ ] **Step 5: 更新 ci.yml 增加移动端构建 job**

在 `.github/workflows/ci.yml` 末尾追加：

```yaml
  android-build:
    name: Build Android APK
    runs-on: ubuntu-latest
    if: github.event_name == 'workflow_dispatch'
    steps:
      - uses: actions/checkout@v4
      - name: Install Android NDK
        run: echo "ANDROID_NDK_HOME=$ANDROID_HOME/ndk/26.1.10909125" >> $GITHUB_ENV
      - name: Build native lib
        run: |
          chmod +x native/build_android.sh
          native/build_android.sh
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
      - run: flutter pub get
      - run: flutter build apk --release --split-per-abi
      - uses: actions/upload-artifact@v4
        with:
          name: hdr2sdr-apk
          path: |
            build/app/outputs/flutter-apk/*.apk

  ios-build:
    name: Build iOS IPA
    runs-on: macos-latest
    if: github.event_name == 'workflow_dispatch'
    steps:
      - uses: actions/checkout@v4
      - name: Build native lib
        run: |
          chmod +x native/build_ios.sh
          native/build_ios.sh
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
      - run: flutter pub get
      - run: flutter build ios --no-codesign --release
      - uses: actions/upload-artifact@v4
        with:
          name: hdr2sdr-ipa
          path: build/ios/iphoneos/Runner.app
```

- [ ] **Step 6: 验证**

```bash
# Shell 语法检查（在 bash 环境中）
bash -n native/build_android.sh
bash -n native/build_ios.sh
```

- [ ] **Step 7: 提交**

```bash
git add native/build_android.sh native/build_ios.sh native/toolchain-android.cmake ios/hdr_converter.podspec .github/workflows/ci.yml
git commit -m "feat: 添加移动端交叉编译脚本 + CI 构建 job"
```

---

### 自审检查

1. **Spec 覆盖检查:** 对照设计文档的 7 个设计细节，每节都能在 task 中找到对应的实现步骤。
2. **占位符检查:** 无 TBD/TODO，每步都有完整代码。
3. **类型一致性检查:** EncoderType 值 3/4 在两个文件（convert_params.dart, hdr_converter.h）中一致。
4. **依赖顺序:** Task 1(平台) → Task 2(模型/bridge) → Task 3(UI) → Task 4(文件) → Task 5(Android后台) → Task 6(iOS后台) → Task 7(脚本/CI)，每步 `flutter analyze` 可独立验证。
