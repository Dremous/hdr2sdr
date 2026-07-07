import 'video_file.dart';

/// 预设风格枚举
enum PresetStyle {
  standard,
  vivid,
  cinematic,
  custom;

  /// 预设名称
  String get label {
    switch (this) {
      case PresetStyle.standard: return '标准';
      case PresetStyle.vivid: return '鲜艳';
      case PresetStyle.cinematic: return '电影感';
      case PresetStyle.custom: return '自定义';
    }
  }

  /// 预设参数摘要（供 UI 显示）
  String get summary {
    switch (this) {
      case PresetStyle.standard:
        return '峰值1000nit  曝光0EV  饱和度100%';
      case PresetStyle.vivid:
        return '峰值2000nit  曝光+0.5EV  饱和度120%';
      case PresetStyle.cinematic:
        return '峰值4000nit  曝光-0.3EV  饱和度90%';
      case PresetStyle.custom:
        return '手动调节';
    }
  }

  /// 预设对应的 ConvertParams 基础值
  ConvertParams toParams() {
    switch (this) {
      case PresetStyle.standard:
        return const ConvertParams(
          peakLuminance: 1000, exposure: 0.0, saturation: 1.0);
      case PresetStyle.vivid:
        return const ConvertParams(
          peakLuminance: 2000, exposure: 0.5, saturation: 1.2);
      case PresetStyle.cinematic:
        return const ConvertParams(
          peakLuminance: 4000, exposure: -0.3, saturation: 0.9);
      case PresetStyle.custom:
        return const ConvertParams();
    }
  }
}

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

  Map<String, dynamic> toJson() => {
    'direction': direction.name,
    'autoMode': autoMode,
    'presetStyle': presetStyle.name,
    'peakLuminance': peakLuminance,
    'exposure': exposure,
    'saturation': saturation,
    'targetColorSpace': targetColorSpace.name,
    'encoder': encoder.index,
    'crf': crf,
    'targetWidth': targetWidth,
    'targetHeight': targetHeight,
    'cropLeft': cropLeft,
    'cropRight': cropRight,
    'cropTop': cropTop,
    'cropBottom': cropBottom,
  };

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
