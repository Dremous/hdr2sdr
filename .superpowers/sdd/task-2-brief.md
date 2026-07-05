### Task 2: 数据模型定义

**Files:**
- Create: `lib/models/video_file.dart`
- Create: `lib/models/convert_params.dart`
- Create: `lib/models/video_info.dart`

**Interfaces:**
- Produces: `VideoFile`, `ConvertParams`, `VideoInfo` 数据�?
- [ ] **Step 1: 创建 lib/models/video_file.dart**

```dart
enum HdrType {
  sdr,
  hdr10,
  hlg,
  dolbyVision,
}

enum ConvertDirection {
  hdrToSdr,
  sdrToHdr,
}

enum FileStatus {
  pending,
  analyzing,
  ready,
  converting,
  completed,
  failed,
}

class VideoFile {
  final String filePath;
  final String fileName;
  HdrType hdrType;
  FileStatus status;
  String? errorMessage;

  VideoFile({
    required this.filePath,
    required this.fileName,
    this.hdrType = HdrType.sdr,
    this.status = FileStatus.pending,
    this.errorMessage,
  });
}
```

- [ ] **Step 2: 创建 lib/models/convert_params.dart**

```dart
enum PresetStyle { standard, vivid, cinematic, custom }

enum ColorSpace { bt709, bt2020, dciP3 }

enum EncoderType { h264, h265, av1 }

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
```

- [ ] **Step 3: 创建 lib/models/video_info.dart**

```dart
import 'video_file.dart';

class VideoInfo {
  final int width;
  final int height;
  final double fps;
  final int frameCount;
  final double durationSec;
  final bool isHdr;
  final int hdrType; // 0=SDR, 1=HDR10, 2=HLG, 3=DolbyVision
  final double maxLuminance;
  final int pixelFormat;

  const VideoInfo({
    required this.width,
    required this.height,
    required this.fps,
    required this.frameCount,
    required this.durationSec,
    required this.isHdr,
    required this.hdrType,
    this.maxLuminance = 0.0,
    this.pixelFormat = 0,
  });
}
```

- [ ] **Step 4: 提交**

```bash
git add lib/models/
git commit -m "feat: 添加数据模型定义"
```

---

