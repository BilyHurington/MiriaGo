import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../../application/organize/group_assign_service.dart';
import '../../../application/settings_store.dart';
import '../../../data/pilgrimage_repository.dart';
import '../../../map/map_marker_scale.dart';
import '../../../plan/pilgrimage_models.dart';
import '../../../widgets/auto_caching_reference_thumbnail.dart';
import '../../components/components.dart';
import '../../map/map.dart';
import 'organize_common.dart';

/// Initial camera padding of the assignment maps (room for the cards).
const EdgeInsets kAssignMapFitPadding = EdgeInsets.fromLTRB(48, 220, 48, 140);

/// Markers of the ungrouped points in an assignment tool. [highlighted]
/// points (assignable / inside the box) use the primary style, others the
/// muted one.
MarkerLayer assignPointMarkerLayer(
  BuildContext context, {
  required List<PilgrimagePoint> points,
  required bool Function(PilgrimagePoint point) highlighted,
  required String? selectedId,
  required ValueChanged<PilgrimagePoint>? onTap,
  String highlightedTooltip = '可分配点位',
  String mutedTooltip = '距离外点位',
}) {
  final colors = context.colors;
  final scale = normalizedMapMarkerScale(
    context.select<SettingsStore, double>(
      (store) => store.settings.mapMarkerScale,
    ),
  );
  // Selected marker last so it is drawn on top.
  final ordered = [
    for (final point in points)
      if (point.id != selectedId) point,
    for (final point in points)
      if (point.id == selectedId) point,
  ];
  return MarkerLayer(
    markers: [
      for (final point in ordered)
        PointMarker.marker(
          key: ValueKey('assign-marker-${point.id}'),
          point: point.position,
          scale: scale,
          child: PointMarker(
            kind: PointMarkerKind.pending,
            color: highlighted(point) ? colors.primary : colors.textTertiary,
            selected: point.id == selectedId,
            label: point.id == selectedId ? point.name : null,
            tooltip: highlighted(point) ? highlightedTooltip : mutedTooltip,
            onTap: onTap == null ? null : () => onTap(point),
          ),
        ),
    ],
  );
}

/// Bottom card of an assignment tool when no point is selected.
class AssignHintCard extends StatelessWidget {
  const AssignHintCard({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return MapToolCard(
      child: Text(
        message,
        key: const ValueKey('assign-hint'),
        textAlign: TextAlign.center,
        style: context.text.labelLarge?.copyWith(
          color: context.colors.textSecondary,
        ),
      ),
    );
  }
}

/// Bottom card for the selected point of an assignment tool: reference
/// thumbnail, name, the nearest / target group line and whether it would be
/// assigned. Tapping opens the point details.
class AssignPointCard extends StatelessWidget {
  const AssignPointCard({
    required this.planId,
    required this.point,
    required this.groupLine,
    required this.assignable,
    required this.onOpenDetail,
    this.assignableLabel = '在最大距离范围内',
    this.unassignableLabel = '超出最大距离',
    super.key,
  });

  final String planId;
  final PilgrimagePoint point;

  /// 「宇治站附近 · 320 m」 or 「没有可用片区关键点」.
  final String groupLine;
  final bool assignable;
  final VoidCallback onOpenDetail;
  final String assignableLabel;
  final String unassignableLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = context.text;
    final tone = assignable ? c.primaryText : c.warning;
    return MapToolCard(
      key: const ValueKey('assign-point-card'),
      onTap: onOpenDetail,
      child: Row(
        children: [
          ClipRRect(
            borderRadius: Radii.smAll,
            child: SizedBox.square(
              dimension: 56,
              child: ColoredBox(
                color: c.surfaceMuted,
                child: AutoCachingReferenceThumbnail(
                  key: ValueKey('$planId:${point.id}'),
                  planId: planId,
                  point: point,
                  repository: context.read<PilgrimageRepository>(),
                  placeholder: Icon(
                    Symbols.image_rounded,
                    color: c.textTertiary,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: Space.x3),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  point.name,
                  locale: MiriaFonts.japanese,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  groupLine,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall?.copyWith(color: c.textSecondary),
                ),
                const SizedBox(height: 2),
                Text(
                  assignable ? assignableLabel : unassignableLabel,
                  key: const ValueKey('assign-point-status'),
                  style: text.labelMedium?.copyWith(color: tone),
                ),
              ],
            ),
          ),
          const SizedBox(width: Space.x2),
          Icon(
            assignable ? Symbols.check_circle_rounded : Symbols.info_rounded,
            color: tone,
            size: 22,
          ),
        ],
      ),
    );
  }
}

/// Control card of 最近分配 (old `_NearestAssignPanel`).
class NearestAssignPanel extends StatelessWidget {
  const NearestAssignPanel({
    required this.distanceMeters,
    required this.assignableCount,
    required this.ungroupedCount,
    required this.groupCount,
    required this.isSaving,
    required this.onDistanceChanged,
    required this.onAssign,
    super.key,
  });

