import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../app_theme.dart';

class MapMarkerCluster<T> {
  const MapMarkerCluster({required this.items, required this.position});

  final List<T> items;
  final LatLng position;

  bool get isCluster => items.length > 1;
}

List<MapMarkerCluster<T>> clusterMapMarkers<T>({
  required Iterable<T> items,
  required LatLng Function(T item) positionOf,
  required MapCamera camera,
  required double radiusPixels,
  bool Function(T item)? keepSeparate,
}) {
  final radius = radiusPixels.clamp(1.0, 256.0);
  final radiusSquared = radius * radius;
  final buckets = <(int, int), List<_WorkingCluster<T>>>{};
  final workingClusters = <_WorkingCluster<T>>[];
  final separateClusters = <MapMarkerCluster<T>>[];

  for (final item in items) {
    final position = positionOf(item);
    if (keepSeparate?.call(item) ?? false) {
      separateClusters.add(MapMarkerCluster(items: [item], position: position));
      continue;
    }

    final projected = camera.projectAtZoom(position);
    final cell = _cellFor(projected, radius);
    _WorkingCluster<T>? nearest;
    var nearestDistanceSquared = double.infinity;
    final candidates = <_WorkingCluster<T>>{};

    for (var x = cell.$1 - 1; x <= cell.$1 + 1; x++) {
      for (var y = cell.$2 - 1; y <= cell.$2 + 1; y++) {
        candidates.addAll(buckets[(x, y)] ?? const []);
      }
    }

    for (final candidate in candidates) {
      final dx = projected.dx - candidate.center.dx;
      final dy = projected.dy - candidate.center.dy;
      final distanceSquared = dx * dx + dy * dy;
      if (distanceSquared <= radiusSquared &&
          distanceSquared < nearestDistanceSquared) {
        nearest = candidate;
        nearestDistanceSquared = distanceSquared;
      }
    }

    if (nearest == null) {
      final cluster = _WorkingCluster<T>(item, projected);
      workingClusters.add(cluster);
      buckets.putIfAbsent(cell, () => []).add(cluster);
      continue;
    }

    nearest.add(item, projected);
    final updatedCell = _cellFor(nearest.center, radius);
    final updatedBucket = buckets.putIfAbsent(updatedCell, () => []);
    if (!updatedBucket.contains(nearest)) {
      updatedBucket.add(nearest);
    }
  }

  return [
    for (final cluster in workingClusters)
      MapMarkerCluster(
        items: List<T>.unmodifiable(cluster.items),
        position: cluster.items.length == 1
            ? positionOf(cluster.items.single)
            : camera.unprojectAtZoom(cluster.center),
      ),
    ...separateClusters,
  ];
}

(int, int) _cellFor(Offset point, double cellSize) {
  return ((point.dx / cellSize).floor(), (point.dy / cellSize).floor());
}

class _WorkingCluster<T> {
  _WorkingCluster(T item, Offset point)
    : items = [item],
      _sumX = point.dx,
      _sumY = point.dy;

  final List<T> items;
  double _sumX;
  double _sumY;

  Offset get center => Offset(_sumX / items.length, _sumY / items.length);

  void add(T item, Offset point) {
    items.add(item);
    _sumX += point.dx;
    _sumY += point.dy;
  }
}

class MapMarkerClusterBadge extends StatelessWidget {
  const MapMarkerClusterBadge({
    required this.count,
    required this.onTap,
    super.key,
  });

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = count > 999 ? '999+' : '$count';
    final fontSize = label.length >= 4 ? 13.0 : 15.0;

    return Semantics(
      button: true,
      label: '$count 个聚合点位，点击放大',
      child: Tooltip(
        message: '$count 个点位',
        child: Material(
          color: Colors.transparent,
          child: InkResponse(
            onTap: onTap,
            radius: 25,
            customBorder: const CircleBorder(),
            child: Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accent,
                border: Border.all(color: Colors.white, width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.28),
                    blurRadius: 0,
                    spreadRadius: 4,
                  ),
                  const BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Text(
                label,
                maxLines: 1,
                style: TextStyle(
                  color: AppColors.onAccent,
                  fontSize: fontSize,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

double nextClusterZoom(MapCamera camera, int maxClusterZoom) {
  return math.min(
    camera.maxZoom ?? 24,
    math.min(camera.zoom + 2, maxClusterZoom + 0.25),
  );
}
