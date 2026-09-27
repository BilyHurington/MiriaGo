import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/data/pilgrimage_repository.dart';
import 'package:miriago/data/sample_pilgrimage_repository.dart';
import 'package:miriago/ui/app/app.dart';

/// Common window sizes from DESIGN §5.8.
abstract final class TestSizes {
  static const phoneSmall = Size(320, 568);
  static const phone = Size(390, 844);
  static const phoneLandscape = Size(844, 390);
  static const tablet = Size(820, 1180);
  static const tabletLandscape = Size(1180, 820);
  static const desktop = Size(1440, 900);
}

/// Boots the full app on sample data at [location] with a given window
/// [size]. Returns the repository so tests can inspect writes.
Future<PilgrimageRepository> pumpMiriaApp(
  WidgetTester tester, {
  String location = '/plan',
  Size size = TestSizes.phone,
  double textScale = 1,
  PilgrimageRepository? repository,
}) async {
  final repo = repository ?? SamplePilgrimageRepository();
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpWidget(
    MiriaGoBootstrap(
      repositoryLoader: () async => repo,
      initialLocation: location,
    ),
  );
  // Let startup (settings, plan, first frame) finish.
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  return repo;
}
