import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/convert_provider.dart';
import '../widgets/drop_zone.dart';
import '../widgets/file_list_tile.dart';
import 'preview_panel.dart';
import 'param_panel.dart';
import 'progress_panel.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  Future<void> _pickFiles(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp4', 'mkv', 'mov', 'avi', 'mxf', 'webm'],
      allowMultiple: true,
    );
    if (result != null && context.mounted) {
      context.read<ConvertProvider>().addFiles(
            result.files
                .map((f) => f.path ?? '')
                .where((p) => p.isNotEmpty)
                .toList(),
          );
    }
  }

  Future<void> _pickOutputDir(BuildContext context) async {
    final dir = await FilePicker.platform.getDirectoryPath();
    if (dir != null && context.mounted) {
      context.read<ConvertProvider>().setOutputDirectory(dir);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('HDR↔SDR 视频转换工具'),
        centerTitle: true,
      ),
      body: Consumer<ConvertProvider>(
        builder: (context, provider, _) {
          return LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 900;
              if (isWide) {
                return _buildWideLayout(context, provider, theme);
              } else {
                return _buildNarrowLayout(context, provider, theme);
              }
            },
          );
        },
      ),
    );
  }

  Widget _buildWideLayout(
      BuildContext context, ConvertProvider provider, ThemeData theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 左侧: 文件管理和参数
        Expanded(
          flex: 2,
          child: Column(
            children: [
              Expanded(child: _buildFileSection(context, provider, theme)),
              const Divider(height: 1),
              Expanded(
                flex: 2,
                child: ParamPanel(),
              ),
            ],
          ),
        ),
        const VerticalDivider(width: 1),
        // 右侧: 预览和进度
        Expanded(
          flex: 3,
          child: Column(
            children: [
              const Expanded(flex: 3, child: PreviewPanel()),
              const ProgressPanel(),
              _buildActionBar(context, provider),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNarrowLayout(
      BuildContext context, ConvertProvider provider, ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          DropZone(
            onFilesDropped: (paths) => provider.addFiles(paths),
            onPickFiles: () => _pickFiles(context),
          ),
          const SizedBox(height: 12),
          _buildFileSection(context, provider, theme),
          const SizedBox(height: 16),
          const PreviewPanel(),
          const SizedBox(height: 16),
          const ParamPanel(),
          const ProgressPanel(),
          const SizedBox(height: 16),
          _buildActionBar(context, provider),
        ],
      ),
    );
  }

  Widget _buildFileSection(
      BuildContext context, ConvertProvider provider, ThemeData theme) {
    return Column(
      children: [
        if (provider.queue.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('文件列表 (${provider.queue.length})',
                    style: theme.textTheme.titleSmall),
                TextButton(
                  onPressed: () => _pickOutputDir(context),
                  child: Text(
                    provider.outputDirectory ?? '选择输出目录',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: provider.queue.length,
              itemBuilder: (context, index) {
                return FileListTile(
                  file: provider.queue[index],
                  index: index,
                  onRemove: () => provider.removeFile(index),
                );
              },
            ),
          ),
        ] else
          Expanded(
            child: DropZone(
              onFilesDropped: (paths) => provider.addFiles(paths),
              onPickFiles: () => _pickFiles(context),
            ),
          ),
      ],
    );
  }

  Widget _buildActionBar(BuildContext context, ConvertProvider provider) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: provider.isConverting || provider.queue.isEmpty
              ? null
              : () => provider.startConversion(),
          icon: const Icon(Icons.swap_horiz),
          label: Text(provider.isConverting ? '转换中...' : '开始转换'),
        ),
      ),
    );
  }
}
