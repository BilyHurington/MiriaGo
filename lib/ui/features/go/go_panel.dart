import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../application/go/go_queue.dart';
import '../../../plan/pilgrimage_models.dart';
import '../../components/components.dart';
import '../points/point_shared.dart';

/// 「‹ 片区名 ›」 header with route dots and 「x/y」 (DESIGN §8.2).
///
/// Previous / next do not wrap (Δ7); a horizontal swipe changes the group
/// on touch; tapping the name opens the group switcher.
class GoGroupHeader extends StatelessWidget {
  const GoGroupHeader({
    required this.buckets,
    required this.index,
    required this.statusOf,
    required this.onSelect,
    required this.onOpenPicker,
    super.key,
  });

  final List<PlanGroupBucket> buckets;
  final int index;
  final VisitStatus Function(PilgrimagePoint point) statusOf;
  final ValueChanged<int> onSelect;
  final VoidCallback onOpenPicker;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bucket = buckets[index];
    final previous = adjacentGroupIndex(index, -1, buckets.length);
    final next = adjacentGroupIndex(index, 1, buckets.length);
    final total = bucket.points.length;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      supportedDevices: const {PointerDeviceKind.touch},
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity.abs() < 250) return;
        final target = velocity < 0 ? next : previous;
        if (target != null) onSelect(target);
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.x1, 0, Space.x1, Space.x1),
        child: Row(
          children: [
            MiriaIconButton(
              key: const ValueKey('go-group-previous'),
              icon: Symbols.chevron_left_rounded,
              tooltip: '上一个片区',
              onPressed: previous == null ? null : () => onSelect(previous),
            ),
            Expanded(
              child: MiriaPressable(
                key: const ValueKey('go-group-name'),
                onTap: onOpenPicker,
                borderRadius: Radii.smAll,
                semanticLabel:
                    '片区：${bucket.name}，已完成 ${bucket.completedCount}/$total，'
                    '点击切换片区',
                excludeSemantics: true,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Space.x2,
                    vertical: Space.x1,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              bucket.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              locale: MiriaFonts.japanese,
                              style: context.text.titleSmall,
                            ),
                          ),
                          Icon(
                            Symbols.expand_more_rounded,
                            size: 18,
                            color: c.textTertiary,
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (total > 0)
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: RouteDots(
                                  statuses: [
                                    for (final point in bucket.points)
                                      statusOf(point),
                                  ],
                                ),
                              ),
                            ),
                          const SizedBox(width: Space.x2),
                          Text(
                            '${bucket.completedCount}/$total',
                            key: const ValueKey('go-group-progress'),
                            style: context.text.caption.copyWith(
                              color: c.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            MiriaIconButton(
              key: const ValueKey('go-group-next'),
              icon: Symbols.chevron_right_rounded,
              tooltip: '下一个片区',
              onPressed: next == null ? null : () => onSelect(next),
            ),
          ],
        ),
      ),
    );
  }
}

/// Callbacks for the actions on a point in the 巡礼 panel.
@immutable
class GoPointActions {
  const GoPointActions({
    required this.onOpenDetail,
    required this.onNavigate,
    required this.onOpenExternal,
    required this.onCamera,
    required this.onToggleCompletion,
    this.onSetCurrent,
  });

  final VoidCallback onOpenDetail;
  final VoidCallback onNavigate;
  final VoidCallback onOpenExternal;
  final VoidCallback onCamera;
  final VoidCallback onToggleCompletion;

  /// Null hides 「设为当前目标」.
  final VoidCallback? onSetCurrent;
}

/// One-line summary of the focused point, shown in the header while the
/// bottom sheet rests at peek (DESIGN §8.2 「收起」).
class GoCompactTargetRow extends StatelessWidget {
  const GoCompactTargetRow({
    required this.point,
    required this.status,
    required this.label,
    required this.actions,
    super.key,
  });

