import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../application/organize/organize_view.dart';
import '../../../plan/pilgrimage_models.dart';
import '../../../plan/reference_image_status.dart';
import '../../components/components.dart';

/// Pinned header of one section of the 片区与点位 list.
class OrganizeSectionHeader extends StatelessWidget {
  const OrganizeSectionHeader({
    required this.section,
    required this.color,
    required this.collapsed,
    required this.focused,
    required this.onTap,
    this.menuActions = const [],
    super.key,
  });

  final OrganizeSection section;
  final Color color;
  final bool collapsed;

  /// Highlighted (the map shows this section).
  final bool focused;
  final VoidCallback onTap;
  final List<MenuAction> menuActions;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = context.text;
    final muted = section.isEmpty && !section.isInbox;
    final meta = section.isInbox
        ? '${section.totalCount} 个点位等待整理'
        : [
            section.anchorText,
            section.orderModeText,
            section.progressText,
          ].join(' · ');
    final title = section.isInbox ? '待整理' : section.bucket.name;
    return ColoredBox(
      color: c.canvas,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.x2, Space.x2, Space.x2, 0),
        child: ContextMenuRegion(
          actions: menuActions,
          title: title,
          longPress: false,
          child: MiriaPressable(
            key: ValueKey('organize-section-${section.id}'),
            onTap: onTap,
            selected: focused,
            borderRadius: Radii.smAll,
            semanticLabel: '$title，$meta，${collapsed ? '已折叠' : '已展开'}',
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  Space.x2,
                  Space.x2,
                  0,
                  Space.x2,
                ),
                child: Row(
                  children: [
                    Icon(
                      section.isInbox
                          ? Symbols.inventory_2_rounded
                          : Symbols.folder_rounded,
                      fill: 1,
                      size: 22,
                      color: muted ? c.textTertiary : color,
                    ),
                    const SizedBox(width: Space.x3),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  title,
                                  locale: section.isInbox
                                      ? null
                                      : MiriaFonts.japanese,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: text.titleSmall?.copyWith(
                                    color: muted ? c.textSecondary : null,
                                  ),
                                ),
                              ),
                              if (muted) ...[
                                const SizedBox(width: Space.x2),
                                Tag(
                                  key: ValueKey(
                                    'organize-section-empty-${section.id}',
                                  ),
                                  label: '空',
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            meta,
                            key: ValueKey(
                              'organize-section-meta-${section.id}',
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: text.caption.copyWith(
                              color: muted ? c.textTertiary : c.textSecondary,
                              fontFeatures: MiriaFonts.tabular,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (menuActions.isNotEmpty)
                      Builder(
                        builder: (buttonContext) => MiriaIconButton(
                          key: ValueKey('organize-section-menu-${section.id}'),
                          icon: Symbols.more_horiz_rounded,
                          tooltip: '片区操作',
                          compact: true,
                          onPressed: () => showActionMenu(
                            buttonContext,
                            actions: menuActions,
                            title: title,
                            anchor: buttonContext,
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: Space.x2),
                      child: AnimatedRotation(
                        turns: collapsed ? -0.25 : 0,
                        duration: Motion.of(context, Motion.standard),
                        child: Icon(
                          Symbols.expand_more_rounded,
                          size: 22,
                          color: c.textTertiary,
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
    );
  }
}

/// 「待整理」 tools: 最近分配 / 框选分配.
class OrganizeInboxTools extends StatelessWidget {
  const OrganizeInboxTools({
    required this.onNearestAssign,
    required this.onBoxAssign,
    super.key,
  });

  final VoidCallback? onNearestAssign;
  final VoidCallback? onBoxAssign;

  @override
  Widget build(BuildContext context) {
    // With large text the labels would collapse to bare icons side by side.
    final stacked = MediaQuery.textScalerOf(context).scale(1) > 1.4;
    final nearest = MiriaButton.secondary(
      key: const ValueKey('organize-nearest-assign'),
      label: '最近分配',
      icon: Symbols.auto_awesome_rounded,
      size: MiriaButtonSize.sm,
      expand: true,
      onPressed: onNearestAssign,
    );
    final box = MiriaButton.secondary(
      key: const ValueKey('organize-box-assign'),
      label: '框选分配',
      icon: Symbols.select_rounded,
      size: MiriaButtonSize.sm,
      expand: true,
      onPressed: onBoxAssign,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Space.x4,
        Space.x1,
        Space.x4,
        Space.x2,
      ),
      child: stacked
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                nearest,
                const SizedBox(height: Space.x2),
                box,
              ],
            )
          : Row(
              children: [
                Expanded(child: nearest),
                const SizedBox(width: Space.x2),
                Expanded(child: box),
              ],
            ),
    );
  }
}

/// Reference image cache pill (old `_CacheStatusPill`).
class ReferenceStatusPill extends StatelessWidget {
  const ReferenceStatusPill({required this.status, super.key});

  final ReferenceImageStatus status;

  @override
  Widget build(BuildContext context) {
    return Tag(
      label: referenceStatusLabel(status),
      tone: switch (status) {
        ReferenceImageStatus.none => MiriaTone.neutral,
        ReferenceImageStatus.localUpload => MiriaTone.info,
        ReferenceImageStatus.fullCached => MiriaTone.success,
        ReferenceImageStatus.remote => MiriaTone.warning,
      },
    );
  }
}

/// One point of the 片区与点位 list.
class OrganizePointRow extends StatelessWidget {
  const OrganizePointRow({
    required this.point,
    required this.index,
    required this.status,
    required this.referenceStatus,
    required this.selectionMode,
    required this.checked,
    required this.highlighted,
    required this.onTap,
    required this.onLongPress,
    required this.onToggle,
    required this.menuActions,
    this.dragHandle,
    super.key,
  });

  final PilgrimagePoint point;
  final int index;
  final VisitStatus status;
  final ReferenceImageStatus referenceStatus;
  final bool selectionMode;
  final bool checked;

  /// Shown in the inspector / on the map.
  final bool highlighted;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onToggle;
  final List<MenuAction> menuActions;

  /// Drag handle for manually ordered groups.
  final Widget? dragHandle;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final Widget leading;
    if (selectionMode) {
      leading = Checkbox(
        key: ValueKey('organize-point-check-${point.id}'),
        value: checked,
        onChanged: (_) => onToggle(),
      );
    } else if (dragHandle != null) {
      leading = dragHandle!;
    } else {
      leading = SizedBox(
        width: 28,
        child: Text(
          '${index + 1}',
          textAlign: TextAlign.center,
          style: context.text.labelMedium?.copyWith(
            color: c.textTertiary,
            fontFeatures: MiriaFonts.tabular,
          ),
        ),
      );
    }
    final subtitle = pointRowSubtitle(point);
    return ListRow(
      key: ValueKey('organize-point-${point.id}'),
      title: point.name,
      titleLocale: MiriaFonts.japanese,
      subtitle: subtitle.isEmpty ? null : subtitle,
      subtitleLocale: MiriaFonts.japanese,
      subtitleMaxLines: 1,
      leading: leading,
      below: Wrap(
        spacing: Space.x2,
        runSpacing: Space.x1,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          StatusBadge(status: status, compact: true),
          ReferenceStatusPill(status: referenceStatus),
        ],
      ),
      trailing: selectionMode || menuActions.isEmpty
          ? null
          : Builder(
              builder: (buttonContext) => MiriaIconButton(
                key: ValueKey('organize-point-menu-${point.id}'),
                icon: Symbols.more_vert_rounded,
                tooltip: '点位操作',
                compact: true,
                onPressed: () => showActionMenu(
                  buttonContext,
                  actions: menuActions,
                  title: point.name,
                  anchor: buttonContext,
                ),
              ),
            ),
      contextActions: selectionMode ? const [] : menuActions,
      contextMenuTitle: point.name,
      selected: checked || highlighted,
      onTap: selectionMode ? onToggle : onTap,
      onLongPress: selectionMode ? onToggle : onLongPress,
      padding: const EdgeInsets.fromLTRB(
        Space.x2,
        Space.x2,
        Space.x1,
        Space.x2,
      ),
      borderRadius: Radii.smAll,
    );
  }
}

/// Compact draggable row of the 「调整片区顺序」 mode.
class OrganizeGroupOrderRow extends StatelessWidget {
  const OrganizeGroupOrderRow({
    required this.group,
    required this.pointCount,
    required this.color,
    required this.index,
    required this.enabled,
    super.key,
  });

  final PilgrimagePlanGroup group;
  final int pointCount;
  final Color color;
  final int index;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = context.text;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.x1),
      child: Material(
        color: c.surface,
        borderRadius: Radii.smAll,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Row(
            children: [
              const SizedBox(width: Space.x3),
              Icon(Symbols.folder_rounded, fill: 1, color: color, size: 22),
              const SizedBox(width: Space.x3),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: Space.x2),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.name,
                        locale: MiriaFonts.japanese,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: text.titleSmall,
                      ),
                      Text(
                        '$pointCount 个点位',
                        style: text.caption.copyWith(color: c.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
              ReorderableDragStartListener(
                index: index,
                enabled: enabled,
                child: Semantics(
                  label: '拖动调整「${group.name}」的顺序',
                  child: SizedBox(
                    key: ValueKey('organize-group-drag-${group.id}'),
                    width: 48,
                    height: 48,
                    child: Icon(
                      Symbols.drag_indicator_rounded,
                      color: enabled ? c.textSecondary : c.textDisabled,
                    ),
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

/// Bottom bar while selecting points: 全选 / 清空, 移动, 完成, 取消完成, 删除.
class OrganizeBatchBar extends StatelessWidget {
  const OrganizeBatchBar({
    required this.selectedCount,
    required this.allSelected,
    required this.busy,
    required this.onSelectAll,
    required this.onClear,
    required this.onMove,
    required this.onComplete,
    required this.onReopen,
    required this.onDelete,
    super.key,
  });

  final int selectedCount;
  final bool allSelected;
  final bool busy;
  final VoidCallback onSelectAll;
  final VoidCallback onClear;
  final VoidCallback onMove;
  final VoidCallback onComplete;
  final VoidCallback onReopen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final enabled = selectedCount > 0 && !busy;
    return Row(
      key: const ValueKey('organize-batch-bar'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _BatchAction(
          key: const ValueKey('organize-batch-toggle-all'),
          label: allSelected ? '清空' : '全选',
          icon: allSelected
              ? Symbols.deselect_rounded
              : Symbols.select_all_rounded,
          onPressed: busy ? null : (allSelected ? onClear : onSelectAll),
        ),
        _BatchAction(
          key: const ValueKey('organize-batch-move'),
          label: '移动',
          icon: Symbols.drive_file_move_rounded,
          onPressed: enabled ? onMove : null,
        ),
        _BatchAction(
          key: const ValueKey('organize-batch-complete'),
          label: '完成',
          icon: Symbols.check_circle_rounded,
          onPressed: enabled ? onComplete : null,
        ),
        _BatchAction(
          key: const ValueKey('organize-batch-reopen'),
          label: '取消完成',
          icon: Symbols.undo_rounded,
          onPressed: enabled ? onReopen : null,
        ),
        _BatchAction(
          key: const ValueKey('organize-batch-delete'),
          label: '删除',
          icon: Symbols.delete_rounded,
          destructive: true,
          onPressed: enabled ? onDelete : null,
        ),
      ],
    );
  }
}

/// Icon-over-label toolbar button of the batch bar.
class _BatchAction extends StatelessWidget {
  const _BatchAction({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.destructive = false,
    super.key,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final enabled = onPressed != null;
    final color = !enabled
        ? c.textDisabled
        : destructive
        ? c.danger
        : c.primaryText;
    return Expanded(
      child: MiriaPressable(
        onTap: onPressed,
        enabled: enabled,
        borderRadius: Radii.smAll,
        semanticLabel: label,
        button: true,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Space.x1,
              vertical: Space.x1,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(height: 2),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.labelSmall?.copyWith(color: color),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
