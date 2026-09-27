import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../application/settings_store.dart';
import '../../map/map_marker_clustering.dart';
import '../../map/map_marker_scale.dart';
import '../../plan/pilgrimage_models.dart';
import '../../plan/plan_group_utils.dart';
import '../../plan/reference_image_status.dart';
import '../../utils/selected_item_order.dart';
import '../../widgets/image_load_limiter.dart';
import '../design/theme.dart';
import 'group_hull_layer.dart';
import 'map_markers.dart';
import 'plan_map.dart';

/// Debounce for recomputing which points show thumbnails (old app: 180 ms).
const Duration kThumbnailBoundsDebounce = Duration(milliseconds: 180);

/// Point markers for a [PlanMap], with clustering, thumbnail mode and
/// overlap browsing ported from the old `PilgrimageMapScreen`.
///
/// Generic over the item type so it serves plan points and Anitabi
/// candidates alike: pass how to read an item's id, position and marker
/// kind. Must be a child of [PlanMap] (it reads the map camera).
///
/// - Items without a position, and completed items when [hideCompleted],
///   are not drawn.
/// - Clustering follows the settings (`mapMarkerClusteringEnabled`,
///   `mapMarkerClusterRadius`, `mapMarkerClusterMaxZoom`). The selected
///   item never joins a normal cluster and is drawn on top.
/// - Tapping a cluster zooms to `min(zoom + 2, clusterMaxZoom + 0.25)`;
///   above the cluster max zoom only overlapping items merge and tapping
///   zooms +2 until the maximum zoom, where [onBrowseOverlap] receives the
///   items ordered by [items] (plan order).
/// - Thumbnail mode ([showThumbnails]) shows image cards when at most
///   `mapThumbnailVisibleThreshold` items are in view (0 disables); the
///   visible set is recomputed when the camera settles (180 ms debounce)
///   and images load through a shared [ImageLoadLimiter]
///   (`mapThumbnailConcurrentLoads`).
class PlanMarkerLayer<T> extends StatefulWidget {
  const PlanMarkerLayer({
    required this.items,
    required this.idOf,
    required this.positionOf,
    required this.kindOf,
    this.selectedId,
    this.onTap,
    this.onBrowseOverlap,
    this.labelOf,
    this.tooltipOf,
    this.colorOf,
    this.imageOf,
    this.showThumbnails = false,
    this.hideCompleted = false,
    this.overlapIds = const [],
    this.onOverlapInvalidated,
    this.enabled = true,
    this.keyPrefix = 'plan-map',
    this.settings,
    super.key,
  });

  /// All items, in plan order (used to order overlap browsing).
  final List<T> items;
  final String Function(T item) idOf;

  /// Null when the item has no coordinate.
  final LatLng? Function(T item) positionOf;
  final PointMarkerKind Function(T item) kindOf;
  final String? selectedId;
  final ValueChanged<T>? onTap;

  /// Opened by tapping a cluster at maximum zoom; items in plan order.
  final ValueChanged<List<T>>? onBrowseOverlap;

  /// Name shown under the selected marker (and as hover tooltip).
  final String Function(T item)? labelOf;
  final String Function(T item)? tooltipOf;

  /// Accent for pending / importable markers and thumbnail status colour.
  final Color? Function(BuildContext context, T item)? colorOf;
  final MarkerImage? Function(T item)? imageOf;

  final bool showThumbnails;
  final bool hideCompleted;

  /// Ids of the overlap group currently being browsed (in browse order).
  /// At maximum zoom these are drawn as just the selected marker.
  final List<String> overlapIds;

  /// Called when the camera leaves maximum zoom while [overlapIds] is
  /// non-empty; the page should close its overlap browser.
  final VoidCallback? onOverlapInvalidated;

  /// False ignores taps (e.g. while importing).
  final bool enabled;

  /// Key prefix: markers are keyed `'$keyPrefix-marker-$id'`, clusters
  /// `'$keyPrefix-cluster-$firstId-$count'`.
  final String keyPrefix;

  /// Settings override; defaults to the provided [SettingsStore].
  final AppSettings? settings;

  @override
  State<PlanMarkerLayer<T>> createState() => _PlanMarkerLayerState<T>();
}

