import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../app_theme.dart';
import '../map/map_marker_clustering.dart';
import '../map/map_marker_scale.dart';
import '../map/map_navigation_launcher.dart';
import '../map/map_tile_config.dart';
import '../widgets/snackbar_helper.dart';
import '../data/anitabi_client.dart';
import '../data/anitabi_image_url.dart';
import '../data/pilgrimage_repository.dart';
import '../data/reference_image_cache_stub.dart'
    if (dart.library.io) '../data/reference_image_cache_io.dart'
    as reference_image_cache;
import '../widgets/copyable_text.dart';
import '../widgets/confirm_action_dialog.dart';
import '../widgets/input_dialog.dart';
import '../widgets/auto_caching_reference_thumbnail.dart';
import '../widgets/image_viewer_screen.dart';
import '../widgets/image_load_limiter.dart';
import '../widgets/map_thumbnail_marker.dart';
import '../widgets/reference_thumbnail_stub.dart'
    if (dart.library.io) '../widgets/reference_thumbnail_io.dart';
import '../widgets/responsive_button.dart';
import '../widgets/app_scaled_route.dart';
import '../widgets/app_back_button.dart';
import '../utils/limited_concurrency.dart';
import '../utils/selected_item_order.dart';
import 'nearest_group_assign_screen.dart';
import 'pilgrimage_models.dart';
import 'pilgrimage_work_dropdown.dart';
import 'plan_group_picker_sheet.dart';
import 'work_manager_screen.dart';

class AnitabiMapImportScreen extends StatefulWidget {
  AnitabiMapImportScreen({
    required this.plan,
    required this.repository,
    this.initialBangumiId,
    this.initialPointId,
    this.initialSettings,
    AnitabiClient? anitabiClient,
    super.key,
  }) : anitabiClient =
           anitabiClient ??
           AnitabiClient(serviceConfig: initialSettings?.anitabiServiceConfig);

  final PilgrimagePlan plan;
  final PilgrimageRepository repository;
  final int? initialBangumiId;
  final String? initialPointId;
  final AppSettings? initialSettings;
  final AnitabiClient anitabiClient;

  @override
  State<AnitabiMapImportScreen> createState() => _AnitabiMapImportScreenState();
}

class _ImportOverlapPointBrowser {
  _ImportOverlapPointBrowser({required List<String> pointIds})
    : pointIds = List.unmodifiable(pointIds);

  final List<String> pointIds;
}

class _AnitabiMapImportScreenState extends State<AnitabiMapImportScreen> {
  static const double _fallbackLoadedPointsZoom = 15;
  static const Duration _thumbnailBoundsDebounceDuration = Duration(
    milliseconds: 180,
  );

  final MapController _mapController = MapController();
  late final Set<String> _importedPointIds;
  late PilgrimagePlan _importedPlan = widget.plan;
  PilgrimageWork? _selectedWork;
  late AppSettings _settings = widget.initialSettings ?? const AppSettings();
  AnitabiBangumiLite? _lite;
  List<AnitabiPoint> _points = const [];
  AnitabiPoint? _selectedPoint;
  _ImportOverlapPointBrowser? _overlapPointBrowser;
  Object? _error;
  bool _isLoading = false;
  bool _isImporting = false;
  _ImportProgress? _importProgress;
  bool _didUpdatePlan = false;
  bool _showThumbnailMarkers = false;
  bool _isBoxSelecting = false;
  Offset? _selectionStart;
  Offset? _selectionEnd;
  int _loadGeneration = 0;
  final ValueNotifier<LatLngBounds?> _visibleBoundsNotifier = ValueNotifier(
    null,
  );
  Timer? _thumbnailBoundsDebounce;
  LatLng? _pendingMapCenter;
  double? _pendingMapZoom;
  late final ImageLoadLimiter _thumbnailLoadLimiter = ImageLoadLimiter(
    _settings.mapThumbnailConcurrentLoads,
  );

  List<PilgrimageWork> get _works {
    final selectedWork = _selectedWork;
    if (selectedWork == null ||
        _importedPlan.works.any((work) => work.id == selectedWork.id)) {
      return _importedPlan.works;
    }
    return [..._importedPlan.works, selectedWork];
  }

  int _nextLoadGeneration() {
    _loadGeneration += 1;
    return _loadGeneration;
  }

  bool _isActiveLoad(int generation) {
    return mounted && generation == _loadGeneration;
  }

  @override
  void initState() {
    super.initState();
    _importedPointIds = widget.plan.points.map((point) => point.id).toSet();
    _loadSettings();
    final initialBangumiId = widget.initialBangumiId;
    final initialPointId = widget.initialPointId;
    if (initialBangumiId != null && initialPointId != null) {
      _loadInitialPointLink(initialBangumiId, initialPointId);
      return;
    }

    if (initialBangumiId != null) {
      _loadInitialBangumiId(initialBangumiId);
    } else {
      final works = _works;
      if (works.isNotEmpty) {
        final bangumiWork = works
            .where((work) => work.bangumiId != null)
            .firstOrNull;
        final initialWork = bangumiWork ?? works.first;
        _selectedWork = initialWork;
        if (initialWork.bangumiId != null) {
          _loadPoints(initialWork);
        }
      }
    }
  }

  Future<void> _loadSettings() async {
    final settings = await widget.repository.loadAppSettings();
    if (!mounted) {
      return;
    }
    setState(() {
      _settings = settings;
    });
    _thumbnailLoadLimiter.maxConcurrent = settings.mapThumbnailConcurrentLoads;
  }

  @override
  void dispose() {
    _thumbnailBoundsDebounce?.cancel();
    _visibleBoundsNotifier.dispose();
    super.dispose();
  }

  Future<void> _refreshAnitabiData() async {
    widget.anitabiClient.clearStaticCache();
    ScaffoldMessenger.of(context).showStatusSnack(
      kind: AppStatusBannerKind.running,
      title: '正在清除缓存并重新加载 Anitabi 点位...',
      icon: LucideIcons.brushCleaning,
    );

    final initialBangumiId = widget.initialBangumiId;
    final initialPointId = widget.initialPointId;
    if (initialBangumiId != null && initialPointId != null) {
      await _loadInitialPointLink(initialBangumiId, initialPointId);
      return;
    }

    if (initialBangumiId != null && _selectedWork == null) {
      await _loadInitialBangumiId(initialBangumiId);
      return;
    }

    final works = _works;
    final work =
        _selectedWork ??
        works.where((work) => work.bangumiId != null).firstOrNull ??
        works.firstOrNull;
    if (work?.bangumiId != null) {
      await _loadPoints(work!);
      return;
    }

    setState(() {
      _error = null;
    });
  }

  Future<void> _openWorkManager() async {
    final didUpdate = await Navigator.of(context).push<bool>(
      appScaledMaterialPageRoute<bool>(
        settings: _settings,
        builder: (_) => WorkManagerScreen(
          plan: _importedPlan,
          repository: widget.repository,
          settings: _settings,
        ),
      ),
    );
    if (!mounted || didUpdate != true) {
      return;
    }

    final plans = await widget.repository.loadPlans();
    if (!mounted) {
      return;
    }
    final updatedPlan = plans.firstWhere((plan) => plan.id == _importedPlan.id);
    setState(() {
      _replaceImportedPlan(updatedPlan);
      _didUpdatePlan = true;
    });
    await _refreshAnitabiData();
  }

  Future<void> _loadPoints(PilgrimageWork work) async {
    final generation = _nextLoadGeneration();
    final bangumiId = work.bangumiId;
    if (bangumiId == null) {
      setState(() {
        _selectedWork = work;
        _isLoading = false;
        _error = null;
        _lite = null;
        _points = const [];
        _overlapPointBrowser = null;
        _selectedPoint = null;
      });
      _showManualWorkMessage();
      return;
    }

    setState(() {
      _selectedWork = work;
      _isLoading = true;
      _error = null;
      _points = const [];
      _overlapPointBrowser = null;
      _selectedPoint = null;
    });

    try {
      final lite = await _fetchBangumiLite(work);
      if (!_isActiveLoad(generation)) {
        return;
      }
      final points = await widget.anitabiClient.fetchPoints(
        bangumiId,
        lite: lite,
      );
      if (!_isActiveLoad(generation)) {
        return;
      }

      setState(() {
        _lite = lite;
        _points = points;
        _overlapPointBrowser = null;
        _selectedPoint = _initialSelectedPointForLoadedPoints(points, lite);
      });
      _requestMapMove(
        _centerForLoadedPoints(points, lite),
        _zoomForLoadedPoints(points, lite),
      );
    } catch (error) {
      if (!_isActiveLoad(generation)) {
        return;
      }

      setState(() {
        _error = error;
      });
    } finally {
      if (_isActiveLoad(generation)) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showManualWorkMessage() {
    ScaffoldMessenger.of(context).showStatusSnack(
      kind: AppStatusBannerKind.warning,
      title: '手动添加的作品没有 Bangumi ID，无法从 Anitabi 地图导入点位。',
    );
  }

  void _requestMapMove(LatLng center, double zoom) {
    _pendingMapCenter = center;
    _pendingMapZoom = zoom;
    _moveMapAfterBuild(center, zoom);
  }

  void _moveMapAfterBuild(LatLng center, double zoom, {int attempt = 0}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      try {
        _mapController.move(center, zoom);
        if (_pendingMapCenter == center && _pendingMapZoom == zoom) {
          _pendingMapCenter = null;
          _pendingMapZoom = null;
        }
      } catch (_) {
        if (attempt < 5) {
          Future<void>.delayed(const Duration(milliseconds: 50), () {
            if (mounted) {
              _moveMapAfterBuild(center, zoom, attempt: attempt + 1);
            }
          });
        }
      }
    });
  }

