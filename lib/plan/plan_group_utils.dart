import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'pilgrimage_models.dart';

enum PointSortMode { plan, distance }

const previewCurrentLocation = LatLng(34.8903, 135.8009);

const planGroupMapColors = [
  Color(0xFF0F8B8D),
  Color(0xFFFFCE00),
  Color(0xFF7C3AED),
  Color(0xFF2563EB),
  Color(0xFFE11D48),
];

const ungroupedMapMarkerColor = Color(0xFF6B7280);

Color planGroupMapColorAt(int index) {
  return planGroupMapColors[index % planGroupMapColors.length];
}

Color mapColorForGroupBucket(PlanGroupBucket group, int index) {
  return group.isUngrouped
      ? ungroupedMapMarkerColor
      : planGroupMapColorAt(index);
}

Color mapColorForPoint(PilgrimagePoint point, List<PlanGroupBucket> groups) {
  for (var index = 0; index < groups.length; index += 1) {
    final group = groups[index];
    if (point.groupId == null && group.isUngrouped) {
      return mapColorForGroupBucket(group, index);
    }
    if (point.groupId == group.id) {
      return mapColorForGroupBucket(group, index);
    }
  }
  return ungroupedMapMarkerColor;
}

class PlanGroupBucket {
  const PlanGroupBucket({
    required this.id,
    required this.name,
    required this.points,
    required this.completedCount,
    this.group,
    this.isUngrouped = false,
  });

  final String id;
  final String name;
  final PilgrimagePlanGroup? group;
  final List<PilgrimagePoint> points;
  final int completedCount;
  final bool isUngrouped;

  bool get isManualOrder => group?.orderMode == PlanGroupOrderMode.manual;

  String get orderModeLabel {
    if (isUngrouped) {
      return '待整理';
    }
    return isManualOrder ? '手动' : '无序';
  }

  String get anchorLabel {
    if (isUngrouped) {
      return '等待分入片区';
    }
    final anchorName = group?.anchorName;
    if (anchorName == null || anchorName.trim().isEmpty) {
      return '未设置关键点';
    }
    return '关键点：$anchorName';
  }
}

List<PlanGroupBucket> planGroupBuckets(
  PilgrimagePlan plan,
  Set<String> completedPointIds,
) {
  final sortedGroups = sortGroupsByPlanOrder(plan.groups);
  final buckets = [
    for (final group in sortedGroups)
      PlanGroupBucket(
        id: group.id,
        name: group.name,
        group: group,
        points: sortPointsByPlanOrder(
          plan.points.where((point) => point.groupId == group.id),
        ),
        completedCount: plan.points
            .where(
              (point) =>
                  point.groupId == group.id &&
                  completedPointIds.contains(point.id),
            )
            .length,
      ),
  ];
  final ungroupedPoints = sortPointsByPlanOrder(
    plan.points.where((point) => point.groupId == null),
  );
  buckets.add(
    PlanGroupBucket(
      id: 'ungrouped',
      name: '未分组',
      points: ungroupedPoints,
      completedCount: ungroupedPoints
          .where((point) => completedPointIds.contains(point.id))
          .length,
      isUngrouped: true,
    ),
  );
  return buckets;
}

