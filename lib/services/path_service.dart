import 'dart:io';
import 'package:path_provider/path_provider.dart';

class PathService {
  /// 获取平台默认输出目录
  static Future<String> getOutputDirectory() async {
    final dir = await getApplicationDocumentsDirectory();
    final outDir = Directory('${dir.path}${Platform.pathSeparator}HDR2SDR_Output');
    if (!await outDir.exists()) {
      await outDir.create(recursive: true);
    }
    return outDir.path;
  }
}