  void _handleMapReady() {
    final center = _pendingMapCenter;
    final zoom = _pendingMapZoom;
    if (center != null && zoom != null) {
      _moveMapAfterBuild(center, zoom);
    }
  }

  Future<void> _loadInitialBangumiId(int bangumiId) async {
    final generation = _nextLoadGeneration();
    setState(() {
      _isLoading = true;
      _error = null;
      _points = const [];
      _overlapPointBrowser = null;
      _selectedPoint = null;
    });

    try {
      final lite = await _fetchBangumiLiteForBangumiId(bangumiId);
      if (!_isActiveLoad(generation)) {
        return;
      }
      final work = _workForBangumiId(lite.bangumiId) ?? _workFromLite(lite);

      final points = await widget.anitabiClient.fetchPoints(
        lite.bangumiId,
        lite: lite,
      );
      if (!_isActiveLoad(generation)) {
        return;
      }

      setState(() {
        _selectedWork = work;
        _lite = lite;
        _points = points;
        _overlapPointBrowser = null;
        _selectedPoint = _initialSelectedPointForLoadedPoints(points, lite);
      });
      _requestMapMove(
        _centerForLoadedPoints(points, lite),
        _zoomForLoadedPoints(points, lite),
      );
    } catch (error) {
      if (!_isActiveLoad(generation)) {
        return;
      }

      setState(() {
        _error = error;
      });
    } finally {
      if (_isActiveLoad(generation)) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadInitialPointLink(int bangumiId, String pointId) async {
    final generation = _nextLoadGeneration();
    setState(() {
      _isLoading = true;
      _error = null;
      _points = const [];
      _overlapPointBrowser = null;
      _selectedPoint = null;
    });

    try {
      final result =
          await widget.anitabiClient.findPointGlobally(pointId: pointId) ??
          await widget.anitabiClient.findPointInBangumi(
            bangumiId: bangumiId,
            pointId: pointId,
          );
      if (!_isActiveLoad(generation)) {
        return;
      }
      if (result == null) {
        throw const AnitabiPointNotFoundException();
      }

      final lite = result.work;
      final work = _workForBangumiId(lite.bangumiId) ?? _workFromLite(lite);

      setState(() {
        _selectedWork = work;
        _lite = lite;
        _points = result.points;
        _overlapPointBrowser = null;
        _selectedPoint = result.point;
      });
      _requestMapMove(result.point.position, math.max(lite.zoom, 15));
    } catch (error) {
      if (!_isActiveLoad(generation)) {
        return;
      }

      setState(() {
        _error = error;
      });
    } finally {
      if (_isActiveLoad(generation)) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<AnitabiBangumiLite> _fetchBangumiLite(PilgrimageWork work) async {
    final bangumiId = work.bangumiId;
    if (bangumiId == null) {
      throw const AnitabiStaticDataUnavailableException('Missing Bangumi ID');
    }

    final staticLite = await _fetchStaticBangumiLiteIfSupported(bangumiId);
    if (staticLite != null) {
      return staticLite;
    }

    try {
      return await widget.anitabiClient.fetchBangumiLite(bangumiId);
    } catch (_) {
      return AnitabiBangumiLite(
        bangumiId: bangumiId,
        title: work.title,
        subtitle: work.subtitle,
        city: work.city,
        center: const LatLng(35.0, 135.0),
        zoom: 12,
        pointsLength: 0,
      );
    }
  }

  Future<AnitabiBangumiLite> _fetchBangumiLiteForBangumiId(
    int bangumiId,
  ) async {
    final staticLite = await _fetchStaticBangumiLiteIfSupported(bangumiId);
    if (staticLite != null) {
      return staticLite;
    }
    return widget.anitabiClient.fetchBangumiLite(bangumiId);
  }

  Future<AnitabiBangumiLite?> _fetchStaticBangumiLiteIfSupported(
    int bangumiId,
  ) {
    if (widget.anitabiClient.runtimeType != AnitabiClient) {
      return Future.value();
    }
    return widget.anitabiClient.fetchBangumiLiteFromStatic(bangumiId);
  }

  PilgrimageWork? _workForBangumiId(int bangumiId) {
    for (final work in _importedPlan.works) {
      if (work.bangumiId == bangumiId) {
        return work;
      }
    }
    return null;
  }

  PilgrimageWork _workFromLite(AnitabiBangumiLite lite) {
    return PilgrimageWork(
      id: 'bangumi-${lite.bangumiId}',
      bangumiId: lite.bangumiId,
      title: lite.title,
      subtitle: lite.subtitle,
      city: lite.city,
      source: WorkSource.bangumi,
    );
  }

  void _replaceImportedPlan(PilgrimagePlan plan) {
    final previousSelectedWork = _selectedWork;
    _importedPlan = plan;
    if (previousSelectedWork != null) {
      _selectedWork = _matchingWorkInPlan(plan, previousSelectedWork);
    }
    _importedPointIds
      ..clear()
      ..addAll(plan.points.map((point) => point.id));
  }

  PilgrimageWork? _matchingWorkInPlan(
    PilgrimagePlan plan,
    PilgrimageWork selectedWork,
  ) {
    for (final work in plan.works) {
      if (work.id == selectedWork.id) {
        return work;
      }
    }
    final bangumiId = selectedWork.bangumiId;
    if (bangumiId != null) {
      for (final work in plan.works) {
        if (work.bangumiId == bangumiId) {
          return work;
        }
      }
    }
    return plan.works.firstOrNull;
  }

  void _selectPoint(
    AnitabiPoint point, {
    bool preserveOverlapBrowser = false,
    _ImportOverlapPointBrowser? overlapPointBrowser,
  }) {
    if (_isImporting) {
      return;
    }
    final selectedBangumiId = _selectedWork?.bangumiId;
    if (selectedBangumiId == null || point.bangumiId != selectedBangumiId) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    messenger.removeCurrentSnackBar();
    messenger.clearSnackBars();
    setState(() {
      if (overlapPointBrowser != null) {
        _overlapPointBrowser = overlapPointBrowser;
      } else if (!preserveOverlapBrowser) {
        _overlapPointBrowser = null;
      }
      _selectedPoint = point;
    });
  }

  void _openOverlapPointBrowser(
    List<AnitabiPoint> points,
    List<AnitabiPoint> visiblePoints,
  ) {
    if (_isImporting) {
      return;
    }
    final orderedPoints = orderMapClusterItems<AnitabiPoint>(
      items: points,
      planOrder: visiblePoints,
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
      overlapPointBrowser: _ImportOverlapPointBrowser(
        pointIds: orderedPoints.map((point) => point.id).toList(),
      ),
    );
  }

  void _moveOverlapPoint(int offset) {
    final browser = _overlapPointBrowser;
    if (browser == null || browser.pointIds.length < 2) {
      return;
    }
    final pointsById = {
      for (final point in _pointsForWork(_selectedWork)) point.id: point,
    };
    final points = [
      for (final pointId in browser.pointIds) ?pointsById[pointId],
    ];
    if (points.length < 2) {
      setState(() => _overlapPointBrowser = null);
      return;
    }
    final selectedIndex = points.indexWhere(
      (point) => point.id == _selectedPoint?.id,
    );
    final nextIndex = nextMapOverlapIndex(
      currentIndex: selectedIndex < 0 ? 0 : selectedIndex,
      offset: offset,
      total: points.length,
    );
    _selectPoint(points[nextIndex], preserveOverlapBrowser: true);
  }

  PilgrimagePoint? _importedPointFor(AnitabiPoint point) {
    final importedPointId = point.toPilgrimagePoint(_selectedWork!).id;
    for (final importedPoint in _importedPlan.points) {
      if (importedPoint.id == importedPointId) {
        return importedPoint;
      }
    }
    return null;
  }

  List<AnitabiPoint> get _availablePoints {
    final work = _selectedWork;
    if (work == null) {
      return const [];
    }
    return _pointsForWork(work)
        .where(
          (point) =>
              !_importedPointIds.contains(point.toPilgrimagePoint(work).id),
        )
        .toList(growable: false);
  }

  List<AnitabiPoint> _pointsForWork(PilgrimageWork? work) {
    final bangumiId = work?.bangumiId;
    if (bangumiId == null) {
      return const [];
    }
    return _points
        .where((point) => point.bangumiId == bangumiId)
        .toList(growable: false);
  }

  AnitabiPoint? _selectedPointForWork(PilgrimageWork? work) {
    final point = _selectedPoint;
    final bangumiId = work?.bangumiId;
    if (point == null || bangumiId == null || point.bangumiId != bangumiId) {
      return null;
    }
    return point;
  }

  LatLng _initialMapCenter({
    required AnitabiPoint? selectedPoint,
    required List<AnitabiPoint> visiblePoints,
  }) {
    final pendingCenter = _pendingMapCenter;
    if (pendingCenter != null) {
      return pendingCenter;
    }
    if (selectedPoint != null) {
      return selectedPoint.position;
    }
    return _centerForLoadedPoints(visiblePoints, _lite);
  }

  double _initialMapZoom({required AnitabiPoint? selectedPoint}) {
    final pendingZoom = _pendingMapZoom;
    if (pendingZoom != null) {
      return pendingZoom;
    }
    final liteZoom = _lite?.zoom;
    if (selectedPoint != null) {
      return math.max(liteZoom ?? 15, 15);
    }
    return liteZoom ?? 12;
  }

  LatLng _centerForLoadedPoints(
    List<AnitabiPoint> points,
    AnitabiBangumiLite? lite,
  ) {
    final center = lite?.center;
    if (center != null && _isValidMapCenter(center)) {
      return center;
    }
    if (points.isEmpty) {
      return const LatLng(35.0, 135.0);
    }
    final boundsCenter = _pointBoundsCenter(points);
    return _nearestPointTo(boundsCenter, points).position;
  }

  LatLng _pointBoundsCenter(List<AnitabiPoint> points) {
    var minLat = points.first.position.latitude;
    var maxLat = minLat;
    var minLng = points.first.position.longitude;
    var maxLng = minLng;
    for (final point in points.skip(1)) {
      minLat = math.min(minLat, point.position.latitude);
      maxLat = math.max(maxLat, point.position.latitude);
      minLng = math.min(minLng, point.position.longitude);
      maxLng = math.max(maxLng, point.position.longitude);
    }
    return LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2);
  }

  double _zoomForLoadedPoints(
    List<AnitabiPoint> points,
    AnitabiBangumiLite? lite,
  ) {
    final center = lite?.center;
    if (points.isNotEmpty && (center == null || !_isValidMapCenter(center))) {
      return _fallbackLoadedPointsZoom;
    }
    return lite?.zoom ?? 12;
  }

  AnitabiPoint? _initialSelectedPointForLoadedPoints(
    List<AnitabiPoint> points,
    AnitabiBangumiLite? lite,
  ) {
    if (points.isEmpty) {
      return null;
    }

    final center = lite?.center;
    if (center != null && _isValidMapCenter(center)) {
      return points.first;
    }

    return _nearestPointTo(_pointBoundsCenter(points), points);
  }

  AnitabiPoint _nearestPointTo(LatLng center, List<AnitabiPoint> points) {
    var nearest = points.first;
    var nearestDistance = _roughDistanceSquared(center, nearest.position);
    for (final point in points.skip(1)) {
      final distance = _roughDistanceSquared(center, point.position);
      if (distance < nearestDistance) {
        nearest = point;
        nearestDistance = distance;
      }
    }
    return nearest;
  }

  double _roughDistanceSquared(LatLng first, LatLng second) {
    final lat = first.latitude - second.latitude;
    final lng = first.longitude - second.longitude;
    return lat * lat + lng * lng;
  }

  bool _isValidMapCenter(LatLng center) {
    final latitude = center.latitude;
    final longitude = center.longitude;
    if (!latitude.isFinite || !longitude.isFinite) {
      return false;
    }
    if (latitude.abs() < 0.0001 && longitude.abs() < 0.0001) {
      return false;
    }
    return latitude >= -90 &&
        latitude <= 90 &&
        longitude >= -180 &&
        longitude <= 180;
  }

  Rect? get _selectionRect {
    final start = _selectionStart;
    final end = _selectionEnd;
    if (start == null || end == null) {
      return null;
    }
    return Rect.fromPoints(start, end);
  }

  List<AnitabiPoint> _pointsInSelection() {
    final rect = _selectionRect;
    final work = _selectedWork;
    if (rect == null || work == null) {
      return const [];
    }

    return _availablePoints
        .where((point) {
          final offset = _mapController.camera.latLngToScreenOffset(
            point.position,
          );
          return rect.contains(offset);
        })
        .toList(growable: false);
  }

  Future<void> _importSelectedPoint() async {
    final work = _selectedWork;
    final point = _selectedPoint;
    if (work == null ||
        point == null ||
        point.bangumiId != work.bangumiId ||
        _isImporting) {
      return;
    }

    final pilgrimagePoint = point.toPilgrimagePoint(work);
    if (_importedPointIds.contains(pilgrimagePoint.id)) {
      return;
    }

    await _importPoints(
      [point],
      successMessage: '已加入计划，可继续选择点位。',
      failureMessage: '点位导入失败，请稍后重试。',
    );
  }

  Future<void> _importAllAvailablePoints() async {
    final points = _availablePoints;
    final confirmed = await _confirmBulkImport(
      title: '添加所有点位',
      message: '将把当前作品中 ${points.length} 个还不在计划里的点位加入计划，并暂时放在未分组。',
      confirmLabel: '添加全部',
    );
    if (!confirmed) {
      return;
    }

    await _importPoints(
      points,
      successMessage: '已添加所有未加入的点位。',
      failureMessage: '批量导入失败，请稍后重试。',
    );
  }

  Future<void> _importSelectedBoxPoints() async {
    final points = _pointsInSelection();
    if (points.isEmpty) {
      ScaffoldMessenger.of(context).showStatusSnack(
        kind: AppStatusBannerKind.warning,
        title: '框选范围内没有可添加点位',
      );
      return;
    }

    final confirmed = await _confirmBulkImport(
      title: '添加框选点位',
      message: '将把框选范围内 ${points.length} 个还不在计划里的点位加入计划，并暂时放在未分组。',
      confirmLabel: '添加框选',
    );
    if (!confirmed) {
      return;
    }

    await _importPoints(
      points,
      successMessage: '已添加框选点位。',
      failureMessage: '框选点位导入失败，请稍后重试。',
      exitBoxSelectionOnSuccess: true,
    );
  }

  Future<void> _importPoints(
    List<AnitabiPoint> points, {
    required String successMessage,
    required String failureMessage,
    bool exitBoxSelectionOnSuccess = false,
  }) async {
    final work = _selectedWork;
    if (work == null || points.isEmpty || _isImporting) {
      return;
    }

    final pilgrimagePoints = points
        .where((point) => point.bangumiId == work.bangumiId)
        .map((point) => point.toPilgrimagePoint(work))
        .where((point) => !_importedPointIds.contains(point.id))
        .toList(growable: false);
    if (pilgrimagePoints.isEmpty) {
      return;
    }

    setState(() {
      _isImporting = true;
      _importProgress = _ImportProgress.importing(
        total: pilgrimagePoints.length,
      );
    });

    var shouldShowOrganizeGuide = false;
    try {
      final messenger = ScaffoldMessenger.of(context);
      messenger.showStatusSnack(
        kind: AppStatusBannerKind.running,
        title: '正在导入 ${pilgrimagePoints.length} 个点位...',
        icon: LucideIcons.mapPinPlus,
      );
      var importedPlan = pilgrimagePoints.length == 1
          ? await widget.repository.addPointToPlan(
              planId: widget.plan.id,
              point: pilgrimagePoints.single,
            )
          : await widget.repository.addPointsToPlan(
              planId: widget.plan.id,
              points: pilgrimagePoints,
            );
      if (!mounted) {
        return;
      }

      setState(() {
        _replaceImportedPlan(importedPlan);
        _didUpdatePlan = true;
        _selectionStart = null;
        _selectionEnd = null;
        if (exitBoxSelectionOnSuccess) {
          _isBoxSelecting = false;
        }
        _importProgress = _ImportProgress.caching(
          total: pilgrimagePoints.length,
        );
      });

      var cached = 0;
      var cacheFailed = 0;
      var processed = 0;
      var lastProgressSnackBarAt = DateTime.fromMillisecondsSinceEpoch(0);
      final imageCacheUpdates = <String, PointImageCacheUpdate>{};
      await runLimitedConcurrent<PilgrimagePoint, _ThumbnailCacheResult>(
        items: pilgrimagePoints,
        maxConcurrent: _settings.mapThumbnailConcurrentLoads,
        task: (pilgrimagePoint, _) async {
          try {
            final thumbnailPath = await reference_image_cache
                .ensureReferenceThumbnailCached(
                  pilgrimagePoint,
                  imageSource: _settings.anitabiImageSource,
                );
            if (thumbnailPath == null || thumbnailPath.isEmpty) {
              return _ThumbnailCacheResult.failed(pilgrimagePoint.id);
            }
            return _ThumbnailCacheResult.succeeded(
              pointId: pilgrimagePoint.id,
              referenceThumbnailPath: thumbnailPath,
            );
          } catch (_) {
            return _ThumbnailCacheResult.failed(pilgrimagePoint.id);
          }
        },
        onResult: (result) {
          processed += 1;
          if (result.referenceThumbnailPath == null) {
            cacheFailed += 1;
          } else {
            cached += 1;
            imageCacheUpdates[result.pointId] = PointImageCacheUpdate(
              referenceThumbnailPath: result.referenceThumbnailPath,
              referenceFullImagePath: importedPlan.points
                  .firstWhere((point) => point.id == result.pointId)
                  .referenceFullImagePath,
            );
          }

          if (!mounted) {
            return;
          }
          setState(() {
            _replaceImportedPlan(importedPlan);
            _didUpdatePlan = true;
            _importProgress = _ImportProgress.caching(
              total: pilgrimagePoints.length,
              processed: processed,
              succeeded: cached,
            );
          });
          final now = DateTime.now();
          final shouldShowProgressSnackBar =
              processed == pilgrimagePoints.length ||
              now.difference(lastProgressSnackBarAt) >=
                  const Duration(milliseconds: 450);
          if (shouldShowProgressSnackBar) {
            lastProgressSnackBarAt = now;
            messenger.showStatusSnack(
              kind: AppStatusBannerKind.running,
              title: '正在缓存缩略图 $processed/${pilgrimagePoints.length}，成功 $cached',
              icon: LucideIcons.images,
              duration: const Duration(milliseconds: 1200),
            );
          }
        },
      );

      if (!mounted) {
        return;
      }

      if (imageCacheUpdates.isNotEmpty) {
        importedPlan = await widget.repository.updatePointImageCaches(
          planId: widget.plan.id,
          updatesByPointId: imageCacheUpdates,
        );
      }

      setState(() {
        _replaceImportedPlan(importedPlan);
        _didUpdatePlan = true;
        _selectionStart = null;
        _selectionEnd = null;
        if (exitBoxSelectionOnSuccess) {
          _isBoxSelecting = false;
        }
      });
      messenger.showStatusSnack(
        kind: cacheFailed == 0
            ? AppStatusBannerKind.success
            : AppStatusBannerKind.warning,
        title: cacheFailed == 0
            ? successMessage
            : '已导入 ${pilgrimagePoints.length} 个点位，缩略图缓存 $cached/${pilgrimagePoints.length}，其余稍后会自动补齐。',
      );
      shouldShowOrganizeGuide = pilgrimagePoints.length > 1;
    } catch (error, stackTrace) {
      debugPrint('Failed to import Anitabi points: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showStatusSnack(kind: AppStatusBannerKind.error, title: failureMessage);
      return;
    } finally {
      if (mounted) {
        setState(() {
          _isImporting = false;
          _importProgress = null;
        });
      }
    }

    if (!mounted || !shouldShowOrganizeGuide) {
      return;
    }
    try {
      await _showOrganizeImportedPointsGuide(pilgrimagePoints);
    } catch (error, stackTrace) {
      debugPrint('Failed to organize imported Anitabi points: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showStatusSnack(
          kind: AppStatusBannerKind.warning,
          title: '点位已导入，但整理流程打开失败，可以稍后在计划中调整片区。',
        );
      }
    }
  }

  Future<bool> _confirmBulkImport({
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    return showConfirmActionDialog(
      context,
      title: title,
      message: message,
      confirmLabel: confirmLabel,
    );
  }

  Future<void> _showOrganizeImportedPointsGuide(
    List<PilgrimagePoint> importedPoints,
  ) async {
    final action = await showDialog<_ImportOrganizeAction>(
      context: context,
      builder: (context) => _ImportOrganizeDialog(
        importedCount: importedPoints.length,
        onNearestAssign: () =>
            Navigator.of(context).pop(_ImportOrganizeAction.nearestAssign),
        onAssignToGroup: () =>
            Navigator.of(context).pop(_ImportOrganizeAction.assignToGroup),
        onLater: () => Navigator.of(context).pop(_ImportOrganizeAction.later),
      ),
    );
    if (!mounted || action == null || action == _ImportOrganizeAction.later) {
      return;
    }

    switch (action) {
      case _ImportOrganizeAction.assignToGroup:
        await _assignImportedPointsToGroup(
          importedPoints.map((point) => point.id).toSet(),
        );
      case _ImportOrganizeAction.nearestAssign:
        await _openNearestAssign();
      case _ImportOrganizeAction.later:
        break;
    }
  }

  Future<void> _assignImportedPointsToGroup(Set<String> pointIds) async {
    const ungroupedOptionId = '__ungrouped__';
    final groups = _importedPlan.groups.toList(growable: false)
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    final selectedGroupId = await showPlanGroupSelectionSheet(
      context: context,
      title: '分配到片区',
      subtitle: '选择一个片区作为刚导入点位的所属片区',
      selectedOptionId: ungroupedOptionId,
      options: [
        const PlanGroupSelectionOption(id: ungroupedOptionId, title: '未分入片区'),
        for (final group in groups)
          PlanGroupSelectionOption(id: group.id, title: group.name),
      ],
      onCreateOption: () async {
        final created = await _createGroupForAssignment();
        return created == null
            ? null
            : PlanGroupSelectionOption(id: created.id, title: created.name);
      },
    );
    if (!mounted || selectedGroupId == null) {
      return;
    }

    final groupId = selectedGroupId == ungroupedOptionId
        ? null
        : selectedGroupId;
    try {
      final updatedPlan = await widget.repository.movePointsToGroup(
        planId: _importedPlan.id,
        pointIds: pointIds,
        groupId: groupId,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _replaceImportedPlan(updatedPlan);
        _didUpdatePlan = true;
      });
      final groupName = groupId == null
          ? '未分入片区'
          : updatedPlan.groups
                    .where((group) => group.id == groupId)
                    .map((group) => group.name)
                    .firstOrNull ??
                '所选片区';
      ScaffoldMessenger.of(context).showStatusSnack(
        kind: AppStatusBannerKind.success,
        title: '已将 ${pointIds.length} 个点位分配到「$groupName」',
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showStatusSnack(
          kind: AppStatusBannerKind.error,
          title: '点位分配失败，请稍后重试。',
        );
      }
    }
  }

  Future<PilgrimagePlanGroup?> _createGroupForAssignment() async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => const _ImportedPointsCreateGroupDialog(),
    );
    final trimmedName = name?.trim();
    if (trimmedName == null || trimmedName.isEmpty || !mounted) {
      return null;
    }

    final nextOrderIndex = _importedPlan.groups.isEmpty
        ? 0
        : _importedPlan.groups
                  .map((group) => group.orderIndex)
                  .reduce((a, b) => a > b ? a : b) +
              1;
    final now = DateTime.now();
    final group = PilgrimagePlanGroup(
      id: 'group-${now.microsecondsSinceEpoch}',
      name: trimmedName,
      orderIndex: nextOrderIndex,
      createdAt: now,
    );
    try {
      final updatedPlan = await widget.repository.createPlanGroup(
        planId: _importedPlan.id,
        group: group,
      );
      if (!mounted) {
        return null;
      }
      setState(() {
        _replaceImportedPlan(updatedPlan);
        _didUpdatePlan = true;
      });
      return updatedPlan.groups
          .where((candidate) => candidate.id == group.id)
          .firstOrNull;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showStatusSnack(
          kind: AppStatusBannerKind.error,
          title: '片区创建失败，请稍后重试。',
        );
      }
      return null;
    }
  }

