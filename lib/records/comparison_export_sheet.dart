import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../app_theme.dart';
import '../data/pilgrimage_repository.dart';
import '../data/anitabi_image_source_scope.dart';
import '../plan/pilgrimage_models.dart';
import '../widgets/image_viewer_screen.dart';
import '../widgets/responsive_button.dart';
import '../widgets/snackbar_helper.dart';
import 'comparison_export_config.dart';
import 'comparison_export_config_editor.dart';
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
    this.exporter = exportComparisonImage,
    super.key,
  });

  final String? referenceImagePath;
  final String? referenceImageUrl;
  final String capturedPath;
  final Map<ComparisonMetadataField, String> metadata;
  final String? colorGradingSummary;
  final PilgrimageRepository repository;
  final ComparisonImageExporter exporter;

  static Future<void> show(
    BuildContext context, {
    required String? referenceImagePath,
    required String? referenceImageUrl,
    required String capturedPath,
    required Map<ComparisonMetadataField, String> metadata,
    required String? colorGradingSummary,
    required PilgrimageRepository repository,
    ComparisonImageExporter exporter = exportComparisonImage,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: false,
      enableDrag: false,
      isDismissible: true,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (context) => ComparisonExportSheet(
        referenceImagePath: referenceImagePath,
        referenceImageUrl: referenceImageUrl,
        capturedPath: capturedPath,
        metadata: metadata,
        colorGradingSummary: colorGradingSummary,
        repository: repository,
        exporter: exporter,
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
  var _loading = true;
  var _settingsLoaded = false;
  var _isExiting = false;
  Future<void> _settingsWrite = Future.value();

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
    try {
      final settings = await widget.repository.loadAppSettings();
      if (!mounted) return;
      final config = ComparisonExportConfig.fromSettings(settings);
      setState(() {
        _settings = settings;
        _config = config;
        _settingsLoaded = true;
        ComparisonExportConfig.lastUsed = config;
        _pilgrimNameController.text = config.pilgrimName;
      });
    } catch (_) {
      _showFailure('读取导出设置失败，请重试。');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _persistSettings(AppSettings settings) {
    final write = _settingsWrite.then(
      (_) => widget.repository.saveAppSettings(settings),
    );
    _settingsWrite = write.catchError((Object _) {});
    return write;
  }

  void _showFailure(String message) {
    if (!mounted || _isExiting) return;
    ScaffoldMessenger.of(
      context,
    ).showStatusSnack(kind: AppStatusBannerKind.error, title: message);
  }

  Future<void> _updateConfig(ComparisonExportConfig config) async {
    if (_exporting || !_settingsLoaded || _isExiting) return;
    setState(() => _config = config);
    ComparisonExportConfig.lastUsed = config;
    final settings = config.applyToSettings(_settings);
    _settings = settings;
    try {
      await _persistSettings(settings);
    } catch (_) {
      _showFailure('导出设置保存失败，导出时将重试。');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final sheetHeight = MediaQuery.sizeOf(context).height * 0.84;

    return PopScope(
      canPop: !_exporting,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: sheetHeight,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SheetHeader(exporting: _exporting || _isExiting),
              const Divider(height: 1),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
                  child: AbsorbPointer(
                    absorbing: _exporting || !_settingsLoaded || _isExiting,
                    child: ComparisonExportConfigEditor(
                      config: _config,
                      pilgrimNameController: _pilgrimNameController,
                      onChanged: _updateConfig,
                    ),
                  ),
                ),
              ),
              _SheetFooter(
                bottomInset: bottomInset,
                exporting: _exporting || _loading || _isExiting,
                onExport: _doExport,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _doExport() async {
    if (!mounted || _exporting || _loading || _isExiting) return;
    setState(() => _exporting = true);
    try {
      if (!_settingsLoaded) await _loadSavedConfig();
      if (!mounted || !_settingsLoaded) return;
      final config = _config;
      ComparisonExportConfig.lastUsed = config;
      final settings = config.applyToSettings(_settings);
      await _persistSettings(settings);
      if (!mounted) return;
      final result = await widget.exporter(
        referenceImagePath: widget.referenceImagePath,
        referenceImageUrl: widget.referenceImageUrl,
        capturedPath: widget.capturedPath,
        config: config,
        metadata: widget.metadata,
        colorGradingSummary: widget.colorGradingSummary,
      );

      if (!mounted) return;
      if (result.disposition == ComparisonExportDisposition.canceled) return;
      if (!result.isSuccess) {
        _showFailure(_failureMessage(result));
        return;
      }
      final navigator = Navigator.of(context);
      final imageSource = AnitabiImageSourceScope.of(context);
      if (result.disposition == ComparisonExportDisposition.downloaded) {
        ScaffoldMessenger.of(context).showStatusSnack(
          kind: AppStatusBannerKind.success,
          title: '对比图已交给浏览器下载',
        );
      }
      setState(() {
        _exporting = false;
        _isExiting = true;
      });
      navigator.pop();
      if (result.disposition == ComparisonExportDisposition.localFile &&
          navigator.mounted) {
        // The sheet context belongs to the route just popped. Use the retained
        // navigator and captured image source, never that outgoing context.
        await navigator.push<void>(
          MaterialPageRoute(
            builder: (_) => ImageViewerScreen(
              filePath: result.path,
              imageSource: imageSource,
            ),
          ),
        );
      }
    } catch (_) {
      _showFailure('导出失败，设置或图片未能保存，请重试。');
    } finally {
      if (mounted && !_isExiting) setState(() => _exporting = false);
    }
  }

  String _failureMessage(ComparisonExportImageResult result) {
    return result.message ??
        switch (result.failureReason) {
          ComparisonExportFailureReason.referenceUnavailable =>
            '参考图不可用，无法导出对比图片。',
          ComparisonExportFailureReason.capturedPhotoUnavailable =>
            '巡礼图不可用，无法导出对比图片。',
          ComparisonExportFailureReason.budgetExceeded => '图片超过处理预算，原件未更改。',
          ComparisonExportFailureReason.unsupportedFormat => '当前平台不支持处理此图片格式。',
          ComparisonExportFailureReason.invalidData => '图片数据无法解码。',
          ComparisonExportFailureReason.renderFailed || null => '导出失败，请稍后重试。',
        };
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.exporting});

  final bool exporting;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: exporting ? null : () => Navigator.of(context).pop(),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
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
              icon: const Icon(LucideIcons.x),
            ),
          ],
        ),
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
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + bottomInset),
        child: ResponsiveTwoButtonRow(
          spacing: 12,
          stackBelowWidth: 250,
          first: OutlinedButton(
            onPressed: exporting ? null : () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          second: FilledButton(
            onPressed: exporting ? null : onExport,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(46),
            ),
            child: exporting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const ResponsiveButtonContent(
                    icon: LucideIcons.download,
                    label: '导出对比图',
                    shortLabel: '导出',
                    semanticLabel: '导出对比图',
                  ),
          ),
        ),
      ),
    );
  }
}
