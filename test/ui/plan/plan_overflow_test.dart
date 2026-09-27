import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/data/sample_pilgrimage_repository.dart';

import '../../helpers/pump_app.dart';

void main() {
  for (final location in ['/plan', '/plan/works', '/plan/memo', '/plans']) {
    testWidgets('no overflow on a small phone at 2x text: $location', (
      tester,
    ) async {
      final repository = SamplePilgrimageRepository();
      await repository.createPlan(name: '镰仓之旅 · 一个非常长的计划名称', area: '镰仓市');
      await repository.setActivePlan('sample-uji-hibike');
      await pumpMiriaApp(
        tester,
        location: location,
        size: TestSizes.phoneSmall,
        textScale: 2,
        repository: repository,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('empty plan onboarding fits a small phone at 2x text', (
    tester,
  ) async {
    final repository = SamplePilgrimageRepository();
    await repository.createPlan(name: '新巡礼计划 2', area: '未设置区域');
    await pumpMiriaApp(
      tester,
      location: '/plan',
      size: TestSizes.phoneSmall,
      textScale: 2,
      repository: repository,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('switcher and memo editor fit a small phone at 2x text', (
    tester,
  ) async {
    await pumpMiriaApp(
      tester,
      location: '/plan/memo',
      size: TestSizes.phoneSmall,
      textScale: 2,
    );
    await tester.tap(find.byKey(const ValueKey('memo-start')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('plan-switcher-chip')));
    await tester.pumpAndSettle();
    expect(find.text('切换计划'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
