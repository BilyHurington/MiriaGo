import 'package:flutter/material.dart';

import '../app_theme.dart';
import 'pilgrimage_models.dart';
import 'plan_group_utils.dart';

Future<void> showPlanGroupPickerSheet({
  required BuildContext context,
  required List<PlanGroupBucket> groups,
  required String selectedGroupId,
  required ValueChanged<PlanGroupBucket> onSelectGroup,
  Future<PilgrimagePlanGroup?> Function()? onCreateGroup,
  bool showProgressRing = true,
  bool emphasizeTotalCount = false,
}) {
  final pickerGroups = [...groups];
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setSheetState) {
          return SafeArea(
            top: false,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.84 > 536
                    ? 536
                    : MediaQuery.sizeOf(context).height * 0.84,
              ),
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '选择区域',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '共 ${pickerGroups.length} 个区域',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (onCreateGroup != null)
                        IconButton(
                          key: const ValueKey('plan-group-picker-create'),
                          tooltip: '新建片区',
                          onPressed: () async {
                            final created = await onCreateGroup();
                            if (created == null || !context.mounted) {
                              return;
                            }
                            setSheetState(() {
                              pickerGroups
                                ..removeWhere((group) => group.id == created.id)
                                ..add(
                                  PlanGroupBucket(
                                    id: created.id,
                                    name: created.name,
                                    group: created,
                                    points: const [],
                                    completedCount: 0,
                                  ),
                                )
                                ..sort((a, b) {
                                  if (a.isUngrouped) {
                                    return 1;
                                  }
                                  if (b.isUngrouped) {
                                    return -1;
                                  }
                                  return a.group!.orderIndex.compareTo(
                                    b.group!.orderIndex,
                                  );
                                });
                            });
                          },
                          icon: const Icon(Icons.create_new_folder_outlined),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  for (final group in pickerGroups)
                    _PlanGroupPickerTile(
                      group: group,
                      selected: group.id == selectedGroupId,
                      showProgressRing: showProgressRing,
                      emphasizeTotalCount: emphasizeTotalCount,
                      onTap: () {
                        Navigator.of(context).pop();
                        onSelectGroup(group);
                      },
                    ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

class _PlanGroupPickerTile extends StatelessWidget {
  const _PlanGroupPickerTile({
    required this.group,
    required this.selected,
    required this.showProgressRing,
    required this.emphasizeTotalCount,
    required this.onTap,
  });

  final PlanGroupBucket group;
  final bool selected;
  final bool showProgressRing;
  final bool emphasizeTotalCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accentColor = Theme.of(context).colorScheme.primary;
    final progress = group.points.isEmpty
        ? 0.0
        : (group.completedCount / group.points.length)
              .clamp(0.0, 1.0)
              .toDouble();
    final completed =
        group.points.isNotEmpty && group.completedCount >= group.points.length;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected
            ? accentColor.withValues(alpha: 0.08)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('plan-group-picker-option-${group.name}'),
          onTap: onTap,
          child: SizedBox(
            height: 68,
            child: Stack(
              children: [
                if (showProgressRing && !completed)
                  Positioned.fill(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        key: ValueKey('plan-group-picker-progress-${group.id}'),
                        widthFactor: progress,
                        heightFactor: 1,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: accentColor.withValues(
                              alpha: selected ? 0.18 : 0.08,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ),
                if (selected)
                  Positioned(
                    key: const ValueKey('plan-group-picker-selected-accent'),
                    left: 0,
                    top: 9,
                    bottom: 9,
                    child: Container(
                      width: 4,
                      decoration: BoxDecoration(
                        color: accentColor,
                        borderRadius: const BorderRadius.horizontal(
                          right: Radius.circular(4),
                        ),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
                  child: Row(
                    children: [
                      if (completed)
                        SizedBox(
                          key: ValueKey(
                            'plan-group-picker-completed-icon-${group.id}',
                          ),
                          width: 28,
                          height: 26,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Icon(
                                Icons.folder,
                                color: AppColors.accentDark,
                                size: 28,
                              ),
                              const Padding(
                                padding: EdgeInsets.only(top: 2),
                                child: Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 14,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        SizedBox(
                          width: 28,
                          child: Icon(
                            group.isUngrouped
                                ? (selected
                                      ? Icons.inventory_2
                                      : Icons.inventory_2_outlined)
                                : (selected
                                      ? Icons.folder
                                      : Icons.folder_outlined),
                            color: selected
                                ? accentColor
                                : AppColors.textSecondary,
                            size: 24,
                          ),
                        ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              group.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              group.anchorLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                                letterSpacing: 0,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 44,
                        child: Text.rich(
                          key: ValueKey('plan-group-picker-count-${group.id}'),
                          TextSpan(
                            text: '${group.completedCount}',
                            children: [
                              TextSpan(
                                text: '/',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0,
                                ),
                              ),
                              TextSpan(
                                text: '${group.points.length}',
                                style: TextStyle(
                                  fontSize: emphasizeTotalCount ? 17 : 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0,
                                ),
                              ),
                            ],
                          ),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: selected
                                ? AppColors.accentDark
                                : AppColors.textSecondary,
                            fontSize: emphasizeTotalCount ? 10 : 17,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PlanGroupSelectionOption {
  const PlanGroupSelectionOption({required this.id, required this.title});

  final String id;
  final String title;
}

Future<String?> showPlanGroupSelectionSheet({
  required BuildContext context,
  required String title,
  required String subtitle,
  required List<PlanGroupSelectionOption> options,
  required String selectedOptionId,
  Future<PlanGroupSelectionOption?> Function()? onCreateOption,
}) {
  final pickerOptions = [...options];
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setSheetState) {
          Future<void> createOption() async {
            final create = onCreateOption;
            if (create == null) {
              return;
            }
            final created = await create();
            if (created == null || !context.mounted) {
              return;
            }
            setSheetState(() {
              pickerOptions
                ..removeWhere((option) => option.id == created.id)
                ..add(created);
            });
          }

          return SafeArea(
            top: false,
            child: SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.82 > 520
                  ? 520
                  : MediaQuery.sizeOf(context).height * 0.82,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView(
                      key: const ValueKey('plan-point-group-options-list'),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        for (final option in pickerOptions)
                          _PlanGroupSelectionTile(
                            option: option,
                            selected: option.id == selectedOptionId,
                            onTap: () => Navigator.of(context).pop(option.id),
                          ),
                      ],
                    ),
                  ),
                  if (onCreateOption != null) ...[
                    Divider(height: 1, color: AppColors.border),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          key: const ValueKey('plan-point-group-create-entry'),
                          borderRadius: BorderRadius.circular(8),
                          onTap: createOption,
                          child: SizedBox(
                            height: 46,
                            child: Row(
                              children: [
                                const SizedBox(width: 8),
                                Icon(Icons.add, color: AppColors.accent),
                                const SizedBox(width: 12),
                                Text(
                                  '新建片区',
                                  style: TextStyle(
                                    color: AppColors.accentDark,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

class _PlanGroupSelectionTile extends StatefulWidget {
  const _PlanGroupSelectionTile({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final PlanGroupSelectionOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_PlanGroupSelectionTile> createState() =>
      _PlanGroupSelectionTileState();
}

class _PlanGroupSelectionTileState extends State<_PlanGroupSelectionTile> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        clipBehavior: Clip.antiAlias,
        child: MouseRegion(
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: InkWell(
            onTap: widget.onTap,
            hoverColor: Colors.transparent,
            highlightColor: Colors.transparent,
            child: SizedBox(
              key: ValueKey('plan-point-group-option-${widget.option.title}'),
              height: 44,
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  curve: Curves.easeOut,
                  height: 36,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: widget.selected
                        ? AppColors.accent.withValues(alpha: 0.08)
                        : _hovered
                        ? AppColors.accent.withValues(alpha: 0.05)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      children: [
                        Icon(
                          widget.selected
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          key: ValueKey(
                            'plan-point-group-selection-${widget.option.title}',
                          ),
                          color: widget.selected
                              ? AppColors.accent
                              : AppColors.textSecondary,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            widget.option.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
