import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:miriago/application/navigation/route_planner.dart';
import 'package:miriago/map/current_location_resolver.dart';
import 'package:miriago/map/map_navigation_launcher.dart';
import 'package:miriago/map/valhalla_route_client.dart';
import 'package:miriago/plan/pilgrimage_models.dart';

// Scenarios ported from the old navigation_route_confirm_screen_test.dart.

const _work = PilgrimageWork(
  id: 'work-1',
  title: '测试作品',
  subtitle: '',
  city: '京都',
  source: WorkSource.manual,
);
const _point = PilgrimagePoint(
  id: 'point-1',
  work: _work,
  name: '井用机前步行道',
  subtitle: 'あじろぎの道',
  position: LatLng(34.8899, 135.8081),
  episodeLabel: 'EP 1',
  referenceLabel: '手动',
);
const _middle = PilgrimagePoint(
  id: 'point-mid',
  work: _work,
  name: '宇治桥',
  subtitle: '宇治橋',
  position: LatLng(34.8929, 135.8065),
  episodeLabel: 'EP 2',
  referenceLabel: '手动',
);
const _last = PilgrimagePoint(
  id: 'point-2',
  work: _work,
  name: '京阪宇治站前',
  subtitle: '京阪宇治駅前',
  position: LatLng(34.8942, 135.8069),
  episodeLabel: 'EP 5',
  referenceLabel: '手动',
);
const _here = LatLng(34.887, 135.805);

class _Routes extends ValhallaRouteClient {
  final requests = <List<LatLng>>[];
  Object? failure;

  @override
  Future<NavigationRoute> route({
    required String baseUrl,
    required List<LatLng> locations,
  }) async {
    requests.add(List.of(locations));
    final error = failure;
    if (error != null) throw error;
    return NavigationRoute(
      shape: locations,
      maneuvers: const [],
      distanceKm: 0.5,
      duration: const Duration(minutes: 8),
    );
  }
}

RoutePlanner _planner({
  PilgrimagePoint point = _point,
  List<PilgrimagePoint> stops = const [],
  String? groupName,
  _Routes? routes,
  NavigationLocationResolver? location,
  MapNavigationLauncher launcher = const MapNavigationLauncher(),
}) {
  final planner = RoutePlanner(
    point: point,
    settings: const AppSettings(),
    groupName: groupName,
    stops: stops,
    routeClient: routes ?? _Routes(),
    locationResolver: location ?? () async => _here,
    externalNavigationLauncher: launcher,
  );
  addTearDown(planner.dispose);
  return planner;
}

void main() {
  test('a zone chain highlights connecting the whole group', () async {
    final routes = _Routes();
    final planner = _planner(
      groupName: '宇治站附近',
      stops: const [_point, _last],
      routes: routes,
    );
    expect(planner.status, RoutePlannerStatus.loading);
    await planner.start();
    expect(planner.status, RoutePlannerStatus.ready);
    expect(planner.canChainZone, isTrue);
    expect(planner.title, '串联整个片区');
    expect(planner.subtitle, '按顺序连接 2 个点位：井用机前步行道 → 京阪宇治站前');
    expect(routes.requests.single, [_here, _point.position, _last.position]);
    final args = await planner.startNavigation(chainZone: true);
    expect(args!.groupName, '宇治站附近');
    expect(args.stops.map((s) => s.id), ['point-1', 'point-2']);
    expect(args.initialLocation, _here);
    expect(routes.requests, hasLength(1));
  });

  test('the chain starts at the selected point', () async {
    final planner = _planner(
      point: _middle,
      groupName: '宇治站附近',
      stops: const [_point, _middle, _last],
    );
    await planner.start();
    expect(planner.subtitle, '按顺序连接 2 个点位：宇治桥 → 京阪宇治站前');
    expect(planner.remainingStops.map((s) => s.id), ['point-mid', 'point-2']);
  });

  test('only the selected point re-requests a point-only route', () async {
    final routes = _Routes();
    final planner = _planner(stops: const [_point, _last], routes: routes);
    await planner.start();
    final args = await planner.startNavigation(chainZone: false);
    expect(routes.requests, hasLength(2));
    expect(routes.requests.last, [_here, _point.position]);
    expect(args!.stops.single.id, _point.id);
    expect(args.groupName, isNull);
  });

  test('a single stop only offers starting navigation', () async {
    final planner = _planner(stops: const [_point]);
    await planner.start();
    expect(planner.canChainZone, isFalse);
    expect(planner.title, '导航到选中点');
    expect(planner.subtitle, '终点：井用机前步行道');
  });

  test('stops without coordinates are dropped', () {
    final noCoordinate = _last.copyWith(position: const LatLng(0, 0));
    final planner = _planner(stops: [_point, noCoordinate]);
    expect(planner.resolvedStops.length, noCoordinate.hasCoordinate ? 2 : 1);
  });

  test('route and location failures show the old messages', () async {
    final routes = _Routes()
      ..failure = const ValhallaRouteException('测试路径服务不可用');
    final planner = _planner(routes: routes);
    await planner.start();
    expect(planner.status, RoutePlannerStatus.error);
    expect(planner.errorMessage, '测试路径服务不可用');
    routes.failure = StateError('boom');
    await planner.retry();
    expect(planner.errorMessage, '路线加载失败，请检查定位和路径服务设置');
    expect(await planner.startNavigation(chainZone: false), isNull);

    final located = _planner(
      location: () async => throw const CurrentLocationException(
        CurrentLocationFailure.serviceDisabled,
      ),
    );
    await located.start();
    expect(located.errorMessage, '定位服务未开启。');
    routes.failure = null;
    await planner.retry();
    expect(planner.status, RoutePlannerStatus.ready);
  });

  test('leaving before the location resolves requests no route', () async {
    final location = Completer<LatLng>();
    final routes = _Routes();
    final planner = RoutePlanner(
      point: _point,
      settings: const AppSettings(),
      stops: const [_point],
      routeClient: routes,
      locationResolver: () => location.future,
    );
    final loading = planner.start();
    planner.dispose();
    location.complete(_here);
    await loading;
    expect(routes.requests, isEmpty);
  });

  test('the external fallback opens the configured app', () async {
    Uri? opened;
    final planner = _planner(
      launcher: MapNavigationLauncher(
        useAndroidGoogleMapsIntent: false,
        externalNavigationLauncher: (uri) async {
          opened = uri;
          return true;
        },
      ),
    );
    expect(await planner.openExternalNavigation(), isTrue);
    expect(opened, isNotNull);
  });
}
