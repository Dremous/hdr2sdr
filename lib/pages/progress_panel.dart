import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/convert_provider.dart';

class ProgressPanel extends StatefulWidget {
  const ProgressPanel({super.key});

  @override
  State<ProgressPanel> createState() => _ProgressPanelState();
}

class _ProgressPanelState extends State<ProgressPanel> {
  bool _showComplete = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<ConvertProvider>(
      builder: (context, provider, _) {
        if (!provider.isConverting && provider.currentFile == null) {
          if (_showComplete) {
            // 完成后延迟隐藏
            Future.delayed(const Duration(seconds: 3), () {
              if (mounted) setState(() => _showComplete = false);
            });
            return _buildPanel(context, provider);
          }
          return const SizedBox.shrink();
        }

        if (provider.progress >= 100 && !_showComplete) {
          _showComplete = true;
        }
        if (!provider.isConverting && provider.currentFile == null) {
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted) setState(() => _showComplete = false);
          });
        }

        return _buildPanel(context, provider);
      },
    );
  }

  Widget _buildPanel(BuildContext context, ConvertProvider provider) {
    final isComplete = provider.progress >= 100 && !provider.isConverting;
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isComplete
                  ? '转换完成: ${provider.currentFile?.fileName ?? ""}'
                  : '正在转换: ${provider.currentFile?.fileName ?? ""}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: provider.progress / 100.0,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${provider.progress.toStringAsFixed(1)}%'),
                if (provider.totalFrames > 0)
                  Text('第${provider.currentFrame}/${provider.totalFrames}帧'),
              ],
            ),
            const SizedBox(height: 8),
            if (provider.isConverting)
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
  }
}
