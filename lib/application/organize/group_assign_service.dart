import 'package:flutter_map/flutter_map.dart' show LatLngBounds;
import 'package:latlong2/latlong.dart';

import '../../plan/pilgrimage_models.dart';
import '../../plan/plan_group_utils.dart';

/// Distance slider range of 最近分配 (old: 50 m – 5 km, 99 divisions).
const double kNearestAssignMinMeters = 50;
const double kNearestAssignMaxMeters = 5000;
const int kNearestAssignDivisions = 99;

/// Clamps a stored `nearestAssignDistanceMeters` into the slider range.
double clampNearestAssignDistance(double meters) =>
    meters.clamp(kNearestAssignMinMeters, kNearestAssignMaxMeters).toDouble();

/// Old `_formatDistance`: 「850 m」 below 1 km, otherwise 「1.2 km」.
String formatAssignDistance(double meters) {
  if (meters >= 1000) {
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }
  return '${meters.round()} m';
}

/// The only points the assignment tools handle: ungrouped points that
/// have coordinates.
List<PilgrimagePoint> unassignedPositionedPoints(PilgrimagePlan plan) => plan
    .points
    .where((point) => point.groupId == null && point.hasCoordinate)
    .toList(growable: false);

/// Old map centre of both assignment tools: the average of the ungrouped
/// points and the group key points; `previewCurrentLocation` when empty.
LatLng assignMapCenter(
  Iterable<PilgrimagePoint> points,
  Iterable<LatLng> anchors,
) {
  final positions = [for (final point in points) point.position, ...anchors];
  if (positions.isEmpty) return previewCurrentLocation;
  var latitude = 0.0;
  var longitude = 0.0;
  for (final position in positions) {
    latitude += position.latitude;
    longitude += position.longitude;
  }
  return LatLng(latitude / positions.length, longitude / positions.length);
}

/// 最近分配 (ported from the old `NearestGroupAssignScreen`).
///
/// Every ungrouped point with coordinates goes to the group whose key point
/// is nearest, provided that distance is at most the chosen maximum. Only
/// groups with a (resolved) key point take part; ties keep the group that
/// comes first in plan order.
///
/// Build one per plan: anchors, the sorted target groups and each point's
/// nearest group are computed once, so moving the slider stays cheap even
/// for large imports.
class NearestGroupAssigner {
  NearestGroupAssigner(this.plan)
    : anchorsByGroupId = {
        for (final group in plan.groups)
          group.id: ?resolvedGroupAnchorPosition(group, plan.points),
      },
      ungroupedPoints = unassignedPositionedPoints(plan) {
    targetGroups = sortGroupsByPlanOrder(
      plan.groups.where((group) => anchorsByGroupId.containsKey(group.id)),
    );
  }

  final PilgrimagePlan plan;

  /// Resolved key point of every group that has one.
  final Map<String, LatLng> anchorsByGroupId;

  /// Groups with a key point, in plan order.
  late final List<PilgrimagePlanGroup> targetGroups;

  /// Ungrouped points with coordinates.
  final List<PilgrimagePoint> ungroupedPoints;

  static const Distance _distance = Distance();
  final Map<String, (PilgrimagePlanGroup?, double?)> _nearest = {};

  LatLng? anchorOf(PilgrimagePlanGroup group) => anchorsByGroupId[group.id];

  (PilgrimagePlanGroup?, double?) _nearestFor(PilgrimagePoint point) {
    return _nearest.putIfAbsent(point.id, () {
      PilgrimagePlanGroup? nearestGroup;
      var nearestMeters = double.infinity;
      for (final group in targetGroups) {
        final meters = _distance(point.position, anchorsByGroupId[group.id]!);
        if (meters < nearestMeters) {
          nearestMeters = meters;
          nearestGroup = group;
        }
      }
      return (nearestGroup, nearestGroup == null ? null : nearestMeters);
    });
  }

  PilgrimagePlanGroup? nearestGroupFor(PilgrimagePoint point) =>
      _nearestFor(point).$1;

  /// Distance to the nearest key point in metres, or null without groups.
  double? nearestDistanceFor(PilgrimagePoint point) => _nearestFor(point).$2;

  bool isAssignable(PilgrimagePoint point, double maxMeters) {
    final distance = nearestDistanceFor(point);
    return distance != null && distance <= maxMeters;
  }

  /// Point ids per target group id for [maxMeters].
  Map<String, Set<String>> assignments(double maxMeters) {
    final assignments = <String, Set<String>>{};
    for (final point in ungroupedPoints) {
      final (group, meters) = _nearestFor(point);
      if (group == null || meters == null) continue;
      if (meters <= maxMeters) {
        assignments.putIfAbsent(group.id, () => {}).add(point.id);
      }
    }
    return assignments;
  }

  /// The map written by `assignPointsToGroups`.
  Map<String, String?> groupIdsByPointId(double maxMeters) => {
    for (final entry in assignments(maxMeters).entries)
      for (final pointId in entry.value) pointId: entry.key,
  };

  int assignableCount(double maxMeters) =>
      ungroupedPoints.where((point) => isAssignable(point, maxMeters)).length;

  LatLng get mapCenter => assignMapCenter(ungroupedPoints, [
    for (final group in targetGroups) anchorsByGroupId[group.id]!,
  ]);
}

/// 框选分配: ungrouped points with coordinates inside [bounds].
List<PilgrimagePoint> boxSelectedPoints(
  PilgrimagePlan plan,
  LatLngBounds? bounds,
) {
  if (bounds == null) return const [];
  return [
    for (final point in unassignedPositionedPoints(plan))
      if (bounds.contains(point.position)) point,
  ];
}

/// Target group of 框选分配: the chosen group when it still exists,
/// otherwise the first group in plan order (old behaviour).
PilgrimagePlanGroup? boxTargetGroup(PilgrimagePlan plan, String? groupId) {
  final groups = sortGroupsByPlanOrder(plan.groups);
  if (groupId == null) return groups.firstOrNull;
  return groups.where((group) => group.id == groupId).firstOrNull ??
      groups.firstOrNull;
}
