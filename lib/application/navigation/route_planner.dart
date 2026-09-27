import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../../map/current_location_resolver.dart';
import '../../map/map_navigation_launcher.dart';
import '../../map/valhalla_route_client.dart';
import '../../plan/pilgrimage_models.dart';
import '../../plan/plan_group_utils.dart';

typedef NavigationLocationResolver = Future<LatLng> Function();

/// Arguments for `/navigate` (the in-app navigation page), produced by the
/// route preview.
@immutable
class NavigationArgs {
  const NavigationArgs({
    required this.point,
    required this.stops,
    required this.initialRoute,
    required this.initialLocation,
    this.groupName,
    this.routeClient,
  });

  /// The point the user chose (first target).
  final PilgrimagePoint point;

  /// Stops in visiting order.
  final List<PilgrimagePoint> stops;
  final String? groupName;
  final NavigationRoute initialRoute;
  final LatLng initialLocation;

  /// Shared with the preview so its short-lived route cache is reused.
  final ValhallaRouteClient? routeClient;
}

/// Stops with coordinates; the point itself when none of them has one.
List<PilgrimagePoint> coordinateNavigationStops({
  required PilgrimagePoint point,
  required List<PilgrimagePoint> stops,
}) {
  final resolved = [
    for (final stop in stops)
      if (stop.hasCoordinate) stop,
  ];
  if (resolved.isEmpty && point.hasCoordinate) {
    return [point];
  }
  return resolved;
}

/// 「A → B → C」.
String navigationStopChainLabel(List<PilgrimagePoint> stops) {
  return [for (final stop in stops) stop.name].join(' → ');
}

enum RoutePlannerStatus { loading, error, ready }

/// Route preview use case, ported from the old
/// `NavigationRouteConfirmScreen` state: builds the tour for a point,
/// resolves the current location, requests the walking route and decides
/// whether starting needs a point-only re-request.
class RoutePlanner extends ChangeNotifier {
  RoutePlanner({
    required this.point,
    required this.settings,
    this.groupName,
    List<PilgrimagePoint> stops = const [],
    ValhallaRouteClient? routeClient,
    this._locationResolver,
    this.externalNavigationLauncher = const MapNavigationLauncher(),
  }) : routeClient = routeClient ?? ValhallaRouteClient() {
    resolvedStops = coordinateNavigationStops(point: point, stops: stops);
    remainingStops = remainingNavigationStops(
      point: point,
      stops: resolvedStops,
    );
  }

  /// Builds a planner for [point] with its group tour (old `openForPoint`).
  factory RoutePlanner.forPoint({
    required PilgrimagePoint point,
    required AppSettings settings,
    List<PlanGroupBucket> buckets = const [],
    ValhallaRouteClient? routeClient,
    NavigationLocationResolver? locationResolver,
    MapNavigationLauncher externalNavigationLauncher =
        const MapNavigationLauncher(),
  }) {
    final tour = inAppNavigationTourFor(point: point, buckets: buckets);
    return RoutePlanner(
      point: point,
      settings: settings,
      groupName: tour.groupName,
      stops: tour.stops,
      routeClient: routeClient,
      locationResolver: locationResolver,
      externalNavigationLauncher: externalNavigationLauncher,
    );
  }

  final PilgrimagePoint point;
  AppSettings settings;
  final String? groupName;
  final ValhallaRouteClient routeClient;
  final MapNavigationLauncher externalNavigationLauncher;
  final NavigationLocationResolver? _locationResolver;

  late final List<PilgrimagePoint> resolvedStops;
  late final List<PilgrimagePoint> remainingStops;

  NavigationRoute? _route;
  LatLng? _start;
  Object? _error;
  var _loading = true;
  var _requestToken = 0;
  final _disposed = Completer<void>();

  NavigationRoute? get route => _route;
  LatLng? get startLocation => _start;
  Object? get error => _error;
  bool get isLoading => _loading;
  bool get isDisposed => _disposed.isCompleted;

  RoutePlannerStatus get status => _loading
      ? RoutePlannerStatus.loading
      : _error != null
      ? RoutePlannerStatus.error
      : RoutePlannerStatus.ready;

  /// 「串联整个片区」 when at least two stops remain.
  bool get canChainZone => remainingStops.length >= 2;

  String get title => canChainZone ? '串联整个片区' : '导航到选中点';

  String get subtitle => canChainZone
      ? '按顺序连接 ${remainingStops.length} 个点位：${navigationStopChainLabel(remainingStops)}'
      : '终点：${point.name}';

  /// Route shape, or the straight chain while the route is loading.
  List<LatLng> get routePoints =>
      _route?.shape ??
      [
        _start,
        for (final stop in remainingStops) stop.position,
      ].whereType<LatLng>().toList(growable: false);

  String get errorMessage {
    final error = _error;
    if (error is CurrentLocationException) {
      return currentLocationFailureMessage(error);
    }
    if (error is ValhallaRouteException) return error.message;
    return '路线加载失败，请检查定位和路径服务设置';
  }

  void _notify() {
    if (!_disposed.isCompleted) notifyListeners();
  }

  /// Initial load (old `initState`).
  Future<void> start() => loadRoute(remainingStops);

  /// 重试.
  Future<void> retry() => loadRoute(remainingStops);

  Future<void> loadRoute(List<PilgrimagePoint> stops) async {
    final requestToken = ++_requestToken;
    _loading = true;
    _error = null;
    _notify();
    try {
      final start = _start ?? await _resolveLocation();
      if (isDisposed || requestToken != _requestToken) return;
      final route = await routeClient.route(
        baseUrl: settings.valhallaBaseUrl,
        locations: [start, for (final stop in stops) stop.position],
      );
      if (isDisposed || requestToken != _requestToken) return;
      _start = start;
      _route = route;
      _loading = false;
      _notify();
    } on CurrentLocationCancelled {
      return;
    } on Object catch (error) {
      if (isDisposed || requestToken != _requestToken) return;
      _loading = false;
      _error = error;
      _notify();
    }
  }

  Future<LatLng> _resolveLocation() async {
    final custom = _locationResolver;
    if (custom != null) return custom();
    final position = await resolveCurrentLocation(cancelled: _disposed.future);
    return LatLng(position.latitude, position.longitude);
  }

  /// Old `_startNavigation`: returns the navigation arguments, or null when
  /// the (re)requested route failed or the page was left. "仅导航到选中点"
  /// with several remaining stops re-requests a point-only route.
  Future<NavigationArgs?> startNavigation({required bool chainZone}) async {
    final selectedStops = chainZone ? resolvedStops : [point];
    final activeStops = remainingNavigationStops(
      point: point,
      stops: selectedStops,
    );
    if (_route == null || (!chainZone && remainingStops.length > 1)) {
      await loadRoute(activeStops);
      if (isDisposed || _route == null || _error != null) return null;
    }
    return NavigationArgs(
      point: point,
      groupName: chainZone ? groupName : null,
      stops: activeStops,
      initialRoute: _route!,
      initialLocation: _start!,
      routeClient: routeClient,
    );
  }

  /// 用{外部地图}导航. False → 「无法打开外部地图」.
  Future<bool> openExternalNavigation() {
    return externalNavigationLauncher.openWalking(
      point,
      settings.navigationApp,
    );
  }

  @override
  void dispose() {
    // Stops a pending location lookup so it cannot prompt or keep GPS running
    // after the user left, and prevents the route request that would follow.
    if (!_disposed.isCompleted) _disposed.complete();
    super.dispose();
  }
}
