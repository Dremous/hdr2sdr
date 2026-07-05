import 'package:flutter/material.dart';
import '../models/convert_params.dart';

/// 预设风格选择器组件，使用分段按钮切换预设风格
class PresetSelector extends StatelessWidget {
  /// 当前选中的预设风格
  final PresetStyle current;

  /// 预设风格变更回调
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
        ButtonSegment(value: PresetStyle.cinematic, label: Text('电影感')),
        ButtonSegment(value: PresetStyle.custom, label: Text('自定义')),
      ],
      selected: {current},
      onSelectionChanged: (set) => onChanged(set.first),
    );
  }
}