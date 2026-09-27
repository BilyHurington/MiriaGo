import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:miriago/map/map_location_tracker.dart';
import 'package:miriago/ui/map/map.dart';

import 'map_test_harness.dart';

Position _position(double lat, double lng) => Position(
  latitude: lat,
  longitude: lng,
  timestamp: DateTime(2026),
  accuracy: 12,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

void main() {
  testWidgets('binding activates tracking only while visible', (tester) async {
    final stores = await MapTestStores.load();
    final stream = StreamController<Position>.broadcast();
    addTearDown(stream.close);
    var listens = 0;
    final controller = MapLocationController(
      tracker: MapLocationTracker(
        resolve: (_) async => _position(34.89, 135.80),
        streamFactory: (_) {
          listens++;
          return stream.stream;
        },
      ),
    );
    addTearDown(controller.dispose);

    Widget build({required bool enabled}) => mapTestApp(
      stores: stores,
      child: MapLocationBinding(
        controller: controller,
        enabled: enabled,
        child: const SizedBox.expand(),
      ),
    );

    await tester.pumpWidget(build(enabled: true));
    await tester.pump();
    expect(controller.isActive, isTrue);

    final located = await controller.locate();
    await tester.pump();
    expect(located!.latitude, 34.89);
    expect(controller.accuracyMeters, 12);
    expect(controller.isStale, isFalse);
    // Continuous mode (default setting) follows after the first fix.
    expect(listens, 1);

    stream.addError(const LocationServiceDisabledException());
    await tester.pump();
    expect(controller.error, '定位服务未开启，请开启后重试。');
    expect(controller.isStale, isTrue);

    await tester.pumpWidget(build(enabled: false));
    await tester.pump();
    expect(controller.isActive, isFalse);
  });

  testWidgets('location puck layer draws the position', (tester) async {
    final stores = await MapTestStores.load();
    final controller = MapLocationController(
      tracker: MapLocationTracker(
        resolve: (_) async => _position(34.89, 135.80),
        streamFactory: (_) => const Stream.empty(),
      ),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      mapTestApp(
        stores: stores,
        child: PlanMap(
          disableTiles: true,
          initialCenter: const LatLng(34.89, 135.80),
          children: [LocationPuckLayer(controller: controller)],
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(LocationPuck), findsNothing);
    await controller.locate();
    await tester.pump();
    expect(find.byType(LocationPuck), findsOneWidget);
  });
}
