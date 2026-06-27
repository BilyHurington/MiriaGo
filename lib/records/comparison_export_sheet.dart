import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../data/pilgrimage_repository.dart';
import '../plan/pilgrimage_models.dart';
import '../widgets/image_viewer_screen.dart';
import 'comparison_export_config.dart';
import 'comparison_export_config_storage_stub.dart'
    if (dart.library.io) 'comparison_export_config_storage_io.dart';
import 'comparison_exporter_stub.dart'
    if (dart.library.io) 'comparison_exporter_io.dart';

class ComparisonExportSheet extends StatefulWidget {
  const ComparisonExportSheet({
    required this.referenceImagePath,
    required this.referenceImageUrl,
    required this.capturedPath,
    required this.metadata,
    required this.colorGradingSummary,
    required this.repository,
    super.key,
  });

  final String? referenceImagePath;
  final String? referenceImageUrl;
  final String capturedPath;
  final Map<ComparisonMetadataField, String> metadata;
  final String? colorGradingSummary;
  final PilgrimageRepository repository;

  static Future<void> show(
    BuildContext context, {
    required String? referenceImagePath,
    required String? referenceImageUrl,
    required String capturedPath,
    required Map<ComparisonMetadataField, String> metadata,
    required String? colorGradingSummary,
    required PilgrimageRepository repository,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (context) => ComparisonExportSheet(
        referenceImagePath: referenceImagePath,
        referenceImageUrl: referenceImageUrl,
        capturedPath: capturedPath,
        metadata: metadata,
        colorGradingSummary: colorGradingSummary,
        repository: repository,
      ),
    );
  }

  @override
  State<ComparisonExportSheet> createState() => _ComparisonExportSheetState();
}

class _ComparisonExportSheetState extends State<ComparisonExportSheet> {
  var _config = ComparisonExportConfig.lastUsed;
  var _settings = const AppSettings();
  late final TextEditingController _pilgrimNameController;
  var _exporting = false;

  static List<Color> get _borderColorOptions => <Color>[
    Colors.white,
    Colors.black,
    AppColors.accent,
  ];

  static const _borderColorLabels = <String>['白色', '黑色', '主题色'];

  @override
  void initState() {
    super.initState();
    _config = ComparisonExportConfig.lastUsed.withSettings(_settings);
    _pilgrimNameController = TextEditingController(text: _config.pilgrimName);
    _loadSavedConfig();
  }

  @override
  void dispose() {
    _pilgrimNameController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedConfig() async {
    final settings = await widget.repository.loadAppSettings();
    final saved = await loadComparisonExportConfig();
    if (!mounted) {
      return;
    }

    final migratedConfig = (saved ?? _config).copyWith(
      showPilgrimName: settings.comparisonShowPilgrimName,
      pilgrimName: settings.comparisonPilgrimName.isEmpty
          ? saved?.pilgrimName
          : settings.comparisonPilgrimName,
    );
    final migratedSettings = migratedConfig.applyToSettings(settings);
    if (migratedSettings.comparisonPilgrimName !=
            settings.comparisonPilgrimName ||
        migratedSettings.comparisonShowPilgrimName !=
            settings.comparisonShowPilgrimName) {
      await widget.repository.saveAppSettings(migratedSettings);
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _settings = migratedSettings;
      _config = migratedConfig;
      ComparisonExportConfig.lastUsed = migratedConfig;
      _pilgrimNameController.text = migratedConfig.pilgrimName;
    });
  }

  Future<void> _updateConfig(ComparisonExportConfig config) async {
    setState(() => _config = config);
    ComparisonExportConfig.lastUsed = config;
    final settings = config.applyToSettings(_settings);
    _settings = settings;
    await Future.wait([
      saveComparisonExportConfig(config),
      widget.repository.saveAppSettings(settings),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final sheetHeight = MediaQuery.sizeOf(context).height * 0.84;

    return SafeArea(
      top: false,
      child: SizedBox(
        height: sheetHeight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SheetHeader(exporting: _exporting),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _AppearanceSection(
                      config: _config,
                      borderColorOptions: _borderColorOptions,
                      borderColorLabels: _borderColorLabels,
                      onChanged: _updateConfig,
                    ),
                    const SizedBox(height: 18),
                    _MetadataSection(
                      config: _config,
                      pilgrimNameController: _pilgrimNameController,
                      onChanged: _updateConfig,
                    ),
                  ],
                ),
              ),
            ),
            _SheetFooter(
              bottomInset: bottomInset,
              exporting: _exporting,
              onExport: _doExport,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _doExport() async {
    setState(() => _exporting = true);
    ComparisonExportConfig.lastUsed = _config;
    final settings = _config.applyToSettings(_settings);
    await Future.wait([
      saveComparisonExportConfig(_config),
      widget.repository.saveAppSettings(settings),
    ]);

    final result = await exportComparisonImage(
      referenceImagePath: widget.referenceImagePath,
      referenceImageUrl: widget.referenceImageUrl,
      capturedPath: widget.capturedPath,
      config: _config,
      metadata: widget.metadata,
      colorGradingSummary: widget.colorGradingSummary,
    );

    if (!mounted) return;

    if (result.isSuccess) {
      Navigator.of(context).pop();
      ImageViewerScreen.show(context, filePath: result.path);
    } else {
      setState(() => _exporting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_failureMessage(result))));
    }
  }

  String _failureMessage(ComparisonExportImageResult result) {
    return switch (result.failureReason) {
      ComparisonExportFailureReason.referenceUnavailable => '参考图不可用，无法导出对比图片。',
      ComparisonExportFailureReason.capturedPhotoUnavailable =>
        '巡礼图不可用，无法导出对比图片。',
      ComparisonExportFailureReason.renderFailed || null => '导出失败，请稍后重试。',
    };
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.exporting});

  final bool exporting;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 12, 10),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              '导出对比图',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
          ),
          IconButton(
            tooltip: '关闭',
            onPressed: exporting ? null : () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }
}

