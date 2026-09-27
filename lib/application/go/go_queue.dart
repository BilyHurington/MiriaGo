import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../../map/map_marker_clustering.dart';
import '../../plan/pilgrimage_models.dart';
import '../../plan/plan_group_utils.dart';

export '../../plan/plan_group_utils.dart'
    show PlanGroupBucket, PointSortMode, groupMapCenter, planGroupBuckets;

/// Id of the synthetic 「未分组」 bucket produced by [planGroupBuckets].
const String kGoUngroupedBucketId = 'ungrouped';

/// Fallback map centre when nothing else is known (old app: Kyoto).
const LatLng kGoFallbackCenter = LatLng(34.9671, 135.7727);

/// Sort choice of the 巡礼 queue (old plan screen `_SortOrderControl`).
@immutable
class GoSort {
  const GoSort({this.mode = PointSortMode.plan, this.descending = false});

  final PointSortMode mode;
  final bool descending;

  /// Short label of the mode (old `_sortModeLabel`).
  String get modeLabel => switch (mode) {
    PointSortMode.plan => '默认计划',
    PointSortMode.distance => '按距离',
  };

  /// Menu label of the mode (old menu items).
  static String menuLabel(PointSortMode mode) => switch (mode) {
    PointSortMode.plan => '默认计划顺序',
    PointSortMode.distance => '按距离当前位置',
  };

  /// Direction label (old `_sortDirectionTooltip`).
  String get directionLabel => directionLabelFor(mode, descending);

  static String directionLabelFor(PointSortMode mode, bool descending) =>
      switch (mode) {
        PointSortMode.plan => descending ? '反序' : '正序',
        PointSortMode.distance => descending ? '远到近' : '近到远',
      };

  /// e.g. 「默认计划 · 正序」.
  String get label => '$modeLabel · $directionLabel';

  GoSort copyWith({PointSortMode? mode, bool? descending}) => GoSort(
    mode: mode ?? this.mode,
    descending: descending ?? this.descending,
  );

  @override
  bool operator ==(Object other) =>
      other is GoSort && other.mode == mode && other.descending == descending;

  @override
  int get hashCode => Object.hash(mode, descending);
}

/// Points of [bucket] as listed in the queue. Points without coordinates
/// always come last; distance sorting falls back to the preview location
/// when [location] is unknown (old `displayPointsForGroup`).
List<PilgrimagePoint> goQueuePoints(
  PlanGroupBucket bucket, {
  GoSort sort = const GoSort(),
  LatLng? location,
}) {
  final points = displayPointsForGroup(
    bucket,
    sortMode: sort.mode,
    descending: sort.descending,
    currentLocation: location,
  );
  if (sort.mode == PointSortMode.distance) return points;
  // Plan order: keep points without coordinates last as well.
  return [
    for (final point in points)
      if (point.hasCoordinate) point,
    for (final point in points)
      if (!point.hasCoordinate) point,
  ];
}

/// Index of the bucket the header shows: the plan's `currentGroupId` when
/// it names a bucket, otherwise the first one; -1 when there is none.
int goGroupIndex(List<PlanGroupBucket> buckets, String? currentGroupId) {
  if (buckets.isEmpty) return -1;
  final index = buckets.indexWhere((bucket) => bucket.id == currentGroupId);
  return index < 0 ? 0 : index;
}

/// Previous / next group without wrapping (DESIGN Δ7). Null at the ends.
int? adjacentGroupIndex(int index, int delta, int length) {
  final next = index + delta;
  if (index < 0 || next < 0 || next >= length) return null;
  return next;
}

/// Bucket id that contains [point]: its group when that group exists,
/// otherwise the synthetic 「未分组」 bucket.
String goBucketIdForPoint(
  PilgrimagePoint point,
  List<PlanGroupBucket> buckets,
) {
  final groupId = point.groupId;
  if (groupId != null &&
      buckets.any((bucket) => !bucket.isUngrouped && bucket.id == groupId)) {
    return groupId;
  }
  return kGoUngroupedBucketId;
}

/// Initial centre of the 巡礼 map (old `PilgrimageMapScreen.build`):
/// selected point → current target → first visible point → centre of the
/// shown group → Kyoto.
LatLng goInitialMapCenter({
  PilgrimagePoint? selected,
  PilgrimagePoint? current,
  Iterable<PilgrimagePoint> visiblePoints = const [],
  PlanGroupBucket? group,
}) {
  if (selected != null && selected.hasCoordinate) return selected.position;
  if (current != null && current.hasCoordinate) return current.position;
  for (final point in visiblePoints) {
    if (point.hasCoordinate) return point.position;
  }
  if (group != null) return groupMapCenter(group);
  return kGoFallbackCenter;
}

/// Points drawn on the map: positioned, and not completed when the user
/// hides completed points.
List<PilgrimagePoint> goVisibleMapPoints(
  Iterable<PilgrimagePoint> points, {
  required VisitStatus Function(PilgrimagePoint point) statusOf,
  required bool hideCompleted,
}) => [
  for (final point in points)
    if (point.hasCoordinate &&
        (!hideCompleted || statusOf(point) != VisitStatus.completed))
      point,
];

/// Whether 「设为当前目标」 is offered on a selected point: it needs
/// coordinates and must be pending (old map card `showCurrent`).
bool goCanOfferSetCurrent(PilgrimagePoint point, VisitStatus status) =>
    point.hasCoordinate && status == VisitStatus.pending;

/// Overlapping points in plan order (old `_openOverlapPointBrowser`).
List<PilgrimagePoint> goOrderedOverlap(
  Iterable<PilgrimagePoint> points,
  List<PlanGroupBucket> buckets,
) => orderMapClusterItems<PilgrimagePoint>(
  items: points,
  planOrder: buckets.expand((bucket) => bucket.points),
  idOf: (point) => point.id,
);

/// Keyboard ↑/↓ in the queue: moves within [length] without wrapping.
/// With nothing selected, ↓ picks the first row and ↑ the last.
int? goKeyboardIndex(int currentIndex, int delta, int length) {
  if (length <= 0) return null;
  if (currentIndex < 0) return delta > 0 ? 0 : length - 1;
  return (currentIndex + delta).clamp(0, length - 1);
}

/// 「作品 · 集数」 line of a point (old map card `_metaText`, restyled).
String goPointMeta(PilgrimagePoint point) {
  final episode = point.displayEpisodeLabel.trim();
  if (episode.isEmpty) return point.work.title;
  return '${point.work.title} · $episode';
}