class _PlanMarkerLayerState<T> extends State<PlanMarkerLayer<T>> {
  ImageLoadLimiter? _limiter;
  StreamSubscription<MapEvent>? _events;
  MapController? _mapController;
  Timer? _boundsDebounce;
  LatLngBounds? _visibleBounds;
  bool _boundsInitialised = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = MapController.of(context);
    if (!identical(controller, _mapController)) {
      _events?.cancel();
      _mapController = controller;
      _events = controller.mapEventStream.listen(_handleMapEvent);
    }
  }

  @override
  void didUpdateWidget(covariant PlanMarkerLayer<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.showThumbnails != widget.showThumbnails) {
      _boundsDebounce?.cancel();
      _visibleBounds = null;
      _boundsInitialised = false;
    }
  }

  @override
  void dispose() {
    _events?.cancel();
    _boundsDebounce?.cancel();
    super.dispose();
  }

  void _handleMapEvent(MapEvent event) {
    if (!mounted) return;
    if (widget.overlapIds.isNotEmpty && !isAtMaximumMapZoom(event.camera)) {
      widget.onOverlapInvalidated?.call();
    }
    if (!widget.showThumbnails) return;
    if (event is MapEventMoveStart ||
        event is MapEventFlingAnimationStart ||
        event is MapEventDoubleTapZoomStart) {
      _boundsDebounce?.cancel();
      return;
    }
    if (event is MapEventMoveEnd ||
        event is MapEventFlingAnimationEnd ||
        event is MapEventFlingAnimationNotStarted ||
        event is MapEventDoubleTapZoomEnd) {
      _setVisibleBounds(event.camera);
      return;
    }
    if ((event is MapEventMove &&
            event.source == MapEventSource.mapController) ||
        event is MapEventScrollWheelZoom ||
        event is MapEventNonRotatedSizeChange) {
      _boundsDebounce?.cancel();
      _boundsDebounce = Timer(kThumbnailBoundsDebounce, () {
        if (!mounted || !widget.showThumbnails) return;
        try {
          _setVisibleBounds(_mapController!.camera);
        } catch (_) {
          // The controller may briefly be unavailable while the map mounts.
        }
      });
    }
  }

  void _setVisibleBounds(MapCamera camera) {
    _boundsDebounce?.cancel();
    if (!mounted || !widget.showThumbnails) return;
    setState(() {
      _visibleBounds = camera.visibleBounds;
      _boundsInitialised = true;
    });
  }

  ImageLoadLimiter _imageLimiter(AppSettings settings) {
    final limiter = _limiter ??= ImageLoadLimiter(
      settings.mapThumbnailConcurrentLoads,
    );
    if (limiter.maxConcurrent != settings.mapThumbnailConcurrentLoads) {
      limiter.maxConcurrent = settings.mapThumbnailConcurrentLoads;
    }
    return limiter;
  }

  Set<String> _thumbnailIds(
    List<(T, LatLng)> visible,
    LatLngBounds? bounds,
    AppSettings settings,
  ) {
    if (!widget.showThumbnails) return const {};
    final threshold = settings.mapThumbnailVisibleThreshold.clamp(0, 200);
    if (threshold <= 0) return const {};
    final inView = bounds == null
        ? visible
        : visible.where((entry) => bounds.contains(entry.$2)).toList();
    if (inView.length > threshold) return const {};
    return {for (final entry in inView) widget.idOf(entry.$1)};
  }

  void _openOverlap(List<T> clusterItems) {
    final ordered = orderMapClusterItems<T>(
      items: clusterItems,
      planOrder: widget.items,
      idOf: widget.idOf,
    );
    if (ordered.isEmpty) return;
    if (ordered.length == 1) {
      widget.onTap?.call(ordered.single);
      return;
    }
    widget.onBrowseOverlap?.call(ordered);
  }

  void _zoomCluster(LatLng position, double zoom) {
    final planMap = PlanMapScope.maybeOf(context);
    if (planMap != null && planMap.isReady) {
      unawaited(planMap.moveTo(position, zoom: zoom));
    } else {
      _mapController?.move(position, zoom);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings =
        widget.settings ??
        context.select<SettingsStore, AppSettings>((store) => store.settings);
    final camera = MapCamera.of(context);
    final scale = normalizedMapMarkerScale(settings.mapMarkerScale);
    final selectedId = widget.selectedId;

    // Items that can be drawn, with their positions.
    final visible = <(T, LatLng)>[];
    final visibleById = <String, (T, LatLng)>{};
    for (final item in widget.items) {
      final position = widget.positionOf(item);
      if (position == null) continue;
      if (widget.hideCompleted &&
          widget.kindOf(item) == PointMarkerKind.completed) {
        continue;
      }
      final entry = (item, position);
      visible.add(entry);
      visibleById[widget.idOf(item)] = entry;
    }
    final selectedEntry = selectedId == null ? null : visibleById[selectedId];
    final mapEntries = selectedItemsLast<(T, LatLng)>(
      visible,
      isSelected: (entry) => widget.idOf(entry.$1) == selectedId,
    );

    final overlapEntries = [
      for (final id in widget.overlapIds) ?visibleById[id],
    ];
    final overlapIndex = overlapEntries.indexWhere(
      (entry) => widget.idOf(entry.$1) == selectedId,
    );
    final hasActiveOverlap = overlapEntries.length > 1 && overlapIndex >= 0;

    if (widget.showThumbnails && !_boundsInitialised) {
      _boundsInitialised = true;
      _visibleBounds = camera.visibleBounds;
    }
    final thumbnailIds = _thumbnailIds(visible, _visibleBounds, settings);

    final atMaximumZoom = isAtMaximumMapZoom(camera);
    final clusterMaxZoom = settings.mapMarkerClusterMaxZoom;
    final normalClustering =
        settings.mapMarkerClusteringEnabled && camera.zoom <= clusterMaxZoom;
    final overlapClustering =
        settings.mapMarkerClusteringEnabled && camera.zoom > clusterMaxZoom;
    final clustering = normalClustering || overlapClustering;
    final activeOverlapIds = hasActiveOverlap && atMaximumZoom
        ? {for (final entry in overlapEntries) widget.idOf(entry.$1)}
        : const <String>{};
    final clusterEntries = activeOverlapIds.isEmpty
        ? mapEntries
        : mapEntries
              .where(
                (entry) => !activeOverlapIds.contains(widget.idOf(entry.$1)),
              )
              .toList(growable: false);
    final terminalRadiusLimit = scaledMapMarkerDimension(
      widget.showThumbnails ? 52 : 44,
      settings.mapMarkerScale,
    );
    final clusterRadius = normalClustering
        ? settings.mapMarkerClusterRadius.toDouble()
        : settings.mapMarkerClusterRadius
              .toDouble()
              .clamp(1, terminalRadiusLimit)
              .toDouble();

    final clusters = clustering
        ? clusterMapMarkers<(T, LatLng)>(
            items: clusterEntries,
            positionOf: (entry) => entry.$2,
            camera: camera,
            radiusPixels: clusterRadius,
            keepSeparate: (entry) =>
                activeOverlapIds.isEmpty &&
                normalClustering &&
                widget.idOf(entry.$1) == selectedId,
          )
        : [
            for (final entry in clusterEntries)
              MapMarkerCluster(items: [entry], position: entry.$2),
          ];
    if (activeOverlapIds.isNotEmpty && selectedEntry != null) {
      clusters.add(
        MapMarkerCluster(items: [selectedEntry], position: selectedEntry.$2),
      );
    }

    final limiter = widget.showThumbnails ? _imageLimiter(settings) : null;
    final enabled = widget.enabled;

    Marker pointMarker((T, LatLng) entry) {
      final item = entry.$1;
      final id = widget.idOf(item);
      final selected = id == selectedId;
      final kind = widget.kindOf(item);
      final label = widget.labelOf?.call(item);
      final tooltip = widget.tooltipOf?.call(item) ?? label;
      final color = widget.colorOf?.call(context, item);
      final onTap = enabled && widget.onTap != null
          ? () => widget.onTap!(item)
          : null;
      final key = ValueKey('${widget.keyPrefix}-marker-$id');
      if (widget.showThumbnails) {
        final showImage = selected || thumbnailIds.contains(id);
        return ThumbnailMarker.marker(
          key: key,
          point: entry.$2,
          scale: scale,
          child: ThumbnailMarker(
            key: ValueKey('${widget.keyPrefix}-thumbnail-marker-$id'),
            kind: kind,
            showImage: showImage,
            selected: selected,
            color: color,
            image: widget.imageOf?.call(item),
            loadLimiter: limiter,
            tooltip: tooltip,
            onTap: onTap,
          ),
        );
      }
      return PointMarker.marker(
        key: key,
        point: entry.$2,
        scale: scale,
        child: PointMarker(
          kind: kind,
          selected: selected,
          label: label,
          color: color,
          tooltip: tooltip,
          onTap: onTap,
        ),
      );
    }

    return MarkerLayer(
      rotate: true,
      markers: [
        for (final cluster in clusters)
          if (cluster.isCluster)
            ClusterMarker.marker(
              key: ValueKey(
                '${widget.keyPrefix}-cluster-'
                '${widget.idOf(cluster.items.first.$1)}-${cluster.items.length}',
              ),
              point: cluster.position,
              scale: scale,
              child: ClusterMarker(
                count: cluster.items.length,
                opensBrowser: atMaximumZoom,
                onTap: !enabled
                    ? null
                    : atMaximumZoom
                    ? () => _openOverlap([
                        for (final entry in cluster.items) entry.$1,
                      ])
                    : () => _zoomCluster(
                        cluster.position,
                        normalClustering
                            ? nextClusterZoom(camera, clusterMaxZoom)
                            : nextOverlapClusterZoom(camera),
                      ),
              ),
            )
          else
            pointMarker(cluster.items.single),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Plan point helpers
// ---------------------------------------------------------------------------

/// Reference image of a plan point for [ThumbnailMarker].
MarkerImage planPointMarkerImage(PilgrimagePoint point) => MarkerImage(
  localPath: point.referenceThumbnailPath,
  imageUrl: hasRemoteReferenceImage(point) ? point.referenceImageUrl : null,
);

/// A [PlanMarkerLayer] configured for the plan's own points.
///
/// [statusOf] is usually `session.controller.statusFor`. Group colours come
/// from [groups] (as returned by `planGroupBuckets`) and are used for the
/// thumbnail-mode dots; pending markers keep the primary ring as in DESIGN
/// §6.8 unless [colorPendingByGroup].
PlanMarkerLayer<PilgrimagePoint> planPointMarkerLayer({
  required List<PilgrimagePoint> points,
  required VisitStatus Function(PilgrimagePoint point) statusOf,
  List<PlanGroupBucket> groups = const [],
  String? selectedId,
  ValueChanged<PilgrimagePoint>? onTap,
  ValueChanged<List<PilgrimagePoint>>? onBrowseOverlap,
  bool showThumbnails = false,
  bool hideCompleted = false,
  bool colorPendingByGroup = false,
  List<String> overlapIds = const [],
  VoidCallback? onOverlapInvalidated,
  AppSettings? settings,
  Key? key,
}) {
  final planOrder = groups.isEmpty
      ? points
      : [for (final group in groups) ...group.points];
  final ordered = planOrder.length == points.length ? planOrder : points;
  return PlanMarkerLayer<PilgrimagePoint>(
    key: key,
    items: ordered,
    idOf: (point) => point.id,
    positionOf: (point) => point.hasCoordinate ? point.position : null,
    kindOf: (point) => pointMarkerKindFor(statusOf(point)),
    selectedId: selectedId,
    onTap: onTap,
    onBrowseOverlap: onBrowseOverlap,
    labelOf: (point) => point.name,
    colorOf: groups.isEmpty
        ? null
        : (context, point) => showThumbnails || colorPendingByGroup
              ? mapGroupColorForPoint(context.colors, groups, point)
              : null,
    imageOf: planPointMarkerImage,
    showThumbnails: showThumbnails,
    hideCompleted: hideCompleted,
    overlapIds: overlapIds,
    onOverlapInvalidated: onOverlapInvalidated,
    settings: settings,
  );
}
