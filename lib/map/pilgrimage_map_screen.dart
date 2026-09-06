import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../app_theme.dart';
import 'map_marker_scale.dart';
import '../widgets/snackbar_helper.dart';
import '../camera_reference/camerawesome_reference_screen.dart';
import '../point_detail/point_detail_sheet.dart';
import '../plan/add_points_screen.dart';
import '../plan/plan_group_utils.dart';
import '../plan/plan_group_picker_sheet.dart';
import '../plan/pilgrimage_models.dart';
import '../plan/pilgrimage_plan_controller.dart';
import '../plan/reference_image_status.dart';
import '../records/point_visit_records_screen.dart';
import '../records/visit_record_detail_screen.dart';
import '../utils/selected_item_order.dart';
import '../widgets/copyable_text.dart';
import '../widgets/image_viewer_screen.dart';
import '../widgets/auto_caching_reference_thumbnail.dart';
import '../widgets/image_load_limiter.dart';
import '../widgets/map_thumbnail_marker.dart';
import 'navigation_route_confirm_screen.dart';
import 'map_navigation_launcher.dart';
import 'map_marker_clustering.dart';
import 'map_tile_config.dart';
import 'current_location_resolver.dart';
import '../widgets/reference_thumbnail_stub.dart'
    if (dart.library.io) '../widgets/reference_thumbnail_io.dart';

class PilgrimageMapScreen extends StatefulWidget {
  const PilgrimageMapScreen({
    required this.controller,
    required this.settings,
    super.key,
  });

  final PilgrimagePlanController controller;
  final AppSettings settings;

  @override
  State<PilgrimageMapScreen> createState() => _PilgrimageMapScreenState();
}

class _OverlapPointBrowser {
  _OverlapPointBrowser({required List<String> pointIds})
    : pointIds = List.unmodifiable(pointIds);

  final List<String> pointIds;
}

class _PilgrimageMapScreenState extends State<PilgrimageMapScreen> {
  static const Duration _thumbnailBoundsDebounceDuration = Duration(
    milliseconds: 180,
  );

  final MapController _mapController = MapController();
  final MapNavigationLauncher _navigationLauncher =
      const MapNavigationLauncher();

  LatLng? _currentLocation;
  bool _isLocating = false;
  bool _showThumbnailMarkers = false;
  int _selectedGroupIndex = 0;
  _OverlapPointBrowser? _overlapPointBrowser;
  final ValueNotifier<LatLngBounds?> _visibleBoundsNotifier = ValueNotifier(
    null,
  );
  Timer? _thumbnailBoundsDebounce;
  late final ImageLoadLimiter _thumbnailLoadLimiter = ImageLoadLimiter(
    widget.settings.mapThumbnailConcurrentLoads,
  );

  PilgrimagePlanController get _controller => widget.controller;

