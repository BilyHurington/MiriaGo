import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:miriago/application/navigation/navigation_session.dart';
import 'package:miriago/application/navigation/route_planner.dart';
import 'package:miriago/map/valhalla_route_client.dart';
import 'package:miriago/plan/pilgrimage_models.dart';
import 'package:miriago/ui/features/navigation/navigation_page.dart';
import 'package:miriago/ui/features/navigation/navigation_services.dart';

import '../../helpers/pump_app.dart' show TestSizes;
import '../camera/camera_test_harness.dart';

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
  name: '宇治桥',
  subtitle: '表参道',
  position: LatLng(34.8894, 135.8074),
  episodeLabel: 'EP 1',
  referenceLabel: '手动',
);
const _lastPoint = PilgrimagePoint(
  id: 'point-2',
  work: _work,
  name: '京阪宇治站前',
  subtitle: '京阪宇治駅前',
  position: LatLng(34.8942, 135.8069),
  episodeLabel: 'EP 5',
  referenceLabel: '手动',
);

LatLng _start(PilgrimagePoint p) =>
    LatLng(p.position.latitude - 0.003, p.position.longitude - 0.002);

NavigationRoute _route(List<PilgrimagePoint> stops) {
  final shape = [
    _start(stops.first),
    LatLng(
      stops.first.position.latitude - 0.003,
      stops.first.position.longitude,
    ),
    for (final p in stops) p.position,
  ];
  return NavigationRoute(
    shape: shape,
    maneuvers: [
      const NavigationManeuver(
        type: 1,
        instruction: '开始步行',
        distanceKm: 0.475,
        beginShapeIndex: 0,
        endShapeIndex: 1,
      ),
      const NavigationManeuver(
        type: 10,
        instruction: '右转进入表参道',
        distanceKm: 0.210,
        beginShapeIndex: 1,
        endShapeIndex: 2,
      ),
      NavigationManeuver(
        type: 4,
        instruction: '到达终点',
        distanceKm: 0,
        beginShapeIndex: shape.length - 1,
        endShapeIndex: shape.length - 1,
      ),
    ],
    distanceKm: 0.685,
    duration: const Duration(minutes: 12),
  );
}

class _Routes extends ValhallaRouteClient {
  final requests = <List<LatLng>>[];

  @override
  Future<NavigationRoute> route({
    required String baseUrl,
    required List<LatLng> locations,
  }) async {
    requests.add(List.of(locations));
    return NavigationRoute(
      shape: locations,
      maneuvers: const [],
      distanceKm: 1,
      duration: const Duration(minutes: 10),
    );
  }
}

