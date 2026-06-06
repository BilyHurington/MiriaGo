import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart' as file_selector;

import '../app_theme.dart';
import '../data/pilgrimage_repository.dart';
import '../plan/pilgrimage_models.dart';
import '../widgets/snackbar_helper.dart';
import 'plan_export_delivery.dart';
import 'plan_export_delivery_result.dart';
import 'plan_export_v2.dart';
import 'plan_import_package.dart';
import 'plan_import_preview_screen.dart';
import 'plan_package.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('导入导出')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _PlanExportSummary(plan: widget.plan),
          const SizedBox(height: 16),
          _SectionTitle(
            icon: Icons.import_export_outlined,
            title: '导入',
            subtitle: '选择 .sjhplan 文件，先预览内容再导入。',
          ),
          const SizedBox(height: 10),
          _ActionTile(
            icon: _importing
                ? Icons.hourglass_empty_outlined
                : Icons.import_export_outlined,
            title: _importing ? '读取中...' : '导入 MiriaGo 文件',
            subtitle: '支持 v2 数据包和旧版 v1 JSON 计划包。',
            enabled: !_exporting && !_importing,
            onTap: _importFromFile,
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
            exporting: _exporting || _importing,
            onModeChanged: (mode) => setState(() => _mode = mode),
            onFullReferenceChanged: (value) =>
                setState(() => _includeFullReferenceCache = value),
            onExport: _exportV2,
          ),
          const SizedBox(height: 20),
          _SectionTitle(
            icon: Icons.history_outlined,
            title: '兼容旧版',
            subtitle: '导出 v1.0 纯 JSON 计划包，不包含图片文件。',
          ),
          const SizedBox(height: 10),
          _ActionTile(
            icon: Icons.description_outlined,
            title: '导出旧版 JSON 计划包',
            subtitle: '用于兼容旧版本 MiriaGo / Seichi Junrei Helper。',
            enabled: !_exporting && !_importing,
            onTap: _exportLegacy,
          ),
          const SizedBox(height: 20),
          _SectionTitle(
            icon: Icons.map_outlined,
            title: 'Google My Maps',
            subtitle: '后续导出同一图层、按片区稳定颜色区分的地图文件。',
          ),
          const SizedBox(height: 10),
          const _ActionTile(
            icon: Icons.table_chart_outlined,
            title: '导出 My Maps CSV',
            subtitle: '下一步实现。',
            enabled: false,
            onTap: null,
          ),
        ],
      ),
    );
  }

  Future<void> _importFromFile() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _importing = true);
    try {
      final file = await file_selector.openFile(
        acceptedTypeGroups: const [
          file_selector.XTypeGroup(
            label: 'MiriaGo plan package',
            extensions: [seichiPlanFileExtension],
            mimeTypes: [
              seichiPlanMimeType,
              miriagoExportPackageMimeType,
              'application/octet-stream',
              'application/json',
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

  Future<void> _exportV2() async {
    await _runExport(() async {
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
      final records = await widget.repository.loadVisitRecords(widget.plan.id);
      final package = await buildPlanExportV2Package(
        plan: widget.plan,
        visitRecords: records,
        options: options,
        exportedAt: exportedAt,
      );
      return deliverPlanExport(
        bytes: package.bytes,
        fileName: package.fileName,
        mimeType: miriagoExportPackageMimeType,
        shareSubject: widget.plan.name,
        shareText: 'MiriaGo数据包：${widget.plan.name}',
        extension: seichiPlanFileExtension,
        destination: destination,
      );
    }, successMessage: '数据包已导出');
  }

  Future<void> _exportLegacy() async {
    await _runExport(() async {
      final fileName =
          '${_safeExportName(widget.plan.name)}.$seichiPlanFileExtension';
      final destination = await preparePlanExportDestination(
        fileName: fileName,
        mimeType: seichiPlanMimeType,
        extension: seichiPlanFileExtension,
      );
      final records = await widget.repository.loadVisitRecords(widget.plan.id);
      final package = PlanPackage(plan: widget.plan, visitRecords: records);
      return deliverPlanExport(
        bytes: utf8.encode(package.toJsonString()),
        fileName: fileName,
        mimeType: seichiPlanMimeType,
        shareSubject: widget.plan.name,
        shareText: 'MiriaGo旧版计划包：${widget.plan.name}',
        extension: seichiPlanFileExtension,
        destination: destination,
      );
    }, successMessage: '旧版计划包已生成');
  }

  Future<void> _runExport(
    Future<PlanExportDeliveryResult> Function() action, {
    required String successMessage,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _exporting = true);
    messenger.showReplacingSnackBar(const SnackBar(content: Text('正在导出...')));
    try {
      final result = await action();
      if (!mounted) {
        return;
      }
      if (result.action == PlanExportDeliveryAction.canceled) {
        messenger.showReplacingSnackBar(const SnackBar(content: Text('已取消导出')));
        return;
      }
      messenger.showReplacingSnackBar(SnackBar(content: Text(successMessage)));
    } on PlanExportCanceledException {
      if (!mounted) {
        return;
      }
      messenger.showReplacingSnackBar(const SnackBar(content: Text('已取消导出')));
    } catch (_) {
      if (!mounted) {
        return;
      }
      messenger.showReplacingSnackBar(const SnackBar(content: Text('导出失败')));
    } finally {
      if (mounted) {
        setState(() => _exporting = false);
      }
    }
  }
}

String _safeExportName(String source) {
  final safeName = source
      .replaceAll(RegExp(r'[\\/:*?"<>|\s]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
  return safeName.isEmpty ? 'miriago_plan' : safeName;
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
    required this.exporting,
    required this.onModeChanged,
    required this.onFullReferenceChanged,
    required this.onExport,
  });

  final PlanExportV2Mode mode;
  final bool includeFullReferenceCache;
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
