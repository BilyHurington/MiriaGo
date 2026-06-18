import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart' as file_selector;

import '../app_theme.dart';
import '../data/pilgrimage_repository.dart';
import '../platform/platform_flags_stub.dart'
    if (dart.library.io) '../platform/platform_flags_io.dart';
import '../plan/pilgrimage_models.dart';
import '../widgets/snackbar_helper.dart';
import 'my_maps_csv_export.dart';
import 'plan_export_delivery.dart';
import 'plan_export_delivery_result.dart';
import 'plan_export_size_estimator.dart';
import 'plan_export_v2.dart';
import 'plan_import_package.dart';
import 'plan_import_preview_screen.dart';
import 'plan_package.dart' show seichiPlanFileExtension, seichiPlanMimeType;

class ImportExportScreen extends StatefulWidget {
  const ImportExportScreen({
    required this.plan,
    required this.repository,
    super.key,
  });

  final PilgrimagePlan plan;
  final PilgrimageRepository repository;

  @override
  State<ImportExportScreen> createState() => _ImportExportScreenState();
}

class _ImportExportScreenState extends State<ImportExportScreen> {
  var _mode = PlanExportV2Mode.planOnly;
  var _includeFullReferenceCache = false;
  var _exporting = false;
  var _importing = false;
  var _exportGeneration = 0;
  var _estimateGeneration = 0;
  PlanExportSizeEstimate? _sizeEstimate;
  var _estimatingSize = false;

  bool get _usesExternalIosImport => isIosPlatform;

  @override
  void initState() {
    super.initState();
    _refreshSizeEstimate();
  }