  Future<void> _openNearestAssign() async {
    final settings = await widget.repository.loadAppSettings();
    if (!mounted) {
      return;
    }
    await Navigator.of(context).push<bool>(
      appScaledMaterialPageRoute<bool>(
        settings: settings,
        builder: (_) => NearestGroupAssignScreen(
          plan: _importedPlan,
          settings: settings,
          repository: widget.repository,
        ),
      ),
    );
    if (mounted) {
      await _reloadImportedPlan();
    }
  }

  Future<void> _reloadImportedPlan() async {
    final plan = await widget.repository.loadActivePlan();
    if (!mounted) {
      return;
    }
    setState(() {
      _replaceImportedPlan(plan);
      _didUpdatePlan = true;
    });
  }

  void _toggleBoxSelection() {
    setState(() {
      _isBoxSelecting = !_isBoxSelecting;
      _selectionStart = null;
      _selectionEnd = null;
    });
  }

  void _handleMapEvent(MapEvent event) {
    if (_overlapPointBrowser != null && !isAtMaximumMapZoom(event.camera)) {
      setState(() => _overlapPointBrowser = null);
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
    Iterable<AnitabiPoint> points,
    LatLngBounds? bounds,
  ) {
    if (!_showThumbnailMarkers) {
      return const <String>{};
    }
    final threshold = _settings.mapThumbnailVisibleThreshold.clamp(0, 200);
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

  void _toggleThumbnailMarkers() {
    setState(() {
      _showThumbnailMarkers = !_showThumbnailMarkers;
      if (!_showThumbnailMarkers) {
        _thumbnailBoundsDebounce?.cancel();
        _visibleBoundsNotifier.value = null;
      } else {
        try {
          _visibleBoundsNotifier.value = _mapController.camera.visibleBounds;
        } catch (_) {
          _visibleBoundsNotifier.value = null;
        }
      }
    });
  }

  Marker _buildImportPointMarker({
    required AnitabiPoint point,
    required AnitabiPoint? selectedPoint,
    required Set<String> thumbnailPointIds,
  }) {
    final imported = _importedPointIds.contains(
      point.toPilgrimagePoint(_selectedWork!).id,
    );
    final isSelected = selectedPoint?.id == point.id;
    final showThumbnail =
        _showThumbnailMarkers &&
        (isSelected || thumbnailPointIds.contains(point.id));
    final scale = normalizedMapMarkerScale(_settings.mapMarkerScale);
    final baseWidth = _showThumbnailMarkers
        ? (showThumbnail ? 84.0 : 24.0)
        : 40.0;
    final baseHeight = _showThumbnailMarkers
        ? (showThumbnail ? 82.0 : 24.0)
        : 40.0;
    return Marker(
      key: ValueKey('anitabi-import-marker-${point.id}'),
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
                key: ValueKey('anitabi-import-thumbnail-marker-${point.id}'),
                selected: isSelected,
                imported: imported,
                showThumbnail: showThumbnail,
                markerColor: imported
                    ? AppColors.textSecondary
                    : AppColors.accent,
                imageLoadLimiter: _thumbnailLoadLimiter,
                localPath: _importedPointFor(point)?.referenceThumbnailPath,
                imageUrl: _anitabiThumbnailUrl(point.referenceImageUrl),
                imageSource: _settings.anitabiImageSource,
                tooltip: 'Anitabi 点位',
                onTap: _isImporting ? null : () => _selectPoint(point),
              )
            : _ImportMarker(
                selected: isSelected,
                imported: imported,
                onTap: _isImporting ? null : () => _selectPoint(point),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final works = _works;
    final selectedWork = _selectedWork;
    final visiblePoints = _pointsForWork(selectedWork);
    final selectedPoint = _selectedPointForWork(selectedWork);
    final mapPoints = selectedItemsLast<AnitabiPoint>(
      visiblePoints,
      isSelected: (point) => point.id == selectedPoint?.id,
    );
    final pointsById = {for (final point in visiblePoints) point.id: point};
    final overlapPoints = [
      for (final pointId in _overlapPointBrowser?.pointIds ?? const <String>[])
        ?pointsById[pointId],
    ];
    final overlapPointIndex = overlapPoints.indexWhere(
      (point) => point.id == selectedPoint?.id,
    );
    final hasActiveOverlapBrowser =
        overlapPoints.length > 1 && overlapPointIndex >= 0;

    return PopScope(
      canPop: !_isImporting,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          return;
        }

        Navigator.of(context).pop(_didUpdatePlan);
      },
      child: Scaffold(
        appBar: AppBar(
          leading: appBackButtonIfCanPop(context),
          title: const Text('从作品地图导入'),
          actions: [
            Tooltip(
              message: _showThumbnailMarkers ? '使用图标标记' : '显示缩略图标记',
              child: IconButton(
                onPressed: _toggleThumbnailMarkers,
                icon: Icon(
                  _showThumbnailMarkers
                      ? LucideIcons.mapPin
                      : LucideIcons.image,
                ),
              ),
            ),
            Tooltip(
              message: '清除缓存并重新加载 Anitabi 点位',
              child: IconButton(
                onPressed: _isLoading || _isImporting
                    ? null
                    : _refreshAnitabiData,
                icon: const Icon(LucideIcons.refreshCw),
              ),
            ),
          ],
          bottom: works.isEmpty
              ? null
              : PreferredSize(
                  preferredSize: const Size.fromHeight(58),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: PilgrimageWorkDropdown(
                      works: works,
                      value: _selectedWork,
                      settings: _settings,
                      omitScrollbarInsetWhenUnscrollable: true,
                      onChanged: _isImporting
                          ? null
                          : (work) {
                              if (work != null) {
                                _loadPoints(work);
                              }
                            },
                    ),
                  ),
                ),
        ),
        body: Builder(
          builder: (context) {
            if (_error != null) {
              return _ImportErrorState(
                message: _errorMessageFor(_error),
                detail: _errorDetailFor(_error),
                onRetry: _refreshAnitabiData,
              );
            }

            if (_isLoading && _points.isEmpty) {
              return const _ImportLoadingState();
            }

            if (works.isEmpty) {
              return _EmptyImportState(onOpenWorkManager: _openWorkManager);
            }

            if (!_isLoading &&
                selectedWork?.bangumiId == null &&
                visiblePoints.isEmpty) {
              return const _ManualWorkImportState();
            }

            if (!_isLoading &&
                selectedWork?.bangumiId != null &&
                _lite != null &&
                visiblePoints.isEmpty) {
              return _NoAnitabiPointsState(workTitle: selectedWork!.title);
            }

            return LayoutBuilder(
              builder: (context, constraints) {
                final selectedBoxCount = _pointsInSelection().length;

                return Stack(
                  children: [
                    FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: _initialMapCenter(
                          selectedPoint: selectedPoint,
                          visiblePoints: visiblePoints,
                        ),
                        initialZoom: _initialMapZoom(
                          selectedPoint: selectedPoint,
                        ),
                        minZoom: 4,
                        maxZoom: _settings.mapMaxZoom.toDouble(),
                        onMapReady: _handleMapReady,
                        onMapEvent: _handleMapEvent,
                        keepAlive: true,
                        interactionOptions: const InteractionOptions(
                          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                        ),
                      ),
                      children: [
                        configuredMapTileLayer(_settings),
                        ValueListenableBuilder<LatLngBounds?>(
                          valueListenable: _visibleBoundsNotifier,
                          builder: (context, visibleBounds, _) {
                            final camera = MapCamera.of(context);
                            final thumbnailPointIds =
                                _thumbnailPointIdsForCurrentView(
                                  visiblePoints,
                                  visibleBounds,
                                );
                            final atMaximumZoom = isAtMaximumMapZoom(camera);
                            final normalClusteringEnabled =
                                _settings.mapMarkerClusteringEnabled &&
                                camera.zoom <=
                                    _settings.mapMarkerClusterMaxZoom;
                            final overlapClusteringEnabled =
                                _settings.mapMarkerClusteringEnabled &&
                                camera.zoom > _settings.mapMarkerClusterMaxZoom;
                            final clusteringEnabled =
                                normalClusteringEnabled ||
                                overlapClusteringEnabled;
                            final activeOverlapPointIds =
                                hasActiveOverlapBrowser && atMaximumZoom
                                ? overlapPoints.map((point) => point.id).toSet()
                                : const <String>{};
                            final clusterItems = activeOverlapPointIds.isEmpty
                                ? mapPoints
                                : mapPoints
                                      .where(
                                        (point) => !activeOverlapPointIds
                                            .contains(point.id),
                                      )
                                      .toList(growable: false);
                            final terminalRadiusLimit =
                                scaledMapMarkerDimension(
                                  _showThumbnailMarkers ? 52 : 44,
                                  _settings.mapMarkerScale,
                                );
                            final clusterRadius = normalClusteringEnabled
                                ? _settings.mapMarkerClusterRadius.toDouble()
                                : _settings.mapMarkerClusterRadius
                                      .toDouble()
                                      .clamp(1, terminalRadiusLimit)
                                      .toDouble();
                            final markerClusters = clusteringEnabled
                                ? clusterMapMarkers<AnitabiPoint>(
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
                                        selectedPoint != null)
                                      MapMarkerCluster(
                                        items: [selectedPoint],
                                        position: selectedPoint.position,
                                      ),
                                  ];
                            if (clusteringEnabled &&
                                activeOverlapPointIds.isNotEmpty &&
                                selectedPoint != null) {
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
                                        'anitabi-import-cluster-${cluster.items.first.id}-${cluster.items.length}',
                                      ),
                                      point: cluster.position,
                                      width: scaledMapMarkerDimension(
                                        50,
                                        _settings.mapMarkerScale,
                                      ),
                                      height: scaledMapMarkerDimension(
                                        50,
                                        _settings.mapMarkerScale,
                                      ),
                                      child: ScaledMapMarker(
                                        baseWidth: 50,
                                        baseHeight: 50,
                                        scale: _settings.mapMarkerScale,
                                        child: Center(
                                          child: MapMarkerClusterBadge(
                                            count: cluster.items.length,
                                            opensPointBrowser: atMaximumZoom,
                                            onTap: atMaximumZoom
                                                ? () =>
                                                      _openOverlapPointBrowser(
                                                        cluster.items,
                                                        visiblePoints,
                                                      )
                                                : () => _mapController.move(
                                                    cluster.position,
                                                    normalClusteringEnabled
                                                        ? nextClusterZoom(
                                                            camera,
                                                            _settings
                                                                .mapMarkerClusterMaxZoom,
                                                          )
                                                        : nextOverlapClusterZoom(
                                                            camera,
                                                          ),
                                                  ),
                                          ),
                                        ),
                                      ),
                                    )
                                  else
                                    _buildImportPointMarker(
                                      point: cluster.items.single,
                                      selectedPoint: selectedPoint,
                                      thumbnailPointIds: thumbnailPointIds,
                                    ),
                              ],
                            );
                          },
                        ),
                        configuredMapAttribution(_settings),
                      ],
                    ),
                    if (_isBoxSelecting)
                      Positioned.fill(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onPanStart: (details) {
                            setState(() {
                              _selectionStart = details.localPosition;
                              _selectionEnd = details.localPosition;
                            });
                          },
                          onPanUpdate: (details) {
                            setState(() {
                              _selectionEnd = details.localPosition;
                            });
                          },
                          child: CustomPaint(
                            painter: _SelectionRectPainter(_selectionRect),
                          ),
                        ),
                      ),
                    Positioned(
                      top: 12,
                      left: 16,
                      right: 16,
                      child: _ImportSummary(
                        isLoading: _isLoading,
                        isImporting: _isImporting,
                        importProgress: _importProgress,
                        importedCount: visiblePoints
                            .where(
                              (point) => _importedPointIds.contains(
                                point.toPilgrimagePoint(selectedWork!).id,
                              ),
                            )
                            .length,
                        totalCount: visiblePoints.length,
                        expectedCount: _lite?.pointsLength,
                        availableCount: _availablePoints.length,
                        boxSelectionEnabled: _isBoxSelecting,
                        selectedBoxCount: selectedBoxCount,
                        onToggleBoxSelection: _toggleBoxSelection,
                        onImportAll: _importAllAvailablePoints,
                        onImportSelection: _importSelectedBoxPoints,
                      ),
                    ),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: selectedPoint == null
                          ? _isLoading
                                ? const SizedBox.shrink()
                                : _NoPointSelectedCard(
                                    hasPoints: visiblePoints.isNotEmpty,
                                    expectedCount: _lite?.pointsLength,
                                  )
                          : _AnitabiPointCard(
                              point: selectedPoint,
                              planId: _importedPlan.id,
                              repository: widget.repository,
                              onPlanUpdated: (plan) {
                                if (!mounted) {
                                  return;
                                }
                                setState(() {
                                  _replaceImportedPlan(plan);
                                  _didUpdatePlan = true;
                                });
                              },
                              importedPoint: _importedPointFor(selectedPoint),
                              navigationPoint: selectedPoint.toPilgrimagePoint(
                                _selectedWork!,
                              ),
                              navigationApp: _settings.navigationApp,
                              imported: _importedPointIds.contains(
                                selectedPoint
                                    .toPilgrimagePoint(_selectedWork!)
                                    .id,
                              ),
                              isImporting: _isImporting,
                              onImport: _importSelectedPoint,
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
                );
              },
            );
          },
        ),
      ),
    );
  }

  String _errorMessageFor(Object? error) {
    if (error is AnitabiStaticDataUnavailableException) {
      return 'Anitabi 地图数据无法加载';
    }

    if (error is AnitabiWorkNotFoundException) {
      return 'Anitabi 中没有找到这个作品';
    }

    if (error is AnitabiNoPointsException) {
      return '当前作品暂无 Anitabi 点位';
    }

    if (error is AnitabiPartialPointsException) {
      return 'Anitabi 点位只加载到一部分';
    }

    if (error is AnitabiException && error.statusCode == 404) {
      return '这个 Bangumi 条目暂无 Anitabi 地图数据';
    }

    if (error is AnitabiPointNotFoundException) {
      return '没有找到这个 Anitabi 点位';
    }

    return 'Anitabi 点位加载失败';
  }

  String _errorDetailFor(Object? error) {
    if (error is AnitabiStaticDataUnavailableException) {
      if (kIsWeb) {
        return '可能是 Anitabi 地图数据缓存版本不一致，或当前预览服务网络请求被拦截。请清除缓存并重新加载 Anitabi 点位。';
      }
      return '无法读取 Anitabi 地图索引。请检查网络连接，或清除缓存并重新加载 Anitabi 点位。';
    }

    if (error is AnitabiWorkNotFoundException) {
      return '这个 Bangumi 条目在 Anitabi 地图数据中没有对应作品。可以尝试添加同名动画、原作或其它关联条目。';
    }

    if (error is AnitabiNoPointsException) {
      return 'Anitabi 中能找到这个作品，但当前还没有可导入的地图点位。';
    }

    if (error is AnitabiPartialPointsException) {
      return '当前只取得 ${error.loadedCount} / 共 ${error.expectedCount} 个点位。请重新加载，或检查网络是否能访问 Anitabi 地图数据。';
    }

    if (error is AnitabiException && error.statusCode == 404) {
      return '可以尝试在作品管理中添加同名的原作、游戏或其他关联条目。';
    }

    if (error is AnitabiPointNotFoundException) {
      return '链接里的点位 ID 可能已失效，或 Anitabi 地图数据尚未同步。';
    }

    return '请检查网络后重试，或稍后再重新加载。';
  }
}

