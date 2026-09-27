import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../../application/organize/organize_service.dart';
import '../../../application/plan_session.dart';
import '../../../plan/pilgrimage_models.dart';
import '../../../plan/plan_group_utils.dart';
import '../../app/toast.dart';
import '../../components/components.dart';

/// Id used for the synthetic 「未分组 / 未分入片区」 bucket.
const String kUngroupedId = 'ungrouped';

/// Adaptive "choose a group" picker (radio list + 「新建片区」).
/// Returns a group id, [kUngroupedId], or null when cancelled.
///
/// A null [selectedGroupId] marks 「未分入片区」 as the current choice
/// (old `currentGroupId ?? ungrouped`).
/// OWNER: feature agent C (organize).
Future<String?> pickGroup(
  BuildContext context, {
  required String title,
  String? subtitle,
  String? selectedGroupId,
  bool includeUngrouped = true,
  bool allowCreate = true,
}) async {
  return showAdaptiveSheet<String>(
    context,
    title: title,
    scrollable: false,
    padding: EdgeInsets.zero,
    builder: (sheetContext) => _GroupPickerList(
      subtitle: subtitle,
      selectedId: selectedGroupId ?? (includeUngrouped ? kUngroupedId : null),
      includeUngrouped: includeUngrouped,
      allowCreate: allowCreate,
    ),
  );
}

/// The single 「新建片区」 dialog of the app (validates 「片区名不能为空」)
/// and creates the group through the PlanSession. Returns the new group,
/// or null when cancelled / failed (failure toast 「片区创建失败」 shown).
/// OWNER: feature agent C (organize).
Future<PilgrimagePlanGroup?> showCreateGroupDialog(BuildContext context) async {
  final name = await showInputDialog(
    context,
    title: '新建片区',
    label: '片区名称',
    confirmLabel: '创建',
    validator: (value) => value.trim().isEmpty ? '片区名不能为空' : null,
  );
  if (name == null || !context.mounted) return null;
  final session = context.read<PlanSession>();
  if (!session.isReady) return null;
  try {
    return await createPlanGroupInSession(session, name);
  } on OrganizeFailure catch (failure) {
    if (context.mounted) {
      context.showToast(failure.message, kind: ToastKind.error);
    }
    return null;
  }
}

/// Group chooser used by the 巡礼 header (片区选择器 with progress).
/// Returns a group id / [kUngroupedId] or null.
/// OWNER: feature agent C (organize).
Future<String?> showGroupSwitcherSheet(
  BuildContext context, {
  String? selectedGroupId,
  bool showProgress = true,
  bool emphasizeTotalCount = false,
}) async {
  return showAdaptiveSheet<String>(
    context,
    title: '选择区域',
    scrollable: false,
    padding: EdgeInsets.zero,
    headerActions: [
      Builder(
        builder: (buttonContext) => MiriaIconButton(
          key: const ValueKey('group-switcher-create'),
          icon: Symbols.create_new_folder_rounded,
          tooltip: '新建片区',
          onPressed: () => showCreateGroupDialog(buttonContext),
        ),
      ),
    ],
    builder: (sheetContext) => _GroupSwitcherList(
      selectedId: selectedGroupId,
      showProgress: showProgress,
      emphasizeTotalCount: emphasizeTotalCount,
    ),
  );
}

// ---------------------------------------------------------------------------
// pickGroup
// ---------------------------------------------------------------------------

class _GroupPickerList extends StatelessWidget {
  const _GroupPickerList({
    required this.subtitle,
    required this.selectedId,
    required this.includeUngrouped,
    required this.allowCreate,
  });

