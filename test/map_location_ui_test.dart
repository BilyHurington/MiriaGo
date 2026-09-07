import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:miriago/app_theme.dart';
import 'package:miriago/data/sample_pilgrimage_repository.dart';
import 'package:miriago/map/map_location_tracker.dart';
import 'package:miriago/map/pilgrimage_map_screen.dart';
import 'package:miriago/plan/pilgrimage_models.dart';
import 'package:miriago/plan/pilgrimage_plan_controller.dart';
import 'package:miriago/plan/plan_screen.dart';
import 'package:miriago/settings/settings_screen.dart';

Position fix(double latitude) => Position(
  latitude: latitude,
  longitude: 135.8,
  timestamp: DateTime.now(),
  accuracy: 5,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

void main() {
  testWidgets(
    'map display switch persists callback immediately and defaults on',
    (tester) async {
      var settings = const AppSettings();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: SettingsScreen(
            repository: SamplePilgrimageRepository(),
            settings: settings,
            onChanged: (value) => settings = value,
          ),
        ),
      );
      await tester.scrollUntilVisible(find.text('地图显示'), 300);
      final header = find
          .ancestor(of: find.text('地图显示'), matching: find.byType(InkWell))
          .first;
      tester.widget<InkWell>(header).onTap!();
      await tester.pumpAndSettle();
      final toggle = find.byKey(
        const ValueKey('continuous-map-location-switch'),
      );
      expect(tester.widget<SwitchListTile>(toggle).value, isTrue);
      tester.widget<SwitchListTile>(toggle).onChanged!(false);
      await tester.pump();
      expect(settings.continuousMapLocation, isFalse);
      expect(tester.widget<SwitchListTile>(toggle).value, isFalse);
    },
  );

  for (final inline in [false, true]) {
    testWidgets(
      '${inline ? 'plan' : 'main'} map updates position without moving camera',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(430, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final repository = SamplePilgrimageRepository();
        final controller = PilgrimagePlanController(
          plan: (await repository.loadPlans()).first,
        );
        final stream = StreamController<Position>.broadcast();
        final tracker = MapLocationTracker(
          resolve: (_) async => fix(34.88),
          streamFactory: (_) => stream.stream,
        );
        const settings = AppSettings(
          mapTileProvider: MapTileProvider.openStreetMap,
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: inline
                ? PlanScreen(
                    controller: controller,
                    repository: repository,
                    settings: settings,
                    locationTracker: tracker,
                    onOpenMap: () {},
                    onOpenPlanManager: () {},
                    onOpenAddPoints: () {},
                    onOpenPointManager: () {},
                    onOpenImportExport: () {},
                  )
                : PilgrimageMapScreen(
                    controller: controller,
                    settings: settings,
                    locationTracker: tracker,
                  ),
          ),
        );
        if (inline) {
          final button = find
              .ancestor(
                of: find.text('地图'),
                matching: find.byType(OutlinedButton),
              )
              .first;
          tester.widget<OutlinedButton>(button).onPressed!();
          await tester.pump();
        }
        await tracker.locate();
        await tester.pump();
        final map = tester
            .widget<FlutterMap>(find.byType(FlutterMap))
            .mapController!;
        const movedCenter = LatLng(34.884, 135.806);
        map.move(movedCenter, 18);
        stream.add(fix(34.885));
        await tester.pump();
        expect(tracker.position!.latitude, 34.885);
        expect(map.camera.center, movedCenter);
        expect(map.camera.zoom, 18);
        final layers = tester.widgetList<MarkerLayer>(find.byType(MarkerLayer));
        expect(
          layers
              .expand((layer) => layer.markers)
              .any((marker) => marker.point == const LatLng(34.885, 135.8)),
          isTrue,
        );
        await tester.pumpWidget(const SizedBox());
        controller.dispose();
        await stream.close();
      },
    );
  }
}
