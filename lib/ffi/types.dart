import 'dart:ffi';
import 'package:ffi/ffi.dart';

/// 视频信息原生结构体（对应 C 端 VideoInfo）
final class VideoInfoNative extends Struct {
  @Int32()
  external int width;

  @Int32()
  external int height;

  @Double()
  external double fps;

  @Int64()
  external int frameCount;

  @Double()
  external double durationSec;

  @Int32()
  external int isHdr;

  @Double()
  external double maxLuminance;

  @Int32()
  external int pixelFormat;
}

/// 转换参数原生结构体（对应 C 端 ConvertParams）
final class ConvertParamsNative extends Struct {
  @Int32()
  external int direction;

  @Int32()
  external int autoMode;

  @Int32()
  external int presetStyle;

  @Double()
  external double peakLuminance;

  @Double()
  external double exposure;

  @Double()
  external double saturation;

  @Int32()
  external int targetColorSpace;

  @Int32()
  external int encoder;

  @Int32()
  external int crf;

  @Int32()
  external int targetWidth;

  @Int32()
  external int targetHeight;

  @Int32()
  external int cropLeft;

  @Int32()
  external int cropRight;

  @Int32()
  external int cropTop;

  @Int32()
  external int cropBottom;
}

/// 进度回调函数签名
typedef ProgressCallbackNative = Void Function(
  Int32 percent,
  Int64 currentFrame,
  Int64 totalFrames,
  Pointer<Void> userData,
);

/// 完成回调函数签名
typedef CompletionCallbackNative = Void Function(
  Int32 success,
  Pointer<Utf8> errorMsg,
  Pointer<Void> userData,
);

/// 转换器句柄类型
typedef ConverterHandle = Pointer<Void>;
