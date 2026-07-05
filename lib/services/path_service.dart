import 'package:flutter/services.dart';

class PathService {
  static const _channel = MethodChannel('hdr2sdr/path');

  /// 获取平台默认输出目录（Android Downloads / iOS Documents）
  static Future<String> getOutputDirectory() async {
    final path = await _channel.invokeMethod<String>('getOutputDirectory');
    return path ?? '';
  }
}
