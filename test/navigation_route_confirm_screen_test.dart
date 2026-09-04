import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:miriago/app_theme.dart';
import 'package:miriago/map/navigation_route_confirm_screen.dart';
import 'package:miriago/map/map_navigation_launcher.dart';
import 'package:miriago/map/valhalla_route_client.dart';
import 'package:miriago/plan/pilgrimage_models.dart';

void main() {
  const work = PilgrimageWork(
    id: 'work-1',
    title: '测试作品',
    subtitle: '',
    city: '京都',
    source: WorkSource.manual,
  );
  const point = PilgrimagePoint(
    id: 'point-1',
    work: work,
    name: '井用机前步行道',
    subtitle: 'あじろぎの道',
    position: LatLng(34.8899, 135.8081),
    episodeLabel: 'EP 1',
    referenceLabel: '手动',
  );
  const lastPoint = PilgrimagePoint(
    id: 'point-2',
    work: work,
    name: '京阪宇治站前',
    subtitle: '京阪宇治駅前',
    position: LatLng(34.8942, 135.8069),
    episodeLabel: 'EP 5',
    referenceLabel: '手动',
  );

  Future<void> pumpConfirm(
    WidgetTester tester, {
    String? groupName,
    List<PilgrimagePoint> stops = const [],
    PilgrimagePoint? startPoint,
  }) async {
    final selected = startPoint ?? point;
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () => NavigationRouteConfirmScreen.open(
                    context,
                    point: selected,
                    settings: const AppSettings(),
                    groupName: groupName,
                    stops: stops,
                    routeClient: _TestRouteClient(),
                    locationResolver: () async => const LatLng(34.887, 135.805),
                  ),
                  child: const Text('打开确认'),
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('打开确认'));
    await tester.pumpAndSettle();
  }

  testWidgets('zone confirm highlights chaining the whole group', (
    tester,
  ) async {
    await pumpConfirm(
      tester,
      groupName: '宇治站附近',
      stops: const [point, lastPoint],
    );

    expect(
      find.byKey(const ValueKey('navigation-route-confirm-screen')),
      findsOneWidget,
    );
    expect(find.text('确认路线'), findsOneWidget);
    expect(find.text('片区'), findsOneWidget);
    expect(find.text('宇治站附近'), findsOneWidget);
    expect(find.text('串联整个片区导航'), findsOneWidget);
    expect(find.textContaining('点击即按顺序连接'), findsNothing);
    expect(find.text('仅导航到选中点'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('in-app-navigation-screen')),
      findsNothing,
    );
  });

  testWidgets('confirming the zone starts chained in-app navigation', (
    tester,
  ) async {
    await pumpConfirm(
      tester,
      groupName: '宇治站附近',
      stops: const [point, lastPoint],
    );

    await tester.tap(
      find.byKey(const ValueKey('navigation-route-confirm-zone')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('navigation-route-confirm-screen')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('in-app-navigation-screen')),
      findsOneWidget,
    );
    expect(find.textContaining('井用机前步行道'), findsOneWidget);
    expect(find.text('片区'), findsOneWidget);
  });

  testWidgets('confirming a single selected point skips the zone chain', (
    tester,
  ) async {
    await pumpConfirm(
      tester,
      groupName: '宇治站附近',
      stops: const [point, lastPoint],
    );

    await tester.tap(
      find.byKey(const ValueKey('navigation-route-confirm-point')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('in-app-navigation-screen')),
      findsOneWidget,
    );
    expect(find.textContaining('终点: 井用机前步行道'), findsOneWidget);
    expect(find.textContaining('下一个:'), findsNothing);
    expect(find.text('片区'), findsNothing);
  });

  testWidgets('single-stop confirm only offers starting navigation', (
    tester,
  ) async {
    await pumpConfirm(tester, stops: const [point]);

    expect(find.text('串联整个片区导航'), findsNothing);
    expect(find.text('仅导航到选中点'), findsNothing);
    expect(find.text('开始导航'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('navigation-route-confirm-point')),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('终点: 井用机前步行道'), findsOneWidget);
  });

  testWidgets('zone confirm starts the chain from the selected point', (
    tester,
  ) async {
    await pumpConfirm(
      tester,
      groupName: '宇治站附近',
      startPoint: lastPoint,
      stops: const [point, lastPoint],
    );

    expect(find.text('串联整个片区导航'), findsNothing);
    expect(find.textContaining('按顺序连接 2 个点位'), findsNothing);
    expect(find.text('开始导航'), findsOneWidget);
    expect(find.textContaining('终点：京阪宇治站前'), findsOneWidget);
  });

  testWidgets('zone confirm remaining chain starts at the selected point', (
    tester,
  ) async {
    const middle = PilgrimagePoint(
      id: 'point-mid',
      work: work,
      name: '宇治桥',
      subtitle: '宇治橋',
      position: LatLng(34.8929, 135.8065),
      episodeLabel: 'EP 2',
      referenceLabel: '手动',
    );

    await pumpConfirm(
      tester,
      groupName: '宇治站附近',
      startPoint: middle,
      stops: const [point, middle, lastPoint],
    );

    expect(find.textContaining('按顺序连接 2 个点位：宇治桥 → 京阪宇治站前'), findsOneWidget);
    expect(find.textContaining('井用机前步行道'), findsNothing);
    expect(find.text('串联整个片区导航'), findsOneWidget);
  });

  testWidgets('route failure offers retry and external navigation', (
    tester,
  ) async {
    var externalOpened = false;
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () => NavigationRouteConfirmScreen.open(
                context,
                point: point,
                settings: const AppSettings(),
                stops: const [point],
                routeClient: _FailingRouteClient(),
                locationResolver: () async => const LatLng(34.887, 135.805),
                externalNavigationLauncher: MapNavigationLauncher(
                  useAndroidGoogleMapsIntent: false,
                  externalNavigationLauncher: (_) async {
                    externalOpened = true;
                    return true;
                  },
                ),
              ),
              child: const Text('打开确认'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开确认'));
    await tester.pumpAndSettle();
    expect(find.text('测试路径服务不可用'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
    expect(find.text('Google Maps'), findsOneWidget);

    await tester.tap(find.text('Google Maps'));
    await tester.pump();
    expect(externalOpened, isTrue);
  });
}

class _TestRouteClient extends ValhallaRouteClient {
  @override
  Future<NavigationRoute> route({
    required String baseUrl,
    required List<LatLng> locations,
  }) async {
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

class _FailingRouteClient extends ValhallaRouteClient {
  @override
  Future<NavigationRoute> route({
    required String baseUrl,
    required List<LatLng> locations,
  }) async {
    throw const ValhallaRouteException('测试路径服务不可用');
  }
}
