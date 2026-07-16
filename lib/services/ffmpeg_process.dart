import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../models/convert_params.dart';
import '../models/video_info.dart';

class FFmpegProcess {
  String? _ffmpegPath;
  String? _ffprobePath;
  Process? _process;

  /// 检测 Android 设备 ABI
  static Future<String> _detectAbi() async {
    if (!Platform.isAndroid) return '';
    try {
      final r = await Process.run('uname', ['-m']);
      final arch = r.stdout.toString().trim();
      if (arch.contains('aarch64')) return 'arm64-v8a';
      if (arch.contains('x86_64')) return 'x86_64';
      return 'arm64-v8a';
    } catch (_) {
      return 'arm64-v8a';
    }
  }

  static String _abi = '';
  static Future<String> get abi async =>
      _abi.isNotEmpty ? _abi : _abi = await _detectAbi();

  /// 从 assets 提取二进制到可执行路径
  static Future<String> extractBinary(String name) async {
    final abi = await FFmpegProcess.abi;
    final appDir = await getApplicationDocumentsDirectory();
    final binDir = Directory('${appDir.path}/ffmpeg_bin');
    if (!await binDir.exists()) {
      await binDir.create(recursive: true);
    }
    final destPath = '${binDir.path}/${name}_$abi';
    if (!await File(destPath).exists()) {
      final data = await rootBundle.load('assets/ffmpeg/$abi/$name');
      await File(destPath).writeAsBytes(data.buffer.asUint8List(), flush: true);
      await Process.run('chmod', ['+x', destPath]);
    }
    return destPath;
  }

  Future<String> get ffmpegPath async =>
      _ffmpegPath ??= Platform.isAndroid
          ? await extractBinary('ffmpeg')
          : 'ffmpeg';

  Future<String> get ffprobePath async =>
      _ffprobePath ??= Platform.isAndroid
          ? await extractBinary('ffprobe')
          : 'ffprobe';

  /// 获取视频信息（桌面用系统 ffprobe，Android 用解压的）
  static Future<VideoInfo?> getVideoInfo(String path) async {
    try {
      final ffprobe = Platform.isAndroid
          ? await extractBinary('ffprobe')
          : 'ffprobe';
      final proc = await Process.run(ffprobe, [
        '-v', 'quiet',
        '-print_format', 'json',
        '-show_streams',
        '-show_format',
        path,
      ]);
      if (proc.exitCode != 0) return null;

      final json = jsonDecode(proc.stdout as String) as Map<String, dynamic>;
      final streams = json['streams'] as List?;
      if (streams == null || streams.isEmpty) return null;

      Map<String, dynamic>? vs;
      for (final s in streams) {
        if (s['codec_type'] == 'video') {
          vs = s as Map<String, dynamic>;
          break;
        }
      }
      if (vs == null) return null;

      final fmt = json['format'] as Map<String, dynamic>?;
      final durStr = fmt?['duration'] as String?;

      int hdrType = 0;
      final trc = vs['color_transfer'] as String?;
      if (trc == 'smpte2084') {
        hdrType = 1;
      } else if (trc == 'arib-std-b67') {
        hdrType = 2;
      }

      double fps = 0;
      final rfr = vs['r_frame_rate'] as String?;
      if (rfr != null && rfr.contains('/')) {
        final p = rfr.split('/');
        fps = double.parse(p[0]) / double.parse(p[1]);
      }

      return VideoInfo(
        width: vs['width'] as int? ?? 0,
        height: vs['height'] as int? ?? 0,
        fps: fps,
        frameCount: int.tryParse(vs['nb_frames'] as String? ?? '') ?? 0,
        durationSec: double.tryParse(durStr ?? '') ?? 0,
        isHdr: hdrType > 0,
        hdrType: hdrType,
      );
    } catch (e) {
      debugPrint('[ffprobe] 获取视频信息失败: $e');
      return null;
    }
  }

  /// 构建 FFmpeg 参数
  List<String> buildArgs({
    required String input,
    required String output,
    required ConvertParams params,
    required bool isHdrToSdr,
  }) {
    final peak = params.peakLuminance > 0 ? params.peakLuminance : 1000.0;
    final crf = params.crf.clamp(0, 51);
    final args = <String>['-i', input, '-y'];

    if (isHdrToSdr) {
      args.addAll([
        '-vf',
        'tonemap=tonemap=bt2390:peak=${peak.toInt()}:desat=0,'
            'setparams=color_primaries=bt709:color_trc=bt709:colorspace=bt709,'
            'format=yuv420p',
        '-c:v', 'libx265',
        '-crf', '$crf', '-preset', 'medium',
      ]);
    } else {
      args.addAll([
        '-vf',
        'zscale=t=linear:npl=100,'
            'zscale=p=bt2020:t=smpte2084:min=0:max=${peak.toInt()},'
            'setparams=color_primaries=bt2020:color_trc=smpte2084:colorspace=bt2020nc,'
            'format=yuv420p10le',
        '-c:v', 'libx265',
        '-crf', '$crf', '-preset', 'medium',
      ]);
    }

    args.addAll(['-c:a', 'copy', output]);
    return args;
  }

  /// 运行转换
  Future<int> run({
    required String input,
    required String output,
    required ConvertParams params,
    required bool isHdrToSdr,
    double? totalDurationSec,
    void Function(double progress)? onProgress,
  }) async {
    final exe = await ffmpegPath;
    final args = buildArgs(
      input: input, output: output, params: params, isHdrToSdr: isHdrToSdr);

    debugPrint('[ffmpeg] $exe ${args.join(' ')}');
    _process = await Process.start(exe, args);

    _process!.stderr
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .listen((line) {
        if (totalDurationSec != null && totalDurationSec > 0 &&
            line.contains('time=') && onProgress != null) {
          final m = RegExp(r'time=(\d{2}):(\d{2}):(\d{2})\.(\d{2})')
              .firstMatch(line);
          if (m != null) {
            final elapsed = int.parse(m.group(1)!) * 3600.0 +
                int.parse(m.group(2)!) * 60.0 +
                int.parse(m.group(3)!) +
                int.parse(m.group(4)!) / 100.0;
            onProgress((elapsed / totalDurationSec).clamp(0.0, 1.0));
          }
        }
      });

    final exitCode = await _process!.exitCode;
    _process = null;
    return exitCode;
  }

  void cancel() {
    _process?.kill();
    _process = null;
  }
}
