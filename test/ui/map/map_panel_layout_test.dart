import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/ui/map/map.dart';

import 'map_test_harness.dart';

void main() {
  late MapTestStores stores;

  setUp(() async {
    stores = await MapTestStores.load();
  });

  const sheetKey = ValueKey('map-panel-sheet');
  const sideKey = ValueKey('map-panel-side');
  const inspectorKey = ValueKey('map-panel-inspector');

  Widget layout({
    MapPanelController? controller,
    Widget? inspector,
    ValueChanged<EdgeInsets>? onInsets,
    VoidCallback? onMapPan,
  }) {
    return MapPanelLayout(
      controller: controller,
      peekHeight: 120,
      map: Builder(
        builder: (context) {
          onInsets?.call(MapPanelScope.maybeOf(context)!.obscured);
          return GestureDetector(
            key: const ValueKey('fake-map'),
            behavior: HitTestBehavior.opaque,
            onPanUpdate: (_) => onMapPan?.call(),
            child: const ColoredBox(color: Color(0xFFCCDDEE)),
          );
        },
      ),
      panelHeader: const SizedBox(height: 40, child: Text('panel header')),
      panel: ListView.builder(
        itemCount: 60,
        itemBuilder: (context, index) =>
            SizedBox(height: 48, child: Text('row $index')),
      ),
      inspector: inspector,
      controls: const SizedBox(
        key: ValueKey('fake-controls'),
        width: 44,
        height: 44,
      ),
    );
  }

  testWidgets('compact windows use a bottom sheet', (tester) async {
    setWindowSize(tester, const Size(390, 844));
    EdgeInsets? insets;
    await tester.pumpWidget(
      mapTestApp(
        stores: stores,
        child: layout(onInsets: (value) => insets = value),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(sheetKey), findsOneWidget);
    expect(find.byKey(sideKey), findsNothing);
    expect(find.text('panel header'), findsOneWidget);
    // Resting at half: ≈45% of the height is covered.
    expect(insets!.bottom, closeTo(844 * kMapSheetHalfFraction, 1));
    // Controls float above the sheet.
    final controls = tester.getRect(
      find.byKey(const ValueKey('fake-controls')),
    );
    expect(controls.bottom, lessThan(844 - 844 * kMapSheetHalfFraction));
  });

  testWidgets('wide windows use a floating side panel and inspector', (
    tester,
  ) async {
    setWindowSize(tester, const Size(1440, 900));
    EdgeInsets? insets;
    await tester.pumpWidget(
      mapTestApp(
        stores: stores,
        child: layout(onInsets: (value) => insets = value),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(sideKey), findsOneWidget);
    expect(find.byKey(sheetKey), findsNothing);
    expect(tester.getSize(find.byKey(sideKey)).width, kMapSidePanelWidth);
    expect(insets!.left, greaterThan(kMapSidePanelWidth));
    expect(insets!.right, 0);
    expect(find.byKey(inspectorKey), findsNothing);

    await tester.pumpWidget(
      mapTestApp(
        stores: stores,
        child: layout(
          onInsets: (value) => insets = value,
          inspector: const Text('inspector body'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(inspectorKey), findsOneWidget);
    expect(find.text('inspector body'), findsOneWidget);
    expect(tester.getSize(find.byKey(inspectorKey)).width, kMapInspectorWidth);
    expect(insets!.right, greaterThan(kMapInspectorWidth));
  });

  testWidgets('short windows use the narrow side panel', (tester) async {
    setWindowSize(tester, const Size(844, 390));
    await tester.pumpWidget(mapTestApp(stores: stores, child: layout()));
    await tester.pumpAndSettle();
    expect(find.byKey(sideKey), findsOneWidget);
    expect(tester.getSize(find.byKey(sideKey)).width, kMapSidePanelShortWidth);
  });

  testWidgets('snap persists across layout switches', (tester) async {
    final controller = MapPanelController(initialSnap: MapPanelSnap.peek);
    addTearDown(controller.dispose);
    setWindowSize(tester, const Size(390, 844));
    await tester.pumpWidget(
      mapTestApp(
        stores: stores,
        child: layout(controller: controller),
      ),
    );
    await tester.pumpAndSettle();
    expect(controller.sheetExtent.value, closeTo(120, 1));

    unawaited(controller.snapTo(MapPanelSnap.full));
    await tester.pumpAndSettle();
    expect(controller.snap, MapPanelSnap.full);
    expect(
      controller.sheetExtent.value,
      closeTo(844 * kMapSheetFullFraction, 1),
    );

    setWindowSize(tester, const Size(1440, 900));
    await tester.pumpAndSettle();
    expect(find.byKey(sideKey), findsOneWidget);
    expect(controller.snap, MapPanelSnap.full);

    setWindowSize(tester, const Size(390, 844));
    await tester.pumpAndSettle();
    expect(find.byKey(sheetKey), findsOneWidget);
    expect(
      controller.sheetExtent.value,
      closeTo(844 * kMapSheetFullFraction, 1),
    );
  });

  testWidgets('dragging the sheet moves it without panning the map', (
    tester,
  ) async {
    final controller = MapPanelController();
    addTearDown(controller.dispose);
    var mapPans = 0;
    setWindowSize(tester, const Size(390, 844));
    await tester.pumpWidget(
      mapTestApp(
        stores: stores,
        child: layout(controller: controller, onMapPan: () => mapPans++),
      ),
    );
    await tester.pumpAndSettle();
    final before = controller.sheetExtent.value;

    await tester.drag(find.text('panel header'), const Offset(0, 200));
    await tester.pumpAndSettle();
    expect(mapPans, 0);
    expect(controller.sheetExtent.value, lessThan(before));
    expect(controller.snap, MapPanelSnap.peek);

    // The map above the sheet still receives drags.
    await tester.drag(
      find.byKey(const ValueKey('fake-map')),
      const Offset(0, 60),
      warnIfMissed: false,
    );
    expect(mapPans, greaterThan(0));
  });

  testWidgets('the panel list scrolls once the sheet is at full', (
    tester,
  ) async {
    final controller = MapPanelController(initialSnap: MapPanelSnap.full);
    addTearDown(controller.dispose);
    setWindowSize(tester, const Size(390, 844));
    await tester.pumpWidget(
      mapTestApp(
        stores: stores,
        child: layout(controller: controller),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('row 0'), findsOneWidget);

    await tester.drag(find.text('row 3'), const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(controller.snap, MapPanelSnap.full);
    expect(find.text('row 0'), findsNothing);
  });
}
