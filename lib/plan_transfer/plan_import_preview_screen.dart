import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../data/pilgrimage_repository.dart';
import 'plan_import_asset_restore.dart';
import 'plan_import_package.dart';

class PlanImportPreviewScreen extends StatefulWidget {
  const PlanImportPreviewScreen({
    required this.importPackage,
    required this.repository,
    super.key,
  });

  final PlanImportPackage importPackage;
  final PilgrimageRepository repository;

  @override
  State<PlanImportPreviewScreen> createState() =>
      _PlanImportPreviewScreenState();
}

class _PlanImportPreviewScreenState extends State<PlanImportPreviewScreen> {
  late var _includeRecords = widget.importPackage.hasVisitRecords;
  late var _includeAssets =
      widget.importPackage.hasRestorableAssets &&
      supportsPlanImportAssetRestore;
  var _importing = false;

  PlanImportPackage get _package => widget.importPackage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('导入内容')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _PackageHeader(importPackage: _package),
          const SizedBox(height: 16),
          _StatsGrid(importPackage: _package),
          const SizedBox(height: 18),
          _SectionTitle(
            icon: Icons.fact_check_outlined,
            title: '选择导入内容',
            subtitle: '导入前不会修改当前数据。',
          ),
          const SizedBox(height: 10),
          _ImportOptionTile(
            icon: Icons.route_outlined,
            title: '计划结构',
            subtitle: '作品、片区、点位、完成状态和当前目标。',
            value: true,
            enabled: false,
            onChanged: null,
          ),
          const SizedBox(height: 8),
          _ImportOptionTile(
            icon: Icons.collections_bookmark_outlined,
            title: '拍摄记录',
            subtitle: _package.isLegacyJson
                ? 'v1 文件不包含照片资源，仅导入计划结构。'
                : _package.hasVisitRecords
                ? '${_package.visitRecordCount} 条记录，包含照片路径和调色参数。'
                : '这个包里没有拍摄记录。',
            value: _includeRecords,
            enabled: !_importing && _package.hasVisitRecords,
            onChanged: (value) => setState(() => _includeRecords = value),
          ),
          const SizedBox(height: 8),
          _ImportOptionTile(
            icon: Icons.photo_library_outlined,
            title: '图片和资源文件',
            subtitle: _assetImportSubtitle,
            value: _includeAssets,
            enabled:
                !_importing &&
                _package.hasRestorableAssets &&
                supportsPlanImportAssetRestore,
            onChanged: (value) => setState(() => _includeAssets = value),
          ),
          if (_package.warnings.isNotEmpty) ...[
            const SizedBox(height: 18),
            _SectionTitle(
              icon: Icons.warning_amber_outlined,
              title: '包内提示',
              subtitle: '导出时记录的缺失或兼容信息。',
            ),
            const SizedBox(height: 10),
            for (final warning in _package.warnings.take(6))
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  warning,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    letterSpacing: 0,
                  ),
                ),
              ),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: FilledButton.icon(
            onPressed: _importing ? null : _importSelected,
            icon: _importing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download_done_outlined),
            label: Text(_importing ? '导入中...' : '导入所选内容'),
          ),
        ),
      ),
    );
  }

  Future<void> _importSelected() async {
    setState(() => _importing = true);
    try {
      final restoredPaths = _includeAssets
          ? await restorePlanImportAssets(_package)
          : const <String, String>{};
      final restored = applyRestoredAssetPaths(
        importPackage: _package,
        restoredPaths: restoredPaths,
        includeRecords: _includeRecords,
      );
      final importedPlan = await widget.repository.importPlanPackage(
        plan: restored.plan,
        visitRecords: restored.visitRecords,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            restored.warnings.isEmpty
                ? '已导入计划「${importedPlan.name}」'
                : '已导入计划「${importedPlan.name}」，部分资源未恢复',
          ),
        ),
      );
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('导入失败')));
    } finally {
      if (mounted) {
        setState(() => _importing = false);
      }
    }
  }

  String get _assetImportSubtitle {
    if (!_package.hasAssets) {
      return '这个包里没有可恢复的资源文件。';
    }
    if (!_package.hasRestorableAssets) {
      return '包内记录了资源，但没有可恢复的资源文件。';
    }
    if (!supportsPlanImportAssetRestore) {
      return '包内有 ${_package.totalAssetCount} 个资源文件；当前平台暂不支持恢复包内资源。';
    }
    return '包内有 ${_package.totalAssetCount} 个资源文件，将恢复到本机存储。';
  }
}

class _PackageHeader extends StatelessWidget {
  const _PackageHeader({required this.importPackage});

  final PlanImportPackage importPackage;

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
            child: Icon(
              Icons.inventory_2_outlined,
              color: AppColors.accentDark,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  importPackage.package.plan.name,
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
                  '${importPackage.versionLabel} / ${importPackage.sourceName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.importPackage});

  final PlanImportPackage importPackage;

  @override
  Widget build(BuildContext context) {
    final exportedAt = importPackage.exportedAt;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _StatChip(label: '作品', value: '${importPackage.workCount}'),
        _StatChip(label: '片区', value: '${importPackage.groupCount}'),
        _StatChip(label: '点位', value: '${importPackage.pointCount}'),
        _StatChip(label: '记录', value: '${importPackage.visitRecordCount}'),
        _StatChip(label: '资源', value: '${importPackage.totalAssetCount}'),
        if (importPackage.appVersion != null)
          _StatChip(label: '版本', value: importPackage.appVersion!),
        if (exportedAt != null)
          _StatChip(
            label: '导出',
            value:
                '${exportedAt.year}-${exportedAt.month.toString().padLeft(2, '0')}-${exportedAt.day.toString().padLeft(2, '0')}',
          ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$label $value',
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 12,
          letterSpacing: 0,
        ),
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

class _ImportOptionTile extends StatelessWidget {
  const _ImportOptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final bool enabled;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: enabled ? AppColors.surface : AppColors.surfaceMuted,
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
                  style: const TextStyle(
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
          Checkbox(
            value: value,
            onChanged: enabled
                ? (checked) {
                    if (checked != null) {
                      onChanged?.call(checked);
                    }
                  }
                : null,
          ),
        ],
      ),
    );
  }
}
