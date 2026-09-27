import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../../data/anitabi_client.dart';
import '../../data/anitabi_image_url.dart';
import '../../data/pilgrimage_repository.dart';
import '../../data/reference_image_cache_stub.dart'
    if (dart.library.io) '../../data/reference_image_cache_io.dart'
    as reference_image_cache;
import '../../map/map_marker_clustering.dart';
import '../../plan/pilgrimage_models.dart';
import '../../utils/limited_concurrency.dart';
import '../plan_session.dart';
import 'add_dependencies.dart';

/// Zoom used when a work's lite centre is missing (old: 15).
const double kAnitabiFallbackLoadedPointsZoom = 15;

/// Minimum zoom when a single point is pre-selected (old: 15).
const double kAnitabiSelectedPointMinZoom = 15;

Future<String?> _defaultThumbnailCacher(
  PilgrimagePoint point,
  AnitabiImageSource source,
) => reference_image_cache.ensureReferenceThumbnailCached(
  point,
  imageSource: source,
);

enum AnitabiImportStage { importing, caching }

/// Progress of an import (old `_ImportProgress`).
@immutable
class AnitabiImportProgress {
  const AnitabiImportProgress.importing({required this.total})
    : stage = AnitabiImportStage.importing,
      processed = 0,
      succeeded = 0;

  const AnitabiImportProgress.caching({
    required this.total,
    this.processed = 0,
    this.succeeded = 0,
  }) : stage = AnitabiImportStage.caching;

  final AnitabiImportStage stage;
  final int total;
  final int processed;
  final int succeeded;

  String get label => switch (stage) {
    AnitabiImportStage.importing => '正在导入 $total 个点位...',
    AnitabiImportStage.caching => '正在缓存缩略图 $processed/$total，成功 $succeeded',
  };
}

/// A camera move requested by the controller (new data loaded).
@immutable
class AnitabiCameraTarget {
  const AnitabiCameraTarget(this.center, this.zoom, this.serial);

  final LatLng center;
  final double zoom;

  /// Increments per request so equal targets still move the map.
  final int serial;
}

/// Result of an import that wrote points.
@immutable
class AnitabiImportOutcome {
  const AnitabiImportOutcome({
    required this.points,
    required this.showOrganizeGuide,
  });

  /// The points that were written (old `pilgrimagePoints`).
  final List<PilgrimagePoint> points;

  /// Old: offer 「整理刚导入的点位」 after importing more than one point.
  final bool showOrganizeGuide;
}

/// Bulk-import confirmation texts (old `_confirmBulkImport` calls).
abstract final class AnitabiImportTexts {
  static const importAllTitle = '添加所有点位';
  static String importAllMessage(int count) =>
      '将把当前作品中 $count 个还不在计划里的点位加入计划，并暂时放在未分组。';
  static const importAllConfirm = '添加全部';
  static const importBoxTitle = '添加框选点位';
  static String importBoxMessage(int count) =>
      '将把框选范围内 $count 个还不在计划里的点位加入计划，并暂时放在未分组。';
  static const importBoxConfirm = '添加框选';
  static const boxEmpty = '框选范围内没有可添加点位';
  static const manualWork = '手动添加的作品没有 Bangumi ID，无法从 Anitabi 地图导入点位。';
  static const organizeFailed = '点位已导入，但整理流程打开失败，可以稍后在计划中调整片区。';
  static const ungroupedName = '未分入片区';
}