  @override
  void dispose() {
    _exportGeneration++;
    _estimateGeneration++;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_exporting,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          return;
        }
        _handleBack();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: '返回',
            onPressed: _handleBack,
            icon: const Icon(Icons.arrow_back),
          ),
          title: const Text('导入导出'),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            _PlanExportSummary(plan: widget.plan),
            const SizedBox(height: 16),
            _SectionTitle(
              icon: Icons.import_export_outlined,
              title: '导入',
              subtitle: _usesExternalIosImport
                  ? '从文件、聊天、浏览器或网盘等位置用 MiriaGo 打开 .sjhplan。'
                  : '选择 .sjhplan 文件，先预览内容再导入。',
            ),
            const SizedBox(height: 10),
            _ActionTile(
              icon: _importing
                  ? Icons.hourglass_empty_outlined
                  : _usesExternalIosImport
                  ? Icons.open_in_new_outlined
                  : Icons.import_export_outlined,
              title: _importing
                  ? '读取中...'
                  : _usesExternalIosImport
                  ? '从其他 App 打开 .sjhplan'
                  : '导入 MiriaGo 文件',
              subtitle: _usesExternalIosImport
                  ? '在文件、聊天、浏览器下载页或网盘中选择 .sjhplan，然后分享或用 MiriaGo 打开。'
                  : '支持 v2 数据包和旧版 v1 JSON 计划包。',
              enabled: !_exporting && !_importing,
              onTap: _usesExternalIosImport
                  ? _showExternalIosImportHelp
                  : _importFromFile,
            ),
            const SizedBox(height: 20),
            _SectionTitle(
              icon: Icons.inventory_2_outlined,
              title: 'MiriaGo 数据包',
              subtitle: '新版 .sjhplan，内部为 zip，包含 manifest.json。',
            ),
            const SizedBox(height: 10),
            _BackupOptions(
              mode: _mode,
              includeFullReferenceCache: _includeFullReferenceCache,
              sizeEstimate: _sizeEstimate,
              estimatingSize: _estimatingSize,
              exporting: _exporting || _importing,
              onModeChanged: (mode) {
                setState(() => _mode = mode);
                _refreshSizeEstimate();
              },
              onFullReferenceChanged: (value) {
                setState(() => _includeFullReferenceCache = value);
                _refreshSizeEstimate();
              },
              onExport: _exportV2,
            ),
            const SizedBox(height: 20),
            _SectionTitle(
              icon: Icons.map_outlined,
              title: 'Google My Maps',
              subtitle: '导出点位 CSV。图片写成链接，可按 Type 列设置样式。',
            ),
            const SizedBox(height: 10),
            _ActionTile(
              icon: _exporting
                  ? Icons.hourglass_empty_outlined
                  : Icons.table_chart_outlined,
              title: '导出 My Maps CSV',
              subtitle: '前 6 列贴近示例格式，作品、集数、来源等拆成独立列。',
              enabled: !_exporting && !_importing,
              onTap: _exportMyMapsCsv,
            ),
          ],
        ),
      ),
    );
  }

  void _handleBack() {
    final messenger = ScaffoldMessenger.of(context);
    if (_exporting) {
      _exportGeneration++;
      setState(() => _exporting = false);
      messenger.showReplacingSnackBar(const SnackBar(content: Text('已取消导出')));
    }
    Navigator.of(context).pop();
  }

  Future<void> _importFromFile() async {
    if (_usesExternalIosImport) {
      _showExternalIosImportHelp();
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _importing = true);
    try {
      final file = await file_selector.openFile(
        acceptedTypeGroups: const [
          file_selector.XTypeGroup(
            label: 'MiriaGo plan package',
            extensions: [seichiPlanFileExtension],
            mimeTypes: [
              miriagoExportPackageMimeType,
              'application/zip',
              'application/x-zip-compressed',
              seichiPlanMimeType,
              'application/octet-stream',
              'application/json',
              'text/json',
              'text/plain',
            ],
          ),
        ],
      );
      if (file == null) {
        return;
      }
      final importPackage = readPlanImportPackageFromBytes(
        await file.readAsBytes(),
        sourceName: file.name,
      );
      if (!mounted) {
        return;
      }
      final imported = await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (_) => PlanImportPreviewScreen(
            importPackage: importPackage,
            repository: widget.repository,
          ),
        ),
      );
      if (imported == true && mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      messenger.showReplacingSnackBar(
        const SnackBar(content: Text('导入文件读取失败')),
      );
    } finally {
      if (mounted) {
        setState(() => _importing = false);
      }
    }
  }

  Future<void> _showExternalIosImportHelp() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('从其他 App 打开 .sjhplan'),
        content: const Text(
          '请在文件、聊天、浏览器下载页、网盘或其他保存位置找到 .sjhplan 文件，然后点开文件，或使用分享/更多菜单选择 MiriaGo。\n\n'
          'MiriaGo 收到文件后会自动进入导入预览页面。若列表里没有 MiriaGo，可以先把文件保存到“文件”App，再长按文件选择分享或打开方式。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportV2() async {
    await _runExport((generation) async {
      final exportedAt = DateTime.now();
      final options = PlanExportV2Options(
        mode: _mode,
        includeFullReferenceCache: _includeFullReferenceCache,
      );
      final fileName = suggestPlanExportV2FileName(
        plan: widget.plan,
        exportedAt: exportedAt,
      );
      final destination = await preparePlanExportDestination(
        fileName: fileName,
        mimeType: miriagoExportPackageMimeType,
        extension: seichiPlanFileExtension,
      );
      if (!_isCurrentExport(generation)) {
        throw const _ExportAbortedException();
      }
      final records = await widget.repository.loadVisitRecords(widget.plan.id);
      if (!_isCurrentExport(generation)) {
        throw const _ExportAbortedException();
      }
      final package = await buildPlanExportV2Package(
        plan: widget.plan,
        visitRecords: records,
        options: options,
        exportedAt: exportedAt,
      );
      if (!_isCurrentExport(generation)) {
        throw const _ExportAbortedException();
      }
      final result = await deliverPlanExport(
        bytes: package.bytes,
        fileName: package.fileName,
        mimeType: miriagoExportPackageMimeType,
        shareSubject: widget.plan.name,
        shareText: 'MiriaGo数据包：${widget.plan.name}',
        extension: seichiPlanFileExtension,
        destination: destination,
      );
      return _PlanExportRunResult(result, package.warnings);
    }, successMessage: '数据包已导出');
  }

  Future<void> _refreshSizeEstimate() async {
    final generation = ++_estimateGeneration;
    setState(() {
      _estimatingSize = true;
    });
    try {
      final records = _mode == PlanExportV2Mode.planWithRecords
          ? await widget.repository.loadVisitRecords(widget.plan.id)
          : const <PilgrimageVisitRecord>[];
      final estimate = await estimatePlanExportV2Size(
        plan: widget.plan,
        visitRecords: records,
        options: PlanExportV2Options(
          mode: _mode,
          includeFullReferenceCache: _includeFullReferenceCache,
        ),
      );
      if (!mounted || generation != _estimateGeneration) {
        return;
      }
      setState(() {
        _sizeEstimate = estimate;
        _estimatingSize = false;
      });
    } catch (_) {
      if (!mounted || generation != _estimateGeneration) {
        return;
      }
      setState(() {
        _sizeEstimate = null;
        _estimatingSize = false;
      });
    }
  }

  Future<void> _exportMyMapsCsv() async {
    await _runExport((generation) async {
      final export = buildMyMapsCsvExport(plan: widget.plan);
      if (!_isCurrentExport(generation)) {
        throw const _ExportAbortedException();
      }
      final destination = await preparePlanExportDestination(
        fileName: export.fileName,
        mimeType: export.mimeType,
        extension: myMapsCsvExtension,
      );
      if (!_isCurrentExport(generation)) {
        throw const _ExportAbortedException();
      }
      final result = await deliverPlanExport(
        bytes: export.bytes,
        fileName: export.fileName,
        mimeType: export.mimeType,
        shareSubject: widget.plan.name,
        shareText: 'MiriaGo My Maps CSV：${widget.plan.name}',
        extension: myMapsCsvExtension,
        destination: destination,
      );
      return _PlanExportRunResult(result);
    }, successMessage: 'My Maps CSV 已导出');
  }

  Future<void> _runExport(
    Future<_PlanExportRunResult> Function(int generation) action, {
    required String successMessage,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final generation = ++_exportGeneration;
    setState(() => _exporting = true);
    messenger.showReplacingSnackBar(const SnackBar(content: Text('正在导出...')));
    try {
      final result = await action(generation);
      if (!_isCurrentExport(generation)) {
        return;
      }
      if (result.delivery.action == PlanExportDeliveryAction.canceled) {
        messenger.showReplacingSnackBar(const SnackBar(content: Text('已取消导出')));
        return;
      }
      messenger.showReplacingSnackBar(
        SnackBar(content: Text(result.successMessage(successMessage))),
      );
    } on PlanExportCanceledException {
      if (!_isCurrentExport(generation)) {
        return;
      }
      messenger.showReplacingSnackBar(const SnackBar(content: Text('已取消导出')));
    } on _ExportAbortedException {
      return;
    } catch (error, stackTrace) {
      debugPrint('Plan export failed: $error');
      debugPrint(stackTrace.toString());
      if (!_isCurrentExport(generation)) {
        return;
      }
      messenger.showReplacingSnackBar(const SnackBar(content: Text('导出失败')));
    } finally {
      if (_isCurrentExport(generation)) {
        setState(() => _exporting = false);
      }
    }
  }

  bool _isCurrentExport(int generation) {
    return mounted && generation == _exportGeneration;
  }
}

