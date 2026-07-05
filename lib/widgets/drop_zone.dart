import 'package:flutter/material.dart';
import 'package:desktop_drop/desktop_drop.dart';

/// 拖拽上传区域组件，支持拖拽文件和点击选择文件
class DropZone extends StatelessWidget {
  /// 文件拖拽完成时的回调，参数为文件路径列表
  final void Function(List<String> paths) onFilesDropped;

  /// 点击选择文件时的回调
  final void Function() onPickFiles;

  const DropZone({
    super.key,
    required this.onFilesDropped,
    required this.onPickFiles,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DropTarget(
      onDragDone: (detail) {
        final paths = detail.files.map((f) => f.path).toList();
        onFilesDropped(paths);
      },
      child: InkWell(
        onTap: onPickFiles,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 180,
          decoration: BoxDecoration(
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.5),
              width: 2,
              strokeAlign: BorderSide.strokeAlignInside,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.cloud_upload_outlined,
                    size: 48, color: theme.colorScheme.primary),
                const SizedBox(height: 12),
                Text('拖拽视频文件到此',
                    style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text('或点击选择文件',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.primary)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}