  @override
  void didUpdateWidget(covariant PilgrimageMapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.settings.mapThumbnailConcurrentLoads !=
        widget.settings.mapThumbnailConcurrentLoads) {
      _thumbnailLoadLimiter.maxConcurrent =
          widget.settings.mapThumbnailConcurrentLoads;
    }
  }

  @override
  void dispose() {
    _thumbnailBoundsDebounce?.cancel();
    _visibleBoundsNotifier.dispose();
    super.dispose();
  }

  Future<void> _locateUser() async {
    setState(() {
      _isLocating = true;
    });

    try {
      final position = await resolveCurrentLocation();
      final location = LatLng(position.latitude, position.longitude);

      if (!mounted) {
        return;
      }

      setState(() {
        _currentLocation = location;
      });
      _mapController.move(location, 16);
    } on CurrentLocationException catch (error) {
      _showSnackBar(currentLocationFailureMessage(error));
    } catch (_) {
      _showSnackBar('定位失败，请检查权限和定位服务。');
    } finally {
      if (mounted) {
        setState(() {
          _isLocating = false;
        });
      }
    }
  }

  Future<void> _openExternalNavigation(PilgrimagePoint point) async {
    final app = widget.settings.navigationApp;
    final opened = await _navigationLauncher.openWalking(point, app);
    if (!opened) {
      _showSnackBar('无法打开${app.label}。');
    }
  }

  void _openInAppNavigation(PilgrimagePoint point) {
    NavigationRouteConfirmScreen.openForPoint(
      context,
      point: point,
      settings: widget.settings,
      buckets: planGroupBuckets(
        _controller.plan,
        _controller.completedPointIds,
      ),
      planController: _controller,
    );
  }

  void _selectPoint(
    PilgrimagePoint point, {
    bool preserveOverlapBrowser = false,
    _OverlapPointBrowser? overlapPointBrowser,
  }) {
    final groups = planGroupBuckets(
      _controller.plan,
      _controller.completedPointIds,
    );
    final groupIndex = groups.indexWhere((group) {
      if (point.groupId == null) {
        return group.isUngrouped;
      }
      return group.id == point.groupId;
    });
    setState(() {
      if (overlapPointBrowser != null) {
        _overlapPointBrowser = overlapPointBrowser;
      } else if (!preserveOverlapBrowser) {
        _overlapPointBrowser = null;
      }
      if (groupIndex >= 0) {
        _selectedGroupIndex = groupIndex;
      }
    });
    _controller.selectPoint(point);
  }

  void _openOverlapPointBrowser(
    List<PilgrimagePoint> points,
    List<PlanGroupBucket> groups,
  ) {
    final orderedPoints = orderMapClusterItems<PilgrimagePoint>(
      items: points,
      planOrder: groups.expand((group) => group.points),
      idOf: (point) => point.id,
    );
    if (orderedPoints.isEmpty) {
      return;
    }
    if (orderedPoints.length == 1) {
      _selectPoint(orderedPoints.single);
      return;
    }

    _selectPoint(
      orderedPoints.first,
      overlapPointBrowser: _OverlapPointBrowser(
        pointIds: orderedPoints.map((point) => point.id).toList(),
      ),
    );
  }

  void _moveOverlapPoint(int offset) {
    final browser = _overlapPointBrowser;
    if (browser == null || browser.pointIds.length < 2) {
      return;
    }
    final points = <PilgrimagePoint>[];
    for (final pointId in browser.pointIds) {
      final point = _controller.pointById(pointId);
      if (point != null && point.hasCoordinate) {
        points.add(point);
      }
    }
    if (points.length < 2) {
      setState(() {
        _overlapPointBrowser = null;
      });
      return;
    }

    final selectedId = _controller.selectedPoint?.id;
    final selectedIndex = points.indexWhere((point) => point.id == selectedId);
    final currentIndex = selectedIndex < 0 ? 0 : selectedIndex;
    final nextIndex = nextMapOverlapIndex(
      currentIndex: currentIndex,
      offset: offset,
      total: points.length,
    );
    _selectPoint(points[nextIndex], preserveOverlapBrowser: true);
  }

  void _centerPoint(PilgrimagePoint point) {
    if (!point.hasCoordinate) {
      return;
    }
    _mapController.move(point.position, _mapController.camera.zoom);
  }

  void _setCurrentPoint(PilgrimagePoint point) {
    _controller.setCurrentPoint(point);
    _selectPoint(point);
    _centerPoint(point);
  }

  void _selectGroup(int index, List<PlanGroupBucket> groups) {
    final nextIndex = index.clamp(0, groups.length - 1);
    final group = groups[nextIndex];
    setState(() {
      _selectedGroupIndex = nextIndex;
      _overlapPointBrowser = null;
    });
    if (group.points.any((point) => point.hasCoordinate)) {
      _mapController.move(groupMapCenter(group), 15);
    }
  }

  void _handleMapEvent(MapEvent event) {
    if (_overlapPointBrowser != null && !isAtMaximumMapZoom(event.camera)) {
      setState(() {
        _overlapPointBrowser = null;
      });
    }
    if (!_showThumbnailMarkers) {
      return;
    }
    if (event is MapEventMoveStart ||
        event is MapEventFlingAnimationStart ||
        event is MapEventDoubleTapZoomStart) {
      _thumbnailBoundsDebounce?.cancel();
      return;
    }

    if (event is MapEventMoveEnd ||
        event is MapEventFlingAnimationEnd ||
        event is MapEventFlingAnimationNotStarted ||
        event is MapEventDoubleTapZoomEnd) {
      _setThumbnailVisibleBounds(event.camera);
      return;
    }

    if (event is MapEventMove && event.source == MapEventSource.mapController) {
      _scheduleThumbnailVisibleBoundsRefresh();
      return;
    }

    if (event is MapEventScrollWheelZoom) {
      _scheduleThumbnailVisibleBoundsRefresh();
    }
  }

  void _scheduleThumbnailVisibleBoundsRefresh() {
    _thumbnailBoundsDebounce?.cancel();
    _thumbnailBoundsDebounce = Timer(_thumbnailBoundsDebounceDuration, () {
      if (!mounted || !_showThumbnailMarkers) {
        return;
      }
      try {
        _setThumbnailVisibleBounds(_mapController.camera);
      } catch (_) {
        // The controller may briefly be unavailable while the map mounts.
      }
    });
  }

  void _setThumbnailVisibleBounds(MapCamera camera) {
    _thumbnailBoundsDebounce?.cancel();
    if (!mounted || !_showThumbnailMarkers) {
      return;
    }
    _visibleBoundsNotifier.value = camera.visibleBounds;
  }

  Set<String> _thumbnailPointIdsForCurrentView(
    Iterable<PilgrimagePoint> points,
    LatLngBounds? bounds,
  ) {
    if (!_showThumbnailMarkers) {
      return const <String>{};
    }
    final threshold = widget.settings.mapThumbnailVisibleThreshold.clamp(
      0,
      200,
    );
    if (threshold <= 0) {
      return const <String>{};
    }
    final visiblePoints = bounds == null
        ? points.toList(growable: false)
        : points
              .where((point) => bounds.contains(point.position))
              .toList(growable: false);
    if (visiblePoints.length > threshold) {
      return const <String>{};
    }
    return visiblePoints.map((point) => point.id).toSet();
  }

  bool _shouldShowPointOnMap(PilgrimagePoint point) {
    if (!point.hasCoordinate) {
      return false;
    }
    if (!widget.settings.hideCompletedPointsOnMap) {
      return true;
    }
    return _controller.statusFor(point) != VisitStatus.completed;
  }

  void _moveToCurrentTarget() {
    final currentPoint = _controller.currentPoint;
    if (currentPoint == null) {
      _showSnackBar('当前计划还没有点位。', kind: AppStatusBannerKind.warning);
      return;
    }

    _selectPoint(currentPoint);
    _centerPoint(currentPoint);
  }

  void _openCamera(PilgrimagePoint point) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CamerawesomeReferenceScreen(
          point: point,
          controller: _controller,
          settings: widget.settings,
        ),
      ),
    );
  }

  void _showPointDetail(PilgrimagePoint point) {
    PointDetailSheet.show(
      context,
      point: point,
      status: _controller.statusFor(point),
      onSetCurrent: () => _setCurrentPoint(point),
      onOpenCamera: () => _openCamera(point),
      onComplete: () => _controller.statusFor(point) == VisitStatus.completed
          ? _controller.reopenPoint(point)
          : _controller.completePoint(point),
      onReplaceReference: (point, image) => _controller.updatePoint(
        point.copyWith(
          referenceImageUrl: null,
          referenceThumbnailPath: image.thumbnailPath,
          referenceFullImagePath: image.fullImagePath,
        ),
      ),
      groups: _controller.plan.groups,
      groupBuckets: planGroupBuckets(
        _controller.plan,
        _controller.completedPointIds,
      ),
      onMoveToGroup: _controller.movePointToGroup,
      records: _controller.recordsForPoint(point.id),
      onOpenRecords: () => _openPointRecords(point),
      onOpenRecord: _openRecordDetail,
      onEditPoint: () => _editPoint(point),
      onDelete: _controller.deletePoint,
      navigationApp: widget.settings.navigationApp,
      settings: widget.settings,
      planController: _controller,
    );
  }

  Future<void> _editPoint(PilgrimagePoint point) async {
    final repository = _controller.repository;
    if (repository == null) {
      _showSnackBar('当前环境无法编辑点位。', kind: AppStatusBannerKind.warning);
      return;
    }
    final updated = await EditPointScreen.open(
      context,
      plan: _controller.plan,
      repository: repository,
      point: point,
    );
    if (updated != true || !mounted) {
      return;
    }
    final updatedPlan = await repository.loadActivePlan();
    if (!mounted) {
      return;
    }
    _controller.replacePlan(updatedPlan);
  }

  void _openPointRecords(PilgrimagePoint point) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PointVisitRecordsScreen(
          point: point,
          controller: _controller,
          settings: widget.settings,
        ),
      ),
    );
  }

  void _openRecordDetail(PilgrimageVisitRecord record) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => VisitRecordDetailScreen(
          record: record,
          point: _controller.pointById(record.pointId),
          controller: _controller,
          settings: widget.settings,
          onDelete: () => _controller.deleteVisitRecord(record),
        ),
      ),
    );
  }

  void _showSnackBar(
    String message, {
    AppStatusBannerKind kind = AppStatusBannerKind.error,
  }) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showStatusSnack(kind: kind, title: message);
  }

  Marker _buildPointMarker({
    required PilgrimagePoint point,
    required PilgrimagePoint? selectedPoint,
    required Set<String> thumbnailPointIds,
    required List<PlanGroupBucket> groups,
  }) {
    final isSelected = point.id == selectedPoint?.id;
    final showThumbnail =
        _showThumbnailMarkers &&
        (isSelected || thumbnailPointIds.contains(point.id));
    final scale = normalizedMapMarkerScale(widget.settings.mapMarkerScale);
    final baseWidth = _showThumbnailMarkers
        ? (showThumbnail ? 84.0 : 24.0)
        : 44.0;
    final baseHeight = _showThumbnailMarkers
        ? (showThumbnail ? 82.0 : 24.0)
        : 44.0;
    return Marker(
      key: ValueKey('plan-map-marker-${point.id}'),
      point: point.position,
      width: scaledMapMarkerDimension(baseWidth, scale),
      height: scaledMapMarkerDimension(baseHeight, scale),
      alignment: _showThumbnailMarkers
          ? (showThumbnail ? Alignment.topCenter : Alignment.center)
          : Alignment.center,
      child: ScaledMapMarker(
        baseWidth: baseWidth,
        baseHeight: baseHeight,
        scale: scale,
        child: _showThumbnailMarkers
            ? MapThumbnailMarker(
                key: ValueKey('plan-map-thumbnail-marker-${point.id}'),
                selected: isSelected,
                imported: _controller.statusFor(point) == VisitStatus.completed,
                showThumbnail: showThumbnail,
                markerColor: mapColorForPoint(point, groups),
                imageLoadLimiter: _thumbnailLoadLimiter,
                localPath: point.referenceThumbnailPath,
                imageUrl: hasRemoteReferenceImage(point)
                    ? point.referenceImageUrl
                    : null,
                imageSource: widget.settings.anitabiImageSource,
                onTap: () => _selectPoint(point),
              )
            : _PointMarker(
                selected: isSelected,
                status: _controller.statusFor(point),
                onTap: () => _selectPoint(point),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final groups = planGroupBuckets(
      _controller.plan,
      _controller.completedPointIds,
    );
    if (_selectedGroupIndex >= groups.length) {
      _selectedGroupIndex = groups.isEmpty ? 0 : groups.length - 1;
    }
    final selectedGroup = groups.isEmpty ? null : groups[_selectedGroupIndex];
    final selectedPoint =
        _controller.points.any(
          (point) => point.id == _controller.selectedPoint?.id,
        )
        ? _controller.selectedPoint
        : null;
    final currentPoint =
        _controller.points.any(
          (point) => point.id == _controller.currentPoint?.id,
        )
        ? _controller.currentPoint
        : null;
    final positionedPoints = _controller.points
        .where(_shouldShowPointOnMap)
        .toList(growable: false);
    final initialFocusPoint = (selectedPoint?.hasCoordinate ?? false)
        ? selectedPoint
        : (currentPoint?.hasCoordinate ?? false)
        ? currentPoint
        : positionedPoints.firstOrNull;
    final initialCenter =
        initialFocusPoint?.position ??
        (selectedGroup == null
            ? _fallbackCenter
            : groupMapCenter(selectedGroup));
    final selectedGroupId = selectedGroup?.id ?? '';
    final mapPoints = selectedItemsLast<PilgrimagePoint>(
      positionedPoints,
      isSelected: (point) => point.id == selectedPoint?.id,
    );
    final overlapPoints = <PilgrimagePoint>[];
    for (final pointId in _overlapPointBrowser?.pointIds ?? const <String>[]) {
      final point = _controller.pointById(pointId);
      if (point != null && _shouldShowPointOnMap(point)) {
        overlapPoints.add(point);
      }
    }
    final overlapPointIndex = overlapPoints.indexWhere(
      (point) => point.id == selectedPoint?.id,
    );
    final hasActiveOverlapBrowser =
        overlapPoints.length > 1 && overlapPointIndex >= 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: initialCenter,
              initialZoom: 15,
              minZoom: 4,
              maxZoom: widget.settings.mapMaxZoom.toDouble(),
              onMapEvent: _handleMapEvent,
              keepAlive: true,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            children: [
              configuredMapTileLayer(widget.settings),
              PolygonLayer(
                simplificationTolerance: 0,
                polygons: groupAreaPolygons(
                  groups,
                  selectedGroupId: selectedGroupId,
                  radiusMeters: widget.settings.mapGroupAreaRadiusMeters
                      .toDouble(),
                ),
              ),
              ValueListenableBuilder<LatLngBounds?>(
                valueListenable: _visibleBoundsNotifier,
                builder: (context, visibleBounds, _) {
                  final camera = MapCamera.of(context);
                  final thumbnailPointIds = _thumbnailPointIdsForCurrentView(
                    positionedPoints,
                    visibleBounds,
                  );
                  final atMaximumZoom = isAtMaximumMapZoom(camera);
                  final normalClusteringEnabled =
                      widget.settings.mapMarkerClusteringEnabled &&
                      camera.zoom <= widget.settings.mapMarkerClusterMaxZoom;
                  final overlapClusteringEnabled =
                      widget.settings.mapMarkerClusteringEnabled &&
                      camera.zoom > widget.settings.mapMarkerClusterMaxZoom;
                  final clusteringEnabled =
                      normalClusteringEnabled || overlapClusteringEnabled;
                  final activeOverlapPointIds =
                      hasActiveOverlapBrowser && atMaximumZoom
                      ? overlapPoints.map((point) => point.id).toSet()
                      : const <String>{};
                  final clusterItems = activeOverlapPointIds.isEmpty
                      ? mapPoints
                      : mapPoints
                            .where(
                              (point) =>
                                  !activeOverlapPointIds.contains(point.id),
                            )
                            .toList(growable: false);
                  final terminalRadiusLimit = scaledMapMarkerDimension(
                    _showThumbnailMarkers ? 52 : 44,
                    widget.settings.mapMarkerScale,
                  );
                  final clusterRadius = normalClusteringEnabled
                      ? widget.settings.mapMarkerClusterRadius.toDouble()
                      : widget.settings.mapMarkerClusterRadius
                            .toDouble()
                            .clamp(1, terminalRadiusLimit)
                            .toDouble();
                  final markerClusters = clusteringEnabled
                      ? clusterMapMarkers<PilgrimagePoint>(
                          items: clusterItems,
                          positionOf: (point) => point.position,
                          camera: camera,
                          radiusPixels: clusterRadius,
                          keepSeparate: (point) =>
                              activeOverlapPointIds.isEmpty &&
                              normalClusteringEnabled &&
                              point.id == selectedPoint?.id,
                        )
                      : [
                          for (final point in clusterItems)
                            MapMarkerCluster(
                              items: [point],
                              position: point.position,
                            ),
                          if (activeOverlapPointIds.isNotEmpty &&
                              selectedPoint != null &&
                              _shouldShowPointOnMap(selectedPoint))
                            MapMarkerCluster(
                              items: [selectedPoint],
                              position: selectedPoint.position,
                            ),
                        ];
                  if (clusteringEnabled &&
                      activeOverlapPointIds.isNotEmpty &&
                      selectedPoint != null &&
                      _shouldShowPointOnMap(selectedPoint)) {
                    markerClusters.add(
                      MapMarkerCluster(
                        items: [selectedPoint],
                        position: selectedPoint.position,
                      ),
                    );
                  }
                  return MarkerLayer(
                    markers: [
                      for (final cluster in markerClusters)
                        if (cluster.isCluster)
                          Marker(
                            key: ValueKey(
                              'plan-map-cluster-${cluster.items.first.id}-${cluster.items.length}',
                            ),
                            point: cluster.position,
                            width: scaledMapMarkerDimension(
                              50,
                              widget.settings.mapMarkerScale,
                            ),
                            height: scaledMapMarkerDimension(
                              50,
                              widget.settings.mapMarkerScale,
                            ),
                            child: ScaledMapMarker(
                              baseWidth: 50,
                              baseHeight: 50,
                              scale: widget.settings.mapMarkerScale,
                              child: Center(
                                child: MapMarkerClusterBadge(
                                  count: cluster.items.length,
                                  opensPointBrowser: atMaximumZoom,
                                  onTap: atMaximumZoom
                                      ? () => _openOverlapPointBrowser(
                                          cluster.items,
                                          groups,
                                        )
                                      : () => _mapController.move(
                                          cluster.position,
                                          normalClusteringEnabled
                                              ? nextClusterZoom(
                                                  camera,
                                                  widget
                                                      .settings
                                                      .mapMarkerClusterMaxZoom,
                                                )
                                              : nextOverlapClusterZoom(camera),
                                        ),
                                ),
                              ),
                            ),
                          )
                        else
                          _buildPointMarker(
                            point: cluster.items.single,
                            selectedPoint: selectedPoint,
                            thumbnailPointIds: thumbnailPointIds,
                            groups: groups,
                          ),
                      if (_currentLocation != null)
                        Marker(
                          point: _currentLocation!,
                          width: scaledMapMarkerDimension(
                            44,
                            widget.settings.mapMarkerScale,
                          ),
                          height: scaledMapMarkerDimension(
                            44,
                            widget.settings.mapMarkerScale,
                          ),
                          child: ScaledMapMarker(
                            baseWidth: 44,
                            baseHeight: 44,
                            scale: widget.settings.mapMarkerScale,
                            child: const _CurrentLocationMarker(),
                          ),
                        ),
                    ],
                  );
                },
              ),
              configuredMapAttribution(widget.settings),
            ],
          ),
          if (selectedGroup != null)
            Positioned(
              left: 12,
              right: 12,
              top: 12,
              child: SafeArea(
                bottom: false,
                child: _MapGroupFilterBar(
                  group: selectedGroup,
                  onTap: () => _showGroupPicker(context, groups),
                ),
              ),
            ),
          Positioned(
            right: 12,
            top: 76,
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  _MapFloatingIconButton(
                    tooltip: '定位',
                    onTap: _isLocating ? null : _locateUser,
                    child: _isLocating
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(LucideIcons.locateFixed, size: 20),
                  ),
                  const SizedBox(height: 8),
                  _MapFloatingIconButton(
                    tooltip: '当前目标',
                    onTap: _moveToCurrentTarget,
                    child: const Icon(LucideIcons.flag, size: 20),
                  ),
                  const SizedBox(height: 8),
                  _MapFloatingIconButton(
                    tooltip: _showThumbnailMarkers ? '使用图标标记' : '显示缩略图标记',
                    selected: _showThumbnailMarkers,
                    onTap: () {
                      setState(() {
                        _showThumbnailMarkers = !_showThumbnailMarkers;
                        if (!_showThumbnailMarkers) {
                          _thumbnailBoundsDebounce?.cancel();
                          _visibleBoundsNotifier.value = null;
                        } else {
                          try {
                            _visibleBoundsNotifier.value =
                                _mapController.camera.visibleBounds;
                          } catch (_) {
                            _visibleBoundsNotifier.value = null;
                          }
                        }
                      });
                    },
                    child: Icon(
                      _showThumbnailMarkers
                          ? LucideIcons.mapPin
                          : LucideIcons.image,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: selectedPoint == null
                ? const _EmptyMapCard()
                : _PointCard(
                    controller: _controller,
                    point: selectedPoint,
                    status: _controller.statusFor(selectedPoint),
                    recordCount: _controller
                        .recordsForPoint(selectedPoint.id)
                        .length,
                    onSetCurrent: selectedPoint.hasCoordinate
                        ? () => _setCurrentPoint(selectedPoint)
                        : null,
                    onOpenDetail: () => _showPointDetail(selectedPoint),
                    onOpenInAppNavigation: selectedPoint.hasCoordinate
                        ? () => _openInAppNavigation(selectedPoint)
                        : null,
                    onOpenExternalNavigation: selectedPoint.hasCoordinate
                        ? () => _openExternalNavigation(selectedPoint)
                        : null,
                    onOpenCamera: () => _openCamera(selectedPoint),
                    onComplete: () =>
                        _controller.statusFor(selectedPoint) ==
                            VisitStatus.completed
                        ? _controller.reopenPoint(selectedPoint)
                        : _controller.completePoint(selectedPoint),
                    overlapPointIndex: hasActiveOverlapBrowser
                        ? overlapPointIndex
                        : null,
                    overlapPointCount: hasActiveOverlapBrowser
                        ? overlapPoints.length
                        : null,
                    onPreviousOverlapPoint: hasActiveOverlapBrowser
                        ? () => _moveOverlapPoint(-1)
                        : null,
                    onNextOverlapPoint: hasActiveOverlapBrowser
                        ? () => _moveOverlapPoint(1)
                        : null,
                  ),
          ),
        ],
      ),
    );
  }

  LatLng get _fallbackCenter {
    return const LatLng(34.9671, 135.7727);
  }

  Future<void> _showGroupPicker(
    BuildContext context,
    List<PlanGroupBucket> groups,
  ) async {
    await showPlanGroupPickerSheet(
      context: context,
      groups: groups,
      selectedGroupId: groups[_selectedGroupIndex].id,
      showProgressRing: widget.settings.showPlanGroupProgress,
      onSelectGroup: (selectedGroup) {
        final index = groups.indexWhere(
          (group) => group.id == selectedGroup.id,
        );
        if (index >= 0) {
          _selectGroup(index, groups);
        }
      },
    );
  }
}

