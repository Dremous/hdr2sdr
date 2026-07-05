### Task 14: Flutter UI �?参数面板

**Files:**
- Create: `lib/pages/param_panel.dart`

- [ ] **Step 1: 创建 lib/pages/param_panel.dart**

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/convert_params.dart';
import '../providers/convert_provider.dart';
import '../widgets/slider_row.dart';
import '../widgets/preset_selector.dart';

class ParamPanel extends StatelessWidget {
  const ParamPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ConvertProvider>(
      builder: (context, provider, _) {
        final params = provider.params;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 转换方向
              Row(
                children: [
                  const Text('转换方向'),
                  const SizedBox(width: 12),
                  SegmentedButton<ConvertDirection>(
                    segments: const [
                      ButtonSegment(
                          value: ConvertDirection.hdrToSdr,
                          label: Text('HDR→SDR')),
                      ButtonSegment(
                          value: ConvertDirection.sdrToHdr,
                          label: Text('SDR→HDR')),
                    ],
                    selected: {params.direction},
                    onSelectionChanged: (set) {
                      provider.updateParams(
                          params.copyWith(direction: set.first));
                    },
                  ),
                ],
              ),
              const Divider(),
              // 自动模式
              SwitchListTile(
                title: const Text('自动模式'),
                subtitle: const Text('自动检�?HDR 类型并设置最佳参�?),
                value: params.autoMode,
                onChanged: (v) {
                  provider.updateParams(params.copyWith(autoMode: v));
                },
              ),
              const Divider(),
              const Text('预设风格', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              PresetSelector(
                current: params.presetStyle,
                onChanged: (style) {
                  provider.updateParams(params.copyWith(presetStyle: style));
                },
              ),
              const Divider(),
              if (!params.autoMode) ...[
                SliderRow(
                  label: '峰值亮�?,
                  value: params.peakLuminance,
                  min: 100,
                  max: 10000,
                  divisions: 99,
                  formatValue: (v) => '${v.toInt()} nit',
                  onChanged: (v) {
                    provider.updateParams(
                        params.copyWith(peakLuminance: v));
                  },
                ),
                SliderRow(
                  label: '曝光补偿',
                  value: params.exposure,
                  min: -2.0,
                  max: 2.0,
                  divisions: 40,
                  formatValue: (v) => '${v.toStringAsFixed(1)} EV',
                  onChanged: (v) {
                    provider.updateParams(params.copyWith(exposure: v));
                  },
                ),
                SliderRow(
                  label: '饱和�?,
                  value: params.saturation,
                  min: 0,
                  max: 2.0,
                  divisions: 200,
                  formatValue: (v) => '${(v * 100).toInt()}%',
                  onChanged: (v) {
                    provider.updateParams(params.copyWith(saturation: v));
                  },
                ),
                const Divider(),
                const Text('色彩空间', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                SegmentedButton<ColorSpace>(
                  segments: const [
                    ButtonSegment(value: ColorSpace.bt709, label: Text('BT.709')),
                    ButtonSegment(value: ColorSpace.bt2020, label: Text('BT.2020')),
                    ButtonSegment(value: ColorSpace.dciP3, label: Text('DCI-P3')),
                  ],
                  selected: {params.targetColorSpace},
                  onSelectionChanged: (set) {
                    provider.updateParams(
                        params.copyWith(targetColorSpace: set.first));
                  },
                ),
                const Divider(),
                const Text('编码设置',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                SegmentedButton<EncoderType>(
                  segments: const [
                    ButtonSegment(value: EncoderType.h264, label: Text('H.264')),
                    ButtonSegment(value: EncoderType.h265, label: Text('H.265')),
                    ButtonSegment(value: EncoderType.av1, label: Text('AV1')),
                  ],
                  selected: {params.encoder},
                  onSelectionChanged: (set) {
                    provider.updateParams(
                        params.copyWith(encoder: set.first));
                  },
                ),
                SliderRow(
                  label: 'CRF',
                  value: params.crf.toDouble(),
                  min: 0,
                  max: 51,
                  divisions: 51,
                  formatValue: (v) => v.toInt().toString(),
                  onChanged: (v) {
                    provider.updateParams(params.copyWith(crf: v.toInt()));
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
```

- [ ] **Step 2: 提交**

```bash
git add lib/pages/param_panel.dart
git commit -m "feat: 添加参数面板页面"
```

---

