/// 视频信息数据模型
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