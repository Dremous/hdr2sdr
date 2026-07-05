import 'package:flutter/material.dart';

/// 带标签和数值显示的滑块行组件
class SliderRow extends StatelessWidget {
  /// 滑块标签文字
  final String label;

  /// 当前值
  final double value;

  /// 最小值
  final double min;

  /// 最大值
  final double max;

  /// 刻度数
  final int divisions;

  /// 数值格式化函数
  final String Function(double value) formatValue;

  /// 值变更回调
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