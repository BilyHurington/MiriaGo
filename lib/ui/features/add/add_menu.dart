import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../../application/plan_session.dart';
import '../../app/router.dart';
import '../../components/components.dart';

/// Which part of the 添加 menu to show.
enum AddMenuSection { all, points, works }

enum _AddAction { anitabiImport, linkImport, manualPoint, bangumi, manualWork }

/// Opens the adaptive 「添加到『计划』」 menu.
/// OWNER: feature agent D (add).
Future<void> showAddMenu(
  BuildContext context, {
  AddMenuSection section = AddMenuSection.all,
}) async {
  final session = context.read<PlanSession>();
  if (!session.isReady) return;
  final plan = session.plan;
  final hasBangumiWork = plan.works.any((work) => work.bangumiId != null);
  final action = await showAdaptiveSheet<_AddAction>(
    context,
    title: '添加到「${plan.name}」',
    padding: const EdgeInsets.only(bottom: Space.x3),
    builder: (sheetContext) => _AddMenuContent(
      section: section,
      onSelected: (action) => Navigator.of(sheetContext).pop(action),
    ),
  );
  if (action == null || !context.mounted) return;
  switch (action) {
    case _AddAction.anitabiImport:
      // Δ2: without a Bangumi work, search first and continue straight
      // into the chosen work's map.
      await context.push<void>(
        hasBangumiWork
            ? Routes.anitabiImport
            : Routes.bangumiSearchThenImport(),
      );
    case _AddAction.linkImport:
      await context.push<void>(Routes.linkImport);
    case _AddAction.manualPoint:
      await openPointEditor(context);
    case _AddAction.bangumi:
      await context.push<void>(Routes.bangumiSearch);
    case _AddAction.manualWork:
      await context.push<void>(Routes.manualWork);
  }
}

/// Opens the point form (create when [pointId] is null, otherwise edit).
/// Returns true when saved.
/// OWNER: feature agent D (add).
Future<bool> openPointEditor(BuildContext context, {String? pointId}) async {
  final saved = await context.push<bool>(
    pointId == null ? Routes.newPoint : Routes.editPoint(pointId),
  );
  return saved ?? false;
}

class _AddMenuContent extends StatelessWidget {
  const _AddMenuContent({required this.section, required this.onSelected});

  final AddMenuSection section;
  final ValueChanged<_AddAction> onSelected;

  @override
  Widget build(BuildContext context) {
    final showPoints = section != AddMenuSection.works;
    final showWorks = section != AddMenuSection.points;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showPoints) ...[
          const SectionHeader(title: '点位'),
          _AddMenuRow(
            key: const ValueKey('add-menu-anitabi-import'),
            icon: Symbols.map_rounded,
            title: '从 Anitabi 作品地图导入',
            subtitle: '在地图上挑选点位（推荐）',
            recommended: true,
            onTap: () => onSelected(_AddAction.anitabiImport),
          ),
          _AddMenuRow(
            key: const ValueKey('add-menu-link-import'),
            icon: Symbols.link_rounded,
            title: '粘贴 Anitabi 链接',
            subtitle: '同时导入作品和点位',
            onTap: () => onSelected(_AddAction.linkImport),
          ),
          _AddMenuRow(
            key: const ValueKey('add-menu-manual-point'),
            icon: Symbols.add_location_alt_rounded,
            title: '手动添加点位',
            subtitle: '不在 Anitabi 上的地点',
            onTap: () => onSelected(_AddAction.manualPoint),
          ),
        ],
        if (showWorks) ...[
          if (showPoints) const SizedBox(height: Space.x2),
          const SectionHeader(title: '作品'),
          _AddMenuRow(
            key: const ValueKey('add-menu-bangumi'),
            icon: Symbols.travel_explore_rounded,
            title: '搜索 Bangumi',
            subtitle: '自动获取作品信息',
            onTap: () => onSelected(_AddAction.bangumi),
          ),
          _AddMenuRow(
            key: const ValueKey('add-menu-manual-work'),
            icon: Symbols.edit_note_rounded,
            title: '手动添加作品',
            subtitle: '未收录的作品',
            onTap: () => onSelected(_AddAction.manualWork),
          ),
        ],
      ],
    );
  }
}

class _AddMenuRow extends StatelessWidget {
  const _AddMenuRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.recommended = false,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool recommended;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ListRow(
      title: title,
      subtitle: subtitle,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: Space.x4,
        vertical: Space.x2,
      ),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: recommended ? c.spotContainer : c.primaryContainer,
          borderRadius: Radii.smAll,
        ),
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: 22,
          color: recommended ? c.onSpot : c.onPrimaryContainer,
        ),
      ),
      trailing: recommended
          ? const Tag(
              label: '推荐',
              tone: MiriaTone.spot,
              icon: Symbols.star_rounded,
            )
          : null,
    );
  }
}
