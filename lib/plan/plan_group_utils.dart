import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'pilgrimage_models.dart';

enum PointSortMode { plan, distance }

const previewCurrentLocation = LatLng(34.8903, 135.8009);

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
  final sortedGroups = [...plan.groups]
    ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
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

List<PilgrimagePoint> sortPointsByPlanOrder(Iterable<PilgrimagePoint> points) {
  final sorted = points.toList();
  sorted.sort((a, b) {
    final orderA = a.groupOrderIndex ?? 1 << 30;
    final orderB = b.groupOrderIndex ?? 1 << 30;
    final orderCompare = orderA.compareTo(orderB);
    if (orderCompare != 0) {
      return orderCompare;
    }
    return a.name.compareTo(b.name);
  });
  return sorted;
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
      final distanceA = distance(location, a.position);
      final distanceB = distance(location, b.position);
      return distanceA.compareTo(distanceB);
    });
  }
  if (descending) {
    return points.reversed.toList(growable: false);
  }
  return points;
}

LatLng groupMapCenter(PlanGroupBucket group) {
  if (group.group?.anchorLatitude != null &&
      group.group?.anchorLongitude != null) {
    return LatLng(group.group!.anchorLatitude!, group.group!.anchorLongitude!);
  }
  if (group.points.isEmpty) {
    return previewCurrentLocation;
  }

  final latitude =
      group.points.map((point) => point.position.latitude).reduce((a, b) => a + b) /
      group.points.length;
  final longitude =
      group.points.map((point) => point.position.longitude).reduce((a, b) => a + b) /
      group.points.length;
  return LatLng(latitude, longitude);
}

List<Polygon> groupAreaPolygons(
  List<PlanGroupBucket> groups, {
  required String selectedGroupId,
}) {
  const colors = [
    Color(0xFF0F8B8D),
    Color(0xFFFFCE00),
    Color(0xFF7C3AED),
    Color(0xFF2563EB),
    Color(0xFFE11D48),
  ];

  final polygons = <Polygon>[];
  for (var index = 0; index < groups.length; index += 1) {
    final group = groups[index];
    if (group.isUngrouped || group.points.isEmpty) {
      continue;
    }
    final points = roundedGroupHull(group.points);
    if (points.length < 3) {
      continue;
    }
    final color = colors[index % colors.length];
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

List<LatLng> roundedGroupHull(List<PilgrimagePoint> points) {
  const zoom = 15.0;
  const radiusPixels = 42.0;
  const circleSegments = 24;
  final pixels = points
      .map((point) => _latLngToWorldPixel(point.position, zoom))
      .toList(growable: false);

  final circleSamples = <math.Point<double>>[];
  for (final pixel in pixels) {
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
  final sinLat = math.sin(latLng.latitude * math.pi / 180).clamp(-0.9999, 0.9999);
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
