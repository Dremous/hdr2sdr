import 'dart:async';
import 'dart:ffi';
import 'dart:isolate';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/video_file.dart';
import '../models/convert_params.dart';
import '../models/video_info.dart';
import '../services/path_service.dart';
import '../ffi/native_bridge.dart';

/// 在后台 Isolate 中执行转换，避免阻塞主 UI 线程
void _runConversionInIsolate(List<dynamic> args) {
  final filePath = args[0] as String;
  final outputPath = args[1] as String;
  final params = args[2] as ConvertParams;
  final sendPort = args[3] as SendPort;

  try {
    print('[hdr2sdr] Isolate 内部: 加载原生库...');
    final bridge = NativeBridge.instance;
    print('[hdr2sdr] Isolate 内部: 原生库加载成功，创建 handle...');
    final handle = bridge.create();
    print('[hdr2sdr] Isolate 内部: handle 创建成功，打开视频...');

    try {
      final openResult = bridge.open(handle, filePath);
      if (openResult < 0) {
        print('[hdr2sdr] Isolate 内部: 打不开视频, 错误码=$openResult');
        sendPort.send({
          'type': 'complete',
          'success': false,
          'error': '无法打开视频文件（错误码: $openResult）',
        });
        bridge.destroy(handle);
        return;
      }

      print('[hdr2sdr] Isolate 内部: 视频已打开，设置参数并开始转换...');
      bridge.setParams(handle, params);

      // 发回视频信息给 UI 显示
      final info = bridge.getInfo(handle);
      if (info != null) {
        sendPort.send({
          'type': 'info',
          'width': info.width,
          'height': info.height,
          'fps': info.fps,
          'frames': info.frameCount,
          'duration': info.durationSec,
          'isHdr': info.isHdr,
        });
      } else {
        sendPort.send({
          'type': 'info',
          'width': 0, 'height': 0, 'fps': 0.0,
          'frames': 0, 'duration': 0.0, 'isHdr': false,
        });
      }

      // 传 nullptr 回调 → C 端同步执行转换（进度由 Dart Timer 模拟）
      // TODO: NativeCallable / Pointer.fromFunction 均有 Void/void 类型不兼容，
      // 等待 Dart SDK 修复或改用 polling 方式
      final startResult = bridge.start(
          handle, outputPath, nullptr, nullptr, nullptr);
      print('[hdr2sdr] Isolate 内部: 转换结束, 结果=$startResult');
      bridge.close(handle);
      bridge.destroy(handle);

      sendPort.send({
        'type': 'complete',
        'success': startResult == 0,
        'error': startResult == 0 ? null : '转换失败（错误码: $startResult）',
      });
    } catch (e) {
      print('[hdr2sdr] Isolate 内部异常: $e');
      try {
        bridge.close(handle);
      } catch (_) {}
      try {
        bridge.destroy(handle);
      } catch (_) {}
      sendPort.send({
        'type': 'complete',
        'success': false,
        'error': '转换异常: $e',
      });
    }
  } catch (e) {
    print('[hdr2sdr] Isolate 内部: 无法加载原生库: $e');
    sendPort.send({
      'type': 'complete',
      'success': false,
      'error': '无法加载原生库: $e',
    });
  }
}

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

  /// 后台转换 Isolate（取消时 kill 之）
  Isolate? _conversionIsolate;
  /// 模拟进度定时器（原生未接入进度回调时的 UI 反馈）
  Timer? _progressTimer;

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
      final lastSep =
          _currentFile!.filePath.lastIndexOf(RegExp(r'[/\\]'));
      if (lastSep < 0) return baseName;
      return '${_currentFile!.filePath.substring(0, lastSep + 1)}$baseName';
    }

    final separator = dir.endsWith('/') || dir.endsWith('\\') ? '' : '/';
    return '$dir$separator$baseName';
  }

  void startConversion() {
    if (_queue.isEmpty || _isConverting) return;
    _isConverting = true;
    _errorMessage = null;
    _progress = 0.0;
    _currentFrame = 0;
    // 取出第一个可转换的文件（pending/completed/failed 均可）
    final files = _queue
        .where((f) => f.status != FileStatus.converting)
        .toList();
    if (files.isEmpty) {
      _isConverting = false;
      return;
    }
    _currentFile = files.first;
    _currentFile!.status = FileStatus.converting;
    _currentFile!.errorMessage = null;
    notifyListeners();

    _ensureOutputDirThenConvert();
  }

  /// 确保输出目录已初始化，再启动转换
  Future<void> _ensureOutputDirThenConvert() async {
    if (_outputDirectory == null || _outputDirectory!.isEmpty) {
      try {
        _outputDirectory = await PathService.getOutputDirectory();
      } catch (_) {
        _outputDirectory = null;
      }
    }
    // 如果还是为空，用视频所在目录兜底
    if (_outputDirectory == null || _outputDirectory!.isEmpty) {
      final p = _currentFile!.filePath;
      final idx = p.lastIndexOf('/');
      if (idx < 0) {
        _outputDirectory = p.lastIndexOf('\\') >= 0
            ? p.substring(0, p.lastIndexOf('\\') + 1)
            : '.';
      } else {
        _outputDirectory = p.substring(0, idx + 1);
      }
    }
    _spawnConversionIsolate();
  }

  /// 在后台 Isolate 中执行转换，主线程立即返回以处理 UI
  void _spawnConversionIsolate() {
    final filePath = _currentFile!.filePath;
    final outputPath = _buildOutputPath();
    final params = _params;

    debugPrint('[hdr2sdr] 正在启动后台转换 Isolate...');
    debugPrint('[hdr2sdr] 输入: $filePath');
    debugPrint('[hdr2sdr] 输出: $outputPath');

    // 启动模拟进度定时器（origin 原生回调之前占位用）
    _startFakeProgress();

    final receivePort = ReceivePort();
    Isolate.spawn(
      _runConversionInIsolate,
      [filePath, outputPath, params, receivePort.sendPort],
    ).then((iso) {
      debugPrint('[hdr2sdr] Isolate 已启动');
      _conversionIsolate = iso;
    }, onError: (e) {
      debugPrint('[hdr2sdr] Isolate 启动失败: $e');
      receivePort.close();
      onConversionComplete(false, '无法创建后台转换线程: $e');
    });

    receivePort.listen((message) {
      debugPrint('[hdr2sdr] 收到 Isolate 消息: $message');
      if (message is Map) {
        final type = message['type'] as String?;
        if (type == 'info') {
          _currentInfo = VideoInfo(
            width: (message['width'] as num?)?.toInt() ?? 0,
            height: (message['height'] as num?)?.toInt() ?? 0,
            fps: (message['fps'] as num?)?.toDouble() ?? 0.0,
            frameCount: (message['frames'] as num?)?.toInt() ?? 0,
            durationSec: (message['duration'] as num?)?.toDouble() ?? 0.0,
            isHdr: message['isHdr'] as bool? ?? false,
            hdrType: 0,
          );
          _totalFrames = _currentInfo!.frameCount;
          notifyListeners();
        } else if (type == 'complete') {
          receivePort.close();
          _conversionIsolate = null;
          _stopFakeProgress();
          _progress = 1.0;
          notifyListeners();
          onConversionComplete(
            message['success'] as bool? ?? false,
            message['error'] as String?,
          );
        }
      }
    });
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
    // 保留 _currentFile 以便 UI 显示完成状态，startConversion 会重新赋值
    notifyListeners();
  }

  /// 取消转换：立即杀死后台 Isolate（由 OS 回收 native 资源）
  void cancelConversion() {
    if (!_isConverting) return;
    _stopFakeProgress();
    final isolate = _conversionIsolate;
    if (isolate != null) {
      isolate.kill(priority: Isolate.immediate);
      _conversionIsolate = null;
    }
    onConversionComplete(false, '已取消转换');
  }

  /// 模拟进度：每秒涨一点直到 90%，完成后跳到 100%
  void _startFakeProgress() {
    _progress = 0.0;
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(milliseconds: 300), (t) {
      if (!_isConverting) {
        t.cancel();
        return;
      }
      _progress = min(_progress + 0.02, 0.90);
      notifyListeners();
    });
  }

  void _stopFakeProgress() {
    _progressTimer?.cancel();
    _progressTimer = null;
  }
}
