import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:miriago/ui/map/map.dart';

import 'map_test_harness.dart';

void main() {
  final camera = MapCamera(
    crs: const Epsg3857(),
    center: const LatLng(34.89, 135.80),
    zoom: 15,
    rotation: 0,
    nonRotatedSize: const Size(400, 800),
  );

  test('bounds of a screen rect match its corners in any drag direction', () {
    const rect = Rect.fromLTRB(100, 200, 300, 500);
    final bounds = boundsForScreenRect(camera, rect);
    final reversed = boundsForScreenRect(
      camera,
      Rect.fromPoints(rect.bottomRight, rect.topLeft),
    );
    final topLeft = camera.screenOffsetToLatLng(rect.topLeft);
    final bottomRight = camera.screenOffsetToLatLng(rect.bottomRight);
    expect(bounds.north, closeTo(topLeft.latitude, 1e-9));
    expect(bounds.west, closeTo(topLeft.longitude, 1e-9));
    expect(bounds.south, closeTo(bottomRight.latitude, 1e-9));
    expect(bounds.east, closeTo(bottomRight.longitude, 1e-9));
    expect(reversed.north, bounds.north);
    expect(reversed.south, bounds.south);

    final inside = camera.screenOffsetToLatLng(const Offset(200, 300));
    final outside = camera.screenOffsetToLatLng(const Offset(20, 20));
    expect(bounds.contains(inside), isTrue);
    expect(bounds.contains(outside), isFalse);
    expect(itemsInBounds<LatLng?>([inside, outside, null], (p) => p, bounds), [
      inside,
    ]);
  });

  test('rotated camera uses all four corners', () {
    final rotated = MapCamera(
      crs: const Epsg3857(),
      center: const LatLng(34.89, 135.80),
      zoom: 15,
      rotation: 30,
      nonRotatedSize: const Size(400, 800),
    );
    const rect = Rect.fromLTRB(100, 200, 300, 500);
    final bounds = boundsForScreenRect(rotated, rect);
    for (final corner in [
      rect.topLeft,
      rect.topRight,
      rect.bottomLeft,
      rect.bottomRight,
    ]) {
      final point = rotated.screenOffsetToLatLng(corner);
      expect(point.latitude, inInclusiveRange(bounds.south, bounds.north));
      expect(point.longitude, inInclusiveRange(bounds.west, bounds.east));
    }
  });

  testWidgets('dragging selects a box and does not pan the map', (
    tester,
  ) async {
    final stores = await MapTestStores.load();
    setWindowSize(tester, const Size(400, 800));
    final map = PlanMapController();
    final selection = BoxSelectController();
    addTearDown(map.dispose);
    addTearDown(selection.dispose);
    LatLngBounds? selected;

    Widget build({required bool active}) => mapTestApp(
      stores: stores,
      scaffold: false,
      child: PlanMap(
        controller: map,
        disableTiles: true,
        showAttribution: false,
        initialCenter: const LatLng(34.89, 135.80),
        children: [
          BoxSelectLayer(
            active: active,
            controller: selection,
            onSelected: (bounds) => selected = bounds,
          ),
        ],
      ),
    );

    await tester.pumpWidget(build(active: true));
    await tester.pump();
    final centerBefore = map.camera!.center;
    final expected = boundsForScreenRect(
      map.camera!,
      const Rect.fromLTRB(100, 200, 300, 500),
    );

    final gesture = await tester.startGesture(const Offset(100, 200));
    await gesture.moveTo(const Offset(200, 350));
    await gesture.moveTo(const Offset(300, 500));
    await gesture.up();
    await tester.pump();

    expect(map.camera!.center, centerBefore);
    expect(selected, isNotNull);
    expect(selected!.north, closeTo(expected.north, 1e-9));
    expect(selected!.south, closeTo(expected.south, 1e-9));
    expect(selected!.west, closeTo(expected.west, 1e-9));
    expect(selected!.east, closeTo(expected.east, 1e-9));
    expect(selection.hasSelection, isTrue);

    // Leaving box-select mode clears the selection and the map pans again.
    await tester.pumpWidget(build(active: false));
    await tester.pump();
    expect(selection.hasSelection, isFalse);
    await tester.dragFrom(const Offset(200, 400), const Offset(0, 120));
    await tester.pump();
    expect(map.camera!.center, isNot(centerBefore));
  });
}
