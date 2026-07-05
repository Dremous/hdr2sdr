import 'video_file.dart';

/// 预设风格枚举
enum PresetStyle { standard, vivid, cinematic, custom }

/// 色彩空间枚举
enum ColorSpace { bt709, bt2020, dciP3 }

/// 编码器类型枚举
enum EncoderType { h264, h265, av1, h264Hardware, h265Hardware }

/// 转换参数数据模型
class ConvertParams {
  final ConvertDirection direction;
  final bool autoMode;
  final PresetStyle presetStyle;
  final double peakLuminance;
  final double exposure;
  final double saturation;
  final ColorSpace targetColorSpace;
  final EncoderType encoder;
  final int crf;
  final int targetWidth;
  final int targetHeight;
  final int cropLeft;
  final int cropRight;
  final int cropTop;
  final int cropBottom;

  const ConvertParams({
    this.direction = ConvertDirection.hdrToSdr,
    this.autoMode = true,
    this.presetStyle = PresetStyle.standard,
    this.peakLuminance = 1000.0,
    this.exposure = 0.0,
    this.saturation = 1.0,
    this.targetColorSpace = ColorSpace.bt709,
    this.encoder = EncoderType.h265,
    this.crf = 23,
    this.targetWidth = 0,
    this.targetHeight = 0,
    this.cropLeft = 0,
    this.cropRight = 0,
    this.cropTop = 0,
    this.cropBottom = 0,
  });

  /// 带参数复制的拷贝方法
  ConvertParams copyWith({
    ConvertDirection? direction,
    bool? autoMode,
    PresetStyle? presetStyle,
    double? peakLuminance,
    double? exposure,
    double? saturation,
    ColorSpace? targetColorSpace,
    EncoderType? encoder,
    int? crf,
    int? targetWidth,
    int? targetHeight,
    int? cropLeft,
    int? cropRight,
    int? cropTop,
    int? cropBottom,
  }) {
    return ConvertParams(
      direction: direction ?? this.direction,
      autoMode: autoMode ?? this.autoMode,
      presetStyle: presetStyle ?? this.presetStyle,
      peakLuminance: peakLuminance ?? this.peakLuminance,
      exposure: exposure ?? this.exposure,
      saturation: saturation ?? this.saturation,
      targetColorSpace: targetColorSpace ?? this.targetColorSpace,
      encoder: encoder ?? this.encoder,
      crf: crf ?? this.crf,
      targetWidth: targetWidth ?? this.targetWidth,
      targetHeight: targetHeight ?? this.targetHeight,
      cropLeft: cropLeft ?? this.cropLeft,
      cropRight: cropRight ?? this.cropRight,
      cropTop: cropTop ?? this.cropTop,
      cropBottom: cropBottom ?? this.cropBottom,
    );
  }
}
