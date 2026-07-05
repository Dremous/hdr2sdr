/// HDR 类型枚举
enum HdrType {
  sdr,
  hdr10,
  hlg,
  dolbyVision,
}

/// 转换方向枚举
enum ConvertDirection {
  hdrToSdr,
  sdrToHdr,
}

/// 文件状态枚举
enum FileStatus {
  pending,
  analyzing,
  ready,
  converting,
  completed,
  failed,
}

/// 视频文件数据模型
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