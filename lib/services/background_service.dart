import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/services.dart';
import '../models/convert_params.dart';

class BackgroundService {
  BackgroundService._();

  static const MethodChannel _channel = MethodChannel('hdr2sdr/background');
  static const EventChannel _eventChannel = EventChannel('hdr2sdr/background_event');

  static StreamSubscription<dynamic>? _subscription;

  static void Function(double progress, int currentFrame, int totalFrames)? onProgress;
  static void Function(bool success, String? error)? onComplete;

  static void initialize() {
    _subscription?.cancel();
    _subscription = _eventChannel.receiveBroadcastStream().listen((event) {
      if (event is Map) {
        final type = event['type'] as String?;
        if (type == 'progress') {
          final progress = (event['progress'] as num?)?.toDouble() ?? 0.0;
          final current = (event['currentFrame'] as num?)?.toInt() ?? 0;
          final total = (event['totalFrames'] as num?)?.toInt() ?? 0;
          onProgress?.call(progress, current, total);
        } else if (type == 'complete') {
          final success = event['success'] as bool? ?? true;
          final error = event['error'] as String?;
          onComplete?.call(success, error);
        }
      }
    });
  }

  static Future<void> startConversion({
    required String filePath,
    required String outputPath,
    required ConvertParams params,
  }) async {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    initialize();
    if (Platform.isIOS) {
      // iOS 后台仅触发 BGTaskScheduler 注册，无需传递参数
      await _channel.invokeMethod('startConversion');
    } else {
      await _channel.invokeMethod('startConversion', {
        'filePath': filePath,
        'outputPath': outputPath,
        'params': params.toJson(),
      });
    }
  }

  static Future<void> cancelConversion() async {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    await _channel.invokeMethod('cancelConversion');
  }

  static void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }
}
