import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/video_file.dart';
import '../providers/convert_provider.dart';

/// 转换进度面板：显示进度条、帧数、取消按钮和错误信息
class ProgressPanel extends StatelessWidget {
  const ProgressPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ConvertProvider>(
      builder: (context, provider, _) {
        final show = provider.isConverting ||
            (provider.currentFile?.status == FileStatus.completed) ||
            (provider.currentFile?.status == FileStatus.failed);
        if (!show) return const SizedBox.shrink();

        final isComplete = !provider.isConverting &&
            provider.currentFile?.status == FileStatus.completed;
        final isFailed = !provider.isConverting &&
            provider.currentFile?.status == FileStatus.failed;

        return Card(
          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(
                      isComplete
                          ? Icons.check_circle
                          : isFailed
                              ? Icons.error
                              : Icons.sync,
                      color: isComplete
                          ? Colors.green
                          : isFailed
                              ? Colors.red
                              : Theme.of(context).colorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isComplete
                            ? '转换完成: ${provider.currentFile?.fileName ?? ""}'
                            : isFailed
                                ? '转换失败: ${provider.currentFile?.fileName ?? ""}'
                                : '正在转换: ${provider.currentFile?.fileName ?? ""}',
                        style: Theme.of(context).textTheme.titleSmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isComplete || isFailed)
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => provider.dismissCurrentFile(),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: provider.isConverting
                      ? (provider.progress / 100.0).clamp(0.0, 1.0)
                      : 1.0,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                  color: isFailed ? Colors.red : null,
                ),
                const SizedBox(height: 8),
                Text(
                  isComplete
                      ? '100%'
                      : '${provider.progress.toStringAsFixed(1)}%',
                ),
                if (provider.isConverting) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: provider.cancelConversion,
                      icon: const Icon(Icons.stop),
                      label: const Text('取消'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                    ),
                  ),
                ],
                if (provider.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '错误: ${provider.errorMessage}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
