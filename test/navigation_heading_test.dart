import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:miriago/map/navigation_heading.dart';

void main() {
  test('headings reject invalid values and cross north on the short arc', () {
    for (final value in [null, -1.0, double.nan, double.infinity, 360.0]) {
      expect(normalizedHeading(value), isNull);
    }
    expect(normalizedHeading(0), 0);
    expect(shortestHeadingDelta(359, 1), 2);
    expect(shortestHeadingDelta(1, 359), -2);
  });

  testWidgets('direction expires, rejects errors and stops with its owner', (
    tester,
  ) async {
    var cancels = 0;
    final stream = StreamController<double?>.broadcast(
      onCancel: () => cancels++,
    );
    final heading = NavigationHeading(staleAfter: const Duration(seconds: 3));
    heading.start(() => stream.stream);
    await tester.pump();
    stream.add(359);
    await tester.pump();
    stream.add(1);
    await tester.pump();
    expect(heading.value! * 360, closeTo(361, 0.001));
    stream.add(null);
    await tester.pump();
    expect(heading.value, isNull);
    stream.add(90);
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));
    expect(heading.value, isNull);
    stream.addError(StateError('no sensor'));
    await tester.pump();
    expect(heading.value, isNull);
    heading.stop();
    await tester.pump();
    expect(cancels, 1);
    heading.dispose();
    await stream.close();
  });

  testWidgets('bearing rotates with the map and falls back to a circle', (
    tester,
  ) async {
    final heading = ValueNotifier<double?>(0.25);
    final map = MapController();
    await tester.pumpWidget(
      MaterialApp(
        home: FlutterMap(
          mapController: map,
          options: const MapOptions(
            initialCenter: LatLng(35, 139),
            initialZoom: 16,
          ),
          children: [
            MarkerLayer(
              markers: [
                Marker(
                  point: const LatLng(35, 139),
                  width: 56,
                  height: 56,
                  rotate: false,
                  child: NavigationLocationPuck(heading: heading),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    final marker = tester
        .widget<MarkerLayer>(find.byType(MarkerLayer))
        .markers
        .single;
    expect(marker.rotate, isFalse);
    expect(
      tester
          .widget<AnimatedRotation>(
            find.byKey(const ValueKey('navigation-heading-sector')),
          )
          .turns,
      0.25,
    );
    map.rotate(90);
    await tester.pumpAndSettle();
    expect(map.camera.rotation, 90);
    expect(
      tester
          .widget<AnimatedRotation>(
            find.byKey(const ValueKey('navigation-heading-sector')),
          )
          .turns,
      0.25,
    );
    heading.value = null;
    await tester.pump();
    expect(
      find.byKey(const ValueKey('navigation-heading-sector')),
      findsNothing,
    );
    await tester.pumpWidget(const SizedBox());
    heading.dispose();
    map.dispose();
  });
}
