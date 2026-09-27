import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../application/organize/group_assign_service.dart';
import '../../../application/organize/organize_service.dart';
import '../../../application/plan_session.dart';
import '../../../plan/pilgrimage_models.dart';
import '../../../plan/plan_group_utils.dart';
import '../../app/toast.dart';
import '../../components/components.dart';
import '../../map/map.dart';
import '../points/point_detail_entry.dart';
import 'assign_widgets.dart';
import 'group_picker.dart';
import 'organize_common.dart';

/// Opens the target-group picker of 框选分配. A group created through
/// 「新建片区」 is returned as the new target (old `_createGroup`).
Future<String?> pickBoxAssignTarget(
  BuildContext context, {
  required PilgrimagePlanGroup? current,
}) {
  final count = context.read<PlanSession>().plan.groups.length;
  return pickGroup(
    context,
    title: '选择片区',
    subtitle: '共 $count 个片区',
    subtitleBuilder: (plan) => '共 ${plan.groups.length} 个片区',
    selectedGroupId: current?.id,
    includeUngrouped: false,
    selectCreated: true,
  );
}

/// Confirms and runs 框选分配 of [points] into [target] (old
/// `_confirmAssignBox`). Returns true when the points were moved.
Future<bool> confirmBoxAssign(
  BuildContext context, {
  required OrganizeService service,
  required PilgrimagePlanGroup? target,
  required List<PilgrimagePoint> points,
}) async {
  if (service.isSaving) return false;
  if (target == null) {
    context.showToast('请先创建片区', kind: ToastKind.warning);
    return false;
  }
  if (points.isEmpty) {
    context.showToast('框选范围内没有未分组点位', kind: ToastKind.warning);
    return false;
  }
  final count = points.length;
  final confirmed = await showConfirmDialog(
    context,
    title: '确认框选分配',
    message: '将把 $count 个未分组点位移动到「${target.name}」。',
    confirmLabel: '分配',
    emphasizedValues: ['$count 个未分组点位', target.name],
  );
  if (!confirmed || !context.mounted) return false;
  final moved = await runOrganizeWrite(
    context,
    () => service.assignBox({for (final point in points) point.id}, target.id),
  );
  if (moved != true || !context.mounted) return false;
  context.showToast('已分配 $count 个点位');
  return true;
}

/// 框选分配 (`/plan/organize/assign/box`, DESIGN §8.10): drag a box over
/// ungrouped points and move them into one group.
class BoxAssignPage extends StatefulWidget {
  const BoxAssignPage({super.key});

  @override
  State<BoxAssignPage> createState() => _BoxAssignPageState();
}

class _BoxAssignPageState extends State<BoxAssignPage> {
  late final OrganizeService _service;
  final PlanMapController _map = PlanMapController();
  final BoxSelectController _box = BoxSelectController();
  String? _targetGroupId;
  String? _selectedPointId;
  bool _boxSelecting = false;

  @override
  void initState() {
    super.initState();
    _service = OrganizeService(session: context.read<PlanSession>())
      ..addListener(_changed);
    _box.addListener(_changed);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _service
      ..removeListener(_changed)
      ..dispose();
    _box
      ..removeListener(_changed)
      ..dispose();
    _map.dispose();
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
      service: _service,
      target: target,
      points: points,
    );
    if (!done || !mounted) return;
    _box.clear();
    setState(() => _selectedPointId = null);
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<PlanSession>();
    if (!session.isReady) {
      return const MiriaPageScaffold(
        title: '框选分配',
        body: Center(child: ProgressRing()),
      );
    }
    final plan = session.plan;
    final colors = context.colors;
    final ungrouped = unassignedPositionedPoints(plan);
    final target = boxTargetGroup(plan, _targetGroupId);
    final boxed = boxSelectedPoints(plan, _box.bounds);
    final boxedIds = {for (final point in boxed) point.id};
    final buckets = planGroupBuckets(
      plan,
      session.controller.completedPointIds,
    );
    final anchors = groupAnchorsFor(buckets, plan.points, colors);
    final selected = ungrouped
        .where((point) => point.id == _selectedPointId)
        .firstOrNull;
    final saving = _service.isSaving;

    final Widget bottom = selected == null
        ? AssignHintCard(
            message: plan.groups.isEmpty
                ? '请先在片区管理中设置关键点'
                : '未分组 ${ungrouped.length} 个 · 点击地图点位查看详情',
          )
        : AssignPointCard(
            planId: plan.id,
            point: selected,
            groupLine: target == null ? '没有可用片区关键点' : target.name,
            assignable: boxedIds.contains(selected.id),
            assignableLabel: '已框选',
            unassignableLabel: '未框选',
            onOpenDetail: () => showPointDetail(
              context,
              pointId: selected.id,
              scope: PointDetailScope.assign,
            ),
          );

    return PopScope(
      canPop: !saving,
      child: MiriaPageScaffold(
        title: '框选分配',
        body: MapToolLayout(
          map: PlanMap(
            controller: _map,
            initialCenter: assignMapCenter(ungrouped, [
              for (final anchor in anchors) anchor.position,
            ]),
            initialFitPoints: [
              for (final point in ungrouped) point.position,
              for (final anchor in anchors) anchor.position,
            ],
            initialZoom: 14.5,
            initialFitMaxZoom: 15,
            initialFitPadding: kAssignMapFitPadding,
            disableTiles: OrganizeDebug.disableMapTiles,
            children: [
              AnchorMarkerLayer(anchors: anchors),
              assignPointMarkerLayer(
                context,
                points: ungrouped,
                highlighted: (point) => boxedIds.contains(point.id),
                highlightedTooltip: '已框选',
                mutedTooltip: '未框选',
                selectedId: _selectedPointId,
                onTap: _boxSelecting
                    ? null
                    : (point) => setState(() => _selectedPointId = point.id),
              ),
              BoxSelectLayer(active: _boxSelecting, controller: _box),
            ],
          ),
          top: BoxAssignPanel(
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
          ),
          bottom: bottom,
        ),
      ),
    );
  }
}
