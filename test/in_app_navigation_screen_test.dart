import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:miriago/app_theme.dart';
import 'package:miriago/map/in_app_navigation_screen.dart';
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
    name: '宇治桥',
    subtitle: '表参道',
    position: LatLng(34.8894, 135.8074),
    episodeLabel: 'EP 1',
    referenceLabel: '手动',
  );

  Future<void> pumpScreen(
    WidgetTester tester, {
    AppSettings settings = const AppSettings(),
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
                  onPressed: () => InAppNavigationScreen.open(
                    context,
                    point: selected,
                    settings: settings,
                    groupName: groupName,
                    stops: stops,
                  ),
                  child: const Text('打开导航'),
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('打开导航'));
    await tester.pumpAndSettle();
  }

  testWidgets('renders light-mode apple-style navigation chrome', (
    tester,
  ) async {
    await pumpScreen(tester);

    expect(
      find.byKey(const ValueKey('in-app-navigation-screen')),
      findsOneWidget,
    );
    expect(find.text('475米'), findsOneWidget);
    expect(find.text('右转进入表参道'), findsOneWidget);
    expect(find.textContaining('终点: 宇治桥'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('in-app-navigation-trip-summary')),
      findsOneWidget,
    );
    expect(find.text('到达'), findsOneWidget);
    expect(find.text('小时'), findsOneWidget);
    expect(find.text('公里'), findsOneWidget);
    expect(find.text('17 分钟'), findsNothing);
    expect(
      find.byKey(const ValueKey('in-app-navigation-expand')),
      findsOneWidget,
    );
    expect(find.text('结束路线'), findsNothing);
  });

  testWidgets('navigation chrome uses theme accent instead of map blue', (
    tester,
  ) async {
    await pumpScreen(tester);

    final icon = tester.widget<Icon>(
      find.descendant(
        of: find.byKey(const ValueKey('in-app-navigation-recenter')),
        matching: find.byType(Icon),
      ),
    );
    expect(icon.color, AppColors.accent);
    expect(icon.color, isNot(const Color(0xFF007AFF)));
  });

  testWidgets(
    'collapsing the bottom panel keeps the sheet flush with the screen',
    (tester) async {
      await pumpScreen(tester);

      await tester.tap(find.byKey(const ValueKey('in-app-navigation-expand')));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('in-app-navigation-collapse')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 140));

      final panel = tester.getRect(
        find.byKey(const ValueKey('in-app-navigation-bottom-panel')),
      );
      expect(panel.bottom, 844);
      expect(panel.height, greaterThan(80));
    },
  );

  testWidgets('expanded sheet shows destination details and can end route', (
    tester,
  ) async {
    await pumpScreen(tester);

    await tester.tap(find.byKey(const ValueKey('in-app-navigation-expand')));
    await tester.pumpAndSettle();

    expect(find.text('结束路线'), findsOneWidget);
    expect(find.text('已到达'), findsOneWidget);
    expect(find.text('全部点位'), findsOneWidget);
    expect(find.text('到达'), findsOneWidget);
    expect(find.text('小时'), findsOneWidget);
    expect(find.text('公里'), findsOneWidget);
    expect(find.text('详细信息'), findsNothing);
    expect(find.text('宇治桥'), findsWidgets);
    expect(find.textContaining('测试作品'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('in-app-navigation-collapse')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('in-app-navigation-arrive-debug')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('in-app-navigation-arrive-debug-sheet')),
      findsOneWidget,
    );
    expect(find.text('到达点位'), findsOneWidget);
    expect(find.textContaining('第 1 / 1 个剩余点位'), findsOneWidget);
    expect(find.text('打开相机'), findsOneWidget);
    expect(find.text('前往下一点'), findsNothing);
    expect(find.text('片区'), findsNothing);
    Navigator.of(
      tester.element(
        find.byKey(const ValueKey('in-app-navigation-arrive-debug-sheet')),
      ),
    ).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('in-app-navigation-all-stops')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('in-app-navigation-all-stops-sheet')),
      findsOneWidget,
    );
    expect(find.textContaining('终点: 宇治桥'), findsWidgets);

    Navigator.of(
      tester.element(
        find.byKey(const ValueKey('in-app-navigation-all-stops-sheet')),
      ),
    ).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('in-app-navigation-end-route')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('in-app-navigation-screen')),
      findsNothing,
    );
  });

  testWidgets('trip summary stays visible after collapsing the panel', (
    tester,
  ) async {
    await pumpScreen(tester, groupName: '宇治站附近');

    expect(
      find.byKey(const ValueKey('in-app-navigation-trip-summary')),
      findsOneWidget,
    );
    expect(find.text('到达'), findsOneWidget);
    expect(find.textContaining('终点: 宇治桥'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('in-app-navigation-expand')));
    await tester.pumpAndSettle();
    expect(find.text('结束路线'), findsOneWidget);
    expect(find.text('到达'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('in-app-navigation-collapse')));
    await tester.pumpAndSettle();

    expect(find.text('结束路线'), findsNothing);
    expect(
      find.byKey(const ValueKey('in-app-navigation-trip-summary')),
      findsOneWidget,
    );
    expect(find.text('到达'), findsOneWidget);
    expect(find.text('小时'), findsOneWidget);
    expect(find.text('公里'), findsOneWidget);
    expect(find.text('片区'), findsOneWidget);
    expect(find.text('宇治站附近'), findsOneWidget);
    expect(find.textContaining('终点: 宇治桥'), findsOneWidget);
    final zoneStrip = tester.getRect(
      find.byKey(const ValueKey('in-app-navigation-top-zone')),
    );
    expect(zoneStrip.center.dx, closeTo(195, 24));
    expect(zoneStrip.top, lessThan(80));
    expect(zoneStrip.width, greaterThan(300));
  });

  testWidgets('instruction pager can swipe to the next preview step', (
    tester,
  ) async {
    await pumpScreen(tester);

    await tester.drag(
      find.byKey(const ValueKey('in-app-navigation-steps')),
      const Offset(-280, 0),
    );
    await tester.pumpAndSettle();

    expect(find.text('210米'), findsOneWidget);
    expect(find.text('沿表参道直行'), findsOneWidget);
  });

  testWidgets('dark theme mode uses dark navigation chrome', (tester) async {
    await pumpScreen(
      tester,
      settings: const AppSettings(themeMode: AppThemeMode.dark),
    );

    final scaffold = tester.widget<Scaffold>(
      find.byKey(const ValueKey('in-app-navigation-screen')),
    );
    expect(scaffold.backgroundColor, const Color(0xFF1C1C1E));
    expect(find.text('475米'), findsOneWidget);
    expect(find.textContaining('终点: 宇治桥'), findsOneWidget);
  });

  test('resolvedAppBrightness follows light, dark, and system', () {
    expect(
      resolvedAppBrightness(
        const AppSettings(),
        platformBrightness: Brightness.dark,
      ),
      Brightness.light,
    );
    expect(
      resolvedAppBrightness(
        const AppSettings(themeMode: AppThemeMode.dark),
        platformBrightness: Brightness.light,
      ),
      Brightness.dark,
    );
    expect(
      resolvedAppBrightness(
        const AppSettings(themeMode: AppThemeMode.system),
        platformBrightness: Brightness.dark,
      ),
      Brightness.dark,
    );
  });

  testWidgets('zone tour shows next stop, group badge, and all points', (
    tester,
  ) async {
    const lastPoint = PilgrimagePoint(
      id: 'point-2',
      work: work,
      name: '京阪宇治站前',
      subtitle: '京阪宇治駅前',
      position: LatLng(34.8942, 135.8069),
      episodeLabel: 'EP 5',
      referenceLabel: '手动',
    );

    await pumpScreen(
      tester,
      groupName: '宇治站附近',
      stops: const [point, lastPoint],
    );

    expect(find.text('片区'), findsOneWidget);
    expect(find.text('宇治站附近'), findsOneWidget);
    expect(find.text('宇治桥'), findsOneWidget);
    expect(find.textContaining('下一个:'), findsNothing);
    expect(find.textContaining('终点: 宇治桥'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('in-app-navigation-expand')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('in-app-navigation-arrive-debug')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('in-app-navigation-arrive-debug-sheet')),
      findsOneWidget,
    );
    expect(find.text('到达点位'), findsOneWidget);
    expect(find.textContaining('第 1 / 2 个剩余点位'), findsOneWidget);
    expect(find.text('打开相机'), findsOneWidget);
    expect(find.text('片区'), findsOneWidget);
    expect(find.text('京阪宇治站前'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('in-app-navigation-arrive-debug-next')),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('终点: 京阪宇治站前'), findsOneWidget);
    expect(find.text('结束路线'), findsNothing);
    expect(find.text('已到达'), findsNothing);
    expect(
      find.byKey(const ValueKey('in-app-navigation-expand')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('in-app-navigation-expand')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('in-app-navigation-all-stops')));
    await tester.pumpAndSettle();

    expect(find.textContaining('下一个:'), findsNothing);
    expect(find.textContaining('终点: 京阪宇治站前'), findsWidgets);
  });

  testWidgets('zone tour from a later point skips earlier stops', (
    tester,
  ) async {
    const firstPoint = PilgrimagePoint(
      id: 'point-0',
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

    await pumpScreen(
      tester,
      groupName: '宇治站附近',
      stops: const [firstPoint, point, lastPoint],
    );

    expect(find.textContaining('宇治桥'), findsOneWidget);
    expect(find.textContaining('下一个:'), findsNothing);
    expect(find.textContaining('下一个: 井用机前步行道'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('in-app-navigation-expand')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('in-app-navigation-all-stops')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('in-app-navigation-stop-skipped-point-0')),
      findsOneWidget,
    );
    expect(find.text('井用机前步行道'), findsOneWidget);
    expect(find.textContaining('宇治桥'), findsWidgets);
    expect(find.textContaining('下一个:'), findsNothing);
    expect(find.textContaining('终点: 京阪宇治站前'), findsOneWidget);
  });
}
