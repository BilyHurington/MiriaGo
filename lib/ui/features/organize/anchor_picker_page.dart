import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' show MarkerLayer;
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../../application/organize/organize_service.dart';
import '../../../application/organize/organize_view.dart';
import '../../../application/plan_session.dart';
import '../../../application/settings_store.dart';
import '../../../map/map_marker_scale.dart';
import '../../../plan/pilgrimage_models.dart';
import '../../../plan/plan_group_utils.dart';
import '../../components/components.dart';
import '../../map/map.dart';
import 'location_picker.dart';
import 'organize_common.dart';

/// Result of the key-point picker (old `GroupAnchorSelection`): a plan
/// point (name, position, id), a map position (「手动关键点」, id null) or
/// nothing (cleared, Δ6).
@immutable
class GroupAnchorSelection {
  const GroupAnchorSelection({
    required this.name,
    required this.position,
    required this.pointId,
  });

  const GroupAnchorSelection.clear()
    : name = null,
      position = null,
      pointId = null;

  factory GroupAnchorSelection.point(PilgrimagePoint point) =>
      GroupAnchorSelection(
        name: point.name,
        position: point.position,
        pointId: point.id,
      );

  factory GroupAnchorSelection.manual(LatLng position) =>
      GroupAnchorSelection(name: '手动关键点', position: position, pointId: null);

  /// The stored key point of [group] (a linked point wins over the stored
  /// coordinates, like the old picker).
  factory GroupAnchorSelection.of(
    PilgrimagePlanGroup group,
    List<PilgrimagePoint> points,
  ) {
    final anchorPointId = group.anchorPointId;
    if (anchorPointId != null) {
      for (final point in points) {
        if (point.id == anchorPointId && point.hasCoordinate) {
          return GroupAnchorSelection.point(point);
        }
      }
    }
    final latitude = group.anchorLatitude;
    final longitude = group.anchorLongitude;
    if (latitude != null && longitude != null) {
      return GroupAnchorSelection(
        name: group.anchorName ?? '手动关键点',
        position: LatLng(latitude, longitude),
        pointId: null,
      );
    }
    return const GroupAnchorSelection.clear();
  }

  final String? name;
  final LatLng? position;
  final String? pointId;

  bool get isEmpty => position == null;

  @override
  bool operator ==(Object other) =>
      other is GroupAnchorSelection &&
      other.name == name &&
      other.position == position &&
      other.pointId == pointId;

  @override
  int get hashCode => Object.hash(name, position, pointId);
}

/// 选择关键点 (`/plan/organize/anchor/:groupId`, DESIGN §8.10).
///
/// Pick a plan point (the map zooms to 16), use the centre crosshair for
/// any place (「手动关键点」, Δ5) or type coordinates. The key point can be
/// cleared and the cleared state saved (Δ6).
class AnchorPickerPage extends StatefulWidget {
  const AnchorPickerPage({required this.groupId, super.key});
  final String groupId;

  @override
  State<AnchorPickerPage> createState() => _AnchorPickerPageState();
}

class _AnchorPickerPageState extends State<AnchorPickerPage> {
  late final OrganizeService _service;
  final PlanMapController _map = PlanMapController();
  GroupAnchorSelection? _selection;
  GroupAnchorSelection? _original;
  LatLng? _center;

  @override
  void initState() {
    super.initState();
    _service = OrganizeService(session: context.read<PlanSession>())
      ..addListener(_changed);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _service
      ..removeListener(_changed)
      ..dispose();
    _map.dispose();
    super.dispose();
  }

  PilgrimagePlanGroup? _group(PilgrimagePlan plan) =>
      plan.groups.where((group) => group.id == widget.groupId).firstOrNull;

  void _selectPoint(PilgrimagePoint point) {
    setState(() => _selection = GroupAnchorSelection.point(point));
    unawaited(_map.moveTo(point.position, zoom: 16));
  }

  void _useCrosshair() {
    final center = _center ?? _map.visibleCenter;
    if (center == null) return;
    setState(() => _selection = GroupAnchorSelection.manual(center));
  }

  Future<void> _inputCoordinates(LatLng fallback) async {
    final current = _selection?.position ?? _center ?? fallback;
    final result = await showCoordinateInputDialog(context, initial: current);
    if (result == null || !mounted) return;
    setState(() => _selection = GroupAnchorSelection.manual(result));
    unawaited(_map.moveTo(result, zoom: 16));
  }

  Future<void> _confirmClear() async {
    final confirmed = await showConfirmDialog(
      context,
      title: '清除选点',
      message: '将清除当前选择的关键点，可继续在本页重新选择。',
      confirmLabel: '清除选点',
    );
    if (!confirmed || !mounted) return;
    setState(() => _selection = const GroupAnchorSelection.clear());
  }