class _AppearanceSection extends StatelessWidget {
  const _AppearanceSection({
    required this.config,
    required this.borderColorOptions,
    required this.borderColorLabels,
    required this.onChanged,
  });

  final ComparisonExportConfig config;
  final List<Color> borderColorOptions;
  final List<String> borderColorLabels;
  final ValueChanged<ComparisonExportConfig> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('外观'),
        const SizedBox(height: 8),
        Row(
          children: [
            const _FieldLabel('边框宽度'),
            const Spacer(),
            Text(
              config.borderWidthPercent == 0
                  ? '无'
                  : '${config.borderWidthPercent.toStringAsFixed(1)}%',
              style: TextStyle(
                color: AppColors.accent,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        Slider(
          value: config.borderWidthPercent,
          min: 0,
          max: 3.0,
          divisions: 30,
          onChanged: (v) => onChanged(config.copyWith(borderWidthPercent: v)),
        ),
        const SizedBox(height: 12),
        const _FieldLabel('边框颜色'),
        const SizedBox(height: 6),
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
        const SizedBox(height: 16),
        const _FieldLabel('输出宽度'),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ComparisonOutputWidth.values
              .map((ow) {
                return _OptionChip(
                  label: ow.label,
                  selected: config.outputWidth == ow,
                  onSelected: () => onChanged(config.copyWith(outputWidth: ow)),
                );
              })
              .toList(growable: false),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            const Text(
              '显示标签',
              style: TextStyle(fontSize: 14, letterSpacing: 0),
            ),
            const Spacer(),
            Switch(
              value: config.showLabels,
              onChanged: (v) => onChanged(config.copyWith(showLabels: v)),
            ),
          ],
        ),
      ],
    );
  }
}

class _MetadataSection extends StatelessWidget {
  const _MetadataSection({
    required this.config,
    required this.pilgrimNameController,
    required this.onChanged,
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
        const SizedBox(height: 8),
        TextFormField(
          controller: pilgrimNameController,
          decoration: const InputDecoration(
            labelText: '巡礼者名字',
            prefixIcon: Icon(Icons.person_outline),
          ),
          textInputAction: TextInputAction.done,
          onChanged: (value) => onChanged(config.copyWith(pilgrimName: value)),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Expanded(
              child: Text(
                '在右侧显示巡礼者',
                style: TextStyle(fontSize: 14, letterSpacing: 0),
              ),
            ),
            Switch(
              value: config.showPilgrimName,
              onChanged: (v) => onChanged(config.copyWith(showPilgrimName: v)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Expanded(
              child: Text(
                '底部显示调色参数',
                style: TextStyle(fontSize: 14, letterSpacing: 0),
              ),
            ),
            Switch(
              value: config.showColorGradingParams,
              onChanged: (v) =>
                  onChanged(config.copyWith(showColorGradingParams: v)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final itemWidth = constraints.maxWidth >= 360
                ? (constraints.maxWidth - 8) / 2
                : constraints.maxWidth;

            return Wrap(
              spacing: 8,
              runSpacing: 2,
              children: ComparisonMetadataField.values
                  .map((field) {
                    final selected = config.metadataFields.contains(field);
                    return SizedBox(
                      width: itemWidth,
                      child: Row(
                        children: [
                          Checkbox(
                            value: selected,
                            onChanged: (_) {
                              final updated = Set<ComparisonMetadataField>.from(
                                config.metadataFields,
                              );
                              if (selected) {
                                updated.remove(field);
                              } else {
                                updated.add(field);
                              }
                              onChanged(
                                config.copyWith(metadataFields: updated),
                              );
                            },
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                          ),
                          Expanded(
                            child: Text(
                              field.label,
                              style: const TextStyle(
                                fontSize: 14,
                                letterSpacing: 0,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  })
                  .toList(growable: false),
            );
          },
        ),
      ],
    );
  }
}

class _SheetFooter extends StatelessWidget {
  const _SheetFooter({
    required this.bottomInset,
    required this.exporting,
    required this.onExport,
  });

  final double bottomInset;
  final bool exporting;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + bottomInset),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: exporting ? null : () => Navigator.of(context).pop(),
                child: const Text('取消'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed: exporting ? null : onExport,
                icon: exporting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.download, size: 18),
                label: Text(exporting ? '导出中...' : '导出'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(46),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionChip extends StatelessWidget {
  const _OptionChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.white : AppColors.textPrimary,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
      ),
      selected: selected,
      selectedColor: AppColors.accent,
      backgroundColor: AppColors.surfaceMuted,
      side: BorderSide(color: selected ? AppColors.accent : AppColors.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      onSelected: (_) => onSelected(),
    );
  }
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
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected
                    ? (color == AppColors.accent
                          ? AppColors.textPrimary
                          : AppColors.accent)
                    : color == Colors.white
                    ? AppColors.border
                    : Colors.transparent,
                width: selected ? 3 : 1,
              ),
              boxShadow: selected
                  ? const [
                      BoxShadow(
                        color: Color(0x33000000),
                        blurRadius: 4,
                        offset: Offset(0, 1),
                      ),
                    ]
                  : null,
            ),
            child: selected
                ? Icon(
                    Icons.check,
                    size: 18,
                    color: color.computeLuminance() > 0.55
                        ? AppColors.textPrimary
                        : Colors.white,
                  )
                : null,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              letterSpacing: 0,
            ),
          ),
        ],
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
        fontSize: 16,
        fontWeight: FontWeight.w800,
        letterSpacing: 0,
      ),
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
        color: AppColors.textSecondary,
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
    );
  }
}