class _ExportAbortedException implements Exception {
  const _ExportAbortedException();
}

class _PlanExportRunResult {
  const _PlanExportRunResult(this.delivery, [this.warnings = const <String>[]]);

  final PlanExportDeliveryResult delivery;
  final List<String> warnings;

  String successMessage(String fallback) {
    if (warnings.isEmpty) {
      return fallback;
    }
    return '$fallback，部分资源未能加入';
  }
}

class _PlanExportSummary extends StatelessWidget {
  const _PlanExportSummary({required this.plan});

  final PilgrimagePlan plan;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.archive_outlined, color: AppColors.accentDark),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  plan.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${plan.groups.length} 个片区 / ${plan.points.length} 个点位',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.accentDark, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 2),
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
      ],
    );
  }
}

class _BackupOptions extends StatelessWidget {
  const _BackupOptions({
    required this.mode,
    required this.includeFullReferenceCache,
    required this.sizeEstimate,
    required this.estimatingSize,
    required this.exporting,
    required this.onModeChanged,
    required this.onFullReferenceChanged,
    required this.onExport,
  });

  final PlanExportV2Mode mode;
  final bool includeFullReferenceCache;
  final PlanExportSizeEstimate? sizeEstimate;
  final bool estimatingSize;
  final bool exporting;
  final ValueChanged<PlanExportV2Mode> onModeChanged;
  final ValueChanged<bool> onFullReferenceChanged;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<PlanExportV2Mode>(
            segments: const [
              ButtonSegment(
                value: PlanExportV2Mode.planOnly,
                icon: Icon(Icons.route_outlined),
                label: Text('纯计划'),
              ),
              ButtonSegment(
                value: PlanExportV2Mode.planWithRecords,
                icon: Icon(Icons.collections_bookmark_outlined),
                label: Text('计划+记录'),
              ),
            ],
            selected: {mode},
            onSelectionChanged: exporting
                ? null
                : (values) => onModeChanged(values.first),
          ),
          const SizedBox(height: 10),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              '包含完整参考图缓存',
              style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0),
            ),
            subtitle: const Text('默认仍会包含缩略图和用户自己添加的参考图。'),
            value: includeFullReferenceCache,
            onChanged: exporting ? null : onFullReferenceChanged,
          ),
          const SizedBox(height: 2),
          _ExportSizeEstimateRow(
            estimate: sizeEstimate,
            estimating: estimatingSize,
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: exporting ? null : onExport,
            icon: exporting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.ios_share_outlined, size: 18),
            label: Text(exporting ? '导出中...' : '导出 MiriaGo 数据包'),
          ),
        ],
      ),
    );
  }
}

class _ExportSizeEstimateRow extends StatelessWidget {
  const _ExportSizeEstimateRow({
    required this.estimate,
    required this.estimating,
  });

  final PlanExportSizeEstimate? estimate;
  final bool estimating;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (estimating)
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else
          Icon(
            Icons.inventory_2_outlined,
            size: 18,
            color: AppColors.textSecondary,
          ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            estimating ? '正在估算数据包大小...' : estimate?.label ?? '预计数据包大小：暂时无法估算',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: enabled ? AppColors.surface : AppColors.surfaceMuted,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: enabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: enabled ? AppColors.accentDark : AppColors.textSecondary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: enabled
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 2),
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
              Icon(
                Icons.chevron_right,
                color: enabled ? AppColors.textSecondary : AppColors.border,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
