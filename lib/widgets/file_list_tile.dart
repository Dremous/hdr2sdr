import 'package:flutter/material.dart';
import '../models/video_file.dart';

/// 文件列表中单个文件的卡片组件，显示文件名和状态标签
class FileListTile extends StatelessWidget {
  /// 要显示的视频文件数据
  final VideoFile file;

  /// 文件在列表中的索引
  final int index;

  /// 移除文件的回调
  final VoidCallback onRemove;

  const FileListTile({
    super.key,
    required this.file,
    required this.index,
    required this.onRemove,
  });

  /// 根据文件状态返回对应的颜色
  Color _statusColor(FileStatus status) {
    switch (status) {
      case FileStatus.pending:
        return Colors.grey;
      case FileStatus.analyzing:
        return Colors.blue;
      case FileStatus.ready:
        return Colors.green;
      case FileStatus.converting:
        return Colors.orange;
      case FileStatus.completed:
        return Colors.green;
      case FileStatus.failed:
        return Colors.red;
    }
  }

  /// 根据文件状态返回对应的中文文本
  String _statusText(FileStatus status) {
    switch (status) {
      case FileStatus.pending:
        return '等待';
      case FileStatus.analyzing:
        return '分析中';
      case FileStatus.ready:
        return '就绪';
      case FileStatus.converting:
        return '转换中';
      case FileStatus.completed:
        return '已完成';
      case FileStatus.failed:
        return '失败';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
      child: ListTile(
        leading: Icon(Icons.video_file, color: theme.colorScheme.primary),
        title: Text(file.fileName, overflow: TextOverflow.ellipsis),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _statusColor(file.status).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _statusText(file.status),
                style: TextStyle(
                  color: _statusColor(file.status),
                  fontSize: 12,
                ),
              ),
            ),
            if (file.status == FileStatus.pending)
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: onRemove,
              ),
          ],
        ),
      ),
    );
  }
}