  final String? subtitle;
  final String? selectedId;
  final bool includeUngrouped;
  final bool allowCreate;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final session = context.watch<PlanSession>();
    final groups = session.isReady
        ? sortGroupsByPlanOrder(session.plan.groups)
        : const <PilgrimagePlanGroup>[];
    final options = [
      if (includeUngrouped) (id: kUngroupedId, title: '未分入片区', ja: false),
      for (final group in groups) (id: group.id, title: group.name, ja: true),
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (subtitle != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.x4, 0, Space.x4, Space.x2),
            child: Text(
              subtitle!,
              style: context.text.caption.copyWith(color: c.textSecondary),
            ),
          ),
        Flexible(
          child: options.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(Space.x4),
                  child: EmptyState(
                    title: '请先创建片区',
                    icon: Symbols.folder_rounded,
                    compact: true,
                  ),
                )
              : ListView.builder(
                  key: const ValueKey('group-picker-options'),
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(horizontal: Space.x2),
                  itemCount: options.length,
                  itemBuilder: (context, index) {
                    final option = options[index];
                    return _RadioTile(
                      key: ValueKey('group-picker-option-${option.id}'),
                      title: option.title,
                      japanese: option.ja,
                      selected: option.id == selectedId,
                      onTap: () => Navigator.of(context).pop(option.id),
                    );
                  },
                ),
        ),
        if (allowCreate) ...[
          Divider(height: 1, color: c.hairline),
          Padding(
            padding: const EdgeInsets.all(Space.x2),
            child: ListRow(
              key: const ValueKey('group-picker-create'),
              title: '新建片区',
              titleStyle: context.text.titleSmall?.copyWith(
                color: c.primaryText,
              ),
              leading: Icon(Symbols.add_rounded, color: c.primary),
              minHeight: 48,
              borderRadius: Radii.smAll,
              padding: const EdgeInsets.symmetric(
                horizontal: Space.x3,
                vertical: Space.x2,
              ),
              onTap: () => showCreateGroupDialog(context),
            ),
          ),
        ],
        SizedBox(height: MediaQuery.paddingOf(context).bottom),
      ],
    );
  }
}

