import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import '../models/convert_params.dart';
import '../models/video_info.dart';
import 'types.dart';

/// Native Bridge 单例类，封装所有 dart:ffi 调用
class NativeBridge {
  static NativeBridge? _instance;
  late final DynamicLibrary _lib;
  late final Pointer<Void> Function() _create;
  late final void Function(Pointer<Void>) _destroy;
  late final int Function(Pointer<Void>, Pointer<Utf8>) _open;
  late final void Function(Pointer<Void>) _close;
  late final int Function(Pointer<Void>) _getFrameCount;
  late final void Function(Pointer<Void>, Pointer<VideoInfoNative>) _getInfo;
  late final void Function(Pointer<Void>, ConvertParamsNative)
      _setParams;
  late final int Function(
    Pointer<Void>,
    Pointer<Uint8>,
    int,
    Pointer<Int32>,
    Pointer<Int32>,
  ) _getFrame;
  late final int Function(
    Pointer<Void>,
    Pointer<Utf8>,
    Pointer<NativeFunction<ProgressCallbackNative>>,
    Pointer<NativeFunction<CompletionCallbackNative>>,
    Pointer<Void>,
  ) _start;
  late final void Function(Pointer<Void>) _cancel;

  NativeBridge._() {
    if (Platform.isWindows) {
      _lib = DynamicLibrary.open('hdr_converter.dll');
    } else if (Platform.isMacOS) {
      _lib = DynamicLibrary.open('libhdr_converter.dylib');
    } else if (Platform.isLinux) {
      _lib = DynamicLibrary.open('libhdr_converter.so');
    } else if (Platform.isAndroid) {
      _lib = DynamicLibrary.open('libhdr_converter.so');
    } else if (Platform.isIOS) {
      _lib = DynamicLibrary.process();
    } else {
      throw UnsupportedError('不支持的平台');
    }

    _create =
        _lib.lookupFunction<Pointer<Void> Function(), Pointer<Void> Function()>(
            'converter_create');
    _destroy = _lib.lookupFunction<Void Function(Pointer<Void>),
        void Function(Pointer<Void>)>('converter_destroy');
    _open = _lib.lookupFunction<Int32 Function(Pointer<Void>, Pointer<Utf8>),
        int Function(Pointer<Void>, Pointer<Utf8>)>('converter_open');
    _close = _lib.lookupFunction<Void Function(Pointer<Void>),
        void Function(Pointer<Void>)>('converter_close');
    _getFrameCount = _lib.lookupFunction<Int32 Function(Pointer<Void>),
        int Function(Pointer<Void>)>('converter_get_frame_count');
    _getInfo = _lib.lookupFunction<
        Void Function(Pointer<Void>, Pointer<VideoInfoNative>),
        void Function(
            Pointer<Void>, Pointer<VideoInfoNative>)>('converter_get_info');
    _setParams = _lib.lookupFunction<
        Void Function(Pointer<Void>, ConvertParamsNative),
        void Function(Pointer<Void>,
            ConvertParamsNative)>('converter_set_params');
    _getFrame = _lib.lookupFunction<
        Int32 Function(Pointer<Void>, Pointer<Uint8>, Int64, Pointer<Int32>,
            Pointer<Int32>),
        int Function(Pointer<Void>, Pointer<Uint8>, int, Pointer<Int32>,
            Pointer<Int32>)>('converter_get_frame');
    _start = _lib.lookupFunction<
        Int32 Function(
            Pointer<Void>,
            Pointer<Utf8>,
            Pointer<NativeFunction<ProgressCallbackNative>>,
            Pointer<NativeFunction<CompletionCallbackNative>>,
            Pointer<Void>),
        int Function(
            Pointer<Void>,
            Pointer<Utf8>,
            Pointer<NativeFunction<ProgressCallbackNative>>,
            Pointer<NativeFunction<CompletionCallbackNative>>,
            Pointer<Void>)>('converter_start');
    _cancel = _lib.lookupFunction<Void Function(Pointer<Void>),
        void Function(Pointer<Void>)>('converter_cancel');
  }

  /// 获取单例实例
  static NativeBridge get instance {
    _instance ??= NativeBridge._();
    return _instance!;
  }

  /// 创建转换器实例，返回句柄
  ConverterHandle create() => _create();

  /// 销毁转换器实例
  void destroy(ConverterHandle handle) => _destroy(handle);

  /// 打开视频文件，path 为文件路径
  int open(ConverterHandle handle, String path) {
    final ptr = path.toNativeUtf8();
    final result = _open(handle, ptr);
    malloc.free(ptr);
    return result;
  }

  /// 关闭已打开的视频文件
  void close(ConverterHandle handle) => _close(handle);

  /// 获取视频帧总数
  int getFrameCount(ConverterHandle handle) => _getFrameCount(handle);

  /// 获取视频信息，返回 VideoInfo 对象
  VideoInfo? getInfo(ConverterHandle handle) {
    final nativeInfo = calloc<VideoInfoNative>();
    _getInfo(handle, nativeInfo);
    final info = VideoInfo(
      width: nativeInfo.ref.width,
      height: nativeInfo.ref.height,
      fps: nativeInfo.ref.fps,
      frameCount: nativeInfo.ref.frameCount,
      durationSec: nativeInfo.ref.durationSec,
      isHdr: nativeInfo.ref.isHdr != 0,
      hdrType: nativeInfo.ref.isHdr,
      maxLuminance: nativeInfo.ref.maxLuminance,
      pixelFormat: nativeInfo.ref.pixelFormat,
    );
    calloc.free(nativeInfo);
    return info;
  }

  /// 设置转换参数
  void setParams(ConverterHandle handle, ConvertParams params) {
    final nativeParams = calloc<ConvertParamsNative>();
    nativeParams.ref.direction = params.direction.index;
    nativeParams.ref.autoMode = params.autoMode ? 1 : 0;
    nativeParams.ref.presetStyle = params.presetStyle.index;
    nativeParams.ref.peakLuminance = params.peakLuminance;
    nativeParams.ref.exposure = params.exposure;
    nativeParams.ref.saturation = params.saturation;
    nativeParams.ref.targetColorSpace = params.targetColorSpace.index;
    nativeParams.ref.encoder = params.encoder.index;
    nativeParams.ref.crf = params.crf;
    nativeParams.ref.targetWidth = params.targetWidth;
    nativeParams.ref.targetHeight = params.targetHeight;
    nativeParams.ref.cropLeft = params.cropLeft;
    nativeParams.ref.cropRight = params.cropRight;
    nativeParams.ref.cropTop = params.cropTop;
    nativeParams.ref.cropBottom = params.cropBottom;
    _setParams(handle, nativeParams.ref);  // 按值传递结构体
    calloc.free(nativeParams);
  }

  /// 获取指定时间戳的帧数据
  int getFrame(ConverterHandle handle, Pointer<Uint8> buffer, int timestampUs,
      Pointer<Int32> outWidth, Pointer<Int32> outHeight) {
    return _getFrame(handle, buffer, timestampUs, outWidth, outHeight);
  }

  /// 开始转换任务
  int start(
    ConverterHandle handle,
    String outputPath,
    Pointer<NativeFunction<ProgressCallbackNative>> progressCb,
    Pointer<NativeFunction<CompletionCallbackNative>> completeCb,
    Pointer<Void> userData,
  ) {
    final ptr = outputPath.toNativeUtf8();
    final result = _start(handle, ptr, progressCb, completeCb, userData);
    malloc.free(ptr);
    return result;
  }

  /// 取消当前转换任务
  void cancel(ConverterHandle handle) => _cancel(handle);
}
