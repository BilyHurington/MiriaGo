import 'pilgrimage_models.dart';

/// Plan order of groups: `orderIndex`, then name for equal indexes.
int compareGroupsByPlanOrder(PilgrimagePlanGroup a, PilgrimagePlanGroup b) {
  final orderCompare = a.orderIndex.compareTo(b.orderIndex);
  if (orderCompare != 0) {
    return orderCompare;
  }
  return a.name.compareTo(b.name);
}

List<PilgrimagePlanGroup> sortGroupsByPlanOrder(
  Iterable<PilgrimagePlanGroup> groups,
) {
  return groups.toList()..sort(compareGroupsByPlanOrder);
}

List<PilgrimagePoint> sortPointsByPlanOrder(Iterable<PilgrimagePoint> points) {
  final sorted = points.toList().indexed.toList();
  sorted.sort((a, b) {
    final orderA = a.$2.groupOrderIndex ?? 1 << 30;
    final orderB = b.$2.groupOrderIndex ?? 1 << 30;
    final orderCompare = orderA.compareTo(orderB);
    if (orderCompare != 0) {
      return orderCompare;
    }
    return a.$1.compareTo(b.$1);
  });
  return sorted.map((entry) => entry.$2).toList(growable: false);
}

/// The next target after [completedPoint]: pending points of its own group
/// first, then the following groups in plan order (wrapping around to the
/// earlier groups), with the ungrouped points last. A completed ungrouped
/// point continues with the remaining ungrouped points, then the groups. `groupOrderIndex` is only compared within a group.
PilgrimagePoint? nextPendingPointAfterCompletion({
  required Iterable<PilgrimagePoint> points,
  required Iterable<PilgrimagePlanGroup> groups,
  required PilgrimagePoint completedPoint,
  required Set<String> completedPointIds,
}) {
  return _pendingPointInGroupWalk(
    points: points,
    groups: groups,
    completedPointIds: completedPointIds,
    startGroupId: completedPoint.groupId,
  );
}

/// The first pending point when no previous target anchors the walk: groups
/// in plan order, ungrouped points last.
PilgrimagePoint? firstPendingPointInPlanOrder({
  required Iterable<PilgrimagePoint> points,
  required Iterable<PilgrimagePlanGroup> groups,
  required Set<String> completedPointIds,
}) {
  return _pendingPointInGroupWalk(
    points: points,
    groups: groups,
    completedPointIds: completedPointIds,
    startAtFirstGroup: true,
  );
}

PilgrimagePoint? _pendingPointInGroupWalk({
  required Iterable<PilgrimagePoint> points,
  required Iterable<PilgrimagePlanGroup> groups,
  required Set<String> completedPointIds,
  String? startGroupId,
  bool startAtFirstGroup = false,
}) {
  final groupIds = [for (final group in sortGroupsByPlanOrder(groups)) group.id];
  final knownGroupIds = groupIds.toSet();
  // `null` is the ungrouped bucket; points of unknown groups also land there.
  final bucketIds = <String?>[...groupIds, null];
  final bucketPoints = <String?, List<PilgrimagePoint>>{
    for (final id in bucketIds) id: <PilgrimagePoint>[],
  };
  for (final point in points) {
    final groupId = knownGroupIds.contains(point.groupId)
        ? point.groupId
        : null;
    bucketPoints[groupId]!.add(point);
  }

  final List<String?> walk;
  if (startAtFirstGroup) {
    walk = bucketIds;
  } else if (knownGroupIds.contains(startGroupId)) {
    final start = groupIds.indexOf(startGroupId!);
    walk = [...groupIds.skip(start), ...groupIds.take(start), null];
  } else {
    walk = [null, ...groupIds];
  }
  for (final bucketId in walk) {
    final next = sortPointsByPlanOrder(bucketPoints[bucketId]!)
        .where(
          (point) =>
              point.hasCoordinate && !completedPointIds.contains(point.id),
        )
        .firstOrNull;
    if (next != null) {
      return next;
    }
  }
  return null;
}

/// Visit records newest first; equal capture times fall back to the id,
/// descending, so every repository returns the same stable order.
int compareVisitRecordsNewestFirst(
  PilgrimageVisitRecord a,
  PilgrimageVisitRecord b,
) {
  final capturedCompare = b.capturedAt.compareTo(a.capturedAt);
  if (capturedCompare != 0) {
    return capturedCompare;
  }
  return b.id.compareTo(a.id);
}

/// Groups whose key point is [point] take over its current position, so the
/// stored anchor copy does not go stale when the point is moved.
List<PilgrimagePlanGroup> refreshLinkedGroupAnchors(
  List<PilgrimagePlanGroup> groups,
  PilgrimagePoint point,
) {
  if (!point.hasCoordinate ||
      !groups.any((group) => group.anchorPointId == point.id)) {
    return groups;
  }
  return [
    for (final group in groups)
      group.anchorPointId == point.id
          ? group.copyWith(
              anchorLatitude: point.position.latitude,
              anchorLongitude: point.position.longitude,
            )
          : group,
  ];
}

/// Point ids per target group (`null` = ungrouped), in first-seen order.
Map<String?, Set<String>> pointIdsByTargetGroup(
  Map<String, String?> groupIdsByPointId,
) {
  final result = <String?, Set<String>>{};
  for (final entry in groupIdsByPointId.entries) {
    result.putIfAbsent(entry.value, () => <String>{}).add(entry.key);
  }
  return result;
}
