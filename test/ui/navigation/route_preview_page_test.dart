import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:miriago/application/navigation/route_planner.dart';
import 'package:miriago/map/map_navigation_launcher.dart';
import 'package:miriago/map/valhalla_route_client.dart';
import 'package:miriago/plan/plan_group_utils.dart';
import 'package:miriago/ui/features/navigation/navigation_page.dart';
import 'package:miriago/ui/features/navigation/navigation_services.dart';
import 'package:miriago/ui/features/navigation/route_preview_page.dart';

import '../../helpers/pump_app.dart' show TestSizes;
import '../camera/camera_test_harness.dart';

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
      maneuvers: [
        NavigationManeuver(
          type: 4,
          instruction: '继续直行',
          distanceKm: 0.5,
          beginShapeIndex: 0,
          endShapeIndex: locations.length - 1,
        ),
      ],
      distanceKm: 0.5,
      duration: const Duration(minutes: 8),
    );
  }
}

const _here = LatLng(34.887, 135.805);

void main() {
  late FeatureTestStores stores;
  late _Routes routes;
  Object? navigatedArgs;

  Future<String> pumpPreview(
    WidgetTester tester, {
    Size size = TestSizes.phone,
    double textScale = 1,
    NavigationLocationResolver? location,
    MapNavigationLauncher? launcher,
    bool zone = true,
    String? initialLocation,
  }) async {
    setTestWindow(tester, size, textScale: textScale);
    stores = await FeatureTestStores.load();
    routes = _Routes();
    navigatedArgs = null;
    final plan = stores.session.plan;
    final buckets = planGroupBuckets(plan, const {});
    final zoneBucket = buckets.firstWhere(
      (b) =>
          !b.isUngrouped && b.points.where((p) => p.hasCoordinate).length >= 2,
    );
    final pointId = zone
        ? zoneBucket.points.first.id
        : zoneBucket.points.last.id;
    final router = GoRouter(
      initialLocation: initialLocation ?? '/route/$pointId',
      routes: [
        GoRoute(
          path: '/go',
          builder: (context, state) => const Text('go-page'),
        ),
        GoRoute(
          path: '/route/:pointId',
          builder: (context, state) =>
              RoutePreviewPage(pointId: state.pathParameters['pointId']!),
        ),
        GoRoute(
          path: '/navigate',
          builder: (context, state) {
            navigatedArgs = state.extra;
            return NavigationPage(args: state.extra ?? const Object());
          },
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      featureTestRouterApp(
        stores: stores,
        router: router,
        wrap: (child) => NavigationServices(
          routeClient: routes,
          locationResolver: location ?? () async => _here,
          externalNavigationLauncher: launcher,
          locationStreamFactory: () => const Stream.empty(),
          headingStreamFactory: (_) => const Stream.empty(),
          preciseLocationCheck: ({required mayRequest}) async => true,
          disableMapTiles: true,
          child: child,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    return pointId;
  }

  testWidgets('loading, then a zone chain with both start buttons', (
    tester,
  ) async {
    final location = Completer<LatLng>();
    await pumpPreview(tester, location: () => location.future);
    expect(find.text('确认路线'), findsOneWidget);
    expect(find.text('正在获取当前位置并规划步行路线…'), findsOneWidget);
    expect(find.text('片区'), findsOneWidget);
    expect(find.text('串联整个片区'), findsOneWidget);
    expect(find.textContaining('按顺序连接'), findsOneWidget);
    location.complete(_here);
    await tester.pump();
    await tester.pump();
    expect(find.text('正在获取当前位置并规划步行路线…'), findsNothing);
    expect(find.text('串联整个片区导航'), findsOneWidget);
    expect(find.text('仅导航到选中点'), findsOneWidget);
    expect(routes.requests.single.first, _here);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a single remaining stop only offers 开始导航', (tester) async {
    await pumpPreview(tester, zone: false);
    expect(find.text('导航到选中点'), findsOneWidget);
    expect(find.textContaining('终点：'), findsOneWidget);
    expect(find.text('开始导航'), findsOneWidget);
    expect(find.text('串联整个片区导航'), findsNothing);
  });

  testWidgets('failure offers retry and the external map', (tester) async {
    var externalOpened = false;
    await pumpPreview(
      tester,
      launcher: MapNavigationLauncher(
        useAndroidGoogleMapsIntent: false,
        externalNavigationLauncher: (_) async {
          externalOpened = true;
          return false;
        },
      ),
      location: () async {
        if (routes.requests.isEmpty) {
          routes.failure = const ValhallaRouteException('测试路径服务不可用');
        }
        return _here;
      },
    );
    await tester.pump();
    expect(find.text('测试路径服务不可用'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
    final external = find.byKey(
      const ValueKey('navigation-route-external-fallback'),
    );
    expect(external, findsOneWidget);
    await tester.tap(external);
    await tester.pump();
    expect(externalOpened, isTrue);
    expect(toastTitles(stores), ['无法打开外部地图']);
    clearToasts(stores);
    await tester.pump(const Duration(milliseconds: 500));

    routes.failure = null;
    await tester.tap(find.text('重试'));
    await tester.pump();
    await tester.pump();
    expect(find.text('串联整个片区导航'), findsOneWidget);
  });

  testWidgets('starting the zone replaces the preview with navigation', (
    tester,
  ) async {
    final pointId = await pumpPreview(tester);
    await tester.tap(find.text('串联整个片区导航'));
    await tester.pumpAndSettle();
    final args = navigatedArgs as NavigationArgs;
    expect(args.point.id, pointId);
    expect(args.stops.length, greaterThanOrEqualTo(2));
    expect(args.groupName, isNotNull);
    expect(routes.requests, hasLength(1));
    expect(
      find.byKey(const ValueKey('in-app-navigation-screen')),
      findsOneWidget,
    );
    expect(find.text('确认路线'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  group('without a page underneath (deep link / reload)', () {
    testWidgets('closing the preview goes to 巡礼', (tester) async {
      await pumpPreview(tester);
      await tester.tap(find.byType(CloseButton));
      await tester.pumpAndSettle();
      expect(find.text('go-page'), findsOneWidget);
      expect(find.text('确认路线'), findsNothing);
    });

    testWidgets('结束路线 after starting from the preview goes to 巡礼', (
      tester,
    ) async {
      await pumpPreview(tester);
      await tester.tap(find.text('串联整个片区导航'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('in-app-navigation-expand')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('结束路线'));
      await tester.pumpAndSettle();
      expect(find.text('go-page'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('in-app-navigation-screen')),
        findsNothing,
      );
    });

    testWidgets('/navigate without arguments: 返回 goes to 巡礼', (tester) async {
      await pumpPreview(tester, initialLocation: '/navigate');
      expect(find.text('没有正在进行的导航'), findsOneWidget);
      await tester.tap(find.text('返回'));
      await tester.pumpAndSettle();
      expect(find.text('go-page'), findsOneWidget);
    });

    testWidgets('a pushed preview still closes back to its page', (
      tester,
    ) async {
      final pointId = await pumpPreview(tester, initialLocation: '/go');
      final router = GoRouter.of(tester.element(find.text('go-page')));
      unawaited(router.push<void>('/route/$pointId'));
      await tester.pumpAndSettle();
      expect(find.text('确认路线'), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('go-page'), findsOneWidget);
      expect(find.text('确认路线'), findsNothing);
    });
  });

  testWidgets('仅导航到选中点 re-requests a point-only route', (tester) async {
    final pointId = await pumpPreview(tester);
    await tester.tap(find.text('仅导航到选中点'));
    await tester.pumpAndSettle();
    final args = navigatedArgs as NavigationArgs;
    expect(args.stops.single.id, pointId);
    expect(args.groupName, isNull);
    expect(routes.requests, hasLength(2));
    expect(routes.requests.last, hasLength(2));
  });

  for (final (size, scale) in [
    (TestSizes.phoneLandscape, 1.0),
    (TestSizes.phoneLandscape, 2.0),
    (TestSizes.phoneSmall, 2.0),
    (TestSizes.desktop, 1.0),
  ]) {
    testWidgets('no overflow at $size x$scale', (tester) async {
      await pumpPreview(tester, size: size, textScale: scale);
      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const ValueKey('navigation-route-confirm-zone')),
        findsOneWidget,
      );
    });
  }
}
