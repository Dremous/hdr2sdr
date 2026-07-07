import 'package:flutter/material.dart';
import '../models/convert_params.dart';

/// 预设风格选择器组件，使用分段按钮切换预设风格，并显示各预设的具体参数
class PresetSelector extends StatelessWidget {
  final PresetStyle current;
  final ValueChanged<PresetStyle> onChanged;
  final bool showParamsDetail; // 是否显示参数详情

  const PresetSelector({
    super.key,
    required this.current,
    required this.onChanged,
    this.showParamsDetail = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SegmentedButton<PresetStyle>(
          segments: PresetStyle.values.map((s) {
            return ButtonSegment(
              value: s,
              label: Text(s.label),
            );
          }).toList(),
          selected: {current},
          onSelectionChanged: (set) {
            onChanged(set.first);
          },
        ),
        if (showParamsDetail) ...[
          const SizedBox(height: 8),
          Text(
            current.summary,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}