enum _ImportProgressStage { importing, caching }

class _ImportProgress {
  const _ImportProgress.importing({required this.total})
    : stage = _ImportProgressStage.importing,
      processed = 0,
      succeeded = 0;

  const _ImportProgress.caching({
    required this.total,
    this.processed = 0,
    this.succeeded = 0,
  }) : stage = _ImportProgressStage.caching;

  final _ImportProgressStage stage;
  final int total;
  final int processed;
  final int succeeded;

  String get label {
    return switch (stage) {
      _ImportProgressStage.importing => '正在导入 $total 个点位...',
      _ImportProgressStage.caching => '正在缓存缩略图 $processed/$total，成功 $succeeded',
    };
  }
}

class _ImportOrganizeDialog extends StatelessWidget {
  const _ImportOrganizeDialog({
    required this.importedCount,
    required this.onNearestAssign,
    required this.onAssignToGroup,
    required this.onLater,
  });

  final int importedCount;
  final VoidCallback onNearestAssign;
  final VoidCallback onAssignToGroup;
  final VoidCallback onLater;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '整理刚导入的点位',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 12),
              Text.rich(
                TextSpan(
                  text: '已导入 ',
                  children: [
                    TextSpan(
                      text: '$importedCount 个点位',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const TextSpan(text: '，并暂时放在未分组。可以直接分配到片区，或按最近关键点快速分配。'),
                  ],
                ),
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  height: 1.55,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: onNearestAssign,
                child: const Text('最近分配'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: onAssignToGroup,
                child: const Text('分配到片区'),
              ),
              const SizedBox(height: 8),
              TextButton(onPressed: onLater, child: const Text('稍后')),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImportedPointsCreateGroupDialog extends StatefulWidget {
  const _ImportedPointsCreateGroupDialog();

  @override
  State<_ImportedPointsCreateGroupDialog> createState() =>
      _ImportedPointsCreateGroupDialogState();
}

class _ImportedPointsCreateGroupDialogState
    extends State<_ImportedPointsCreateGroupDialog> {
  final _controller = TextEditingController();
  String? _errorText;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      setState(() => _errorText = '片区名不能为空');
      return;
    }
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    return AppInputDialog(
      title: '新建片区',
      content: AppDialogField(
        label: '片区名称',
        child: TextField(
          onTapOutside: dismissKeyboardOnTapOutside,
          key: const ValueKey('anitabi-import-group-name-field'),
          controller: _controller,
          autofocus: true,
          decoration: appDialogInputDecoration(errorText: _errorText),
          textInputAction: TextInputAction.done,
          onChanged: (_) {
            if (_errorText != null) {
              setState(() => _errorText = null);
            }
          },
          onSubmitted: (_) => _submit(),
        ),
      ),
      confirmLabel: '创建',
      onConfirm: _submit,
    );
  }
}

