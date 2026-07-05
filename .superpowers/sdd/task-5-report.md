# Task 5 报告: Android 后台转换 Service

## 完成内容

### 新建文件
- `android/app/src/main/kotlin/com/example/hdr2sdr/HdrConversionService.kt` — Android 前台 Service
  - 创建通知渠道 `hdr2sdr_conversion` (API 26+)
  - `startForeground` 显示持久通知
  - `ACTION_START` / `ACTION_CANCEL` 双 intent action 支持
  - 通过 `MainActivity.sendBackgroundEvent()` 回传事件到 Dart
- `lib/services/background_service.dart` — Dart 侧通道封装
  - `MethodChannel('hdr2sdr/background')` 发起 start/cancel 调用
  - `EventChannel('hdr2sdr/background_event')` 接收进度/完成事件
  - 暴露 `onProgress` / `onComplete` 静态回调

### 修改文件
- `AndroidManifest.xml` — 添加 `<service>` 声明 + `FOREGROUND_SERVICE` 权限
- `MainActivity.kt` — 注册 MethodChannel 与 EventChannel，处理 start/cancel 转 Intent
- `convert_params.dart` — 新增 `toJson()` 序列化方法
- `convert_provider.dart` — `startConversion()` 设置回调并调用 BackgroundService；`cancelConversion()` 调用 BackgroundService

## 验证
- `flutter analyze` — 0 issues
- Git commit `c138ad4`
