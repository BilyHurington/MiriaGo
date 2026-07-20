import 'package:flutter/material.dart';

import '../app_theme.dart';
import 'comparison_export_config.dart';

class ComparisonExportConfigEditor extends StatelessWidget {
  const ComparisonExportConfigEditor({
    required this.config,
    required this.pilgrimNameController,
    required this.onChanged,
    super.key,
  });

  final ComparisonExportConfig config;
  final TextEditingController pilgrimNameController;
  final ValueChanged<ComparisonExportConfig> onChanged;

  static List<Color> get borderColorOptions => <Color>[
    Colors.white,
    Colors.black,
    AppColors.accent,
  ];

  static const borderColorLabels = <String>['白色', '黑色', '主题色'];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CurrentConfigSummary(config: config),
        const SizedBox(height: 18),
        const _SectionDivider(),
        const SizedBox(height: 18),
        const _SectionLabel('外观'),
        const SizedBox(height: 12),
        ComparisonAppearanceSection(
          config: config,
          borderColorOptions: borderColorOptions,
          borderColorLabels: borderColorLabels,
          onChanged: onChanged,
        ),
        const SizedBox(height: 20),
        const _SectionDivider(),
        const SizedBox(height: 18),
        ComparisonMetadataSection(
          config: config,
          pilgrimNameController: pilgrimNameController,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

String comparisonExportConfigSummary(ComparisonExportConfig config) {
  final labels = <String>[
    '宽度 ${config.outputWidth.label}',
    config.borderWidthPercent == 0
        ? '无边框'
        : '边框 ${config.borderWidthPercent.toStringAsFixed(1)}%',
    config.showLabels ? '显示标签' : '不显示标签',
  ];
  if (config.showPilgrimName && config.pilgrimName.trim().isNotEmpty) {
    labels.add('巡礼者 ${config.pilgrimName.trim()}');
  }
  return labels.join(' / ');
}

class ComparisonAppearanceSection extends StatelessWidget {
  const ComparisonAppearanceSection({
    required this.config,
    required this.borderColorOptions,
    required this.borderColorLabels,
    required this.onChanged,
    super.key,
  });

  final ComparisonExportConfig config;
  final List<Color> borderColorOptions;
  final List<String> borderColorLabels;
  final ValueChanged<ComparisonExportConfig> onChanged;

  @override
  Widget build(BuildContext context) {
    final automaticOutput = config.outputWidth == ComparisonOutputWidth.auto;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const _FieldLabel('边框宽度'),
            const Spacer(),
            _ValueCapsule(
              label: config.borderWidthPercent == 0
                  ? '无'
                  : '${config.borderWidthPercent.toStringAsFixed(1)}%',
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(
              enabledThumbRadius: 7,
              pressedElevation: 3,
            ),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            valueIndicatorShape: const PaddleSliderValueIndicatorShape(),
            showValueIndicator: ShowValueIndicator.onlyForDiscrete,
          ),
          child: Slider(
            value: config.borderWidthPercent,
            min: 0,
            max: 3.0,
            divisions: 30,
            label: config.borderWidthPercent == 0
                ? '无'
                : '${config.borderWidthPercent.toStringAsFixed(1)}%',
            onChanged: (v) => onChanged(config.copyWith(borderWidthPercent: v)),
          ),
        ),
        const SizedBox(height: 8),
        const _SectionDivider(),
        const SizedBox(height: 16),
        const _FieldLabel('边框颜色'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            for (var i = 0; i < borderColorOptions.length; i += 1)
              _ColorOption(
                color: borderColorOptions[i],
                label: borderColorLabels[i],
                selected: config.borderColor == borderColorOptions[i],
                onTap: () => onChanged(
                  config.copyWith(borderColor: borderColorOptions[i]),
                ),
              ),
          ],
        ),
        const SizedBox(height: 18),
        const _SectionDivider(),
        const SizedBox(height: 16),
        _ToggleSetting(
          title: '自动输出宽度',
          subtitle: '根据图片尺寸自动确定输出宽度',
          value: automaticOutput,
          switchKey: const ValueKey('comparison-output-auto'),
          onChanged: (useAutomatic) {
            onChanged(
              config.copyWith(
                outputWidth: useAutomatic
                    ? ComparisonOutputWidth.auto
                    : ComparisonOutputWidth.w1920,
              ),
            );
          },
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          child: automaticOutput
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: _OutputWidthSelector(
                    selectedWidth: config.outputWidth,
                    onSelected: (width) =>
                        onChanged(config.copyWith(outputWidth: width)),
                  ),
                ),
        ),
        const SizedBox(height: 18),
        const _SectionDivider(),
        const SizedBox(height: 8),
        _ToggleSetting(
          title: '显示标签',
          subtitle: '在参考图上显示“参考”字样，在你拍的巡礼图上显示“巡礼”字样',
          value: config.showLabels,
          onChanged: (value) => onChanged(config.copyWith(showLabels: value)),
        ),
      ],
    );
  }
}

