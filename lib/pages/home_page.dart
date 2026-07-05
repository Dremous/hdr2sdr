import 'package:flutter/material.dart';

/// 主页组件 - 应用的主界面
///
/// 提供拖放区域，供用户将视频文件拖入以进行 HDR↔SDR 转换。
/// 当前为占位版本，后续将集成拖放和文件选择功能。
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('HDR↔SDR Converter'),
        centerTitle: true,
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.video_library, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              '拖放视频文件到此处开始转换',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