  final PilgrimagePoint point;
  final VisitStatus status;
  final String label;
  final GoPointActions actions;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return MiriaPressable(
      key: const ValueKey('go-compact-target'),
      onTap: actions.onOpenDetail,
      borderRadius: Radii.mdAll,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Space.x4,
          Space.x1,
          Space.x2,
          Space.x2,
        ),
        child: Row(
          children: [
            PointThumbnail(point: point, size: 44),
            const SizedBox(width: Space.x3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.labelSmall?.copyWith(
                      color: c.textSecondary,
                    ),
                  ),
                  Text(
                    point.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    locale: MiriaFonts.japanese,
                    style: context.text.titleSmall,
                  ),
                ],
              ),
            ),
            MiriaIconButton(
              key: const ValueKey('go-compact-navigate'),
              icon: Symbols.directions_walk_rounded,
              tooltip: point.hasCoordinate ? '导航' : '坐标待补充',
              onPressed: point.hasCoordinate ? actions.onNavigate : null,
            ),
            MiriaIconButton(
              key: const ValueKey('go-compact-camera'),
              icon: Symbols.photo_camera_rounded,
              tooltip: '拍摄参考',
              onPressed: actions.onCamera,
            ),
            MiriaIconButton(
              key: const ValueKey('go-compact-complete'),
              icon: completionIcon(status),
              tooltip: completionLabel(status),
              onPressed: actions.onToggleCompletion,
            ),
          ],
        ),
      ),
    );
  }
}

/// The 「当前目标」 / 「选中点位」 card: reference image, status, name,
/// work · episode, record count and the main actions.
class GoPointCard extends StatelessWidget {
  const GoPointCard({
    required this.point,
    required this.status,
    required this.recordCount,
    required this.actions,
    this.selection = false,
    this.onBack,
    this.overlapPager,
    this.imageMaxHeight = 190,
    super.key,
  });

  final PilgrimagePoint point;
  final VisitStatus status;
  final int recordCount;
  final GoPointActions actions;

  /// A map selection (「选中点位」 with a back button and status) rather than the
  /// current target.
  final bool selection;
  final VoidCallback? onBack;
  final Widget? overlapPager;

