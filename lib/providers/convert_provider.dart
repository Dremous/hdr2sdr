import 'dart:ffi';
import 'package:flutter/foundation.dart';
import '../models/video_file.dart';
import '../models/convert_params.dart';
import '../models/video_info.dart';
import '../services/path_service.dart';
import '../ffi/native_bridge.dart';
import '../ffi/types.dart';

class ConvertProvider extends ChangeNotifier {
  final List<VideoFile> _queue = [];
  ConvertParams _params = const ConvertParams();
  VideoFile? _currentFile;
  VideoInfo? _currentInfo;
  double _progress = 0.0;
  int _currentFrame = 0;
  int _totalFrames = 0;
  bool _isConverting = false;
  String? _outputDirectory;

  /// 当前转换中持有的原生句柄（cancel 时需要引用）
  ConverterHandle? _currentHandle;

  ConvertProvider() {
    _initOutputDirectory();
  }

  Future<void> _initOutputDirectory() async {
    try {
      _outputDirectory = await PathService.getOutputDirectory();
      notifyListeners();
    } catch (_) {}
  }

  String? _errorMessage;
  Uint8List? _previewFrame;
  Uint8List? get previewFrame => _previewFrame;

  List<VideoFile> get queue => List.unmodifiable(_queue);
  ConvertParams get params => _params;
  VideoFile? get currentFile => _currentFile;
  VideoInfo? get currentInfo => _currentInfo;
  double get progress => _progress;
  int get currentFrame => _currentFrame;
  int get totalFrames => _totalFrames;
  bool get isConverting => _isConverting;
  String? get outputDirectory => _outputDirectory;
  String? get errorMessage => _errorMessage;

  void addFiles(List<String> paths) {
    for (final path in paths) {
      final name = path.split(RegExp(r'[/\\]')).last;
      _queue.add(VideoFile(filePath: path, fileName: name));
    }
    notifyListeners();
  }

  void removeFile(int index) {
    if (index >= 0 && index < _queue.length) {
      _queue.removeAt(index);
      notifyListeners();
    }
  }

  void setOutputDirectory(String dir) {
    _outputDirectory = dir;
    notifyListeners();
  }

  void updateParams(ConvertParams newParams) {
    _params = newParams;
    notifyListeners();
  }

  /// 构造输出文件路径，修复 _outputDirectory 为 null/空时生成根目录路径的 bug
  String _buildOutputPath() {
    final dir = _outputDirectory;
    final baseName = '${_currentFile!.fileName}_sdr.mp4';

    if (dir == null || dir.isEmpty) {
      // 回退：输出到视频文件的同目录
      final lastSep =
          _currentFile!.filePath.lastIndexOf(RegExp(r'[/\\]'));
      if (lastSep < 0) return baseName; // 相对路径
      return '${_currentFile!.filePath.substring(0, lastSep + 1)}$baseName';
    }

    // 确保目录末尾有路径分隔符
    final separator = dir.endsWith('/') || dir.endsWith('\\') ? '' : '/';
    return '$dir$separator$baseName';
  }

  /// 释放当前转换持有的原生句柄（无论成功/失败/异常都确保清理）
  void _cleanupHandle() {
    final handle = _currentHandle;
    _currentHandle = null;
    if (handle != null) {
      try {
        NativeBridge.instance.close(handle);
      } catch (_) {}
      try {
        NativeBridge.instance.destroy(handle);
      } catch (_) {}
    }
  }

  void startConversion() {
    if (_queue.isEmpty || _isConverting) return;
    _isConverting = true;
    _errorMessage = null;
    _progress = 0.0;
    _currentFrame = 0;
    final pending =
        _queue.where((f) => f.status == FileStatus.pending).toList();
    if (pending.isEmpty) {
      _isConverting = false;
      return;
    }
    _currentFile = pending.first;
    _currentFile!.status = FileStatus.converting;
    notifyListeners();

    _tryNativeConversion();
  }

  void _tryNativeConversion() {
    final bridge = NativeBridge.instance;
    _currentHandle = bridge.create();

    try {
      final openResult = bridge.open(_currentHandle!, _currentFile!.filePath);
      if (openResult < 0) {
        _cleanupHandle();
        onConversionComplete(false, '无法打开视频文件（错误码: $openResult）');
        return;
      }

      bridge.setParams(_currentHandle!, _params);

      final info = bridge.getInfo(_currentHandle!);
      if (info != null) {
        _currentInfo = info;
        _totalFrames = info.frameCount;
        notifyListeners();
      }

      // 传 nullptr 回调 → C 端同步执行转换（无进度回调）
      // TODO: 改用 NativeCallable 实现真正的异步回调
      final startResult = bridge.start(
        _currentHandle!,
        _buildOutputPath(),
        nullptr,
        nullptr,
        nullptr,
      );

      _cleanupHandle();

      if (startResult == 0) {
        onConversionComplete(true, null);
      } else {
        onConversionComplete(false, '转换失败（错误码: $startResult）');
      }
    } catch (e) {
      _cleanupHandle();
      onConversionComplete(false, '原生库错误: $e');
    }
  }

  void updateProgress(double p, int current, int total) {
    _progress = p;
    _currentFrame = current;
    _totalFrames = total;
    notifyListeners();
  }

  void onConversionComplete(bool success, String? error) {
    _isConverting = false;
    if (_currentFile != null) {
      _currentFile!.status =
          success ? FileStatus.completed : FileStatus.failed;
      _currentFile!.errorMessage = error;
    }
    if (!success) _errorMessage = error;
    _currentInfo = null;
    _currentFile = null;
    notifyListeners();
  }

  void cancelConversion() {
    if (!_isConverting) return;
    // 调用原生 cancel 让转换线程停止（若 converter_start 是阻塞的同步调用，
    // 则主线程正卡在 bridge.start() 中，cancel 无法即时生效。
    // TODO: 后期将转换移到 Isolate 后台线程）
    final handle = _currentHandle;
    if (handle != null) {
      try {
        NativeBridge.instance.cancel(handle);
      } catch (_) {}
    }
  }
}
