import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import '../models/video_file.dart';
import '../models/convert_params.dart';
import '../models/video_info.dart';
import '../services/path_service.dart';
import '../services/background_service.dart';

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
  final bool _nativeAvailable = true;

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
  Uint8List? get previewFrame => _previewFrame;

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

  void updatePreviewFrame(Uint8List? frame) {
    _previewFrame = frame;
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

    if (!_nativeAvailable) {
      onConversionComplete(false, _nativeMissingMessage());
      return;
    }

    if (Platform.isAndroid || Platform.isIOS) {
      _startMobileConversion();
    } else {
      _startDesktopConversion();
    }
  }

  String _nativeMissingMessage() {
    if (Platform.isWindows) {
      return '缺少 hdr_converter.dll — 请用 MSYS2 编译原生库（cmake -B build -S native && cmake --build build）';
    } else if (Platform.isLinux) {
      return '缺少 libhdr_converter.so — 请编译原生库后放入可执行文件同目录';
    } else if (Platform.isMacOS) {
      return '缺少 libhdr_converter.dylib — 请编译原生库后放入 .app 包内';
    } else {
      return '缺少原生转换库 — 请先编译 C++ 核心';
    }
  }

  void _startMobileConversion() {
    BackgroundService.onProgress = (p, current, total) {
      updateProgress(p, current, total);
    };
    BackgroundService.onComplete = (success, error) {
      onConversionComplete(success, error);
    };
    BackgroundService.startConversion(
      filePath: _currentFile!.filePath,
      outputPath: _outputDirectory ?? '',
      params: _params,
    );
  }

  void _startDesktopConversion() {
    // TODO: 接入 NativeBridge FFI
    onConversionComplete(false, '桌面端转换待实现（NativeBridge 尚未接入）');
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
    BackgroundService.cancelConversion();
    notifyListeners();
  }
}
