import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/ui/map/map.dart';
import 'package:miriago/ui/map/map_gallery_page.dart';

import 'map_test_harness.dart';

void main() {
  for (final size in const [Size(390, 844), Size(844, 390), Size(1440, 900)]) {
    testWidgets('map gallery renders at $size', (tester) async {
      final stores = await MapTestStores.load();
      setWindowSize(tester, size);
      await tester.pumpWidget(
        mapTestApp(
          stores: stores,
          scaffold: false,
          child: const MapGalleryPage(disableTiles: true),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull);
      expect(find.byType(PlanMap), findsOneWidget);
      expect(find.byType(MapControls), findsOneWidget);
      expect(find.byKey(const ValueKey('map-control-locate')), findsOneWidget);
    });
  }

  testWidgets('layers popover toggles settings', (tester) async {
    final stores = await MapTestStores.load();
    setWindowSize(tester, const Size(390, 844));
    await tester.pumpWidget(
      mapTestApp(
        stores: stores,
        scaffold: false,
        child: const MapGalleryPage(disableTiles: true),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    final before = stores.settings.settings.hideCompletedPointsOnMap;
    await tester.tap(find.byKey(const ValueKey('map-control-layers')));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.tap(find.text('隐藏已完成点位'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(stores.settings.settings.hideCompletedPointsOnMap, !before);
  });
}
