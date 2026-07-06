import 'dart:ffi';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../models/video_file.dart';
import '../models/convert_params.dart';
import '../models/video_info.dart';
import '../services/path_service.dart';
import '../ffi/native_bridge.dart';

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

  void startConversion() {
    if (_queue.isEmpty || _isConverting) return;
    _isConverting = true;
    _errorMessage = null;
    _progress = 0.0;
    _currentFrame = 0;
    final pending = _queue.where((f) => f.status == FileStatus.pending).toList();
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
    try {
      final bridge = NativeBridge.instance;
      final handle = bridge.create();
      final outputFile = '${_outputDirectory ?? ''}/${_currentFile!.fileName}_sdr.mp4';

      final openResult = bridge.open(handle, _currentFile!.filePath);
      if (openResult < 0) {
        bridge.destroy(handle);
        onConversionComplete(false, '无法打开视频文件（错误码: $openResult）');
        return;
      }

      bridge.setParams(handle, _params);

      // 获取视频信息用于显示
      final info = bridge.getInfo(handle);
      if (info != null) {
        _currentInfo = info;
        _totalFrames = info.frameCount;
      }

      final startResult = bridge.start(
        handle,
        outputFile,
        nullptr,
        nullptr,
        nullptr,
      );
      bridge.close(handle);
      bridge.destroy(handle);

      if (startResult == 0) {
        onConversionComplete(true, null);
      } else {
        onConversionComplete(false, '转换失败（错误码: $startResult）');
      }
    } catch (e) {
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
      _currentFile!.status = success ? FileStatus.completed : FileStatus.failed;
      _currentFile!.errorMessage = error;
    }
    _currentFile = null;
    if (!success) _errorMessage = error;
    notifyListeners();
  }

  void cancelConversion() {
    _isConverting = false;
    notifyListeners();
  }
}
