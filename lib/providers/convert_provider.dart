import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/video_file.dart';
import '../models/convert_params.dart';
import '../models/video_info.dart';
import '../services/path_service.dart';
import '../services/ffmpeg_process.dart';

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

  final FFmpegProcess _ffmpeg = FFmpegProcess();
  StreamSubscription? _stderrSub;
  Timer? _pollTimer;

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

  ConvertProvider() {
    _initOutputDirectory();
  }

  Future<void> _initOutputDirectory() async {
    try {
      _outputDirectory = await PathService.getOutputDirectory();
      notifyListeners();
    } catch (_) {}
  }

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

  String _buildOutputPath() {
    final dir = _outputDirectory;
    final fullName = _currentFile!.fileName;
    final dotIndex = fullName.lastIndexOf('.');
    final baseName = dotIndex > 0 ? fullName.substring(0, dotIndex) : fullName;
    final isHdrToSdr = _params.autoMode
        ? _currentFile!.hdrType != HdrType.sdr
        : _params.direction == ConvertDirection.hdrToSdr;
    final suffix = isHdrToSdr ? '_sdr' : '_hdr';
    final outputName = '$baseName$suffix.mp4';
    if (dir == null || dir.isEmpty) return outputName;
    final sep = dir.endsWith('/') || dir.endsWith('\\') ? '' : '/';
    return '$dir$sep$outputName';
  }

  bool _isHdrToSdr() {
    if (_params.autoMode) {
      return _currentFile?.hdrType != HdrType.sdr;
    }
    return _params.direction == ConvertDirection.hdrToSdr;
  }

  void startConversion() {
    if (_queue.isEmpty || _isConverting) return;
    _isConverting = true;
    _errorMessage = null;
    _progress = 0.0;
    _currentFrame = 0;

    final files = _queue.where((f) => f.status != FileStatus.converting).toList();
    if (files.isEmpty) { _isConverting = false; return; }
    _currentFile = files.first;
    _currentFile!.status = FileStatus.converting;
    _currentFile!.errorMessage = null;
    notifyListeners();
    _ensureOutputDirThenConvert();
  }

  Future<void> _ensureOutputDirThenConvert() async {
    if (_outputDirectory == null || _outputDirectory!.isEmpty) {
      try {
        _outputDirectory = await PathService.getOutputDirectory();
      } catch (_) {}
    }
    if (_outputDirectory == null || _outputDirectory!.isEmpty) {
      final p = _currentFile!.filePath;
      final idx = p.lastIndexOf('/');
      _outputDirectory = idx >= 0
          ? p.substring(0, idx + 1)
          : (p.lastIndexOf('\\') >= 0 ? p.substring(0, p.lastIndexOf('\\') + 1) : '.');
    }
    _runConversion();
  }

  Future<void> _runConversion() async {
    final input = _currentFile!.filePath;
    final output = _buildOutputPath();
    final params = _params;
    final isHdrToSdr = _isHdrToSdr();

    debugPrint('[convert] 输入: $input');
    debugPrint('[convert] 输出: $output');
    debugPrint('[convert] 方向: ${isHdrToSdr ? "HDR→SDR" : "SDR→HDR"}');

    // 先查视频时长
    final info = await FFmpegProcess.getVideoInfo(input);
    if (info != null) {
      _currentInfo = info;
      _totalFrames = info.frameCount;
      notifyListeners();
    }

    final exitCode = await _ffmpeg.run(
      input: input,
      output: output,
      params: params,
      isHdrToSdr: isHdrToSdr,
      totalDurationSec: info?.durationSec,
      onProgress: (p) {
        _progress = p;
        notifyListeners();
      },
    );

    final success = exitCode == 0;
    _progress = success ? 1.0 : _progress;
    _isConverting = false;
    if (_currentFile != null) {
      _currentFile!.status = success ? FileStatus.completed : FileStatus.failed;
      if (!success) {
        _currentFile!.errorMessage = 'FFmpeg 退出码: $exitCode';
        _errorMessage = _currentFile!.errorMessage;
      }
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _stderrSub?.cancel();
    _ffmpeg.cancel();
    super.dispose();
  }

  void dismissCurrentFile() {
    if (_currentFile != null) {
      _currentFile!.status = FileStatus.pending;
      _currentFile!.errorMessage = null;
    }
    _errorMessage = null;
    notifyListeners();
  }

  void cancelConversion() {
    if (!_isConverting) return;
    _ffmpeg.cancel();
    _isConverting = false;
    if (_currentFile != null) {
      _currentFile!.status = FileStatus.failed;
      _currentFile!.errorMessage = '已取消';
    }
    _errorMessage = '已取消转换';
    notifyListeners();
  }
}
