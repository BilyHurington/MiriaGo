import 'package:flutter/material.dart';

import '../app_theme.dart';
import 'color_grading_params.dart';

class ColorGradingParameterSummary extends StatelessWidget {
  const ColorGradingParameterSummary({required this.activeParams, super.key});

  final ColorGradingParams activeParams;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '调色参数',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _showParameterSheet(context),
                style: AppButtonStyles.compactOutlinedButton(),
                icon: const Icon(Icons.tune, size: 18),
                label: const Text('查看'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '显示当前调色强度下实际生效的参数。',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }

  void _showParameterSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (context) =>
          _ColorGradingParameterSheet(activeParams: activeParams),
    );
  }
}

class _ColorGradingParameterSheet extends StatelessWidget {
  const _ColorGradingParameterSheet({required this.activeParams});

  final ColorGradingParams activeParams;

  @override
  Widget build(BuildContext context) {
    final items = <_ParameterItem>[
      _ParameterItem('亮度', activeParams.brightness, -0.25, 0.25),
      _ParameterItem('曝光', activeParams.exposure, -1.0, 1.0),
      _ParameterItem('对比度', activeParams.contrast, 0.7, 1.4),
      _ParameterItem('饱和度', activeParams.saturation, 0.5, 1.6),
      _ParameterItem('色温', activeParams.temperature, -1.0, 1.0),
      _ParameterItem('色调', activeParams.tint, -1.0, 1.0),
      _ParameterItem('高光', activeParams.highlights, -1.0, 1.0),
      _ParameterItem('阴影', activeParams.shadows, -1.0, 1.0),
      _ParameterItem('红暗部曲线', activeParams.redShadowCurve, -1.0, 1.0),
      _ParameterItem('红中间调曲线', activeParams.redMidCurve, -1.0, 1.0),
      _ParameterItem('红高光曲线', activeParams.redHighlightCurve, -1.0, 1.0),
      _ParameterItem('绿暗部曲线', activeParams.greenShadowCurve, -1.0, 1.0),
      _ParameterItem('绿中间调曲线', activeParams.greenMidCurve, -1.0, 1.0),
      _ParameterItem('绿高光曲线', activeParams.greenHighlightCurve, -1.0, 1.0),
      _ParameterItem('蓝暗部曲线', activeParams.blueShadowCurve, -1.0, 1.0),
      _ParameterItem('蓝中间调曲线', activeParams.blueMidCurve, -1.0, 1.0),
      _ParameterItem('蓝高光曲线', activeParams.blueHighlightCurve, -1.0, 1.0),
    ];

    return SafeArea(
      top: false,
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.74,
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          itemCount: items.length + 1,
          separatorBuilder: (_, index) => index == 0
              ? const SizedBox(height: 10)
              : const Divider(height: 18),
          itemBuilder: (context, index) {
            if (index == 0) {
              return const Text(
                '调色参数',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              );
            }
            return _ParameterRow(item: items[index - 1]);
          },
        ),
      ),
    );
  }
}

class _ParameterItem {
  const _ParameterItem(this.label, this.value, this.min, this.max);

  final String label;
  final double value;
  final double min;
  final double max;
}

class _ParameterRow extends StatelessWidget {
  const _ParameterRow({required this.item});

  final _ParameterItem item;

  @override
  Widget build(BuildContext context) {
    final activeT = ((item.value - item.min) / (item.max - item.min))
        .clamp(0.0, 1.0)
        .toDouble();
    final activeText = item.value.toStringAsFixed(3);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                item.label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
            ),
            Text(
              activeText,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: activeT,
            minHeight: 7,
            backgroundColor: AppColors.surfaceMuted,
            color: AppColors.accent,
          ),
        ),
      ],
    );
  }
}