class _RadioTile extends StatelessWidget {
  const _RadioTile({
    required this.title,
    required this.japanese,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String title;
  final bool japanese;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: ListRow(
        title: title,
        titleLocale: japanese ? MiriaFonts.japanese : null,
        titleMaxLines: 2,
        selected: selected,
        minHeight: 48,
        borderRadius: Radii.smAll,
        padding: const EdgeInsets.symmetric(
          horizontal: Space.x3,
          vertical: Space.x2,
        ),
        leading: Icon(
          selected
              ? Symbols.check_circle_rounded
              : Symbols.radio_button_unchecked_rounded,
          fill: selected ? 1 : 0,
          color: selected ? c.primary : c.textTertiary,
        ),
        onTap: onTap,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// showGroupSwitcherSheet
// ---------------------------------------------------------------------------

class _GroupSwitcherList extends StatelessWidget {
  const _GroupSwitcherList({
    required this.selectedId,
    required this.showProgress,
    required this.emphasizeTotalCount,
  });

  final String? selectedId;
  final bool showProgress;
  final bool emphasizeTotalCount;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final session = context.watch<PlanSession>();
    final buckets = session.isReady
        ? planGroupBuckets(session.plan, session.controller.completedPointIds)
        : const <PlanGroupBucket>[];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.x4, 0, Space.x4, Space.x3),
          child: Text(
            '共 ${buckets.length} 个区域',
            style: context.text.caption.copyWith(color: c.textSecondary),
          ),
        ),
        Flexible(
          child: ListView.builder(
            key: const ValueKey('group-switcher-list'),
            shrinkWrap: true,
            padding: EdgeInsets.fromLTRB(
              Space.x3,
              0,
              Space.x3,
              Space.x3 + MediaQuery.paddingOf(context).bottom,
            ),
            itemCount: buckets.length,
            itemBuilder: (context, index) {
              final bucket = buckets[index];
              return _SwitcherTile(
                key: ValueKey('group-switcher-option-${bucket.id}'),
                bucket: bucket,
                selected: bucket.id == selectedId,
                showProgress: showProgress,
                emphasizeTotalCount: emphasizeTotalCount,
                onTap: () => Navigator.of(context).pop(bucket.id),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SwitcherTile extends StatelessWidget {
  const _SwitcherTile({
    required this.bucket,
    required this.selected,
    required this.showProgress,
    required this.emphasizeTotalCount,
    required this.onTap,
    super.key,
  });

  final PlanGroupBucket bucket;
  final bool selected;
  final bool showProgress;
  final bool emphasizeTotalCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = context.text;
    final total = bucket.points.length;
    final done = bucket.completedCount;
    final progress = total == 0 ? 0.0 : (done / total).clamp(0.0, 1.0);
    final completed = total > 0 && done >= total;
    final countColor = selected ? c.primaryText : c.textSecondary;
    final big = text.titleMedium?.copyWith(
      color: countColor,
      fontFeatures: MiriaFonts.tabular,
    );
    final small = text.caption.copyWith(
      color: countColor,
      fontFeatures: MiriaFonts.tabular,
      fontWeight: FontWeight.w600,
    );

    final Widget icon;
    if (completed) {
      icon = SizedBox(
        key: ValueKey('group-switcher-completed-${bucket.id}'),
        width: 28,
        height: 28,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(Symbols.folder_rounded, fill: 1, size: 28, color: c.primary),
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Icon(
                Symbols.check_rounded,
                size: 15,
                weight: 700,
                color: c.onPrimary,
              ),
            ),
          ],
        ),
      );
    } else {
      icon = Icon(
        bucket.isUngrouped
            ? Symbols.inventory_2_rounded
            : Symbols.folder_rounded,
        fill: selected ? 1 : 0,
        size: 24,
        color: selected ? c.primary : c.textSecondary,
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: Space.x1),
      child: MiriaPressable(
        onTap: onTap,
        selected: selected,
        borderRadius: Radii.smAll,
        semanticLabel:
            '${bucket.name}，${bucket.anchorLabel}，已完成 $done / $total',
        child: ClipRRect(
          borderRadius: Radii.smAll,
          child: Stack(
            children: [
              Positioned.fill(
                child: ColoredBox(
                  color: selected
                      ? c.primaryContainer.withValues(alpha: 0.5)
                      : Colors.transparent,
                ),
              ),
              if (showProgress && !completed && progress > 0)
                Positioned.fill(
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: FractionallySizedBox(
                      key: ValueKey('group-switcher-progress-${bucket.id}'),
                      widthFactor: progress,
                      heightFactor: 1,
                      child: ColoredBox(
                        color: c.primary.withValues(
                          alpha: selected ? 0.16 : 0.08,
                        ),
                      ),
                    ),
                  ),
                ),
              if (selected)
                PositionedDirectional(
                  start: 0,
                  top: Space.x2,
                  bottom: Space.x2,
                  child: Container(
                    width: 4,
                    decoration: BoxDecoration(
                      color: c.primary,
                      borderRadius: const BorderRadiusDirectional.horizontal(
                        end: Radius.circular(4),
                      ),
                    ),
                  ),
                ),
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 64),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Space.x4,
                    Space.x2,
                    Space.x3,
                    Space.x2,
                  ),
                  child: Row(
                    children: [
                      SizedBox(width: 28, child: Center(child: icon)),
                      const SizedBox(width: Space.x3),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              bucket.name,
                              locale: bucket.isUngrouped
                                  ? null
                                  : MiriaFonts.japanese,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: text.titleSmall,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              bucket.anchorLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text.caption.copyWith(
                                color: c.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: Space.x2),
                      Text.rich(
                        key: ValueKey('group-switcher-count-${bucket.id}'),
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '$done',
                              style: emphasizeTotalCount ? small : big,
                            ),
                            TextSpan(text: '/', style: small),
                            TextSpan(
                              text: '$total',
                              style: emphasizeTotalCount ? big : small,
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
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