void main() {
  late StreamController<NavigationLocationSample> locations;
  late _Routes routes;
  late FeatureTestStores stores;

  Future<void> pumpNavigation(
    WidgetTester tester, {
    Size size = TestSizes.phone,
    double textScale = 1,
    List<PilgrimagePoint> stops = const [_point, _lastPoint],
    String? groupName = '宇治站附近',
    bool? precise = true,
  }) async {
    setTestWindow(tester, size, textScale: textScale);
    stores = await FeatureTestStores.load();
    locations = StreamController<NavigationLocationSample>.broadcast(
      sync: true,
    );
    addTearDown(locations.close);
    routes = _Routes();
    await tester.pumpWidget(
      NavigationServices(
        routeClient: routes,
        locationStreamFactory: () => locations.stream,
        headingStreamFactory: (_) => const Stream.empty(),
        preciseLocationCheck: ({required mayRequest}) async => precise,
        disableMapTiles: true,
        child: featureTestApp(
          stores: stores,
          home: NavigationPage(
            args: NavigationArgs(
              point: stops.first,
              stops: stops,
              groupName: groupName,
              initialRoute: _route(stops),
              initialLocation: _start(stops.first),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  for (final (size, scale) in [
    (TestSizes.phone, 1.0),
    (TestSizes.phoneSmall, 2.0),
    (TestSizes.phoneLandscape, 1.0),
    (TestSizes.phoneLandscape, 2.0),
    (TestSizes.tablet, 1.0),
    (TestSizes.desktop, 1.0),
  ]) {
    testWidgets('renders the maneuver card and trip panel at $size x$scale', (
      tester,
    ) async {
      await pumpNavigation(tester, size: size, textScale: scale);
      expect(tester.takeException(), isNull);
      expect(find.text('右转进入表参道'), findsOneWidget);
      expect(find.text('宇治站附近'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('in-app-navigation-trip-summary')),
        findsOneWidget,
      );
      expect(find.text('到达'), findsOneWidget);
      expect(find.text('公里'), findsOneWidget);
      expect(find.byTooltip('回到当前位置'), findsOneWidget);
    });
  }

  testWidgets('arrival sheet opens from live location and advances', (
    tester,
  ) async {
    await pumpNavigation(tester);
    locations.add(
      NavigationLocationSample(position: _point.position, accuracy: 5),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('in-app-navigation-arrival-sheet')),
      findsOneWidget,
    );
    expect(find.text('到达点位'), findsOneWidget);
    expect(find.text('第 1 / 2 个剩余点位'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('in-app-navigation-arrival-next')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('in-app-navigation-arrival-sheet')),
      findsNothing,
    );
    expect(find.text('终点: 京阪宇治站前'), findsOneWidget);
    expect(routes.requests.single.last, _lastPoint.position);
    // Navigation never completes points.
    expect(stores.session.controller.completedPointIds, isEmpty);
  });

  testWidgets('the expanded panel shows details, all stops and end route', (
    tester,
  ) async {
    await pumpNavigation(tester);
    await tester.tap(find.byKey(const ValueKey('in-app-navigation-expand')));
    await tester.pumpAndSettle();
    expect(find.text('全部点位'), findsOneWidget);
    expect(find.text('共 2 个'), findsOneWidget);
    expect(find.text('已到达'), findsOneWidget);
    expect(find.text('结束路线'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('in-app-navigation-all-stops')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('in-app-navigation-all-stops-sheet')),
      findsOneWidget,
    );
    expect(find.text('终点: 京阪宇治站前'), findsOneWidget);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    await tester.tap(find.text('已到达'));
    await tester.pumpAndSettle();
    expect(find.text('打开相机'), findsOneWidget);
    expect(find.text('前往下一点'), findsOneWidget);
  });

  testWidgets('last stop arrival offers 结束路线', (tester) async {
    await pumpNavigation(tester, stops: const [_point], groupName: null);
    await tester.tap(find.byKey(const ValueKey('in-app-navigation-expand')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('已到达'));
    await tester.pumpAndSettle();
    expect(find.text('前往下一点'), findsNothing);
    expect(
      find.byKey(const ValueKey('in-app-navigation-arrival-finish')),
      findsOneWidget,
    );
  });

  testWidgets('approximate location shows the warning with 去设置', (
    tester,
  ) async {
    await pumpNavigation(tester, precise: false);
    await tester.pump();
    expect(
      find.byKey(const ValueKey('navigation-precise-location-warning')),
      findsOneWidget,
    );
    expect(find.text('去设置'), findsOneWidget);
  });

  testWidgets('location errors offer 重试定位', (tester) async {
    await pumpNavigation(tester);
    locations.addError(StateError('service unavailable'));
    await tester.pump();
    expect(find.text('重试定位'), findsOneWidget);
    expect(find.text('定位更新失败，请检查权限和定位服务后重试。'), findsOneWidget);
    locations.add(
      NavigationLocationSample(
        position: LatLng(
          _point.position.latitude - 0.003,
          _point.position.longitude,
        ),
        accuracy: 5,
      ),
    );
    await tester.pump();
    expect(find.text('重试定位'), findsNothing);
  });

  testWidgets('invalid arguments show a message', (tester) async {
    setTestWindow(tester, TestSizes.phone);
    stores = await FeatureTestStores.load();
    await tester.pumpWidget(
      featureTestApp(
        stores: stores,
        home: const NavigationPage(args: Object()),
      ),
    );
    expect(find.text('没有正在进行的导航'), findsOneWidget);
  });
}
