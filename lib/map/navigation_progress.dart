import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

class RouteProgress {
  const RouteProgress({
    required this.nearestShapeIndex,
    required this.distanceFromRouteMeters,
    required this.remainingDistanceMeters,
  });

  final int nearestShapeIndex;
  final double distanceFromRouteMeters;
  final double remainingDistanceMeters;
}

RouteProgress routeProgressFor(LatLng position, List<LatLng> shape) {
  if (shape.isEmpty) {
    return const RouteProgress(
      nearestShapeIndex: 0,
      distanceFromRouteMeters: double.infinity,
      remainingDistanceMeters: 0,
    );
  }
  if (shape.length == 1) {
    final distance = const Distance()(position, shape.first);
    return RouteProgress(
      nearestShapeIndex: 0,
      distanceFromRouteMeters: distance,
      remainingDistanceMeters: distance,
    );
  }

  var nearestIndex = 0;
  var nearestDistance = double.infinity;
  var nearestSegment = 0;
  var nearestFraction = 0.0;
  for (var i = 0; i < shape.length - 1; i++) {
    final projection = _projectOnSegment(position, shape[i], shape[i + 1]);
    final distance = projection.distanceMeters;
    if (distance < nearestDistance) {
      nearestDistance = distance;
      nearestSegment = i;
      nearestFraction = projection.fraction;
      nearestIndex = projection.fraction < 0.5 ? i : i + 1;
    }
  }

  var remaining =
      const Distance()(shape[nearestSegment], shape[nearestSegment + 1]) *
      (1 - nearestFraction);
  for (var i = nearestSegment + 2; i < shape.length; i++) {
    remaining += const Distance()(shape[i - 1], shape[i]);
  }
  return RouteProgress(
    nearestShapeIndex: nearestIndex,
    distanceFromRouteMeters: nearestDistance,
    remainingDistanceMeters: remaining,
  );
}

_SegmentProjection _projectOnSegment(LatLng point, LatLng start, LatLng end) {
  const earthRadius = 6371000.0;
  final referenceLatitude = point.latitude * math.pi / 180;
  double x(double longitude) =>
      longitude * math.pi / 180 * earthRadius * math.cos(referenceLatitude);
  double y(double latitude) => latitude * math.pi / 180 * earthRadius;
  final px = x(point.longitude);
  final py = y(point.latitude);
  final ax = x(start.longitude);
  final ay = y(start.latitude);
  final bx = x(end.longitude);
  final by = y(end.latitude);
  final dx = bx - ax;
  final dy = by - ay;
  final lengthSquared = dx * dx + dy * dy;
  final fraction = lengthSquared == 0
      ? 0.0
      : (((px - ax) * dx + (py - ay) * dy) / lengthSquared).clamp(0.0, 1.0);
  final projectedX = ax + dx * fraction;
  final projectedY = ay + dy * fraction;
  return _SegmentProjection(
    fraction: fraction,
    distanceMeters: math.sqrt(
      math.pow(px - projectedX, 2) + math.pow(py - projectedY, 2),
    ),
  );
}

class _SegmentProjection {
  const _SegmentProjection({
    required this.fraction,
    required this.distanceMeters,
  });
  final double fraction;
  final double distanceMeters;
}

int activeManeuverIndexFor(int shapeIndex, Iterable<int> endShapeIndices) {
  var index = 0;
  for (final end in endShapeIndices) {
    if (shapeIndex <= end) return index;
    index++;
  }
  return math.max(0, index - 1);
}