enum _ImportOrganizeAction { later, assignToGroup, nearestAssign }

class _ThumbnailCacheResult {
  const _ThumbnailCacheResult._({
    required this.pointId,
    required this.referenceThumbnailPath,
  });

  factory _ThumbnailCacheResult.succeeded({
    required String pointId,
    required String referenceThumbnailPath,
  }) {
    return _ThumbnailCacheResult._(
      pointId: pointId,
      referenceThumbnailPath: referenceThumbnailPath,
    );
  }

  factory _ThumbnailCacheResult.failed(String pointId) {
    return _ThumbnailCacheResult._(
      pointId: pointId,
      referenceThumbnailPath: null,
    );
  }

  final String pointId;
  final String? referenceThumbnailPath;
}

class _ImportMarker extends StatelessWidget {
  const _ImportMarker({
    required this.selected,
    required this.imported,
    required this.onTap,
  });

  final bool selected;
  final bool imported;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: imported ? '已导入点位' : '可导入点位',
      onPressed: onTap,
      style: IconButton.styleFrom(
        backgroundColor: imported ? AppColors.surfaceMuted : AppColors.surface,
        foregroundColor: imported ? AppColors.textSecondary : AppColors.accent,
        side: BorderSide(
          color: selected ? AppColors.warning : AppColors.border,
          width: selected ? 2 : 1,
        ),
      ),
      icon: Icon(imported ? LucideIcons.check : LucideIcons.mapPin, size: 22),
    );
  }
}