  /// Height limit of the 16:9 reference image; 0 hides it (short windows).
  final double imageMaxHeight;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final label = selection ? '选中点位' : '当前目标';
    return MiriaCard(
      key: ValueKey(selection ? 'go-selected-card' : 'go-current-card'),
      padding: EdgeInsets.zero,
      selected: selection,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.x1, Space.x1, Space.x3, 0),
            child: Row(
              children: [
                if (onBack != null)
                  MiriaIconButton(
                    key: const ValueKey('go-selected-back'),
                    icon: Symbols.arrow_back_rounded,
                    tooltip: '返回当前目标',
                    onPressed: onBack,
                  )
                else
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Space.x2,
                      Space.x2,
                      Space.x2,
                      Space.x2,
                    ),
                    child: Sparkle(size: 16, color: c.spot),
                  ),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.labelLarge?.copyWith(
                      color: c.textSecondary,
                    ),
                  ),
                ),
                if (recordCount > 0) RecordCountTag(count: recordCount),
              ],
            ),
          ),
          ?overlapPager,
          MiriaPressable(
            onTap: actions.onOpenDetail,
            semanticLabel: '查看「${point.name}」的详情',
            borderRadius: BorderRadius.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (imageMaxHeight > 0)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Space.x3,
                      Space.x2,
                      Space.x3,
                      0,
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) => ClipRRect(
                        borderRadius: Radii.smAll,
                        child: SizedBox(
                          width: constraints.maxWidth,
                          height: math.min(
                            constraints.maxWidth * 9 / 16,
                            imageMaxHeight,
                          ),
                          child: PointReferenceImage(
                            point: point,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Space.x3,
                    Space.x3,
                    Space.x3,
                    0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              point.name,
                              key: const ValueKey('go-card-name'),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              locale: MiriaFonts.japanese,
                              style: context.text.titleMedium,
                            ),
                          ),
                          if (selection) ...[
                            const SizedBox(width: Space.x2),
                            StatusBadge(status: status, compact: true),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        goPointMeta(point),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.bodySmall?.copyWith(
                          color: c.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(Space.x3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PointActionLayout(
                  oneRowMinWidth: 420,
                  navigation: SplitNavButton(
                    available: point.hasCoordinate,
                    onNavigate: actions.onNavigate,
                    onOpenExternal: actions.onOpenExternal,
                    inAppKey: const ValueKey('go-card-in-app-navigation'),
                    externalKey: const ValueKey('go-card-external-navigation'),
                  ),
                  buttons: [
                    MiriaButton.secondary(
                      key: const ValueKey('go-card-camera'),
                      label: '拍摄参考',
                      shortLabel: '拍摄',
                      icon: Symbols.photo_camera_rounded,
                      expand: true,
                      onPressed: actions.onCamera,
                    ),
                    MiriaButton(
                      key: const ValueKey('go-card-complete'),
                      variant: MiriaButtonVariant.tonal,
                      label: completionLabel(status),
                      shortLabel: status == VisitStatus.completed ? '取消' : '完成',
                      semanticLabel: completionLabel(status),
                      icon: completionIcon(status),
                      expand: true,
                      onPressed: actions.onToggleCompletion,
                    ),
                  ],
                ),
                if (actions.onSetCurrent case final onSetCurrent?) ...[
                  const SizedBox(height: Space.x2),
                  MiriaButton(
                    key: const ValueKey('go-card-set-current'),
                    variant: MiriaButtonVariant.tonal,
                    label: '设为当前目标',
                    shortLabel: '设为当前',
                    icon: Symbols.flag_rounded,
                    expand: true,
                    onPressed: onSetCurrent,
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

/// Shown instead of the current-target card when there is no target.
class GoNoTargetCard extends StatelessWidget {
  const GoNoTargetCard({required this.planComplete, super.key});

  final bool planComplete;

  @override
  Widget build(BuildContext context) {
    return InfoBanner(
      key: const ValueKey('go-no-target'),
      kind: planComplete ? InfoBannerKind.success : InfoBannerKind.info,
      icon: planComplete ? Symbols.celebration_rounded : Symbols.flag_rounded,
      title: planComplete ? '全部点位已完成' : '还没有当前目标',
      message: planComplete ? '可以在记录里回顾这次巡礼。' : '在列表中选择一个有坐标的点位，设为当前目标。',
    );
  }
}

/// A queue row: route line, thumbnail, name, work / episode, camera (with
/// record count) and 完成 / 取消完成.
class GoQueueRow extends StatelessWidget {
  const GoQueueRow({
    required this.point,
    required this.status,
    required this.recordCount,
    required this.isFirst,
    required this.isLast,
    required this.previousCompleted,
    required this.selected,
    required this.onTap,
    required this.onCamera,
    required this.onToggleCompletion,
    this.onSetCurrent,
    super.key,
  });

  final PilgrimagePoint point;
  final VisitStatus status;
  final int recordCount;
  final bool isFirst;
  final bool isLast;
  final bool previousCompleted;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onCamera;
  final VoidCallback onToggleCompletion;
  final VoidCallback? onSetCurrent;

  @override
  Widget build(BuildContext context) {
    final meta = goPointMeta(point);
    return ListRow(
      key: ValueKey('go-queue-row-${point.id}'),
      title: point.name,
      titleLocale: MiriaFonts.japanese,
      subtitle: point.hasCoordinate ? meta : '$meta · 坐标待补充',
      selected: selected,
      minHeight: 64,
      onTap: onTap,
      leading: PointThumbnail(point: point, size: 44),
      routeLine: RouteLine(
        status: status,
        isFirst: isFirst,
        isLast: isLast,
        previousCompleted: previousCompleted,
      ),
      semanticLabel:
          '${point.name}，${RouteLine.semanticsFor(status)}'
          '${recordCount > 0 ? '，$recordCount 条记录' : ''}',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          MiriaIconButton(
            key: ValueKey('go-queue-camera-${point.id}'),
            icon: Symbols.photo_camera_rounded,
            tooltip: '拍摄参考',
            compact: true,
            badgeCount: recordCount > 0 ? recordCount : null,
            onPressed: onCamera,
          ),
          MiriaIconButton(
            key: ValueKey('go-queue-complete-${point.id}'),
            icon: completionIcon(status),
            tooltip: completionLabel(status),
            compact: true,
            onPressed: onToggleCompletion,
          ),
        ],
      ),
      contextActions: [
        MenuAction(
          label: '查看详情',
          icon: Symbols.info_rounded,
          onSelected: onTap,
        ),
        if (onSetCurrent case final setCurrent?)
          MenuAction(
            label: '设为当前目标',
            icon: Symbols.flag_rounded,
            onSelected: setCurrent,
          ),
        MenuAction(
          label: completionLabel(status),
          icon: completionIcon(status),
          onSelected: onToggleCompletion,
        ),
        MenuAction(
          label: '拍摄参考',
          icon: Symbols.photo_camera_rounded,
          onSelected: onCamera,
        ),
      ],
    );
  }
}
