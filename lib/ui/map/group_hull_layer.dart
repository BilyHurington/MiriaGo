import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../application/settings_store.dart';
import '../../map/map_marker_scale.dart';
import '../../plan/pilgrimage_models.dart';
import '../../plan/plan_group_utils.dart';
import '../design/theme.dart';
import 'map_markers.dart';

/// Colour of the group bucket at [index] in a `planGroupBuckets` list.
/// The synthetic 「未分组」 bucket uses a neutral colour.
Color mapGroupColor(MiriaColors colors, PlanGroupBucket group, int index) =>
    group.isUngrouped ? colors.textTertiary : colors.groupColor(index);

/// Colour of the group [point] belongs to.
Color mapGroupColorForPoint(
  MiriaColors colors,
  List<PlanGroupBucket> groups,
  PilgrimagePoint point,
) {
  for (var index = 0; index < groups.length; index++) {
    final group = groups[index];
    if (point.groupId == null ? group.isUngrouped : point.groupId == group.id) {
      return mapGroupColor(colors, group, index);
    }
  }
  return colors.textTertiary;
}

/// One rounded area per plan group (DESIGN §6.8 片区范围).
///
/// Hulls come from `roundedGroupHull` with `mapGroupAreaRadiusMeters`
/// (or [radiusMeters]); colours from `context.colors.groupColor(index)`
/// where index is the bucket's position in [groups]. Fill 0.10 / stroke
/// 0.5; the [selectedGroupId] gets fill 0.18 and a thicker stroke.
/// Ungrouped points and groups without coordinates get no area.
///
/// Hulls are cached and only recomputed when point positions change.
class GroupHullLayer extends StatefulWidget {
  const GroupHullLayer({
    required this.groups,
    this.selectedGroupId,
    this.radiusMeters,
    this.visible = true,
    super.key,
  });

  /// Buckets from `planGroupBuckets` (plan order, 「未分组」 last).
  final List<PlanGroupBucket> groups;
  final String? selectedGroupId;
  final double? radiusMeters;
  final bool visible;

  @override
  State<GroupHullLayer> createState() => _GroupHullLayerState();
}

class _GroupHullLayerState extends State<GroupHullLayer> {
  final Map<String, (int, List<LatLng>)> _cache = {};

  List<LatLng> _hullFor(PlanGroupBucket group, double radius) {
    var signature = Object.hash(group.id, radius);
    for (final point in group.points) {
      if (!point.hasCoordinate) continue;
      signature = Object.hash(
        signature,
        point.position.latitude,
        point.position.longitude,
      );
    }
    final cached = _cache[group.id];
    if (cached != null && cached.$1 == signature) return cached.$2;
    final hull = roundedGroupHull(group.points, radiusMeters: radius);
    _cache[group.id] = (signature, hull);
    return hull;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.visible) return const SizedBox.shrink();
    final radius =
        widget.radiusMeters ??
        context
            .select<SettingsStore, int>(
              (store) => store.settings.mapGroupAreaRadiusMeters,
            )
            .toDouble();
    final colors = context.colors;
    final polygons = <Polygon>[];
    final live = <String>{};
    Polygon? selected;
    for (var index = 0; index < widget.groups.length; index++) {
      final group = widget.groups[index];
      if (group.isUngrouped ||
          !group.points.any((point) => point.hasCoordinate)) {
        continue;
      }
      live.add(group.id);
      final hull = _hullFor(group, radius);
      if (hull.length < 3) continue;
      final color = mapGroupColor(colors, group, index);
      final isSelected = group.id == widget.selectedGroupId;
      final polygon = Polygon(
        points: hull,
        color: color.withValues(alpha: isSelected ? 0.18 : 0.10),
        borderColor: color.withValues(alpha: isSelected ? 0.85 : 0.5),
        borderStrokeWidth: isSelected ? 3 : 1.5,
      );
      if (isSelected) {
        selected = polygon;
      } else {
        polygons.add(polygon);
      }
    }
    _cache.removeWhere((id, _) => !live.contains(id));
    return PolygonLayer(
      simplificationTolerance: 0,
      polygons: [...polygons, ?selected],
    );
  }
}

/// Resolved key point of a group.
@immutable
class GroupAnchor {
  const GroupAnchor({
    required this.groupId,
    required this.name,
    required this.position,
    required this.color,
  });

  final String groupId;

  /// Key-point name, falling back to the group name.
  final String name;
  final LatLng position;
  final Color color;
}

/// Key points of every group in [groups] that has one. [allPoints] are all
/// plan points (a linked anchor point may live in another group).
List<GroupAnchor> groupAnchorsFor(
  List<PlanGroupBucket> groups,
  Iterable<PilgrimagePoint> allPoints,
  MiriaColors colors,
) {
  final points = allPoints.toList(growable: false);
  return [
    for (var index = 0; index < groups.length; index++)
      if (groups[index].group case final group?)
        if (resolvedGroupAnchorPosition(group, points) case final position?)
          GroupAnchor(
            groupId: group.id,
            name: (group.anchorName ?? '').trim().isNotEmpty
                ? group.anchorName!.trim()
                : group.name,
            position: position,
            color: mapGroupColor(colors, groups[index], index),
          ),
  ];
}

/// Radius circle (metres) around each group key point, for the nearest
/// assignment tool.
class AnchorRadiusLayer extends StatelessWidget {
  const AnchorRadiusLayer({
    required this.anchors,
    required this.radiusMeters,
    this.highlightedGroupId,
    super.key,
  });

  final List<GroupAnchor> anchors;
  final double radiusMeters;
  final String? highlightedGroupId;

  @override
  Widget build(BuildContext context) {
    return CircleLayer(
      circles: [
        for (final anchor in anchors)
          CircleMarker(
            point: anchor.position,
            radius: radiusMeters,
            useRadiusInMeter: true,
            color: anchor.color.withValues(
              alpha: anchor.groupId == highlightedGroupId ? 0.18 : 0.10,
            ),
            borderColor: anchor.color.withValues(
              alpha: anchor.groupId == highlightedGroupId ? 0.9 : 0.6,
            ),
            borderStrokeWidth: anchor.groupId == highlightedGroupId ? 3 : 2,
          ),
      ],
    );
  }
}

/// Flag markers for group key points.
class AnchorMarkerLayer extends StatelessWidget {
  const AnchorMarkerLayer({
    required this.anchors,
    this.selectedGroupId,
    this.onTap,
    this.scale,
    super.key,
  });

  final List<GroupAnchor> anchors;
  final String? selectedGroupId;
  final ValueChanged<GroupAnchor>? onTap;

  /// Marker scale; defaults to `settings.mapMarkerScale`.
  final double? scale;

  @override
  Widget build(BuildContext context) {
    final markerScale = normalizedMapMarkerScale(
      scale ??
          context.select<SettingsStore, double>(
            (store) => store.settings.mapMarkerScale,
          ),
    );
    return MarkerLayer(
      rotate: true,
      markers: [
        for (final anchor in anchors)
          AnchorMarker.marker(
            key: ValueKey('map-anchor-${anchor.groupId}'),
            point: anchor.position,
            scale: markerScale,
            child: AnchorMarker(
              color: anchor.color,
              name: anchor.name,
              selected: anchor.groupId == selectedGroupId,
              onTap: onTap == null ? null : () => onTap!(anchor),
            ),
          ),
      ],
    );
  }
}