  Future<void> _save(PilgrimagePlanGroup group) async {
    final selection = _selection ?? const GroupAnchorSelection.clear();
    final saved = await runOrganizeWrite(
      context,
      () => _service.setAnchor(
        group,
        name: selection.name,
        position: selection.position,
        pointId: selection.pointId,
      ),
    );
    if (saved == true && mounted) {
      if (context.canPop()) {
        context.pop();
      } else {
        Navigator.of(context).maybePop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<PlanSession>();
    if (!session.isReady) {
      return const MiriaPageScaffold(
        title: '选择关键点',
        body: Center(child: ProgressRing()),
      );
    }
    final plan = session.plan;
    final group = _group(plan);
    if (group == null) {
      return const MiriaPageScaffold(
        title: '选择关键点',
        body: EmptyState(title: '片区不存在。', icon: Symbols.folder_off_rounded),
      );
    }
    final original = _original ??= GroupAnchorSelection.of(group, plan.points);
    final selection = _selection ??= original;
    final points = plan.points
        .where((point) => point.hasCoordinate)
        .toList(growable: false);
    final fallback = averagePointPosition(points) ?? kPickerFallbackCenter;
    final saving = _service.isSaving;
    final changed = selection != original;
    final c = context.colors;
    final scale = normalizedMapMarkerScale(
      context.select<SettingsStore, double>(
        (store) => store.settings.mapMarkerScale,
      ),
    );
    final buckets = planGroupBuckets(
      plan,
      session.controller.completedPointIds,
    );

    return PopScope(
      canPop: !saving,
      child: MiriaPageScaffold(
        title: '选择关键点',
        subtitle: group.name,
        actions: [
          MiriaIconButton(
            key: const ValueKey('anchor-picker-input'),
            icon: Symbols.edit_location_alt_rounded,
            tooltip: '输入经纬度',
            onPressed: saving ? null : () => _inputCoordinates(fallback),
          ),
          MiriaIconButton(
            key: const ValueKey('anchor-picker-clear'),
            icon: Symbols.close_rounded,
            tooltip: '清除选点',
            onPressed: selection.isEmpty || saving ? null : _confirmClear,
          ),
        ],
        body: CenterPinPicker(
          controller: _map,
          initialCenter: selection.position ?? fallback,
          initialZoom: 15,
          pinColor: c.spot,
          disableTiles: OrganizeDebug.disableMapTiles,
          onChanged: (value) => _center = value,
          children: [
            planPointMarkerLayer(
              key: const ValueKey('anchor-picker-points'),
              points: points,
              statusOf: session.controller.statusFor,
              groups: buckets,
              selectedId: selection.pointId,
              onTap: _selectPoint,
            ),
            if (!selection.isEmpty && selection.pointId == null)
              MarkerLayer(
                markers: [
                  AnchorMarker.marker(
                    key: const ValueKey('anchor-picker-manual'),
                    point: selection.position!,
                    scale: scale,
                    child: AnchorMarker(
                      color: c.warning,
                      name: selection.name,
                      selected: true,
                    ),
                  ),
                ],
              ),
          ],
        ),
        bottomBar: _AnchorSelectionBar(
          selection: selection,
          subtitle: selection.pointId == null
              ? null
              : () {
                  final point = plan.points
                      .where((candidate) => candidate.id == selection.pointId)
                      .firstOrNull;
                  return point == null
                      ? null
                      : '${groupNameForPoint(plan, point)} / ${point.subtitle}';
                }(),
          saving: saving,
          canSave: changed || !selection.isEmpty,
          onUseCrosshair: _useCrosshair,
          onSave: () => _save(group),
        ),
      ),
    );
  }
}

class _AnchorSelectionBar extends StatelessWidget {
  const _AnchorSelectionBar({
    required this.selection,
    required this.subtitle,
    required this.saving,
    required this.canSave,
    required this.onUseCrosshair,
    required this.onSave,
  });

  final GroupAnchorSelection selection;
  final String? subtitle;
  final bool saving;
  final bool canSave;
  final VoidCallback onUseCrosshair;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = context.text;
    final position = selection.position;
    final title = selection.isEmpty
        ? '尚未选择关键点'
        : (selection.pointId == null ? '手动关键点' : selection.name ?? '手动关键点');
    final detail = selection.isEmpty ? '可点选点位、把准星对准地图位置或输入经纬度' : subtitle;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Symbols.flag_rounded, color: c.primary, size: 28, fill: 1),
            const SizedBox(width: Space.x3),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    key: const ValueKey('anchor-picker-title'),
                    locale: selection.pointId == null
                        ? null
                        : MiriaFonts.japanese,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: text.titleSmall,
                  ),
                  if (detail != null && detail.isNotEmpty)
                    Text(
                      detail,
                      locale: MiriaFonts.japanese,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall?.copyWith(color: c.textSecondary),
                    ),
                  if (position != null)
                    Text(
                      formatLatLng(position),
                      style: text.caption.copyWith(
                        color: c.textSecondary,
                        fontFeatures: MiriaFonts.tabular,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: Space.x3),
        Row(
          children: [
            Expanded(
              child: MiriaButton.secondary(
                key: const ValueKey('anchor-picker-crosshair'),
                label: '使用准星位置',
                shortLabel: '准星',
                icon: Symbols.my_location_rounded,
                size: MiriaButtonSize.md,
                expand: true,
                onPressed: saving ? null : onUseCrosshair,
              ),
            ),
            const SizedBox(width: Space.x2),
            Expanded(
              child: MiriaButton(
                key: const ValueKey('anchor-picker-save'),
                label: '保存',
                icon: Symbols.check_rounded,
                size: MiriaButtonSize.md,
                expand: true,
                loading: saving,
                onPressed: canSave && !saving ? onSave : null,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
