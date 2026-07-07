import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/convert_params.dart';
import '../models/video_file.dart';
import '../providers/convert_provider.dart';
import '../widgets/slider_row.dart';
import '../widgets/preset_selector.dart';

class ParamPanel extends StatelessWidget {
  final bool isMobile;

  const ParamPanel({super.key, this.isMobile = false});

  String _encoderLabel(EncoderType type) {
    switch (type) {
      case EncoderType.h264:
        return 'H.264';
      case EncoderType.h265:
        return 'H.265';
      case EncoderType.av1:
        return 'AV1';
      case EncoderType.h264Hardware:
        return 'H.264 (硬件)';
      case EncoderType.h265Hardware:
        return 'H.265 (硬件)';
    }
  }

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
              if (!params.autoMode) ...[
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
                        provider
                            .updateParams(params.copyWith(direction: set.first));
                      },
                    ),
                  ],
                ),
                const Divider(),
              ],
              SwitchListTile(
                title: const Text('自动模式'),
                subtitle: Text(params.autoMode
                    ? 'C++ 根据视频 HDR 类型自动选方向'
                    : '自动检测 HDR 类型并设置最佳参数'),
                value: params.autoMode,
                onChanged: (v) {
                  provider.updateParams(params.copyWith(autoMode: v));
                },
              ),
              const Divider(),
              const Text('预设风格',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              PresetSelector(
                current: params.presetStyle,
                onChanged: (style) {
                  final preset = style.toParams();
                  provider.updateParams(params.copyWith(
                    presetStyle: style,
                    peakLuminance: preset.peakLuminance,
                    exposure: preset.exposure,
                    saturation: preset.saturation,
                  ));
                },
              ),
              const Divider(),
              SliderRow(
                label: '峰值亮度',
                value: params.peakLuminance,
                min: 100,
                max: 10000,
                divisions: 99,
                formatValue: (v) => '${v.toInt()} nit',
                enabled: params.presetStyle == PresetStyle.custom,
                onChanged: (v) {
                  provider.updateParams(params.copyWith(peakLuminance: v));
                },
              ),
              SliderRow(
                label: '曝光补偿',
                value: params.exposure,
                min: -2.0,
                max: 2.0,
                divisions: 40,
                formatValue: (v) => '${v.toStringAsFixed(1)} EV',
                enabled: params.presetStyle == PresetStyle.custom,
                onChanged: (v) {
                  provider.updateParams(params.copyWith(exposure: v));
                },
              ),
              SliderRow(
                label: '饱和度',
                value: params.saturation,
                min: 0,
                max: 2.0,
                divisions: 200,
                formatValue: (v) => '${(v * 100).toInt()}%',
                enabled: params.presetStyle == PresetStyle.custom,
                onChanged: (v) {
                  provider.updateParams(params.copyWith(saturation: v));
                },
              ),
              const Divider(),
              const Text('色彩空间',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              SegmentedButton<ColorSpace>(
                segments: const [
                  ButtonSegment(
                      value: ColorSpace.bt709, label: Text('BT.709')),
                  ButtonSegment(
                      value: ColorSpace.bt2020, label: Text('BT.2020')),
                  ButtonSegment(
                      value: ColorSpace.dciP3,
                      label: Text('DCI-P3'),
                      enabled: false),
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
                if (isMobile)
                  DropdownButton<EncoderType>(
                    value: params.encoder,
                    isExpanded: true,
                    items: EncoderType.values.map((e) {
                      return DropdownMenuItem(
                        value: e,
                        child: Text(_encoderLabel(e)),
                      );
                    }).toList(),
                    onChanged: (v) {
                      if (v != null) {
                        provider.updateParams(params.copyWith(encoder: v));
                      }
                    },
                  )
                else
                  SegmentedButton<EncoderType>(
                    segments: const [
                      ButtonSegment(
                          value: EncoderType.h264, label: Text('H.264')),
                      ButtonSegment(
                          value: EncoderType.h265, label: Text('H.265')),
                      ButtonSegment(
                          value: EncoderType.av1, label: Text('AV1')),
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
          ),
        );
      },
    );
  }
}