/// Title of an Anitabi load error (old `_errorMessageFor`).
String anitabiErrorMessageFor(Object? error) {
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

/// Detail of an Anitabi load error (old `_errorDetailFor`).
String anitabiErrorDetailFor(Object? error, {bool isWeb = kIsWeb}) {
  if (error is AnitabiStaticDataUnavailableException) {
    if (isWeb) {
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

/// Small Anitabi thumbnail URL (old `_anitabiThumbnailUrl`, `plan=h160`).
String? anitabiPreviewThumbnailUrl(String? url) {
  final fullUrl = anitabiFullResolutionImageUrl(url);
  if (fullUrl == null || fullUrl.isEmpty) return fullUrl;
  final uri = Uri.tryParse(fullUrl);
  if (uri == null || !anitabiImageHosts.contains(uri.host)) return fullUrl;
  return uri
      .replace(queryParameters: {...uri.queryParameters, 'plan': 'h160'})
      .toString();
}

/// Text copied by the point card's 「点位信息」 (old `_copySummary`).
String anitabiPointCopySummary(AnitabiPoint point) => [
  point.name,
  point.subtitle,
  point.episodeLabel,
  point.note ?? '',
  point.origin,
  '${point.position.latitude.toStringAsFixed(5)},${point.position.longitude.toStringAsFixed(5)}',
].where((value) => value.trim().isNotEmpty).join('\n');

/// Whether [center] is a usable map centre (old `_isValidMapCenter`).
bool isValidAnitabiMapCenter(LatLng center) {
  final latitude = center.latitude;
  final longitude = center.longitude;
  if (!latitude.isFinite || !longitude.isFinite) return false;
  if (latitude.abs() < 0.0001 && longitude.abs() < 0.0001) return false;
  return latitude >= -90 &&
      latitude <= 90 &&
      longitude >= -180 &&
      longitude <= 180;
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

double _roughDistanceSquared(LatLng first, LatLng second) {
  final lat = first.latitude - second.latitude;
  final lng = first.longitude - second.longitude;
  return lat * lat + lng * lng;
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

/// Camera centre after loading [points] (old `_centerForLoadedPoints`).
LatLng anitabiCenterForLoadedPoints(
  List<AnitabiPoint> points,
  AnitabiBangumiLite? lite,
) {
  final center = lite?.center;
  if (center != null && isValidAnitabiMapCenter(center)) return center;
  if (points.isEmpty) return const LatLng(35.0, 135.0);
  return _nearestPointTo(_pointBoundsCenter(points), points).position;
}

/// Camera zoom after loading [points] (old `_zoomForLoadedPoints`).
double anitabiZoomForLoadedPoints(
  List<AnitabiPoint> points,
  AnitabiBangumiLite? lite,
) {
  final center = lite?.center;
  if (points.isNotEmpty &&
      (center == null || !isValidAnitabiMapCenter(center))) {
    return kAnitabiFallbackLoadedPointsZoom;
  }
  return lite?.zoom ?? 12;
}

/// Point selected after loading (old `_initialSelectedPointForLoadedPoints`).
AnitabiPoint? anitabiInitialSelectedPoint(
  List<AnitabiPoint> points,
  AnitabiBangumiLite? lite,
) {
  if (points.isEmpty) return null;
  final center = lite?.center;
  if (center != null && isValidAnitabiMapCenter(center)) return points.first;
  return _nearestPointTo(_pointBoundsCenter(points), points);
}

/// State and use cases of the Anitabi work-map import (old
/// `_AnitabiMapImportScreenState`, minus the widgets).
///
/// The plan is never copied: imported ids and works are read from the
/// [PlanSession] and every write goes through `session.mutate`, so other
/// panes update while importing.
class AnitabiImportController extends ChangeNotifier {
  AnitabiImportController({
    required this.session,
    required this.client,
    required this.readSettings,
    this.initialBangumiId,
    this.initialPointId,
    AnitabiThumbnailCacher? cacheThumbnail,
    this.onNotice,
  }) : _cacheThumbnail =
           cacheThumbnail ??
           AddDependencies.thumbnailCacher ??
           _defaultThumbnailCacher {
    session.addListener(_onSessionChanged);
  }

  final PlanSession session;
  final AnitabiClient client;
  final AppSettings Function() readSettings;
  final int? initialBangumiId;
  final String? initialPointId;
  final AnitabiThumbnailCacher _cacheThumbnail;

  /// Receives the old toasts (running / success / warning / error).
  void Function(AddNotice notice)? onNotice;

  PilgrimageWork? _selectedWork;
  AnitabiBangumiLite? _lite;
  List<AnitabiPoint> _points = const [];
  AnitabiPoint? _selectedPoint;
  List<String> _overlapIds = const [];
  Object? _error;
  bool _isLoading = false;
  bool _isImporting = false;
  AnitabiImportProgress? _progress;
  AnitabiCameraTarget? _camera;
  int _cameraSerial = 0;
  int _loadGeneration = 0;
  bool _disposed = false;
  int _idsRevision = -1;
  Set<String> _importedIds = const {};

  AnitabiBangumiLite? get lite => _lite;
  Object? get error => _error;
  bool get isLoading => _isLoading;
  bool get isImporting => _isImporting;
  AnitabiImportProgress? get progress => _progress;
  AnitabiCameraTarget? get cameraTarget => _camera;
  bool get isDisposed => _disposed;

  /// Ids of the overlap group being browsed (old `_ImportOverlapPointBrowser`).
  List<String> get overlapIds => _overlapIds;

  PilgrimagePlan get plan => session.plan;

  /// Selected work, resolved against the current plan (old
  /// `_matchingWorkInPlan`): by id, then by Bangumi id.
  PilgrimageWork? get selectedWork {
    final selected = _selectedWork;
    if (selected == null) return null;
    final works = plan.works;
    for (final work in works) {
      if (work.id == selected.id) return work;
    }
    final bangumiId = selected.bangumiId;
    if (bangumiId != null) {
      for (final work in works) {
        if (work.bangumiId == bangumiId) return work;
      }
    }
    return selected;
  }

  /// Plan works plus the selected work when it is not in the plan yet.
  List<PilgrimageWork> get works {
    final selected = selectedWork;
    final planWorks = plan.works;
    if (selected == null || planWorks.any((work) => work.id == selected.id)) {
      return planWorks;
    }
    return [...planWorks, selected];
  }

  Set<String> get importedPointIds {
    if (_idsRevision != session.revision) {
      _idsRevision = session.revision;
      _importedIds = plan.points.map((point) => point.id).toSet();
    }
    return _importedIds;
  }

  /// Plan id the Anitabi point is stored under.
  String pilgrimageIdFor(AnitabiPoint point) =>
      'anitabi-${point.bangumiId}-${point.id}';

  bool isImported(AnitabiPoint point) =>
      importedPointIds.contains(pilgrimageIdFor(point));

  /// The plan point created from [point], if imported (old `_importedPointFor`).
  PilgrimagePoint? importedPointFor(AnitabiPoint point) {
    final id = pilgrimageIdFor(point);
    for (final candidate in plan.points) {
      if (candidate.id == id) return candidate;
    }
    return null;
  }

  /// Points of the selected work (old `_pointsForWork`).
  List<AnitabiPoint> get visiblePoints {
    final bangumiId = selectedWork?.bangumiId;
    if (bangumiId == null) return const [];
    return _points
        .where((point) => point.bangumiId == bangumiId)
        .toList(growable: false);
  }

  /// Points of the selected work that are not in the plan yet.
  List<AnitabiPoint> get availablePoints {
    if (selectedWork == null) return const [];
    return visiblePoints
        .where((point) => !isImported(point))
        .toList(growable: false);
  }

  int get importedCount => visiblePoints.where(isImported).length;

  /// Selected point when it belongs to the selected work.
  AnitabiPoint? get selectedPoint {
    final point = _selectedPoint;
    final bangumiId = selectedWork?.bangumiId;
    if (point == null || bangumiId == null || point.bangumiId != bangumiId) {
      return null;
    }
    return point;
  }

  /// Overlap browser points that still exist, in browse order.
  List<AnitabiPoint> get overlapPoints {
    if (_overlapIds.isEmpty) return const [];
    final byId = {for (final point in visiblePoints) point.id: point};
    return [for (final id in _overlapIds) ?byId[id]];
  }

  /// Index of the selected point in [overlapPoints], or -1 when the pager
  /// should not show.
  int get overlapIndex {
    final points = overlapPoints;
    if (points.length < 2) return -1;
    return points.indexWhere((point) => point.id == selectedPoint?.id);
  }

  /// Initial camera (old `_initialMapCenter` / `_initialMapZoom`).
  LatLng get initialCenter {
    final pending = _camera;
    if (pending != null) return pending.center;
    final selected = selectedPoint;
    if (selected != null) return selected.position;
    return anitabiCenterForLoadedPoints(visiblePoints, _lite);
  }

  double get initialZoom {
    final pending = _camera;
    if (pending != null) return pending.zoom;
    final liteZoom = _lite?.zoom;
    if (selectedPoint != null) {
      return math.max(liteZoom ?? 15, kAnitabiSelectedPointMinZoom);
    }
    return liteZoom ?? 12;
  }

  // -------------------------------------------------------------------------
  // Loading
  // -------------------------------------------------------------------------

  /// Initial load (old `initState`): point link → global lookup, Bangumi id
  /// → static lite, otherwise the first Bangumi work of the plan.
  Future<void> start() async {
    final bangumiId = initialBangumiId;
    final pointId = initialPointId;
    if (bangumiId != null && pointId != null) {
      return _loadInitialPointLink(bangumiId, pointId);
    }
    if (bangumiId != null) return _loadInitialBangumiId(bangumiId);
    final works = this.works;
    if (works.isEmpty) return;
    final bangumiWork = works.where((w) => w.bangumiId != null).firstOrNull;
    final initialWork = bangumiWork ?? works.first;
    _selectedWork = initialWork;
    _notify();
    if (initialWork.bangumiId != null) await loadPoints(initialWork);
  }

  /// Clears the static cache and reloads (old `_refreshAnitabiData`).
  Future<void> refresh() async {
    client.clearStaticCache();
    _emit(const AddNotice(AddNoticeKind.running, '正在清除缓存并重新加载 Anitabi 点位...'));
    final bangumiId = initialBangumiId;
    final pointId = initialPointId;
    if (bangumiId != null && pointId != null) {
      return _loadInitialPointLink(bangumiId, pointId);
    }
    if (bangumiId != null && _selectedWork == null) {
      return _loadInitialBangumiId(bangumiId);
    }
    final works = this.works;
    final work =
        selectedWork ??
        works.where((work) => work.bangumiId != null).firstOrNull ??
        works.firstOrNull;
    if (work?.bangumiId != null) return loadPoints(work!);
    _error = null;
    _notify();
  }

  /// Loads the points of [work] (old `_loadPoints`). Manual works show the
  /// 「没有 Bangumi ID」 notice instead.
  Future<void> loadPoints(PilgrimageWork work) async {
    if (_isImporting) return;
    final generation = ++_loadGeneration;
    final bangumiId = work.bangumiId;
    if (bangumiId == null) {
      _selectedWork = work;
      _isLoading = false;
      _error = null;
      _lite = null;
      _points = const [];
      _overlapIds = const [];
      _selectedPoint = null;
      _notify();
      _emit(
        const AddNotice(AddNoticeKind.warning, AnitabiImportTexts.manualWork),
      );
      return;
    }

    _selectedWork = work;
    _isLoading = true;
    _error = null;
    _points = const [];
    _overlapIds = const [];
    _selectedPoint = null;
    _notify();

    try {
      final lite = await _fetchBangumiLite(work);
      if (!_isActive(generation)) return;
      final points = await client.fetchPoints(bangumiId, lite: lite);
      if (!_isActive(generation)) return;
      _lite = lite;
      _points = points;
      _overlapIds = const [];
      _selectedPoint = anitabiInitialSelectedPoint(points, lite);
      _requestCamera(
        anitabiCenterForLoadedPoints(points, lite),
        anitabiZoomForLoadedPoints(points, lite),
      );
    } catch (error) {
      if (!_isActive(generation)) return;
      _error = error;
    } finally {
      if (_isActive(generation)) {
        _isLoading = false;
        _notify();
      }
    }
  }

  Future<void> _loadInitialBangumiId(int bangumiId) async {
    final generation = ++_loadGeneration;
    _isLoading = true;
    _error = null;
    _points = const [];
    _overlapIds = const [];
    _selectedPoint = null;
    _notify();

    try {
      final lite = await _fetchBangumiLiteForBangumiId(bangumiId);
      if (!_isActive(generation)) return;
      final work = _workForBangumiId(lite.bangumiId) ?? _workFromLite(lite);
      final points = await client.fetchPoints(lite.bangumiId, lite: lite);
      if (!_isActive(generation)) return;
      _selectedWork = work;
      _lite = lite;
      _points = points;
      _overlapIds = const [];
      _selectedPoint = anitabiInitialSelectedPoint(points, lite);
      _requestCamera(
        anitabiCenterForLoadedPoints(points, lite),
        anitabiZoomForLoadedPoints(points, lite),
      );
    } catch (error) {
      if (!_isActive(generation)) return;
      _error = error;
    } finally {
      if (_isActive(generation)) {
        _isLoading = false;
        _notify();
      }
    }
  }

  Future<void> _loadInitialPointLink(int bangumiId, String pointId) async {
    final generation = ++_loadGeneration;
    _isLoading = true;
    _error = null;
    _points = const [];
    _overlapIds = const [];
    _selectedPoint = null;
    _notify();

    try {
      final result =
          await client.findPointGlobally(pointId: pointId) ??
          await client.findPointInBangumi(
            bangumiId: bangumiId,
            pointId: pointId,
          );
      if (!_isActive(generation)) return;
      if (result == null) throw const AnitabiPointNotFoundException();
      final lite = result.work;
      final work = _workForBangumiId(lite.bangumiId) ?? _workFromLite(lite);
      _selectedWork = work;
      _lite = lite;
      _points = result.points;
      _overlapIds = const [];
      _selectedPoint = result.point;
      _requestCamera(
        result.point.position,
        math.max(lite.zoom, kAnitabiSelectedPointMinZoom),
      );
    } catch (error) {
      if (!_isActive(generation)) return;
      _error = error;
    } finally {
      if (_isActive(generation)) {
        _isLoading = false;
        _notify();
      }
    }
  }

  Future<AnitabiBangumiLite> _fetchBangumiLite(PilgrimageWork work) async {
    final bangumiId = work.bangumiId;
    if (bangumiId == null) {
      throw const AnitabiStaticDataUnavailableException('Missing Bangumi ID');
    }
    final staticLite = await _fetchStaticBangumiLiteIfSupported(bangumiId);
    if (staticLite != null) return staticLite;
    try {
      return await client.fetchBangumiLite(bangumiId);
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
    if (staticLite != null) return staticLite;
    return client.fetchBangumiLite(bangumiId);
  }

  Future<AnitabiBangumiLite?> _fetchStaticBangumiLiteIfSupported(
    int bangumiId,
  ) {
    // Old behaviour: only the real client reads the static lite index;
    // test doubles answer through fetchBangumiLite.
    if (client.runtimeType != AnitabiClient) return Future.value();
    return client.fetchBangumiLiteFromStatic(bangumiId);
  }

  PilgrimageWork? _workForBangumiId(int bangumiId) {
    for (final work in plan.works) {
      if (work.bangumiId == bangumiId) return work;
    }
    return null;
  }

  PilgrimageWork _workFromLite(AnitabiBangumiLite lite) => PilgrimageWork(
    id: 'bangumi-${lite.bangumiId}',
    bangumiId: lite.bangumiId,
    title: lite.title,
    subtitle: lite.subtitle,
    city: lite.city,
    source: WorkSource.bangumi,
  );

  void _requestCamera(LatLng center, double zoom) {
    _camera = AnitabiCameraTarget(center, zoom, ++_cameraSerial);
  }

  /// Called once the page moved the map to [target].
  void cameraApplied(AnitabiCameraTarget target) {
    if (identical(_camera, target)) _camera = null;
  }

  // -------------------------------------------------------------------------
  // Selection
  // -------------------------------------------------------------------------

  void selectPoint(
    AnitabiPoint point, {
    bool preserveOverlap = false,
    List<String>? overlapIds,
  }) {
    if (_isImporting) return;
    final bangumiId = selectedWork?.bangumiId;
    if (bangumiId == null || point.bangumiId != bangumiId) return;
    if (overlapIds != null) {
      _overlapIds = List.unmodifiable(overlapIds);
    } else if (!preserveOverlap) {
      _overlapIds = const [];
    }
    _selectedPoint = point;
    _notify();
  }

  void clearSelection() {
    if (_selectedPoint == null && _overlapIds.isEmpty) return;
    _selectedPoint = null;
    _overlapIds = const [];
    _notify();
  }

  /// Opens the overlap browser for [points] (already in plan order).
  void openOverlap(List<AnitabiPoint> points) {
    if (_isImporting || points.isEmpty) return;
    if (points.length == 1) {
      selectPoint(points.single);
      return;
    }
    selectPoint(points.first, overlapIds: [for (final p in points) p.id]);
  }

  void closeOverlap() {
    if (_overlapIds.isEmpty) return;
    _overlapIds = const [];
    _notify();
  }

  /// Moves through the overlap group (old `_moveOverlapPoint`).
  void moveOverlap(int offset) {
    if (_overlapIds.length < 2) return;
    final points = overlapPoints;
    if (points.length < 2) {
      _overlapIds = const [];
      _notify();
      return;
    }
    final index = points.indexWhere((p) => p.id == selectedPoint?.id);
    final next = nextMapOverlapIndex(
      currentIndex: index < 0 ? 0 : index,
      offset: offset,
      total: points.length,
    );
    selectPoint(points[next], preserveOverlap: true);
  }

  /// Available points inside [contains] (box selection).
  List<AnitabiPoint> availablePointsWhere(bool Function(LatLng) contains) =>
      availablePoints
          .where((point) => contains(point.position))
          .toList(growable: false);

  // -------------------------------------------------------------------------
  // Importing
  // -------------------------------------------------------------------------

  /// Imports the selected point (old `_importSelectedPoint`).
  Future<AnitabiImportOutcome?> importSelectedPoint() async {
    final work = selectedWork;
    final point = _selectedPoint;
    if (work == null ||
        point == null ||
        point.bangumiId != work.bangumiId ||
        _isImporting) {
      return null;
    }
    if (isImported(point)) return null;
    return importPoints(
      [point],
      successMessage: '已加入计划，可继续选择点位。',
      failureMessage: '点位导入失败，请稍后重试。',
    );
  }

  /// Imports every available point (confirmation is the caller's job).
  Future<AnitabiImportOutcome?> importAll() => importPoints(
    availablePoints,
    successMessage: '已添加所有未加入的点位。',
    failureMessage: '批量导入失败，请稍后重试。',
  );

  /// Imports a box selection (confirmation is the caller's job).
  Future<AnitabiImportOutcome?> importBox(List<AnitabiPoint> points) =>
      importPoints(
        points,
        successMessage: '已添加框选点位。',
        failureMessage: '框选点位导入失败，请稍后重试。',
      );

  /// The import pipeline (old `_importPoints`): write the points, cache
  /// thumbnails with limited concurrency while reporting progress, write
  /// the cache paths back, then report the result.
  Future<AnitabiImportOutcome?> importPoints(
    List<AnitabiPoint> points, {
    required String successMessage,
    required String failureMessage,
  }) async {
    final work = selectedWork;
    if (work == null || points.isEmpty || _isImporting) return null;

    final imported = importedPointIds;
    final pilgrimagePoints = points
        .where((point) => point.bangumiId == work.bangumiId)
        .map((point) => point.toPilgrimagePoint(work))
        .where((point) => !imported.contains(point.id))
        .toList(growable: false);
    if (pilgrimagePoints.isEmpty) return null;

    final total = pilgrimagePoints.length;
    _isImporting = true;
    _progress = AnitabiImportProgress.importing(total: total);
    _notify();

    try {
      _emit(AddNotice(AddNoticeKind.running, '正在导入 $total 个点位...'));
      var importedPlan = await session.mutate(
        (repository, planId) => total == 1
            ? repository.addPointToPlan(
                planId: planId,
                point: pilgrimagePoints.single,
              )
            : repository.addPointsToPlan(
                planId: planId,
                points: pilgrimagePoints,
              ),
      );
      if (_disposed) return null;

      _progress = AnitabiImportProgress.caching(total: total);
      _notify();

      final settings = readSettings();
      var cached = 0;
      var cacheFailed = 0;
      var processed = 0;
      var lastProgressNoticeAt = DateTime.fromMillisecondsSinceEpoch(0);
      final updates = <String, PointImageCacheUpdate>{};
      await runLimitedConcurrent<PilgrimagePoint, ({String id, String? path})>(
        items: pilgrimagePoints,
        maxConcurrent: settings.mapThumbnailConcurrentLoads,
        task: (point, _) async {
          try {
            final path = await _cacheThumbnail(
              point,
              settings.anitabiImageSource,
            );
            return (
              id: point.id,
              path: path == null || path.isEmpty ? null : path,
            );
          } catch (_) {
            return (id: point.id, path: null);
          }
        },
        onResult: (result) {
          processed += 1;
          final path = result.path;
          if (path == null) {
            cacheFailed += 1;
          } else {
            cached += 1;
            updates[result.id] = PointImageCacheUpdate(
              referenceThumbnailPath: path,
              referenceFullImagePath: importedPlan.points
                  .where((point) => point.id == result.id)
                  .firstOrNull
                  ?.referenceFullImagePath,
            );
          }
          if (_disposed) return;
          _progress = AnitabiImportProgress.caching(
            total: total,
            processed: processed,
            succeeded: cached,
          );
          _notify();
          final now = DateTime.now();
          if (processed == total ||
              now.difference(lastProgressNoticeAt) >=
                  const Duration(milliseconds: 450)) {
            lastProgressNoticeAt = now;
            _emit(
              AddNotice(
                AddNoticeKind.running,
                '正在缓存缩略图 $processed/$total，成功 $cached',
                duration: const Duration(milliseconds: 1200),
              ),
            );
          }
        },
      );
      if (_disposed) return null;

      if (updates.isNotEmpty) {
        importedPlan = await session.mutate(
          (repository, planId) => repository.updatePointImageCaches(
            planId: planId,
            updatesByPointId: updates,
          ),
        );
      }
      if (_disposed) return null;

      _emit(
        cacheFailed == 0
            ? AddNotice(AddNoticeKind.success, successMessage)
            : AddNotice(
                AddNoticeKind.warning,
                '已导入 $total 个点位，缩略图缓存 $cached/$total，其余稍后会自动补齐。',
              ),
      );
      return AnitabiImportOutcome(
        points: pilgrimagePoints,
        showOrganizeGuide: total > 1,
      );
    } catch (error, stackTrace) {
      debugPrint('Failed to import Anitabi points: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (_disposed) return null;
      _emit(AddNotice(AddNoticeKind.error, failureMessage));
      return null;
    } finally {
      if (!_disposed) {
        _isImporting = false;
        _progress = null;
        _notify();
      }
    }
  }

  /// Moves freshly imported points into a group (old
  /// `_assignImportedPointsToGroup`); [groupId] null = 未分入片区.
  Future<AddNotice> assignToGroup(Set<String> pointIds, String? groupId) async {
    try {
      final updated = await session.mutate(
        (repository, planId) => repository.movePointsToGroup(
          planId: planId,
          pointIds: pointIds,
          groupId: groupId,
        ),
      );
      final groupName = groupId == null
          ? AnitabiImportTexts.ungroupedName
          : updated.groups
                    .where((group) => group.id == groupId)
                    .map((group) => group.name)
                    .firstOrNull ??
                '所选片区';
      return AddNotice(
        AddNoticeKind.success,
        '已将 ${pointIds.length} 个点位分配到「$groupName」',
      );
    } catch (_) {
      return const AddNotice(AddNoticeKind.error, '点位分配失败，请稍后重试。');
    }
  }

  // -------------------------------------------------------------------------

  bool _isActive(int generation) => !_disposed && generation == _loadGeneration;

  void _onSessionChanged() => _notify();

  void _emit(AddNotice notice) {
    if (_disposed) return;
    onNotice?.call(notice);
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    session.removeListener(_onSessionChanged);
    super.dispose();
  }
}