class _ImportSummary extends StatelessWidget {
  const _ImportSummary({
    required this.isLoading,
    required this.isImporting,
    required this.importProgress,
    required this.importedCount,
    required this.totalCount,
    required this.expectedCount,
    required this.availableCount,
    required this.boxSelectionEnabled,
    required this.selectedBoxCount,
    required this.onToggleBoxSelection,
    required this.onImportAll,
    required this.onImportSelection,
  });

  final bool isLoading;
  final bool isImporting;
  final _ImportProgress? importProgress;
  final int importedCount;
  final int totalCount;
  final int? expectedCount;
  final int availableCount;
  final bool boxSelectionEnabled;
  final int selectedBoxCount;
  final VoidCallback onToggleBoxSelection;
  final VoidCallback onImportAll;
  final VoidCallback onImportSelection;

  @override
  Widget build(BuildContext context) {
    final expected = expectedCount;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (isLoading || isImporting)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(LucideIcons.map, color: AppColors.accent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isLoading
                      ? '正在加载 Anitabi 点位'
                      : importProgress?.label ??
                            '已导入 $importedCount / 当前显示 $totalCount${expected == null ? '' : ' / 共 $expected'}',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
          ),
          if (!isLoading) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                SizedBox(
                  width: 44,
                  height: 44,
                  child: IconButton.outlined(
                    tooltip: '添加所有点位',
                    onPressed: isImporting || availableCount == 0
                        ? null
                        : onImportAll,
                    icon: const Icon(LucideIcons.listChecks, size: 18),
                    style: _summaryIconButtonStyle(false),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 44,
                  height: 44,
                  child: IconButton.outlined(
                    tooltip: boxSelectionEnabled ? '退出框选' : '框选点位',
                    isSelected: boxSelectionEnabled,
                    onPressed: isImporting ? null : onToggleBoxSelection,
                    icon: const Icon(LucideIcons.scan, size: 18),
                    selectedIcon: const Icon(LucideIcons.scan, size: 18),
                    style: _summaryIconButtonStyle(boxSelectionEnabled),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: FilledButton(
                      onPressed:
                          isImporting ||
                              !boxSelectionEnabled ||
                              selectedBoxCount == 0
                          ? null
                          : onImportSelection,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        textStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0,
                        ),
                      ),
                      child: ResponsiveButtonContent(
                        icon: LucideIcons.mapPinPlus,
                        iconSize: 16,
                        label: selectedBoxCount == 0
                            ? '导入框选结果'
                            : '导入 $selectedBoxCount 个',
                        shortLabel: '导入',
                        semanticLabel: '导入框选结果',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  ButtonStyle _summaryIconButtonStyle(bool selected) {
    return IconButton.styleFrom(
      backgroundColor: selected
          ? AppColors.accent.withValues(alpha: 0.12)
          : AppColors.surface,
      foregroundColor: selected ? AppColors.accentDark : AppColors.textPrimary,
      disabledBackgroundColor: AppColors.surfaceMuted,
      disabledForegroundColor: AppColors.textSecondary,
      fixedSize: const Size.square(36),
      minimumSize: const Size.square(36),
      padding: EdgeInsets.zero,
      side: BorderSide(
        color: selected ? AppColors.accent : AppColors.border,
        width: selected ? 2 : 1,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }
}

class _SelectionRectPainter extends CustomPainter {
  const _SelectionRectPainter(this.rect);

  final Rect? rect;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = this.rect;
    if (rect == null) {
      return;
    }

    final normalized = Rect.fromLTRB(
      math.min(rect.left, rect.right),
      math.min(rect.top, rect.bottom),
      math.max(rect.left, rect.right),
      math.max(rect.top, rect.bottom),
    );
    final fillPaint = Paint()
      ..color = AppColors.accent.withValues(alpha: 0.14)
      ..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..color = AppColors.accent
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawRect(normalized, fillPaint);
    canvas.drawRect(normalized, strokePaint);
  }

  @override
  bool shouldRepaint(_SelectionRectPainter oldDelegate) {
    return oldDelegate.rect != rect;
  }
}

class _AnitabiPointCard extends StatelessWidget {
  const _AnitabiPointCard({
    required this.point,
    required this.planId,
    required this.repository,
    required this.onPlanUpdated,
    required this.importedPoint,
    required this.navigationPoint,
    required this.navigationApp,
    required this.imported,
    required this.isImporting,
    required this.onImport,
    this.overlapPointIndex,
    this.overlapPointCount,
    this.onPreviousOverlapPoint,
    this.onNextOverlapPoint,
  });

  final AnitabiPoint point;
  final String planId;
  final PilgrimageRepository repository;
  final ValueChanged<PilgrimagePlan> onPlanUpdated;
  final PilgrimagePoint? importedPoint;
  final PilgrimagePoint navigationPoint;
  final NavigationApp navigationApp;
  final bool imported;
  final bool isImporting;
  final VoidCallback onImport;
  final int? overlapPointIndex;
  final int? overlapPointCount;
  final VoidCallback? onPreviousOverlapPoint;
  final VoidCallback? onNextOverlapPoint;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final imageUrl = _anitabiThumbnailUrl(point.referenceImageUrl);
    final fullImageUrl = anitabiFullResolutionImageUrl(point.referenceImageUrl);
    final localThumbnailPath = importedPoint?.referenceThumbnailPath;
    final localFullPath = importedPoint?.referenceFullImagePath;
    final showOverlapPager =
        overlapPointIndex != null &&
        overlapPointCount != null &&
        onPreviousOverlapPoint != null &&
        onNextOverlapPoint != null;
    void openFullImage() {
      if (fullImageUrl == null) {
        return;
      }
      ImageViewerScreen.show(
        context,
        filePath: localFullPath,
        imageUrl: fullImageUrl,
      );
    }

    void openDetail() {
      _AnitabiPointDetailSheet.show(
        context,
        point: point,
        imageUrl: imageUrl,
        fullImageUrl: fullImageUrl,
        localThumbnailPath: localThumbnailPath,
        localFullPath: localFullPath,
        imported: imported,
        isImporting: isImporting,
        onImport: onImport,
      );
    }

    Future<void> openNavigation() async {
      final opened = await const MapNavigationLauncher().openWalking(
        navigationPoint,
        navigationApp,
      );
      if (!opened && context.mounted) {
        ScaffoldMessenger.of(context).showStatusSnack(
          kind: AppStatusBannerKind.error,
          title: '无法打开${navigationApp.label}。',
        );
      }
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottomInset),
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showOverlapPager) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                child: MapOverlapPointPager(
                  currentIndex: overlapPointIndex!,
                  total: overlapPointCount!,
                  onPrevious: onPreviousOverlapPoint!,
                  onNext: onNextOverlapPoint!,
                ),
              ),
              Divider(
                key: ValueKey('anitabi-import-overlap-point-divider'),
                height: 1,
                indent: 14,
                endIndent: 14,
                color: AppColors.border,
              ),
            ],
            InkWell(
              key: ValueKey('anitabi-point-card-${point.id}'),
              onTap: openDetail,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Material(
                            color: AppColors.surfaceMuted,
                            child: InkWell(
                              onTap: fullImageUrl == null
                                  ? null
                                  : openFullImage,
                              child: SizedBox(
                                key: ValueKey(
                                  'anitabi-point-thumbnail-${point.id}',
                                ),
                                width: 80,
                                height: 80,
                                child: importedPoint == null
                                    ? ReferenceThumbnail(
                                        localPath: localThumbnailPath,
                                        imageUrl: imageUrl,
                                        placeholder: const Icon(
                                          LucideIcons.image,
                                        ),
                                      )
                                    : AutoCachingReferenceThumbnail(
                                        planId: planId,
                                        point: importedPoint!,
                                        repository: repository,
                                        onPlanUpdated: onPlanUpdated,
                                        placeholder: const Icon(
                                          LucideIcons.image,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            key: ValueKey('anitabi-point-text-${point.id}'),
                            height: 80,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CopyableText(
                                  text: point.name,
                                  copyLabel: '点位名称',
                                  onTap: openDetail,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                CopyableText(
                                  text:
                                      '${point.subtitle} / ${point.episodeLabel}',
                                  copyText: _copySummary,
                                  copyLabel: '点位信息',
                                  onTap: openDetail,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                    letterSpacing: 0,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                CopyableText(
                                  text: point.origin,
                                  copyLabel: '来源',
                                  onTap: openDetail,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                    letterSpacing: 0,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ResponsiveTwoButtonRow(
                      first: SizedBox(
                        height: 40,
                        child: OutlinedButton(
                          key: ValueKey('anitabi-point-navigation-${point.id}'),
                          onPressed: openNavigation,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                          ),
                          child: const ResponsiveButtonContent(
                            icon: LucideIcons.navigation,
                            iconSize: 17,
                            label: '导航',
                            semanticLabel: '打开导航',
                          ),
                        ),
                      ),
                      second: SizedBox(
                        height: 40,
                        child: FilledButton(
                          key: ValueKey('anitabi-point-import-${point.id}'),
                          onPressed: imported || isImporting ? null : onImport,
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                          ),
                          child: ResponsiveButtonContent(
                            icon: imported
                                ? LucideIcons.check
                                : LucideIcons.mapPinPlus,
                            label: imported ? '已加入计划' : '加入计划',
                            shortLabel: imported ? '已加入' : '加入',
                            semanticLabel: imported ? '已加入计划' : '加入计划',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _copySummary {
    return [
      point.name,
      point.subtitle,
      point.episodeLabel,
      point.note ?? '',
      point.origin,
      '${point.position.latitude.toStringAsFixed(5)},${point.position.longitude.toStringAsFixed(5)}',
    ].where((value) => value.trim().isNotEmpty).join('\n');
  }
}

class _AnitabiPointDetailSheet extends StatelessWidget {
  const _AnitabiPointDetailSheet({
    required this.point,
    required this.imageUrl,
    required this.fullImageUrl,
    required this.localThumbnailPath,
    required this.localFullPath,
    required this.imported,
    required this.isImporting,
    required this.onImport,
  });

  final AnitabiPoint point;
  final String? imageUrl;
  final String? fullImageUrl;
  final String? localThumbnailPath;
  final String? localFullPath;
  final bool imported;
  final bool isImporting;
  final VoidCallback onImport;

  static Future<void> show(
    BuildContext context, {
    required AnitabiPoint point,
    required String? imageUrl,
    required String? fullImageUrl,
    required String? localThumbnailPath,
    required String? localFullPath,
    required bool imported,
    required bool isImporting,
    required VoidCallback onImport,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (context) => _AnitabiPointDetailSheet(
        point: point,
        imageUrl: imageUrl,
        fullImageUrl: fullImageUrl,
        localThumbnailPath: localThumbnailPath,
        localFullPath: localFullPath,
        imported: imported,
        isImporting: isImporting,
        onImport: onImport,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.78;

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottomInset),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Material(
                      color: AppColors.surfaceMuted,
                      child: InkWell(
                        onTap: fullImageUrl == null
                            ? null
                            : () => ImageViewerScreen.show(
                                context,
                                filePath: localFullPath,
                                imageUrl: fullImageUrl,
                              ),
                        child: SizedBox(
                          width: 112,
                          height: 112,
                          child: ReferenceThumbnail(
                            localPath: localThumbnailPath,
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                            placeholder: const Icon(LucideIcons.image),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CopyableText(
                          text: point.name,
                          copyLabel: '点位名称',
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _AnitabiDetailInfoLine(
                          icon: LucideIcons.film,
                          label: '场景',
                          value: '${point.subtitle} / ${point.episodeLabel}',
                        ),
                        if (point.note?.trim().isNotEmpty == true) ...[
                          const SizedBox(height: 6),
                          _AnitabiDetailInfoLine(
                            icon: LucideIcons.stickyNote,
                            label: '备注',
                            value: point.note!,
                          ),
                        ],
                        const SizedBox(height: 6),
                        _AnitabiDetailInfoLine(
                          icon: LucideIcons.fileCode,
                          label: '来源',
                          value: point.origin,
                        ),
                        const SizedBox(height: 6),
                        _AnitabiDetailInfoLine(
                          icon: LucideIcons.mapPin,
                          label: '坐标',
                          value:
                              '${point.position.latitude.toStringAsFixed(5)}, ${point.position.longitude.toStringAsFixed(5)}',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: FilledButton(
                  onPressed: imported || isImporting
                      ? null
                      : () {
                          Navigator.of(context).pop();
                          onImport();
                        },
                  child: ResponsiveButtonContent(
                    icon: imported ? LucideIcons.check : LucideIcons.mapPinPlus,
                    label: imported ? '已加入计划' : '加入计划',
                    shortLabel: imported ? '已加入' : '加入',
                    semanticLabel: imported ? '已加入计划' : '加入计划',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnitabiDetailInfoLine extends StatelessWidget {
  const _AnitabiDetailInfoLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.textSecondary, size: 18),
        const SizedBox(width: 8),
        SizedBox(
          width: 38,
          child: Text(
            label,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: CopyableText(
            text: value,
            copyLabel: label,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              letterSpacing: 0,
            ),
          ),
        ),
      ],
    );
  }
}

class _NoPointSelectedCard extends StatelessWidget {
  const _NoPointSelectedCard({
    required this.hasPoints,
    required this.expectedCount,
  });

  final bool hasPoints;
  final int? expectedCount;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final message = hasPoints
        ? '点击地图上的点位查看缩略图和详情。'
        : expectedCount == null || expectedCount == 0
        ? '当前作品没有可导入的 Anitabi 点位。'
        : '当前作品共有 $expectedCount 个点位，但没有可导入的带图参考点位。';

    return Container(
      margin: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottomInset),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.pointer, color: AppColors.accent),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String? _anitabiThumbnailUrl(String? url) {
  final fullUrl = anitabiFullResolutionImageUrl(url);
  if (fullUrl == null || fullUrl.isEmpty) {
    return fullUrl;
  }

  final uri = Uri.tryParse(fullUrl);
  if (uri == null || !anitabiImageHosts.contains(uri.host)) {
    return fullUrl;
  }

  return uri
      .replace(queryParameters: {...uri.queryParameters, 'plan': 'h160'})
      .toString();
}

class _EmptyImportState extends StatelessWidget {
  const _EmptyImportState({required this.onOpenWorkManager});

  final VoidCallback onOpenWorkManager;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(LucideIcons.clapperboard, color: AppColors.accent),
                  const SizedBox(width: 8),
                  Text(
                    '还没有作品',
                    style: TextStyle(
                      color: AppColors.accentDark,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const _ImportWorkGuideTimeline(),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onOpenWorkManager,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(46),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  icon: const Icon(LucideIcons.clapperboard, size: 20),
                  label: const Text('作品管理'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ImportWorkGuideTimeline extends StatelessWidget {
  const _ImportWorkGuideTimeline();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        _ImportWorkGuideStep(
          title: '从Bangumi导入',
          body: '点击作品管理中的Bangumi按钮，搜索你想导入的作品并导入。之后你可以在这里直接查看对应作品在Anitabi上的点位。',
          isLast: true,
        ),
      ],
    );
  }
}

class _ImportWorkGuideStep extends StatelessWidget {
  const _ImportWorkGuideStep({
    required this.title,
    required this.body,
    this.isLast = false,
  });

  final String title;
  final String body;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 18,
            child: Stack(
              children: [
                if (!isLast)
                  Positioned(
                    left: 8,
                    top: 10,
                    bottom: 0,
                    child: Container(width: 2, color: AppColors.border),
                  ),
                Positioned(
                  left: 4,
                  top: 5,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    body,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      height: 1.35,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ManualWorkImportState extends StatelessWidget {
  const _ManualWorkImportState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          '手动添加的作品没有 Bangumi ID，无法从 Anitabi 地图导入点位。\n\n请通过 Bangumi/Anitabi 搜索添加作品，或使用手动添加点位。',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
            height: 1.45,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}

class _NoAnitabiPointsState extends StatelessWidget {
  const _NoAnitabiPointsState({required this.workTitle});

  final String workTitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          '「$workTitle」暂无可导入的 Anitabi 点位。',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
            height: 1.45,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}

class _ImportLoadingState extends StatelessWidget {
  const _ImportLoadingState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              '正在加载 Anitabi 作品和点位',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImportErrorState extends StatelessWidget {
  const _ImportErrorState({
    required this.message,
    required this.detail,
    required this.onRetry,
  });

  final String message;
  final String detail;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.map, color: AppColors.textSecondary, size: 32),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(LucideIcons.refreshCw),
              label: const Text('清除缓存并重新加载 Anitabi 点位'),
            ),
          ],
        ),
      ),
    );
  }
}
