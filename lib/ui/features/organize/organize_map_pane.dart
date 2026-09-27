import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../application/organize/group_assign_service.dart';
import '../../../application/organize/organize_service.dart';
import '../../../plan/pilgrimage_models.dart';
import '../../../plan/plan_group_utils.dart';
import '../../components/components.dart';
import '../../map/map.dart';
import 'assign_widgets.dart';
import 'box_assign_page.dart';
import 'organize_common.dart';

/// Map pane of the wide 片区与点位 layout: every group area and key point,
/// all point markers, and 框选分配 directly on the map.
class OrganizeMapPane extends StatefulWidget {
  const OrganizeMapPane({
    required this.controller,
    required this.plan,
    required this.buckets,
    required this.statusOf,
    required this.service,
    required this.focusedGroupId,
    required this.selectedPointId,
    required this.onPointTap,
    required this.onGroupTap,
    required this.boxMode,
    required this.onBoxModeChanged,
    super.key,
  });

  final PlanMapController controller;
  final PilgrimagePlan plan;
  final List<PlanGroupBucket> buckets;
  final VisitStatus Function(PilgrimagePoint point) statusOf;
  final OrganizeService service;
  final String? focusedGroupId;
  final String? selectedPointId;
  final ValueChanged<PilgrimagePoint> onPointTap;
  final ValueChanged<String> onGroupTap;
  final bool boxMode;
  final ValueChanged<bool> onBoxModeChanged;

  @override
  State<OrganizeMapPane> createState() => _OrganizeMapPaneState();
}

class _OrganizeMapPaneState extends State<OrganizeMapPane> {
  final BoxSelectController _box = BoxSelectController();
  String? _targetGroupId;
  bool _boxSelecting = true;

  @override
  void initState() {
    super.initState();
    _box.addListener(_changed);
  }

  @override
  void didUpdateWidget(covariant OrganizeMapPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.boxMode != oldWidget.boxMode) {
      _box.clear();
      _boxSelecting = true;
    }
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _box
      ..removeListener(_changed)
      ..dispose();
    super.dispose();
  }

  Future<void> _pickTarget(PilgrimagePlanGroup? current) async {
    final id = await pickBoxAssignTarget(context, current: current);
    if (id == null || !mounted) return;
    setState(() => _targetGroupId = id);
  }

  Future<void> _assign(
    PilgrimagePlanGroup? target,
    List<PilgrimagePoint> points,
  ) async {
    final done = await confirmBoxAssign(
      context,
      service: widget.service,
      target: target,
      points: points,
    );
    if (done && mounted) _box.clear();
  }

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    final colors = context.colors;
    final anchors = groupAnchorsFor(widget.buckets, plan.points, colors);
    final positioned = [
      for (final point in plan.points)
        if (point.hasCoordinate) point.position,
    ];
    final boxMode = widget.boxMode;
    final target = boxTargetGroup(plan, _targetGroupId);
    final boxed = boxMode
        ? boxSelectedPoints(plan, _box.bounds)
        : const <PilgrimagePoint>[];
    final boxedIds = {for (final point in boxed) point.id};
    final ungrouped = boxMode
        ? unassignedPositionedPoints(plan)
        : const <PilgrimagePoint>[];
    final saving = widget.service.isSaving;

    return Stack(
      fit: StackFit.expand,
      children: [
        PlanMap(
          key: const ValueKey('organize-map'),
          controller: widget.controller,
          initialFitPoints: positioned.isEmpty
              ? [for (final anchor in anchors) anchor.position]
              : positioned,
          disableTiles: OrganizeDebug.disableMapTiles,
          layers: [
            GroupHullLayer(
              groups: widget.buckets,
              selectedGroupId: widget.focusedGroupId,
            ),
          ],
          children: [
            if (boxMode)
              assignPointMarkerLayer(
                context,
                points: ungrouped,
                highlighted: (point) => boxedIds.contains(point.id),
                highlightedTooltip: '已框选',
                mutedTooltip: '未框选',
                selectedId: null,
                onTap: null,
              )
            else
              planPointMarkerLayer(
                key: const ValueKey('organize-map-points'),
                points: plan.points,
                statusOf: widget.statusOf,
                groups: widget.buckets,
                selectedId: widget.selectedPointId,
                colorPendingByGroup: true,
                onTap: widget.onPointTap,
              ),
            AnchorMarkerLayer(
              anchors: anchors,
              selectedGroupId: widget.focusedGroupId,
              onTap: boxMode
                  ? null
                  : (anchor) => widget.onGroupTap(anchor.groupId),
            ),
            BoxSelectLayer(active: boxMode && _boxSelecting, controller: _box),
          ],
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(Space.x3),
            child: Align(
              alignment: AlignmentDirectional.topStart,
              child: boxMode
                  ? ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: MapToolLayout.maxCardWidth,
                      ),
                      child: BoxAssignPanel(
                        targetGroup: target,
                        selectedCount: boxed.length,
                        ungroupedCount: ungrouped.length,
                        isBoxSelecting: _boxSelecting,
                        isSaving: saving,
                        onPickGroup: () => unawaited(_pickTarget(target)),
                        onToggleBoxSelection: () => setState(() {
                          _boxSelecting = !_boxSelecting;
                          _box.clear();
                        }),
                        onAssign: () => unawaited(_assign(target, boxed)),
                        onClose: () => widget.onBoxModeChanged(false),
                      ),
                    )
                  : MapControlButton(
                      key: const ValueKey('organize-map-box-assign'),
                      tooltip: '框选分配',
                      icon: Symbols.select_rounded,
                      onPressed: () => widget.onBoxModeChanged(true),
                    ),
            ),
          ),
        ),
        PositionedDirectional(
          end: Space.x3,
          bottom: Space.x6,
          child: MapControls(mapController: widget.controller),
        ),
      ],
    );
  }
}
