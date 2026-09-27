import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/data/sample_pilgrimage_repository.dart';
import 'package:miriago/plan/pilgrimage_models.dart';
import 'package:miriago/ui/features/settings/settings_page.dart';

import '../../helpers/pump_app.dart';

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

Future<void> _reveal(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await _settle(tester);
}

/// Sample data whose settings saves can be held open.
class _SlowSaveRepository extends SamplePilgrimageRepository {
  Completer<void>? saveGate;

  @override
  Future<void> saveAppSettings(AppSettings settings) async {
    await saveGate?.future;
    return super.saveAppSettings(settings);
  }
}

void main() {
  testWidgets('恢复初始设置 confirms only after the save completed', (tester) async {
    final repository = _SlowSaveRepository();
    await pumpMiriaApp(
      tester,
      location: '/settings/about',
      repository: repository,
    );
    final reset = find.byKey(const ValueKey('settings-reset-button'));
    await _reveal(tester, reset);
    repository.saveGate = Completer<void>();
    await tester.tap(reset);
    await _settle(tester);
    await tester.tap(find.text('恢复').last);
    await _settle(tester);
    expect(find.text('已恢复初始设置'), findsNothing);

    repository.saveGate!.complete();
    await _settle(tester);
    expect(find.text('已恢复初始设置'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    expect(tester.takeException(), isNull);
  });

  testWidgets('phone shows the grouped overview and opens a section page', (
    tester,
  ) async {
    await pumpMiriaApp(tester, location: '/settings', size: TestSizes.phone);
    expect(find.text('外观设置'), findsOneWidget);
    expect(find.text('主题色'), findsOneWidget);
    expect(find.text('主题模式'), findsOneWidget);
    expect(find.text('拍摄图片比例'), findsOneWidget);
    // No two-pane layout on compact windows.
    expect(
      find.byKey(const ValueKey('settings-category-appearance')),
      findsNothing,
    );

    await _reveal(tester, find.text('地图显示'));
    await tester.tap(find.text('地图显示'));
    await _settle(tester);
    expect(find.text('最大缩放倍率'), findsOneWidget);
    expect(find.byTooltip('返回'), findsOneWidget);

    await tester.tap(find.byTooltip('返回'));
    await _settle(tester);
    expect(find.text('最大缩放倍率'), findsNothing);
    expect(find.text('外观设置'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop shows categories next to the selected section', (
    tester,
  ) async {
    await pumpMiriaApp(tester, location: '/settings', size: TestSizes.desktop);
    expect(
      find.byKey(const ValueKey('settings-category-appearance')),
      findsOneWidget,
    );
    // Appearance is selected by default and rendered on the right.
    expect(find.text('主题模式'), findsOneWidget);
    expect(find.text('实时预览'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('settings-category-sources')));
    await _settle(tester);
    expect(find.text('地图源 OpenFreeMap'), findsOneWidget);
    expect(find.text('主题模式'), findsNothing);

    // The Anitabi sub page opens in the detail pane with a way back.
    await _reveal(
      tester,
      find.byKey(const ValueKey('anitabi-service-settings-entry')),
    );
    await tester.tap(
      find.byKey(const ValueKey('anitabi-service-settings-entry')),
    );
    await _settle(tester);
    expect(find.text('测试全部连接'), findsOneWidget);
    expect(find.text('静态地图数据'), findsOneWidget);
    await tester.tap(find.byTooltip('返回数据源设置'));
    await _settle(tester);
    expect(find.text('地图源 OpenFreeMap'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a setting change is saved through the repository', (
    tester,
  ) async {
    final repository = await pumpMiriaApp(
      tester,
      location: '/settings/map',
      size: TestSizes.phone,
    );
    expect(
      (await repository.loadAppSettings()).hideCompletedPointsOnMap,
      isTrue,
    );
    final toggle = find.byKey(
      const ValueKey('hide-completed-points-on-map-toggle'),
    );
    await _reveal(tester, toggle);
    await tester.tap(toggle);
    await _settle(tester);
    expect(
      (await repository.loadAppSettings()).hideCompletedPointsOnMap,
      isFalse,
    );

    // Turning clustering off hides its dependent rows.
    final clustering = find.byKey(const ValueKey('map-clustering-toggle'));
    await _reveal(tester, clustering);
    expect(find.text('聚合范围'), findsOneWidget);
    await tester.tap(clustering);
    await _settle(tester);
    expect(find.text('聚合范围'), findsNothing);
    expect(
      (await repository.loadAppSettings()).mapMarkerClusteringEnabled,
      isFalse,
    );
  });

  testWidgets('theme mode and font size apply immediately', (tester) async {
    final repository = await pumpMiriaApp(
      tester,
      location: '/settings/appearance',
      size: TestSizes.phone,
    );
    await tester.tap(find.text('深色'));
    await _settle(tester);
    await tester.tap(find.text('特大'));
    await _settle(tester);
    final saved = await repository.loadAppSettings();
    expect(saved.themeMode, AppThemeMode.dark);
    expect(saved.fontScale, 1.2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('restoring defaults asks first and mentions data sources', (
    tester,
  ) async {
    final repository = await pumpMiriaApp(
      tester,
      location: '/settings/about',
      size: TestSizes.phone,
    );
    await repository.saveAppSettings(
      const AppSettings(
        mapMaxZoom: 18,
        valhallaBaseUrl: 'https://route.example.org',
      ),
    );
    final button = find.byKey(const ValueKey('settings-reset-button'));
    await _reveal(tester, button);
    await tester.tap(button);
    await _settle(tester);
    expect(
      find.textContaining('数据源设置也会一起恢复', findRichText: true),
      findsOneWidget,
    );

    // Cancel keeps the settings.
    await tester.tap(find.text('取消'));
    await _settle(tester);
    expect((await repository.loadAppSettings()).mapMaxZoom, 18);

    await tester.tap(button);
    await _settle(tester);
    await tester.tap(find.text('恢复'));
    await _settle(tester);
    final saved = await repository.loadAppSettings();
    expect(saved.mapMaxZoom, 22);
    expect(saved.valhallaBaseUrl, const AppSettings().valhallaBaseUrl);
    expect(find.text('已恢复初始设置'), findsOneWidget);
  });

  testWidgets('about opens the privacy policy', (tester) async {
    await pumpMiriaApp(tester, location: '/settings/about');
    final row = find.byKey(const ValueKey('about-privacy-policy'));
    await _reveal(tester, row);
    await tester.tap(row);
    await _settle(tester);
    expect(find.text('隐私政策'), findsWidgets);
  });

  for (final location in [
    '/settings',
    for (final id in [
      'appearance',
      'camera',
      'comparison',
      'map',
      'sources',
      'anitabi',
      'storage',
      'about',
    ])
      '/settings/$id',
  ]) {
    testWidgets('no overflow at small phone with text scale 2: $location', (
      tester,
    ) async {
      await pumpMiriaApp(
        tester,
        location: location,
        size: TestSizes.phoneSmall,
        textScale: 2,
      );
      await _settle(tester);
      expect(find.byType(SettingsPage), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }

  for (final size in [TestSizes.tablet, TestSizes.phoneLandscape]) {
    testWidgets('renders every section at $size', (tester) async {
      await pumpMiriaApp(tester, location: '/settings', size: size);
      for (final id in ['camera', 'map', 'sources', 'storage', 'about']) {
        await pumpMiriaApp(tester, location: '/settings/$id', size: size);
        await _settle(tester);
        expect(tester.takeException(), isNull, reason: id);
      }
    });
  }
}
