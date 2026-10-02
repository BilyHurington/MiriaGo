import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:miriago/app_theme.dart';
import 'package:miriago/data/sample_pilgrimage_repository.dart';
import 'package:miriago/map/map_layers_panel.dart';
import 'package:miriago/map/map_location_tracker.dart';
import 'package:miriago/map/pilgrimage_map_screen.dart';
import 'package:miriago/plan/pilgrimage_models.dart';
import 'package:miriago/plan/pilgrimage_plan_controller.dart';

void main() {
  Future<void> openPanel(
    WidgetTester tester, {
    required Size size,
    required Future<bool> Function(bool value) onChanged,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        key: UniqueKey(),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topRight,
            child: Builder(
              builder: (context) => IconButton(
                key: const ValueKey('open'),
                icon: const Icon(LucideIcons.layers),
                onPressed: () => showMapLayersPanel(
                  context,
                  settings: const AppSettings(),
                  toggles: [
                    MapLayerToggle(
                      id: 'demo',
                      label: '示例开关',
                      description: '说明',
                      icon: LucideIcons.image,
                      value: false,
                      onChanged: onChanged,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('open')));
    await tester.pumpAndSettle();
  }

  SwitchListTile toggle(WidgetTester tester) =>
      tester.widget(find.byKey(const ValueKey('map-layer-toggle-demo')));

  testWidgets('phones get a bottom sheet, wide windows a card', (tester) async {
    await openPanel(
      tester,
      size: const Size(390, 800),
      onChanged: (_) async => true,
    );
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text('图层'), findsOneWidget);

    await openPanel(
      tester,
      size: const Size(1200, 800),
      onChanged: (_) async => true,
    );
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.byKey(const ValueKey('map-layers-panel')), findsOneWidget);
  });

  testWidgets('a switch applies right away and flips back if not saved', (
    tester,
  ) async {
    final saved = Completer<bool>();
    final values = <bool>[];
    await openPanel(
      tester,
      size: const Size(390, 800),
      onChanged: (value) {
        values.add(value);
        return saved.future;
      },
    );

    await tester.tap(find.byKey(const ValueKey('map-layer-toggle-demo')));
    await tester.pump();
    expect(values, [true]);
    expect(toggle(tester).value, isTrue);

    saved.complete(false);
    await tester.pumpAndSettle();
    expect(toggle(tester).value, isFalse);
  });

  testWidgets('a short wide window scrolls the card', (tester) async {
    await openPanel(
      tester,
      size: const Size(1200, 260),
      onChanged: (_) async => true,
    );
    expect(tester.takeException(), isNull);
    final card = find.byKey(const ValueKey('map-layers-panel'));
    expect(
      find.ancestor(of: card, matching: find.byType(SingleChildScrollView)),
      findsOneWidget,
    );
    expect(tester.getBottomLeft(find.byType(Material).last).dy, lessThan(260));
  });

  testWidgets('a late failed save does not undo a newer change', (
    tester,
  ) async {
    final saves = <Completer<bool>>[];
    await openPanel(
      tester,
      size: const Size(390, 800),
      onChanged: (_) {
        final save = Completer<bool>();
        saves.add(save);
        return save.future;
      },
    );
    final demo = find.byKey(const ValueKey('map-layer-toggle-demo'));
    for (var i = 0; i < 3; i++) {
      await tester.tap(demo);
      await tester.pump();
    }
    expect(toggle(tester).value, isTrue);

    // The first change (to on) fails after the user has moved on.
    saves.first.complete(false);
    await tester.pump();
    expect(toggle(tester).value, isTrue);
    saves[1].complete(true);
    saves.last.complete(true);
    await tester.pump();
    expect(toggle(tester).value, isTrue);
  });

  testWidgets('main map layers are stored and applied', (tester) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repository = SamplePilgrimageRepository();
    final controller = PilgrimagePlanController(
      plan: (await repository.loadPlans()).first,
    );
    addTearDown(controller.dispose);
    final tracker = MapLocationTracker(
      resolve: (_) async => Position(
        latitude: 34.88,
        longitude: 135.8,
        timestamp: DateTime(2026),
        accuracy: 5,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      ),
      streamFactory: (_) => const Stream<Position>.empty(),
    );
    var settings = const AppSettings(
      mapTileProvider: MapTileProvider.openStreetMap,
    );
    late StateSetter rebuild;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return PilgrimageMapScreen(
              controller: controller,
              settings: settings,
              locationTracker: tracker,
              onSettingsChanged: (next) async {
                rebuild(() => settings = next);
                return true;
              },
            );
          },
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(PolygonLayer), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('map-layers-button')));
    // The map keeps animating, so settle the sheet frame by frame.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    for (final id in const [
      'thumbnails',
      'group-areas',
      'hide-completed',
      'clustering',
      'continuous-location',
    ]) {
      expect(find.byKey(ValueKey('map-layer-toggle-$id')), findsOneWidget);
    }
    await tester.tap(
      find.byKey(const ValueKey('map-layer-toggle-group-areas')),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const ValueKey('map-layer-toggle-thumbnails')));
    await tester.pump(const Duration(milliseconds: 300));

    expect(settings.mapShowGroupAreas, isFalse);
    expect(settings.mapShowThumbnailMarkers, isTrue);
    expect(find.byType(PolygonLayer), findsNothing);
  });
}
