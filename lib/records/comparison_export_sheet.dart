import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../data/pilgrimage_repository.dart';
import '../plan/pilgrimage_models.dart';
import '../widgets/image_viewer_screen.dart';
import 'comparison_export_config.dart';
import 'comparison_export_config_editor.dart';
import 'comparison_export_config_storage_stub.dart'
    if (dart.library.io) 'comparison_export_config_storage_io.dart';
import 'comparison_exporter_stub.dart'
    if (dart.library.io) 'comparison_exporter_io.dart'
    if (dart.library.js_interop) 'comparison_exporter_web.dart';

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
                child: ComparisonExportConfigEditor(
                  config: _config,
                  pilgrimNameController: _pilgrimNameController,
                  onChanged: _updateConfig,
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
