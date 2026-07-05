import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/video_file.dart';
import '../models/convert_params.dart';
import '../models/video_info.dart';

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
    _currentFile = _queue.firstWhere((f) => f.status == FileStatus.pending);
    _currentFile!.status = FileStatus.converting;
    notifyListeners();
    // 实际的转换调用将在 NativeBridge 实现后完成
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