  final double distanceMeters;
  final int assignableCount;
  final int ungroupedCount;
  final int groupCount;
  final bool isSaving;
  final ValueChanged<double> onDistanceChanged;
  final VoidCallback onAssign;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = context.text;
    final distance = formatAssignDistance(distanceMeters);
    return MapToolCard(
      key: const ValueKey('nearest-assign-panel'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            spacing: Space.x2,
            runSpacing: Space.x1,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Symbols.auto_awesome_rounded,
                    size: 20,
                    color: c.primary,
                  ),
                  const SizedBox(width: Space.x2),
                  Flexible(
                    child: Text(
                      '最大距离 $distance',
                      key: const ValueKey('nearest-assign-distance'),
                      style: text.titleSmall?.copyWith(
                        fontFeatures: MiriaFonts.tabular,
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                '可分配 $assignableCount/$ungroupedCount',
                key: const ValueKey('nearest-assign-count'),
                style: text.labelMedium?.copyWith(
                  color: c.textSecondary,
                  fontFeatures: MiriaFonts.tabular,
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.x1),
          Text(
            '未分组点位会分配到距离最近、且在最大距离范围内的片区关键点。',
            style: text.caption.copyWith(color: c.textSecondary),
          ),
          const SizedBox(height: Space.x2),
          Row(
            children: [
              Expanded(
                child: Text(
                  '当前 $distance',
                  style: text.caption.copyWith(
                    color: c.primaryText,
                    fontWeight: FontWeight.w600,
                    fontFeatures: MiriaFonts.tabular,
                  ),
                ),
              ),
              const SizedBox(width: Space.x2),
              Text(
                '50 m - 5 km',
                style: text.caption.copyWith(color: c.textSecondary),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: Slider(
                  key: const ValueKey('nearest-assign-slider'),
                  value: clampNearestAssignDistance(distanceMeters),
                  min: kNearestAssignMinMeters,
                  max: kNearestAssignMaxMeters,
                  divisions: kNearestAssignDivisions,
                  label: distance,
                  semanticFormatterCallback: formatAssignDistance,
                  onChanged: isSaving ? null : onDistanceChanged,
                ),
              ),
              const SizedBox(width: Space.x2),
              MiriaButton(
                key: const ValueKey('nearest-assign-submit'),
                label: isSaving ? '分配中' : '分配',
                size: MiriaButtonSize.sm,
                loading: isSaving,
                onPressed: isSaving || groupCount == 0 ? null : onAssign,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Control card of 框选分配 (old `_BoxAssignPanel`).
class BoxAssignPanel extends StatelessWidget {
  const BoxAssignPanel({
    required this.targetGroup,
    required this.selectedCount,
    required this.ungroupedCount,
    required this.isBoxSelecting,
    required this.isSaving,
    required this.onPickGroup,
    required this.onToggleBoxSelection,
    required this.onAssign,
    this.onClose,
    super.key,
  });

  final PilgrimagePlanGroup? targetGroup;
  final int selectedCount;
  final int ungroupedCount;
  final bool isBoxSelecting;
  final bool isSaving;
  final VoidCallback onPickGroup;
  final VoidCallback onToggleBoxSelection;
  final VoidCallback onAssign;

  /// Shows a close button (inline mode on the organize map).
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = context.text;
    return MapToolCard(
      key: const ValueKey('box-assign-panel'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: MiriaPressable(
                  key: const ValueKey('box-assign-group-picker'),
                  onTap: isSaving ? null : onPickGroup,
                  borderRadius: Radii.smAll,
                  semanticLabel: '目标片区：${targetGroup?.name ?? '选择片区'}',
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 40),
                    padding: const EdgeInsets.symmetric(
                      horizontal: Space.x3,
                      vertical: Space.x2,
                    ),
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: Radii.smAll,
                      border: Border.all(color: c.hairlineStrong),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Symbols.folder_rounded,
                          size: 20,
                          color: c.textSecondary,
                        ),
                        const SizedBox(width: Space.x2),
                        Expanded(
                          child: Text(
                            targetGroup?.name ?? '选择片区',
                            locale: targetGroup == null
                                ? null
                                : MiriaFonts.japanese,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.titleSmall,
                          ),
                        ),
                        Icon(
                          Symbols.expand_more_rounded,
                          size: 20,
                          color: c.textSecondary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: Space.x2),
              MiriaButton.secondary(
                key: const ValueKey('box-assign-toggle'),
                label: isBoxSelecting ? '结束框选' : '框选',
                shortLabel: isBoxSelecting ? '结束' : '框选',
                semanticLabel: isBoxSelecting ? '结束框选' : '开始框选',
                icon: isBoxSelecting
                    ? Symbols.close_rounded
                    : Symbols.select_rounded,
                size: MiriaButtonSize.sm,
                onPressed: isSaving ? null : onToggleBoxSelection,
              ),
              if (onClose != null) ...[
                const SizedBox(width: Space.x1),
                MiriaIconButton(
                  key: const ValueKey('box-assign-close'),
                  icon: Symbols.close_rounded,
                  tooltip: '关闭框选分配',
                  compact: true,
                  onPressed: isSaving ? null : onClose,
                ),
              ],
            ],
          ),
          const SizedBox(height: Space.x2),
          Row(
            children: [
              Expanded(
                child: Text(
                  '已框选 $selectedCount / 待分配 $ungroupedCount',
                  key: const ValueKey('box-assign-count'),
                  style: text.labelMedium?.copyWith(
                    color: c.textSecondary,
                    fontFeatures: MiriaFonts.tabular,
                  ),
                ),
              ),
              const SizedBox(width: Space.x2),
              MiriaButton(
                key: const ValueKey('box-assign-submit'),
                label: isSaving ? '分配中' : '分配',
                semanticLabel: isSaving ? '正在分配' : '分配选中点位',
                icon: Symbols.drive_file_move_rounded,
                size: MiriaButtonSize.sm,
                loading: isSaving,
                onPressed: isSaving || targetGroup == null || selectedCount == 0
                    ? null
                    : onAssign,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
