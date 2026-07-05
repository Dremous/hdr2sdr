### Task 3: dart:ffi 绑定�?
**Files:**
- Create: `lib/ffi/types.dart`
- Create: `lib/ffi/native_bridge.dart`

**Interfaces:**
- Consumes: `ConvertParams`, `VideoInfo` (from Task 2)
- Produces: `NativeBridge` 单例类封装所�?FFI 调用

- [ ] **Step 1: 创建 lib/ffi/types.dart**

```dart
import 'dart:ffi';
import 'package:ffi/ffi.dart';

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

typedef ProgressCallbackNative = Void Function(
  Int32 percent,
  Int64 currentFrame,
  Int64 totalFrames,
  Pointer<Void> userData,
);

typedef CompletionCallbackNative = Void Function(
  Int32 success,
  Pointer<Utf8> errorMsg,
  Pointer<Void> userData,
);

typedef ConverterHandle = Pointer<Void>;
```

- [ ] **Step 2: 创建 lib/ffi/native_bridge.dart**

```dart
import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import '../models/convert_params.dart';
import '../models/video_info.dart';
import 'types.dart';

class NativeBridge {
  static NativeBridge? _instance;
  late final DynamicLibrary _lib;
  late final Pointer<Void> Function() _create;
  late final void Function(Pointer<Void>) _destroy;
  late final int Function(Pointer<Void>, Pointer<Utf8>) _open;
  late final void Function(Pointer<Void>) _close;
  late final int Function(Pointer<Void>) _getFrameCount;
  late final void Function(Pointer<Void>, Pointer<VideoInfoNative>) _getInfo;
  late final void Function(Pointer<Void>, Pointer<ConvertParamsNative>) _setParams;
  late final int Function(
    Pointer<Void>,
    Pointer<Uint8>,
    Int64,
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
    } else {
      throw UnsupportedError('不支持的平台');
    }

    _create = _lib
        .lookupFunction<Pointer<Void> Function(), Pointer<Void> Function()>(
            'converter_create');
    _destroy = _lib
        .lookupFunction<Void Function(Pointer<Void>), void Function(Pointer<Void>)>(
            'converter_destroy');
    _open = _lib.lookupFunction<
        Int32 Function(Pointer<Void>, Pointer<Utf8>),
        int Function(Pointer<Void>, Pointer<Utf8>)>('converter_open');
    _close = _lib
        .lookupFunction<Void Function(Pointer<Void>), void Function(Pointer<Void>)>(
            'converter_close');
    _getFrameCount = _lib.lookupFunction<
        Int32 Function(Pointer<Void>),
        int Function(Pointer<Void>)>('converter_get_frame_count');
    _getInfo = _lib.lookupFunction<
        Void Function(Pointer<Void>, Pointer<VideoInfoNative>),
        void Function(Pointer<Void>, Pointer<VideoInfoNative>)>(
        'converter_get_info');
    _setParams = _lib.lookupFunction<
        Void Function(Pointer<Void>, Pointer<ConvertParamsNative>),
        void Function(Pointer<Void>, Pointer<ConvertParamsNative>)>(
        'converter_set_params');
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
    _cancel = _lib
        .lookupFunction<Void Function(Pointer<Void>), void Function(Pointer<Void>)>(
            'converter_cancel');
  }

  static NativeBridge get instance {
    _instance ??= NativeBridge._();
    return _instance!;
  }

  ConverterHandle create() => _create();

  void destroy(ConverterHandle handle) => _destroy(handle);

  int open(ConverterHandle handle, String path) {
    final ptr = path.toNativeUtf8();
    final result = _open(handle, ptr);
    calloc.free(ptr);
    return result;
  }

  void close(ConverterHandle handle) => _close(handle);

  int getFrameCount(ConverterHandle handle) => _getFrameCount(handle);

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
    _setParams(handle, nativeParams);
    calloc.free(nativeParams);
  }

  int getFrame(ConverterHandle handle, Pointer<Uint8> buffer, int timestampUs,
      Pointer<Int32> outWidth, Pointer<Int32> outHeight) {
    return _getFrame(handle, buffer, timestampUs, outWidth, outHeight);
  }

  int start(
    ConverterHandle handle,
    String outputPath,
    Pointer<NativeFunction<ProgressCallbackNative>> progressCb,
    Pointer<NativeFunction<CompletionCallbackNative>> completeCb,
    Pointer<Void> userData,
  ) {
    final ptr = outputPath.toNativeUtf8();
    final result = _start(handle, ptr, progressCb, completeCb, userData);
    calloc.free(ptr);
    return result;
  }

  void cancel(ConverterHandle handle) => _cancel(handle);
}
```

- [ ] **Step 3: 提交**

```bash
git add lib/ffi/
git commit -m "feat: 添加 dart:ffi 绑定�?
```

---