List<PilgrimagePlanGroup> sortGroupsByPlanOrder(
  Iterable<PilgrimagePlanGroup> groups,
) {
  final sorted = groups.toList();
  sorted.sort((a, b) {
    final orderCompare = a.orderIndex.compareTo(b.orderIndex);
    if (orderCompare != 0) {
      return orderCompare;
    }
    return a.name.compareTo(b.name);
  });
  return sorted;
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

PilgrimagePoint? nextPendingPointAfterCompletion({
  required Iterable<PilgrimagePoint> points,
  required PilgrimagePoint completedPoint,
  required Set<String> completedPointIds,
}) {
  final sortedPoints = sortPointsByPlanOrder(points);
  final sameGroupNext = sortedPoints
      .where(
        (point) =>
            point.groupId == completedPoint.groupId &&
            point.hasCoordinate &&
            !completedPointIds.contains(point.id),
      )
      .firstOrNull;
  if (sameGroupNext != null) {
    return sameGroupNext;
  }

  return sortedPoints
      .where(
        (point) => point.hasCoordinate && !completedPointIds.contains(point.id),
      )
      .firstOrNull;
}

List<PilgrimagePoint> displayPointsForGroup(
  PlanGroupBucket group, {
  required PointSortMode sortMode,
  required bool descending,
  LatLng? currentLocation,
}) {
  final points = [...group.points];
  if (sortMode == PointSortMode.distance) {
    final location = currentLocation ?? previewCurrentLocation;
    const distance = Distance();
    points.sort((a, b) {
      if (a.hasCoordinate != b.hasCoordinate) {
        return a.hasCoordinate ? -1 : 1;
      }
      if (!a.hasCoordinate) {
        return 0;
      }
      final distanceA = distance(location, a.position);
      final distanceB = distance(location, b.position);
      return distanceA.compareTo(distanceB);
    });
  }
  if (descending) {
    if (sortMode == PointSortMode.distance) {
      final positionedPoints = points
          .where((point) => point.hasCoordinate)
          .toList(growable: false)
          .reversed;
      final pendingPoints = points.where((point) => !point.hasCoordinate);
      return [...positionedPoints, ...pendingPoints];
    }
    return points.reversed.toList(growable: false);
  }
  return points;
}

LatLng groupMapCenter(PlanGroupBucket group) {
  if (group.group?.anchorLatitude != null &&
      group.group?.anchorLongitude != null) {
    return LatLng(group.group!.anchorLatitude!, group.group!.anchorLongitude!);
  }
  final positionedPoints = group.points
      .where((point) => point.hasCoordinate)
      .toList(growable: false);
  if (positionedPoints.isEmpty) {
    return previewCurrentLocation;
  }

  final latitude =
      positionedPoints
          .map((point) => point.position.latitude)
          .reduce((a, b) => a + b) /
      positionedPoints.length;
  final longitude =
      positionedPoints
          .map((point) => point.position.longitude)
          .reduce((a, b) => a + b) /
      positionedPoints.length;
  return LatLng(latitude, longitude);
}

List<Polygon> groupAreaPolygons(
  List<PlanGroupBucket> groups, {
  required String selectedGroupId,
  required double radiusMeters,
}) {
  final polygons = <Polygon>[];
  for (var index = 0; index < groups.length; index += 1) {
    final group = groups[index];
    if (group.isUngrouped ||
        !group.points.any((point) => point.hasCoordinate)) {
      continue;
    }
    final points = roundedGroupHull(group.points, radiusMeters: radiusMeters);
    if (points.length < 3) {
      continue;
    }
    final color = planGroupMapColorAt(index);
    final isSelected = group.id == selectedGroupId;
    polygons.add(
      Polygon(
        points: points,
        color: color.withValues(alpha: isSelected ? 0.28 : 0.14),
        borderColor: color.withValues(alpha: isSelected ? 0.92 : 0.62),
        borderStrokeWidth: isSelected ? 3.5 : 2,
      ),
    );
  }
  return polygons;
}

List<LatLng> roundedGroupHull(
  List<PilgrimagePoint> points, {
  required double radiusMeters,
}) {
  const zoom = 15.0;
  const circleSegments = 48;
  final positionedPoints = points
      .where((point) => point.hasCoordinate)
      .toList(growable: false);

  final circleSamples = <math.Point<double>>[];
  for (final point in positionedPoints) {
    final pixel = _latLngToWorldPixel(point.position, zoom);
    final radiusPixels =
        radiusMeters.clamp(25, 500) /
        _metersPerPixel(point.position.latitude, zoom);
    for (var index = 0; index < circleSegments; index += 1) {
      final angle = math.pi * 2 * index / circleSegments;
      circleSamples.add(
        math.Point(
          pixel.x + math.cos(angle) * radiusPixels,
          pixel.y + math.sin(angle) * radiusPixels,
        ),
      );
    }
  }

  final hull = _convexHull(circleSamples);
  if (hull.length < 3) {
    return const [];
  }
  return hull
      .map((point) => _worldPixelToLatLng(point, zoom))
      .toList(growable: false);
}

double _metersPerPixel(double latitude, double zoom) {
  const earthRadiusMeters = 6378137.0;
  final scale = 256 * math.pow(2, zoom).toDouble();
  return 2 *
      math.pi *
      earthRadiusMeters *
      math.cos(latitude * math.pi / 180) /
      scale;
}

List<math.Point<double>> _convexHull(List<math.Point<double>> points) {
  final sorted = [...points]
    ..sort((a, b) {
      final xCompare = a.x.compareTo(b.x);
      return xCompare == 0 ? a.y.compareTo(b.y) : xCompare;
    });
  if (sorted.length <= 1) {
    return sorted;
  }

  double cross(
    math.Point<double> origin,
    math.Point<double> a,
    math.Point<double> b,
  ) {
    return (a.x - origin.x) * (b.y - origin.y) -
        (a.y - origin.y) * (b.x - origin.x);
  }

  final lower = <math.Point<double>>[];
  for (final point in sorted) {
    while (lower.length >= 2 &&
        cross(lower[lower.length - 2], lower.last, point) <= 0) {
      lower.removeLast();
    }
    lower.add(point);
  }

  final upper = <math.Point<double>>[];
  for (final point in sorted.reversed) {
    while (upper.length >= 2 &&
        cross(upper[upper.length - 2], upper.last, point) <= 0) {
      upper.removeLast();
    }
    upper.add(point);
  }

  return [...lower.take(lower.length - 1), ...upper.take(upper.length - 1)];
}

math.Point<double> _latLngToWorldPixel(LatLng latLng, double zoom) {
  final scale = 256 * math.pow(2, zoom).toDouble();
  final sinLat = math
      .sin(latLng.latitude * math.pi / 180)
      .clamp(-0.9999, 0.9999);
  final x = (latLng.longitude + 180) / 360 * scale;
  final y =
      (0.5 - math.log((1 + sinLat) / (1 - sinLat)) / (4 * math.pi)) * scale;
  return math.Point(x, y);
}

LatLng _worldPixelToLatLng(math.Point<double> point, double zoom) {
  final scale = 256 * math.pow(2, zoom).toDouble();
  final longitude = point.x / scale * 360 - 180;
  final mercatorY = 2 * math.pi * (0.5 - point.y / scale);
  final latitude = math.atan(_sinh(mercatorY)) * 180 / math.pi;
  return LatLng(latitude, longitude);
}

double _sinh(double value) {
  return (math.exp(value) - math.exp(-value)) / 2;
}

class InAppNavigationTour {
  const InAppNavigationTour({
    required this.stops,
    this.groupName,
    this.startIndex = 0,
  });

  final List<PilgrimagePoint> stops;
  final String? groupName;
  final int startIndex;

  List<PilgrimagePoint> get remainingStops {
    if (stops.isEmpty) {
      return const [];
    }
    final index = startIndex.clamp(0, stops.length - 1);
    return stops.sublist(index);
  }
}

int navigationStartIndex({
  required PilgrimagePoint point,
  required List<PilgrimagePoint> stops,
}) {
  final index = stops.indexWhere((stop) => stop.id == point.id);
  return index < 0 ? 0 : index;
}

List<PilgrimagePoint> remainingNavigationStops({
  required PilgrimagePoint point,
  required List<PilgrimagePoint> stops,
}) {
  if (stops.isEmpty) {
    return const [];
  }
  return stops.sublist(navigationStartIndex(point: point, stops: stops));
}

InAppNavigationTour inAppNavigationTourFor({
  required PilgrimagePoint point,
  List<PlanGroupBucket> buckets = const [],
}) {
  PlanGroupBucket? bucket;
  for (final candidate in buckets) {
    if (point.groupId == null) {
      if (candidate.isUngrouped) {
        bucket = candidate;
        break;
      }
      continue;
    }
    if (!candidate.isUngrouped && candidate.id == point.groupId) {
      bucket = candidate;
      break;
    }
  }

  if (bucket == null || bucket.isUngrouped) {
    final stops = [if (point.hasCoordinate) point];
    return InAppNavigationTour(stops: stops);
  }

  final stops = [
    for (final stop in bucket.points)
      if (stop.hasCoordinate) stop,
  ];
  if (stops.isEmpty) {
    return InAppNavigationTour(
      groupName: bucket.name,
      stops: [if (point.hasCoordinate) point],
    );
  }
  return InAppNavigationTour(
    groupName: bucket.name,
    stops: stops,
    startIndex: navigationStartIndex(point: point, stops: stops),
  );
}
