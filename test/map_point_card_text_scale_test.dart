import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:miriago/app_theme.dart';
import 'package:miriago/data/sample_pilgrimage_repository.dart';
import 'package:miriago/map/map_location_tracker.dart';
import 'package:miriago/map/pilgrimage_map_screen.dart';
import 'package:miriago/plan/pilgrimage_models.dart';
import 'package:miriago/plan/pilgrimage_plan_controller.dart';

/// Android 14 style non-linear scaling: small text grows faster than the
/// 18 px reference size.
class _NonLinearScaler extends TextScaler {
  const _NonLinearScaler();

  @override
  double scale(double fontSize) => fontSize * (fontSize < 18 ? 2.6 : 2.0);

  @override
  double get textScaleFactor => 2.0;
}

void main() {
  testWidgets('map point card grows with non-linear large text', (
    tester,
  ) async {
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
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const _NonLinearScaler()),
          child: child!,
        ),
        home: PilgrimageMapScreen(
          controller: controller,
          settings: const AppSettings(
            mapTileProvider: MapTileProvider.openStreetMap,
          ),
          locationTracker: tracker,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    final episode = find.byKey(const ValueKey('map-point-card-episode'));
    expect(episode, findsOneWidget);
    expect(tester.takeException(), isNull);
    final card = find.byKey(const ValueKey('map-point-card-content'));
    expect(
      tester.getBottomLeft(episode).dy,
      lessThanOrEqualTo(tester.getBottomLeft(card).dy),
    );
  });
}
