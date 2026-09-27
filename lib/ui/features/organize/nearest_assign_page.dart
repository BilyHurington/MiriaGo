import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../application/organize/group_assign_service.dart';
import '../../../application/organize/organize_service.dart';
import '../../../application/plan_session.dart';
import '../../../application/settings_store.dart';
import '../../../plan/pilgrimage_models.dart';
import '../../../plan/plan_group_utils.dart';
import '../../app/toast.dart';
import '../../components/components.dart';
import '../../map/map.dart';
import '../points/point_detail_entry.dart';
import 'assign_widgets.dart';
import 'organize_common.dart';

/// 最近分配 (`/plan/organize/assign/nearest`, DESIGN §8.10): every ungrouped
/// point goes to the nearest group key point within the chosen distance.
class NearestAssignPage extends StatefulWidget {
  const NearestAssignPage({super.key});

  @override
  State<NearestAssignPage> createState() => _NearestAssignPageState();
}

class _NearestAssignPageState extends State<NearestAssignPage> {
  late final OrganizeService _service;
  final PlanMapController _map = PlanMapController();
  late double _distance;
  String? _selectedPointId;
  NearestGroupAssigner? _assigner;

  @override
  void initState() {
    super.initState();
    _service = OrganizeService(session: context.read<PlanSession>())
      ..addListener(_onServiceChanged);
    _distance = clampNearestAssignDistance(
      context.read<SettingsStore>().settings.nearestAssignDistanceMeters,
    );
  }

  void _onServiceChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _service
      ..removeListener(_onServiceChanged)
      ..dispose();
    _map.dispose();
    super.dispose();
  }

  NearestGroupAssigner _assignerFor(PilgrimagePlan plan) {
    final current = _assigner;
    if (current != null && identical(current.plan, plan)) return current;
    return _assigner = NearestGroupAssigner(plan);
  }

  Future<void> _confirmAssign(NearestGroupAssigner assigner) async {
    if (_service.isSaving) return;
    final distance = _distance;
    final assignments = assigner.groupIdsByPointId(distance);
    final count = assignments.length;
    if (count == 0) {
      context.showToast('当前距离内没有可分配点位', kind: ToastKind.warning);
      return;
    }
    final confirmed = await showConfirmDialog(
      context,
      title: '确认最近分配',
      message:
          '将把 $count 个未分组点位分配到最近的片区关键点，最大距离为 ${formatAssignDistance(distance)}。',
      confirmLabel: '开始分配',
      emphasizedValues: ['$count 个未分组点位'],
    );
    if (!confirmed || !mounted) return;
    final settings = context.read<SettingsStore>();
    final result = await runOrganizeWrite(
      context,
      () => _service.assignNearest(
        assignments,
        saveDistance: () => settings.patch(
          (current) => current.copyWith(nearestAssignDistanceMeters: distance),
        ),
      ),
    );
    if (!mounted) return;
    setState(() => _selectedPointId = null);
    if (result == null) return;
    context.showToast(
      result.settingsSaved
          ? '已分配 ${result.count} 个点位'
          : '已分配 ${result.count} 个点位，距离设置未保存',
      kind: result.settingsSaved ? ToastKind.success : ToastKind.warning,
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<PlanSession>();
    if (!session.isReady) {
      return const MiriaPageScaffold(
        title: '最近分配',
        body: Center(child: ProgressRing()),
      );
    }
    final plan = session.plan;
    final colors = context.colors;
    final assigner = _assignerFor(plan);
    final buckets = planGroupBuckets(
      plan,
      session.controller.completedPointIds,
    );
    final targetIds = {for (final group in assigner.targetGroups) group.id};
    final anchors = [
      for (final anchor in groupAnchorsFor(buckets, plan.points, colors))
        if (targetIds.contains(anchor.groupId)) anchor,
    ];
    final selected = assigner.ungroupedPoints
        .where((point) => point.id == _selectedPointId)
        .firstOrNull;
    final saving = _service.isSaving;

    Widget bottom;
    if (selected == null) {
      bottom = AssignHintCard(
        message: assigner.targetGroups.isEmpty
            ? '请先在片区管理中设置关键点'
            : '未分组 ${assigner.ungroupedPoints.length} 个 · 点击地图点位查看详情',
      );
    } else {
      final group = assigner.nearestGroupFor(selected);
      bottom = AssignPointCard(
        planId: plan.id,
        point: selected,
        groupLine: group == null
            ? '没有可用片区关键点'
            : '${group.name} · ${formatAssignDistance(assigner.nearestDistanceFor(selected) ?? 0)}',
        assignable: assigner.isAssignable(selected, _distance),
        onOpenDetail: () => showPointDetail(
          context,
          pointId: selected.id,
          scope: PointDetailScope.assign,
        ),
      );
    }

    return PopScope(
      canPop: !saving,
      child: MiriaPageScaffold(
        title: '最近分配',
        body: MapToolLayout(
          map: PlanMap(
            controller: _map,
            initialCenter: assigner.mapCenter,
            initialFitPoints: [
              for (final point in assigner.ungroupedPoints) point.position,
              for (final anchor in anchors) anchor.position,
            ],
            initialZoom: 14.5,
            initialFitMaxZoom: 15,
            initialFitPadding: kAssignMapFitPadding,
            disableTiles: OrganizeDebug.disableMapTiles,
            onTap: (_) {
              if (_selectedPointId != null) {
                setState(() => _selectedPointId = null);
              }
            },
            layers: [
              AnchorRadiusLayer(anchors: anchors, radiusMeters: _distance),
            ],
            children: [
              AnchorMarkerLayer(anchors: anchors),
              assignPointMarkerLayer(
                context,
                points: assigner.ungroupedPoints,
                highlighted: (point) => assigner.isAssignable(point, _distance),
                selectedId: _selectedPointId,
                onTap: (point) => setState(() => _selectedPointId = point.id),
              ),
            ],
          ),
          top: NearestAssignPanel(
            distanceMeters: _distance,
            assignableCount: assigner.assignableCount(_distance),
            ungroupedCount: assigner.ungroupedPoints.length,
            groupCount: assigner.targetGroups.length,
            isSaving: saving,
            onDistanceChanged: (value) => setState(() => _distance = value),
            onAssign: () => unawaited(_confirmAssign(assigner)),
          ),
          bottom: bottom,
        ),
      ),
    );
  }
}
