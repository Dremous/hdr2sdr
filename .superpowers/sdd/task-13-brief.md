### Task 13: Flutter UI �?Widget 组件

**Files:**
- Create: `lib/widgets/drop_zone.dart`
- Create: `lib/widgets/file_list_tile.dart`
- Create: `lib/widgets/slider_row.dart`
- Create: `lib/widgets/preset_selector.dart`

- [ ] **Step 1: 创建 lib/widgets/drop_zone.dart**

```dart
import 'package:flutter/material.dart';
import 'package:desktop_drop/desktop_drop.dart';

class DropZone extends StatelessWidget {
  final void Function(List<String> paths) onFilesDropped;
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
              color: theme.colorScheme.outline.withOpacity(0.5),
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
                Text('拖拽视频文件到此�?,
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
```

- [ ] **Step 2: 创建 lib/widgets/file_list_tile.dart**

```dart
import 'package:flutter/material.dart';
import '../models/video_file.dart';

class FileListTile extends StatelessWidget {
  final VideoFile file;
  final int index;
  final VoidCallback onRemove;

  const FileListTile({
    super.key,
    required this.file,
    required this.index,
    required this.onRemove,
  });

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

  String _statusText(FileStatus status) {
    switch (status) {
      case FileStatus.pending:
        return '等待�?;
      case FileStatus.analyzing:
        return '分析�?;
      case FileStatus.ready:
        return '就绪';
      case FileStatus.converting:
        return '转换�?;
      case FileStatus.completed:
        return '已完�?;
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
                color: _statusColor(file.status).withOpacity(0.2),
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
```

- [ ] **Step 3: 创建 lib/widgets/slider_row.dart**

```dart
import 'package:flutter/material.dart';

class SliderRow extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String Function(double value) formatValue;
  final ValueChanged<double> onChanged;

  const SliderRow({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.formatValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Expanded(
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              label: formatValue(value),
              onChanged: onChanged,
            ),
          ),
          SizedBox(
            width: 60,
            child: Text(
              formatValue(value),
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: 创建 lib/widgets/preset_selector.dart**

```dart
import 'package:flutter/material.dart';
import '../models/convert_params.dart';

class PresetSelector extends StatelessWidget {
  final PresetStyle current;
  final ValueChanged<PresetStyle> onChanged;

  const PresetSelector({
    super.key,
    required this.current,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<PresetStyle>(
      segments: const [
        ButtonSegment(value: PresetStyle.standard, label: Text('标准')),
        ButtonSegment(value: PresetStyle.vivid, label: Text('鲜艳')),
        ButtonSegment(value: PresetStyle.cinematic, label: Text('电影�?)),
        ButtonSegment(value: PresetStyle.custom, label: Text('自定�?)),
      ],
      selected: {current},
      onSelectionChanged: (set) => onChanged(set.first),
    );
  }
}
```

- [ ] **Step 5: 提交**

```bash
git add lib/widgets/
git commit -m "feat: 添加 UI 组件（拖拽区/文件列表/滑块/预设选择器）"
```

---