class _MapGroupFilterBar extends StatelessWidget {
  const _MapGroupFilterBar({required this.group, required this.onTap});

  final PlanGroupBucket group;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const ValueKey('map-group-filter-bar'),
      color: AppColors.surface.withValues(alpha: 0.94),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(
            children: [
              const Icon(LucideIcons.folder, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${group.name} · ${group.completedCount}/${group.points.length}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
              ),
              const Icon(LucideIcons.chevronDown, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapFloatingIconButton extends StatelessWidget {
  const _MapFloatingIconButton({
    required this.tooltip,
    required this.onTap,
    required this.child,
    this.selected = false,
  });

  final String tooltip;
  final VoidCallback? onTap;
  final Widget child;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: selected
            ? AppColors.accent.withValues(alpha: 0.95)
            : AppColors.surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: IconTheme(
            data: IconThemeData(
              color: selected ? AppColors.onAccent : AppColors.textPrimary,
            ),
            child: SizedBox(width: 38, height: 38, child: Center(child: child)),
          ),
        ),
      ),
    );
  }
}

class _PointMarker extends StatelessWidget {
  const _PointMarker({
    required this.selected,
    required this.status,
    required this.onTap,
  });

  final bool selected;
  final VisitStatus status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final markerColors = switch (status) {
      VisitStatus.current => (AppColors.accent, Colors.white),
      VisitStatus.completed => (
        AppColors.surfaceMuted,
        AppColors.textSecondary,
      ),
      VisitStatus.pending => (AppColors.surface, AppColors.accentDark),
    };

