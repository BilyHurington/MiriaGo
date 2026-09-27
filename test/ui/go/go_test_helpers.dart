import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/data/pilgrimage_repository.dart';
import 'package:miriago/data/sample_pilgrimage_repository.dart';
import 'package:miriago/map/map_navigation_launcher.dart';
import 'package:miriago/plan/pilgrimage_models.dart';
import 'package:miriago/ui/app/app.dart';
import 'package:miriago/ui/features/points/point_shared.dart';

import '../../helpers/pump_app.dart';

export '../../helpers/pump_app.dart' show TestSizes;

/// Records external navigation requests instead of launching apps.
class FakeNavigationLauncher extends MapNavigationLauncher {
  FakeNavigationLauncher({this.result = true});

  bool result;
  final opened = <(String, NavigationApp)>[];

  @override
  Future<bool> openWalking(PilgrimagePoint point, NavigationApp app) async {
    opened.add((point.id, app));
    return result;
  }
}

/// Like `pumpMiriaApp`, but without map tiles and with fake launchers.
Future<PilgrimageRepository> pumpGoApp(
  WidgetTester tester, {
  String location = '/go',
  Size size = TestSizes.phone,
  double textScale = 1,
  PilgrimageRepository? repository,
  MapNavigationLauncher? launcher,
  ReferenceImagePicker? pickReferenceImage,
}) async {
  final repo = repository ?? SamplePilgrimageRepository();
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpWidget(
    PointFeatureOverrides(
      disableMapTiles: true,
      navigationLauncher: launcher ?? FakeNavigationLauncher(),
      pickReferenceImage: pickReferenceImage ?? () async => null,
      child: MiriaGoBootstrap(
        repositoryLoader: () async => repo,
        initialLocation: location,
      ),
    ),
  );
  await settle(tester);
  return repo;
}

/// Pumps a few frames (the app has endless animations, so no pumpAndSettle).
Future<void> settle(WidgetTester tester, {int frames = 10}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}
