import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

/// Snapped position of the user on a route shape.
class RouteProgress {
  const RouteProgress({
    required this.nearestShapeIndex,
    required this.segmentIndex,
    required this.segmentFraction,
    required this.distanceFromRouteMeters,
    required this.distanceAlongRouteMeters,
    required this.remainingDistanceMeters,
  });

  /// Shape vertex closest to the snapped position.
  final int nearestShapeIndex;

  /// Segment `shape[segmentIndex] -> shape[segmentIndex + 1]` the user was
  /// snapped onto.
  final int segmentIndex;

  /// Position along [segmentIndex], from 0 (start vertex) to 1 (end vertex).
  final double segmentFraction;
  final double distanceFromRouteMeters;

  /// Route distance from the first shape vertex to the snapped position.
  final double distanceAlongRouteMeters;

  /// Route distance from the snapped position to the end of the shape.
  final double remainingDistanceMeters;
}

/// Cumulative route distance at every shape vertex.
List<double> cumulativeRouteDistances(List<LatLng> shape) {
  const distance = Distance();
  final result = List<double>.filled(shape.length, 0);
  for (var i = 1; i < shape.length; i++) {
    result[i] = result[i - 1] + distance(shape[i - 1], shape[i]);
  }
  return result;
}

/// Snaps [position] onto [shape].
///
/// The search is limited to the vertex range [fromShapeIndex, toShapeIndex]
/// (normally the current leg), so a later leg that runs past the user cannot
/// be picked. When several segments are about equally close, as on
/// out-and-back sections, the one nearest to [previousAlongRouteMeters] wins,
/// with a bias against moving backwards.
RouteProgress routeProgressFor(
  LatLng position,
  List<LatLng> shape, {
  int fromShapeIndex = 0,
  int? toShapeIndex,
  double? previousAlongRouteMeters,
  List<double>? cumulativeDistances,
}) {
  if (shape.isEmpty) {
    return const RouteProgress(
      nearestShapeIndex: 0,
      segmentIndex: 0,
      segmentFraction: 0,
      distanceFromRouteMeters: double.infinity,
      distanceAlongRouteMeters: 0,
      remainingDistanceMeters: 0,
    );
  }
  if (shape.length == 1) {
    final distance = const Distance()(position, shape.first);
    return RouteProgress(
      nearestShapeIndex: 0,
      segmentIndex: 0,
      segmentFraction: 0,
      distanceFromRouteMeters: distance,
      distanceAlongRouteMeters: 0,
      remainingDistanceMeters: distance,
    );
  }

  final cumulative =
      cumulativeDistances != null && cumulativeDistances.length == shape.length
      ? cumulativeDistances
      : cumulativeRouteDistances(shape);
  final lastVertex = shape.length - 1;
  final firstSegment = fromShapeIndex.clamp(0, lastVertex - 1);
  final lastSegment =
      ((toShapeIndex ?? lastVertex).clamp(firstSegment + 1, lastVertex)) - 1;

  final candidates = <_SegmentCandidate>[];
  var nearestDistance = double.infinity;
  for (var i = firstSegment; i <= lastSegment; i++) {
    final projection = _projectOnSegment(position, shape[i], shape[i + 1]);
    final segmentLength = cumulative[i + 1] - cumulative[i];
    candidates.add(
      _SegmentCandidate(
        segment: i,
        fraction: projection.fraction,
        distance: projection.distanceMeters,
        along: cumulative[i] + segmentLength * projection.fraction,
      ),
    );
    nearestDistance = math.min(nearestDistance, projection.distanceMeters);
  }

  const tieToleranceMeters = 8.0;
  _SegmentCandidate? best;
  for (final candidate in candidates) {
    if (candidate.distance > nearestDistance + tieToleranceMeters) continue;
    if (best == null) {
      best = candidate;
      continue;
    }
    if (previousAlongRouteMeters == null) {
      // Without history take the closest segment; exact ties keep the earliest.
      if (candidate.distance < best.distance) best = candidate;
      continue;
    }
    if (_continuityCost(candidate, previousAlongRouteMeters) <
        _continuityCost(best, previousAlongRouteMeters)) {
      best = candidate;
    }
  }
  final snapped = best!;
  final along = snapped.along;
  return RouteProgress(
    nearestShapeIndex: snapped.fraction < 0.5
        ? snapped.segment
        : snapped.segment + 1,
    segmentIndex: snapped.segment,
    segmentFraction: snapped.fraction,
    distanceFromRouteMeters: snapped.distance,
    distanceAlongRouteMeters: along,
    remainingDistanceMeters: math.max(0, cumulative[lastVertex] - along),
  );
}

double _continuityCost(_SegmentCandidate candidate, double previousAlong) {
  final delta = candidate.along - previousAlong;
  // Walking backwards along the route is possible but less likely than
  // continuing forwards, so it costs twice as much.
  return delta >= 0 ? delta : -delta * 2;
}

/// Index of the next maneuver the user still has to perform: the first one in
/// `[firstManeuverIndex, endManeuverIndex)` that begins after [segmentIndex].
/// Returns the last maneuver of the range when all have been passed.
int upcomingManeuverIndex({
  required int segmentIndex,
  required List<int> beginShapeIndices,
  int firstManeuverIndex = 0,
  int? endManeuverIndex,
}) {
  final end = math.min(
    endManeuverIndex ?? beginShapeIndices.length,
    beginShapeIndices.length,
  );
  if (end <= 0) return 0;
  final first = firstManeuverIndex.clamp(0, end - 1);
  for (var i = first; i < end; i++) {
    if (beginShapeIndices[i] > segmentIndex) return i;
  }
  return end - 1;
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

class _SegmentCandidate {
  const _SegmentCandidate({
    required this.segment,
    required this.fraction,
    required this.distance,
    required this.along,
  });
  final int segment;
  final double fraction;
  final double distance;
  final double along;
}

/// Arrival radius around a stop, bounded so a coarse fix cannot claim arrival
/// from hundreds of metres away.
double arrivalRadiusMeters(double accuracy) =>
    (accuracy + 8).clamp(18.0, 40.0).toDouble();

/// Distance from the route that counts as off-route, bounded for coarse fixes.
double offRouteLimitMeters(double accuracy) =>
    (accuracy + 25).clamp(45.0, 100.0).toDouble();

/// Fixes worse than this are shown on the map but not used to decide arrival
/// or rerouting.
const maxDecisionAccuracyMeters = 65.0;

/// Extra distance past the arrival radius the user must move away before a
/// dismissed arrival prompt for the same stop can open again.
const arrivalRearmMarginMeters = 20.0;