    return IconButton(
      tooltip: '巡礼点',
      onPressed: onTap,
      style: IconButton.styleFrom(
        backgroundColor: markerColors.$1,
        foregroundColor: markerColors.$2,
        side: BorderSide(
          color: selected ? AppColors.warning : AppColors.border,
          width: selected ? 2 : 1,
        ),
      ),
      icon: Icon(
        status == VisitStatus.completed
            ? LucideIcons.check
            : LucideIcons.mapPin,
        size: 24,
      ),
    );
  }
}

class _CurrentLocationMarker extends StatelessWidget {
  const _CurrentLocationMarker();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: AppColors.accent,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
        ),
      ),
    );
  }
}

const _mapPointActionExtent = 44.0;
const _mapPointPrimaryActionWidth = 52.0;

class _PointCard extends StatelessWidget {
  const _PointCard({
    required this.controller,
    required this.point,
    required this.status,
    required this.recordCount,
    required this.onSetCurrent,
    required this.onOpenDetail,
    required this.onOpenInAppNavigation,
    required this.onOpenExternalNavigation,
    required this.onOpenCamera,
    required this.onComplete,
    this.overlapPointIndex,
    this.overlapPointCount,
    this.onPreviousOverlapPoint,
    this.onNextOverlapPoint,
  });