class _CurrentConfigSummary extends StatelessWidget {
  const _CurrentConfigSummary({required this.config});

  final ComparisonExportConfig config;

  @override
  Widget build(BuildContext context) {
    final borderLabel = config.borderWidthPercent == 0
        ? '无边框'
        : '${config.borderWidthPercent.toStringAsFixed(1)}% 边框';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('当前配置'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _SummaryChip(
              label: config.outputWidth == ComparisonOutputWidth.auto
                  ? '自动宽度'
                  : config.outputWidth.label,
            ),
            _SummaryChip(label: borderLabel),
            _SummaryChip(label: config.showLabels ? '显示标签' : '隐藏标签'),
          ],
        ),
      ],
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _ValueCapsule extends StatelessWidget {
  const _ValueCapsule({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 48, minHeight: 32),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _OutputWidthSelector extends StatelessWidget {
  const _OutputWidthSelector({
    required this.selectedWidth,
    required this.onSelected,
  });

  final ComparisonOutputWidth selectedWidth;
  final ValueChanged<ComparisonOutputWidth> onSelected;

  static const _fixedWidths = [
    ComparisonOutputWidth.w1080,
    ComparisonOutputWidth.w1920,
    ComparisonOutputWidth.w2560,
    ComparisonOutputWidth.w3840,
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 40,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < _fixedWidths.length; index++) ...[
            Expanded(
              child: _OutputWidthOption(
                key: ValueKey('comparison-output-${_fixedWidths[index].name}'),
                label: _fixedWidths[index].label,
                selected: selectedWidth == _fixedWidths[index],
                onTap: () => onSelected(_fixedWidths[index]),
              ),
            ),
            if (index < _fixedWidths.length - 1)
              const VerticalDivider(
                width: 1,
                thickness: 1,
                color: AppColors.surfaceMuted,
              ),
          ],
        ],
      ),
    );
  }
}

