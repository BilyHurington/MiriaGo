import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/application/add/add_dependencies.dart';
import 'package:miriago/application/add/point_edit_service.dart';
import 'package:miriago/data/pilgrimage_repository.dart';
import 'package:miriago/plan/pilgrimage_models.dart';

import '../../application/add/fakes.dart';
import '../../helpers/pump_app.dart';

export '../../application/add/fakes.dart';
export '../../helpers/pump_app.dart';

/// Boots the app at [location] with fake Anitabi / Bangumi clients, no map
/// tiles and an in-memory reference image store.
Future<ScriptedRepository> pumpAddApp(
  WidgetTester tester, {
  required String location,
  Size size = TestSizes.phone,
  double textScale = 1,
  ScriptedRepository? repository,
  FakeAnitabiClient? anitabi,
  FakeBangumiClient? bangumi,
  FakeImageStore? images,
}) async {
  final repo = repository ?? ScriptedRepository();
  final anitabiClient = anitabi ?? FakeAnitabiClient();
  final bangumiClient = bangumi ?? FakeBangumiClient();
  AddDependencies.overrideForTesting(
    anitabi: (_) => anitabiClient,
    bangumi: () => bangumiClient,
    disableTiles: true,
    cacheThumbnail: (point, _) async => '/cache/${point.id}.jpg',
  );
  ReferenceImageStore.debugOverride = (images ?? FakeImageStore()).store;
  addTearDown(() {
    AddDependencies.resetForTesting();
    ReferenceImageStore.debugOverride = null;
  });
  await pumpMiriaApp(
    tester,
    location: location,
    size: size,
    textScale: textScale,
    repository: repo,
  );
  await settle(tester);
  return repo;
}

/// Pumps a fixed number of frames (pumpAndSettle can spin on indeterminate
/// progress indicators).
Future<void> settle(WidgetTester tester, {int frames = 12}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// A plan without works (for the inline-work and Δ2 paths).
PilgrimagePlan emptyPlan() => PilgrimagePlan(
  id: 'empty-plan',
  name: '空计划',
  area: '京都市',
  works: const [],
  points: const [],
  createdAt: DateTime(2026, 5, 1),
  updatedAt: DateTime(2026, 5, 1),
);

ScriptedRepository emptyPlanRepository() =>
    ScriptedRepository(plans: [emptyPlan()], activePlanId: 'empty-plan');

Future<PilgrimagePlan> activePlan(PilgrimageRepository repository) =>
    repository.loadActivePlan();
