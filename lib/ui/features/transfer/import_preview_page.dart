import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../../application/transfer/plan_import_service.dart';
import '../../../data/pilgrimage_repository.dart';
import '../../../plan_transfer/plan_import_package.dart';
import '../../app/toast.dart';
import '../../components/components.dart';
import 'transfer_notice_toast.dart';

/// 导入内容: package info, statistics, what to import and package notes.
/// Pops `true` after a successful import.
class ImportPreviewPage extends StatefulWidget {
  const ImportPreviewPage({
    required this.package,
    this.supportsAssetRestore,
    this.restoreAssets,
    super.key,
  });

  final PlanImportPackage package;

  /// Overridable for tests (defaults to the platform capability).
  final bool? supportsAssetRestore;
  final PlanImportAssetRestorer? restoreAssets;

  @override
  State<ImportPreviewPage> createState() => _ImportPreviewPageState();
}

class _ImportPreviewPageState extends State<ImportPreviewPage> {
  late PlanImportSelection _selection = PlanImportSelection.initial(
    widget.package,
    supportsAssetRestore: widget.supportsAssetRestore,
  );
  bool _importing = false;

  Future<void> _import() async {
    setState(() => _importing = true);
    final repository = context.read<PilgrimageRepository>();
    final restore = widget.restoreAssets;
    final outcome = restore == null
        ? await importSelectedPlanPackage(
            repository: repository,
            selection: _selection,
          )
        : await importSelectedPlanPackage(
            repository: repository,
            selection: _selection,
            restoreAssets: restore,
          );
    if (!mounted) return;
    context.showTransferNotice(outcome.notice);
    if (outcome.success) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() => _importing = false);
  }

  @override
  Widget build(BuildContext context) {
    final package = widget.package;
    final selection = _selection;
    final warnings = selection.visibleWarnings;
    return PopScope(
      canPop: !_importing,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          context.showToast('正在导入，请稍候。', kind: ToastKind.info);
        }
      },
      child: MiriaPageScaffold(
        title: '导入内容',
        bottomBar: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: WindowLayout.readingWidth,
            ),
            child: MiriaButton(
              key: const ValueKey('import-selected-button'),
              label: _importing ? '导入中...' : '导入所选内容',
              icon: Symbols.download_rounded,
              loading: _importing,
              expand: true,
              size: MiriaButtonSize.lg,
              onPressed: _importing ? null : _import,
            ),
          ),
        ),
        slivers: [
          SliverContentColumn(
            top: Space.x2,
            bottom: Space.x4,
            sliver: SliverList.list(
              children: [
                _PackageHeader(package: package),
                const SizedBox(height: Space.x4),
                Wrap(
                  spacing: Space.x2,
                  runSpacing: Space.x2,
                  children: [
                    for (final stat in planImportStats(package))
                      _StatChip(label: stat.label, value: stat.value),
                  ],
                ),
                const SizedBox(height: Space.x5),
                const _SectionTitle(
                  icon: Symbols.checklist_rounded,
                  title: '选择导入内容',
                  subtitle: '导入前不会修改当前数据。',
                ),
                const SizedBox(height: Space.x2 + 2),
                const _OptionTile(
                  key: ValueKey('import-option-plan'),
                  icon: Symbols.route_rounded,
                  title: '计划结构',
                  subtitle: PlanImportSelection.planSubtitle,
                  value: true,
                  onChanged: null,
                ),
                const SizedBox(height: Space.x2),
                _OptionTile(
                  key: const ValueKey('import-option-records'),
                  icon: Symbols.folder_copy_rounded,
                  title: '拍摄记录',
                  subtitle: selection.recordsSubtitle,
                  value: selection.includeRecords,
                  onChanged: !_importing && selection.recordsSelectable
                      ? (value) => setState(
                          () => _selection = selection.withRecords(value),
                        )
                      : null,
                ),
                const SizedBox(height: Space.x2),
                _OptionTile(
                  key: const ValueKey('import-option-assets'),
                  icon: Symbols.photo_library_rounded,
                  title: '图片和资源文件',
                  subtitle: selection.assetsSubtitle,
                  value: selection.includeAssets,
                  onChanged: !_importing && selection.assetsSelectable
                      ? (value) => setState(
                          () => _selection = selection.withAssets(value),
                        )
                      : null,
                ),
                if (warnings.isNotEmpty) ...[
                  const SizedBox(height: Space.x5),
                  const _SectionTitle(
                    icon: Symbols.warning_rounded,
                    title: '包内提示',
                    subtitle: '导出时记录的缺失或兼容信息。',
                  ),
                  const SizedBox(height: Space.x2 + 2),
                  for (final warning in warnings)
                    Padding(
                      padding: const EdgeInsets.only(bottom: Space.x1 + 2),
                      child: Text(
                        warning,
                        style: context.text.bodySmall?.copyWith(
                          color: context.colors.textSecondary,
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Shows the import preview for [package]. Returns true when imported.
/// OWNER: feature agent F.
Future<bool> openImportPreview(
  BuildContext context,
  PlanImportPackage package,
) async {
  final result = await Navigator.of(context, rootNavigator: true).push<bool>(
    MaterialPageRoute<bool>(
      builder: (_) => ImportPreviewPage(package: package),
    ),
  );
  return result == true;
}

class _PackageHeader extends StatelessWidget {
  const _PackageHeader({required this.package});

  final PlanImportPackage package;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = context.text;
    return MiriaCard(
      padding: const EdgeInsets.all(Space.x3 + 2),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: c.primaryContainer,
              borderRadius: Radii.smAll,
            ),
            child: Icon(
              Symbols.inventory_2_rounded,
              color: c.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: Space.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  package.package.plan.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  '${package.versionLabel} / ${package.sourceName}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: text.caption.copyWith(color: c.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.x2 + 2,
        vertical: Space.x2,
      ),
      decoration: BoxDecoration(
        color: c.surfaceMuted,
        borderRadius: Radii.smAll,
      ),
      child: Text(
        '$label $value',
        style: context.text.labelMedium?.copyWith(
          color: c.textPrimary,
          fontFeatures: MiriaFonts.tabular,
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
    final c = context.colors;
    final text = context.text;
    return Semantics(
      header: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 20, color: c.primaryText),
          ),
          const SizedBox(width: Space.x2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: text.titleSmall),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: text.bodySmall?.copyWith(color: c.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;

  /// Null → locked (plan structure) or unavailable.
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = context.text;
    final enabled = onChanged != null;
    return MiriaCard(
      padding: EdgeInsets.zero,
      color: enabled ? null : c.surfaceMuted,
      child: MergeSemantics(
        child: ListRow(
          leading: Icon(icon, color: enabled ? c.primaryText : c.textSecondary),
          title: title,
          titleStyle: text.titleSmall,
          subtitle: subtitle,
          subtitleMaxLines: 4,
          borderRadius: Radii.mdAll,
          trailing: Checkbox(
            value: value,
            onChanged: enabled
                ? (checked) => onChanged!(checked == true)
                : null,
          ),
          onTap: enabled ? () => onChanged!(!value) : null,
        ),
      ),
    );
  }
}