class _OutputWidthOption extends StatelessWidget {
  const _OutputWidthOption({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                color: selected
                    ? AppColors.accent.withValues(alpha: 0.08)
                    : Colors.transparent,
                alignment: Alignment.center,
                child: Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    color: selected
                        ? AppColors.accentDark
                        : AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    letterSpacing: 0,
                  ),
                ),
              ),
              if (selected)
                Positioned(
                  left: 8,
                  right: 8,
                  bottom: 0,
                  child: Container(
                    height: 3,
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(3),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToggleSetting extends StatelessWidget {
  const _ToggleSetting({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.switchKey,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Key? switchKey;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Switch(key: switchKey, value: value, onChanged: onChanged),
      ],
    );
  }
}

class ComparisonMetadataSection extends StatelessWidget {
  const ComparisonMetadataSection({
    required this.config,
    required this.pilgrimNameController,
    required this.onChanged,
    super.key,
  });

  final ComparisonExportConfig config;
  final TextEditingController pilgrimNameController;
  final ValueChanged<ComparisonExportConfig> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('元数据'),
        const SizedBox(height: 12),
        _ToggleSetting(
          title: '显示巡礼者名字',
          subtitle: '在图片上显示巡礼者名字',
          value: config.showPilgrimName,
          switchKey: const ValueKey('comparison-show-pilgrim-name'),
          onChanged: (value) =>
              onChanged(config.copyWith(showPilgrimName: value)),
        ),
        const SizedBox(height: 10),
        AnimatedOpacity(
          duration: const Duration(milliseconds: 160),
          opacity: config.showPilgrimName ? 1 : 0.45,
          child: TextFormField(
            key: const ValueKey('comparison-pilgrim-name'),
            controller: pilgrimNameController,
            enabled: config.showPilgrimName,
            decoration: _comparisonTextFieldDecoration(
              hintText: '请输入巡礼者名字',
              enabled: config.showPilgrimName,
            ),
            textInputAction: TextInputAction.done,
            onChanged: (value) =>
                onChanged(config.copyWith(pilgrimName: value)),
          ),
        ),
        const SizedBox(height: 20),
        const _SectionDivider(),
        const SizedBox(height: 10),
        _ToggleSetting(
          title: '显示调色参数',
          subtitle: '在图片底部显示调色相关参数',
          value: config.showColorGradingParams,
          onChanged: (value) =>
              onChanged(config.copyWith(showColorGradingParams: value)),
        ),
        const SizedBox(height: 20),
        const _SectionDivider(),
        const SizedBox(height: 18),
        const _SectionLabel('显示内容'),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            const spacing = 8.0;
            final itemWidth = (constraints.maxWidth - spacing * 2) / 3;
            return Wrap(
              spacing: spacing,
              runSpacing: 8,
              children: [
                for (final field in _metadataFieldOrder)
                  SizedBox(
                    width: itemWidth,
                    child: _MetadataFilterChip(
                      field: field,
                      selected: config.metadataFields.contains(field),
                      onSelected: () {
                        final updated = Set<ComparisonMetadataField>.from(
                          config.metadataFields,
                        );
                        if (updated.contains(field)) {
                          updated.remove(field);
                        } else {
                          updated.add(field);
                        }
                        onChanged(config.copyWith(metadataFields: updated));
                      },
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

const _metadataFieldOrder = [
  ComparisonMetadataField.capturedAt,
  ComparisonMetadataField.pointName,
  ComparisonMetadataField.workTitle,
  ComparisonMetadataField.episodeLabel,
  ComparisonMetadataField.coordinates,
  ComparisonMetadataField.anitabiId,
];

class _MetadataFilterChip extends StatelessWidget {
  const _MetadataFilterChip({
    required this.field,
    required this.selected,
    required this.onSelected,
  });

  final ComparisonMetadataField field;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final foreground = selected
        ? AppColors.accentDark
        : AppColors.textSecondary;
    return FilterChip(
      key: ValueKey('comparison-metadata-${field.name}'),
      avatar: Icon(_metadataFieldIcon(field), size: 16, color: foreground),
      label: SizedBox(
        width: double.infinity,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            field.label,
            style: TextStyle(
              color: foreground,
              fontSize: 12,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              letterSpacing: 0,
            ),
          ),
        ),
      ),
      selected: selected,
      showCheckmark: false,
      selectedColor: AppColors.accent.withValues(alpha: 0.08),
      backgroundColor: AppColors.surface,
      side: BorderSide(color: selected ? AppColors.accent : AppColors.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      onSelected: (_) => onSelected(),
    );
  }
}

IconData _metadataFieldIcon(ComparisonMetadataField field) {
  return switch (field) {
    ComparisonMetadataField.capturedAt => Icons.access_time_rounded,
    ComparisonMetadataField.pointName => Icons.place_rounded,
    ComparisonMetadataField.workTitle => Icons.article_rounded,
    ComparisonMetadataField.episodeLabel => Icons.landscape_outlined,
    ComparisonMetadataField.coordinates => Icons.my_location_rounded,
    ComparisonMetadataField.anitabiId => Icons.badge_outlined,
  };
}

InputDecoration _comparisonTextFieldDecoration({
  required String hintText,
  required bool enabled,
}) {
  return InputDecoration(
    hintText: hintText,
    hintStyle: TextStyle(
      color: AppColors.textSecondary.withValues(alpha: 0.42),
      fontSize: 14,
      letterSpacing: 0,
    ),
    filled: true,
    fillColor: enabled ? AppColors.surface : AppColors.surfaceMuted,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    disabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: AppColors.border.withValues(alpha: 0.65)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: AppColors.accent, width: 1.4),
    ),
  );
}

class _ColorOption extends StatelessWidget {
  const _ColorOption({
    required this.color,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: AnimatedScale(
        scale: selected ? 1.03 : 1,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutBack,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          constraints: const BoxConstraints(minWidth: 76, minHeight: 40),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.accent.withValues(alpha: 0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? AppColors.accent : AppColors.border,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: color == Colors.white
                        ? AppColors.border
                        : Colors.transparent,
                  ),
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 140),
                  transitionBuilder: (child, animation) => ScaleTransition(
                    scale: animation,
                    child: FadeTransition(opacity: animation, child: child),
                  ),
                  child: selected
                      ? Icon(
                          Icons.check,
                          key: const ValueKey('selected'),
                          size: 14,
                          color: color.computeLuminance() > 0.55
                              ? AppColors.textPrimary
                              : Colors.white,
                        )
                      : const SizedBox(
                          key: ValueKey('unselected'),
                          width: 14,
                          height: 14,
                        ),
                ),
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  color: selected
                      ? AppColors.accentDark
                      : AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w900,
        letterSpacing: 0,
      ),
    );
  }
}

class _SectionDivider extends StatelessWidget {
  const _SectionDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      thickness: 1,
      color: AppColors.surfaceMuted,
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 14,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
    );
  }
}