  final PilgrimagePlanController controller;
  final PilgrimagePoint point;
  final VisitStatus status;
  final int recordCount;
  final VoidCallback? onSetCurrent;
  final VoidCallback onOpenDetail;
  final VoidCallback? onOpenInAppNavigation;
  final VoidCallback? onOpenExternalNavigation;
  final VoidCallback onOpenCamera;
  final VoidCallback onComplete;
  final int? overlapPointIndex;
  final int? overlapPointCount;
  final VoidCallback? onPreviousOverlapPoint;
  final VoidCallback? onNextOverlapPoint;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final showOverlapPager =
        overlapPointIndex != null &&
        overlapPointCount != null &&
        onPreviousOverlapPoint != null &&
        onNextOverlapPoint != null;

    return Container(
      margin: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottomInset),
      padding: EdgeInsets.fromLTRB(16, showOverlapPager ? 6 : 16, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showOverlapPager) ...[
            MapOverlapPointPager(
              currentIndex: overlapPointIndex!,
              total: overlapPointCount!,
              onPrevious: onPreviousOverlapPoint!,
              onNext: onNextOverlapPoint!,
            ),
            Divider(
              key: ValueKey('map-overlap-point-divider'),
              height: 1,
              color: AppColors.border,
            ),
            const SizedBox(height: 6),
          ],
          GestureDetector(
            key: ValueKey('map-point-card-content-${point.id}'),
            behavior: HitTestBehavior.opaque,
            onTap: onOpenDetail,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PointThumbnail(controller: controller, point: point),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _StatusBadge(status: status),
                          const SizedBox(width: 8),
                          Expanded(
                            child: CopyableText(
                              text: point.name,
                              copyLabel: '点位名称',
                              onTap: onOpenDetail,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      CopyableText(
                        text: _metaText,
                        copyText: _copySummary,
                        copyLabel: '点位信息',
                        onTap: onOpenDetail,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _SplitNavigationButton(
                  inAppLabel: point.hasCoordinate ? '导航' : '坐标待补充',
                  onOpenInAppNavigation: onOpenInAppNavigation,
                  onOpenExternalNavigation: onOpenExternalNavigation,
                ),
              ),
              const SizedBox(width: 4),
              SizedBox(
                width: _mapPointPrimaryActionWidth,
                height: _mapPointActionExtent,
                child: IconButton.outlined(
                  tooltip: '拍摄参考',
                  onPressed: onOpenCamera,
                  icon: SizedBox(
                    width: 24,
                    height: 24,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Center(child: Icon(LucideIcons.camera)),
                        if (recordCount > 0)
                          const Positioned(
                            top: -5,
                            right: -5,
                            child: _MapRecordBadge(),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              SizedBox(
                width: _mapPointPrimaryActionWidth,
                height: _mapPointActionExtent,
                child: IconButton.outlined(
                  tooltip: status == VisitStatus.completed ? '撤回打卡' : '标记完成',
                  onPressed: onComplete,
                  icon: Icon(
                    status == VisitStatus.completed
                        ? LucideIcons.undo2
                        : LucideIcons.circleCheckBig,
                  ),
                ),
              ),
              if (point.hasCoordinate &&
                  status != VisitStatus.current &&
                  status != VisitStatus.completed) ...[
                const SizedBox(width: 4),
                SizedBox(
                  width: _mapPointActionExtent,
                  height: _mapPointActionExtent,
                  child: IconButton.outlined(
                    tooltip: '设为当前目标',
                    onPressed: onSetCurrent,
                    icon: const Icon(LucideIcons.flag),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  String get _metaText {
    final episodeLabel = point.episodeLabel.trim();
    if (episodeLabel.isEmpty) {
      return point.work.title;
    }
    return '${point.work.title} / $episodeLabel';
  }

  String get _copySummary {
    return [
      point.name,
      '${point.work.title} / ${point.work.subtitle}',
      point.subtitle,
      point.displayEpisodeLabel,
      point.hasCoordinate
          ? '${point.position.latitude.toStringAsFixed(5)},${point.position.longitude.toStringAsFixed(5)}'
          : '坐标待补充',
    ].where((value) => value.trim().isNotEmpty).join('\n');
  }
}

class _SplitNavigationButton extends StatelessWidget {
  const _SplitNavigationButton({
    required this.inAppLabel,
    required this.onOpenInAppNavigation,
    required this.onOpenExternalNavigation,
  });

  final String inAppLabel;
  final VoidCallback? onOpenInAppNavigation;
  final VoidCallback? onOpenExternalNavigation;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final enabled =
        onOpenInAppNavigation != null || onOpenExternalNavigation != null;
    final foregroundColor = enabled
        ? colorScheme.onPrimary
        : colorScheme.onSurface.withValues(alpha: 0.38);
    final backgroundColor = enabled
        ? colorScheme.primary
        : colorScheme.onSurface.withValues(alpha: 0.12);

    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: _mapPointActionExtent,
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                key: const ValueKey('map-in-app-navigation-button'),
                onTap: onOpenInAppNavigation,
                child: Center(
                  child: IconTheme(
                    data: IconThemeData(color: foregroundColor),
                    child: Tooltip(
                      message: '应用内导航：$inAppLabel',
                      child: Semantics(
                        label: '应用内导航：$inAppLabel',
                        child: const Icon(Icons.directions_walk, size: 20),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Container(
              key: const ValueKey('map-navigation-button-divider'),
              width: 1,
              height: 28,
              color: foregroundColor.withValues(alpha: 0.38),
            ),
            Expanded(
              child: Tooltip(
                message: '打开外部地图',
                child: InkWell(
                  key: const ValueKey('map-external-navigation-button'),
                  onTap: onOpenExternalNavigation,
                  child: SizedBox(
                    height: _mapPointActionExtent,
                    child: Icon(
                      LucideIcons.navigation,
                      size: 21,
                      color: foregroundColor,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PointThumbnail extends StatelessWidget {
  const _PointThumbnail({required this.controller, required this.point});

  final PilgrimagePlanController controller;
  final PilgrimagePoint point;

  @override
  Widget build(BuildContext context) {
    final repository = controller.repository;
    final remoteImageUrl = hasRemoteReferenceImage(point)
        ? point.referenceImageUrl
        : null;
    return GestureDetector(
      onTap: () => ImageViewerScreen.show(
        context,
        filePath: point.referenceFullImagePath,
        imageUrl: remoteImageUrl,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 64,
          height: 64,
          color: AppColors.surfaceMuted,
          child: repository == null
              ? ReferenceThumbnail(
                  localPath: point.referenceThumbnailPath,
                  imageUrl: remoteImageUrl,
                  placeholder: Icon(
                    LucideIcons.image,
                    color: AppColors.accentDark,
                  ),
                )
              : AutoCachingReferenceThumbnail(
                  planId: controller.plan.id,
                  point: point,
                  repository: repository,
                  onPlanUpdated: controller.replacePlan,
                  placeholder: Icon(
                    LucideIcons.image,
                    color: AppColors.accentDark,
                  ),
                ),
        ),
      ),
    );
  }
}

class _MapRecordBadge extends StatelessWidget {
  const _MapRecordBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('map-point-shot-badge'),
      width: 16,
      height: 16,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.42)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Icon(LucideIcons.images, size: 10, color: AppColors.accentDark),
    );
  }
}

class _EmptyMapCard extends StatelessWidget {
  const _EmptyMapCard();

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Container(
      key: const ValueKey('map-empty-card'),
      margin: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottomInset),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(LucideIcons.map, color: AppColors.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '当前计划还没有点位',
                  style: TextStyle(
                    color: AppColors.accentDark,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '添加点位后会在地图上显示标记。',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    height: 1.45,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final VisitStatus status;

  @override
  Widget build(BuildContext context) {
    final text = switch (status) {
      VisitStatus.current => '当前',
      VisitStatus.completed => '完成',
      VisitStatus.pending => '待访',
    };

    final color = switch (status) {
      VisitStatus.current => AppColors.accent,
      VisitStatus.completed => AppColors.textSecondary,
      VisitStatus.pending => AppColors.warning,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
    );
  }
}
