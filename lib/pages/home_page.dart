import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/convert_provider.dart';
import '../widgets/drop_zone.dart';
import '../widgets/file_list_tile.dart';
import 'preview_panel.dart';
import 'param_panel.dart';
import 'progress_panel.dart';

enum _LayoutMode { desktopWide, desktopNarrow, mobile }

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  static _LayoutMode _resolveLayoutMode(double width) {
    if (width > 900) return _LayoutMode.desktopWide;
    if (width > 600) return _LayoutMode.desktopNarrow;
    return _LayoutMode.mobile;
  }

  Future<void> _pickFiles(BuildContext context) async {
    final result = await FilePicker.pickFiles(
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
    final dir = await FilePicker.getDirectoryPath();
    if (dir != null && context.mounted) {
      context.read<ConvertProvider>().setOutputDirectory(dir);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Consumer<ConvertProvider>(
      builder: (context, provider, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final mode = _resolveLayoutMode(constraints.maxWidth);
            switch (mode) {
              case _LayoutMode.mobile:
                return _buildMobileLayout(context, provider, theme);
              case _LayoutMode.desktopNarrow:
              case _LayoutMode.desktopWide:
                return _buildDesktopLayout(context, provider, theme, mode);
            }
          },
        );
      },
    );
  }

  Scaffold _buildDesktopLayout(
    BuildContext context,
    ConvertProvider provider,
    ThemeData theme,
    _LayoutMode mode,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('HDR↔SDR 视频转换工具'),
        centerTitle: true,
      ),
      body: mode == _LayoutMode.desktopWide
          ? _buildWideLayout(context, provider, theme)
          : _buildNarrowLayout(context, provider, theme),
    );
  }

  Widget _buildMobileLayout(
    BuildContext context,
    ConvertProvider provider,
    ThemeData theme,
  ) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('HDR↔SDR'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.folder), text: '文件'),
              Tab(icon: Icon(Icons.tune), text: '参数'),
              Tab(icon: Icon(Icons.visibility), text: '预览'),
              Tab(icon: Icon(Icons.bar_chart), text: '进度'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildMobileFileTab(context, provider, theme),
            const ParamPanel(isMobile: true),
            const PreviewPanel(),
            _buildMobileProgressTab(context, provider),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileFileTab(
    BuildContext context,
    ConvertProvider provider,
    ThemeData theme,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          DropZone(
            onFilesDropped: (paths) => provider.addFiles(paths),
            onPickFiles: () => _pickFiles(context),
          ),
          const SizedBox(height: 12),
          if (provider.queue.isNotEmpty) ...[
            Row(
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
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: provider.queue.length,
              itemBuilder: (context, index) {
                return FileListTile(
                  file: provider.queue[index],
                  index: index,
                  onRemove: () => provider.removeFile(index),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMobileProgressTab(
    BuildContext context,
    ConvertProvider provider,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const ProgressPanel(),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: (provider.isConverting || provider.queue.isEmpty)
                  ? null
                  : () => provider.startConversion(),
              icon: const Icon(Icons.swap_horiz),
              label: Text(provider.isConverting ? '转换中...' : '开始转换'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWideLayout(
    BuildContext context,
    ConvertProvider provider,
    ThemeData theme,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Column(
            children: [
              Expanded(child: _buildFileSection(context, provider, theme)),
              const Divider(height: 1),
              const Expanded(
                flex: 2,
                child: ParamPanel(),
              ),
            ],
          ),
        ),
        const VerticalDivider(width: 1),
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
    BuildContext context,
    ConvertProvider provider,
    ThemeData theme,
  ) {
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
    BuildContext context,
    ConvertProvider provider,
    ThemeData theme,
  ) {
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
