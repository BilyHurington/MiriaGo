import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../app_theme.dart';
import 'map_colors.dart';
import 'map_marker_scale.dart';

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

/// Size of the cluster circle including its status ring, before the
/// marker scale is applied.
const mapClusterBadgeDiameter = 54.0;

/// Marker box for a cluster badge (room for its shadow).
const mapClusterMarkerExtent = 58.0;

/// Clusters closer than their own badges would draw overlapping rings, so
/// the effective radius never goes below the scaled badge diameter; the
/// stored setting is left as it is.
double effectiveClusterRadius(double settingRadius, double markerScale) {
  return math.max(
    settingRadius,
    mapClusterBadgeDiameter * normalizedMapMarkerScale(markerScale),
  );
}

/// A cluster of map points. The ring around the count shows how many of them
/// are already done (imported into the plan, or visited): a grey arc for that
/// share, the whole badge grey once every point is done.
class MapMarkerClusterBadge extends StatelessWidget {
  const MapMarkerClusterBadge({
    required this.count,
    required this.onTap,
    this.opensPointBrowser = false,
    this.doneCount = 0,
    this.doneLabel = '已完成',
    super.key,
  });

  final int count;
  final VoidCallback onTap;
  final bool opensPointBrowser;

  /// Points in the cluster that are already done.
  final int doneCount;

  /// What "done" means here, e.g. 已加入 or 已打卡.
  final String doneLabel;

  static const _coreDiameter = 44.0;
  static const _ringWidth = 5.0;

  @override
  Widget build(BuildContext context) {
    final label = count > 999 ? '999+' : '$count';
    final fontSize = label.length >= 4 ? 13.0 : 15.0;
    final actionLabel = opensPointBrowser ? '点击浏览' : '点击放大';
    final done = doneCount.clamp(0, count);
    final allDone = count > 0 && done == count;
    final doneColor = AppColors.textSecondary;
    final coreColor = allDone ? doneColor : MapColors.accent;
    final doneSummary = done == 0 ? '' : '，其中 $done 个$doneLabel';
    final tooltip = opensPointBrowser ? '浏览 $count 个重合点位' : '$count 个点位';

    return Semantics(
      button: true,
      label: '$count 个聚合点位$doneSummary，$actionLabel',
      child: Tooltip(
        message: done == 0 ? tooltip : '$tooltip · $done 个$doneLabel',
        child: Material(
          color: Colors.transparent,
          child: InkResponse(
            onTap: onTap,
            radius: mapClusterBadgeDiameter / 2,
            customBorder: const CircleBorder(),
            child: SizedBox.square(
              dimension: mapClusterBadgeDiameter,
              child: CustomPaint(
                key: const ValueKey('map-cluster-status-ring'),
                painter: _ClusterStatusRingPainter(
                  doneFraction: count == 0 ? 0 : done / count,
                  trackColor: MapColors.accent.withValues(alpha: 0.28),
                  doneColor: doneColor,
                  width: _ringWidth,
                ),
                child: Center(
                  child: Container(
                    width: _coreDiameter,
                    height: _coreDiameter,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: coreColor,
                      border: Border.all(color: Colors.white, width: 2.5),
                      boxShadow: const [
                        BoxShadow(
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
                        // The done grey is light in dark mode, so it keeps
                        // the dark on-accent text there.
                        color: allDone && !AppColors.isDark
                            ? Colors.white
                            : MapColors.onAccent,
                        fontSize: fontSize,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ClusterStatusRingPainter extends CustomPainter {
  const _ClusterStatusRingPainter({
    required this.doneFraction,
    required this.trackColor,
    required this.doneColor,
    required this.width,
  });

  final double doneFraction;
  final Color trackColor;
  final Color doneColor;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(width / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width;
    canvas.drawOval(rect, paint..color = trackColor);
    final fraction = doneFraction.clamp(0.0, 1.0);
    if (fraction <= 0) {
      return;
    }
    // Starts at twelve o'clock and runs clockwise.
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * fraction,
      false,
      paint..color = doneColor,
    );
  }

  @override
  bool shouldRepaint(_ClusterStatusRingPainter oldDelegate) =>
      oldDelegate.doneFraction != doneFraction ||
      oldDelegate.trackColor != trackColor ||
      oldDelegate.doneColor != doneColor ||
      oldDelegate.width != width;
}

class MapOverlapPointPager extends StatelessWidget {
  const MapOverlapPointPager({
    required this.currentIndex,
    required this.total,
    required this.onPrevious,
    required this.onNext,
    super.key,
  });

  final int currentIndex;
  final int total;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      key: const ValueKey('map-overlap-point-pager'),
      children: [
        IconButton(
          key: const ValueKey('map-overlap-previous'),
          tooltip: '上一个重合点位',
          visualDensity: VisualDensity.compact,
          onPressed: onPrevious,
          icon: const Icon(LucideIcons.chevronLeft),
        ),
        Expanded(
          child: Text(
            '重合点位  ${currentIndex + 1} / $total',
            textAlign: TextAlign.center,
            maxLines: 1,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
        ),
        IconButton(
          key: const ValueKey('map-overlap-next'),
          tooltip: '下一个重合点位',
          visualDensity: VisualDensity.compact,
          onPressed: onNext,
          icon: const Icon(LucideIcons.chevronRight),
        ),
      ],
    );
  }
}

bool isAtMaximumMapZoom(MapCamera camera, {double tolerance = 0.01}) {
  final maxZoom = camera.maxZoom;
  if (maxZoom == null) {
    return false;
  }
  return camera.zoom >= maxZoom - tolerance;
}

List<T> orderMapClusterItems<T>({
  required Iterable<T> items,
  required Iterable<T> planOrder,
  required String Function(T item) idOf,
}) {
  final orderById = <String, int>{};
  var index = 0;
  for (final item in planOrder) {
    orderById.putIfAbsent(idOf(item), () => index);
    index += 1;
  }

  final ordered = items.toList(growable: false);
  ordered.sort((a, b) {
    final orderA = orderById[idOf(a)] ?? (1 << 30);
    final orderB = orderById[idOf(b)] ?? (1 << 30);
    final orderCompare = orderA.compareTo(orderB);
    if (orderCompare != 0) {
      return orderCompare;
    }
    return idOf(a).compareTo(idOf(b));
  });
  return ordered;
}

int nextMapOverlapIndex({
  required int currentIndex,
  required int offset,
  required int total,
}) {
  if (total <= 0) {
    return 0;
  }
  return (currentIndex + offset) % total;
}

double nextOverlapClusterZoom(MapCamera camera) {
  return math.min(camera.maxZoom ?? 24, camera.zoom + 2);
}

double nextClusterZoom(MapCamera camera, int maxClusterZoom) {
  return math.min(
    camera.maxZoom ?? 24,
    math.min(camera.zoom + 2, maxClusterZoom + 0.25),
  );
}
