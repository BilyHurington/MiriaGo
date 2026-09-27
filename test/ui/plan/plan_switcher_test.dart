import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/data/sample_pilgrimage_repository.dart';

import '../../helpers/pump_app.dart';

Future<(SamplePilgrimageRepository, String)> _twoPlans() async {
  final repository = SamplePilgrimageRepository();
  final other = await repository.createPlan(name: '镰仓之旅', area: '镰仓市');
  await repository.setActivePlan('sample-uji-hibike');
  return (repository, other.id);
}

void main() {
  testWidgets('switching plans from the header chip', (tester) async {
    final (repository, otherId) = await _twoPlans();
    await pumpMiriaApp(
      tester,
      location: '/plan',
      size: TestSizes.phone,
      repository: repository,
    );
    await tester.tap(find.byKey(const ValueKey('plan-switcher-chip')));
    await tester.pumpAndSettle();
    expect(find.text('切换计划'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('plan-switcher-item-sample-uji-hibike')),
      findsOneWidget,
    );
    expect(find.text('暂无作品'), findsOneWidget);
    await tester.tap(find.byKey(ValueKey('plan-switcher-item-$otherId')));
    await tester.pumpAndSettle();
    expect((await repository.loadActivePlan()).id, otherId);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('plan-switcher-chip')),
        matching: find.text('镰仓之旅'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('plan-overview-onboarding')),
      findsOneWidget,
    );
  });

  testWidgets('creating a plan asks for name and area', (tester) async {
    final repository = await pumpMiriaApp(
      tester,
      location: '/plan',
      size: TestSizes.phone,
    );
    await tester.tap(find.byKey(const ValueKey('plan-switcher-chip')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('plan-switcher-create')));
    await tester.pumpAndSettle();
    expect(find.text('新建计划'), findsWidgets);
    final nameField = find.descendant(
      of: find.byKey(const ValueKey('plan-info-name')),
      matching: find.byType(EditableText),
    );
    expect(tester.widget<EditableText>(nameField).controller.text, '新巡礼计划 2');
    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('plan-info-area')),
        matching: find.byType(EditableText),
      ),
      '镰仓市',
    );
    await tester.tap(find.text('创建'));
    await tester.pumpAndSettle();
    final plans = await repository.loadPlans();
    expect(plans, hasLength(2));
    final active = await repository.loadActivePlan();
    expect(active.name, '新巡礼计划 2');
    expect(active.area, '镰仓市');
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('plan-switcher-chip')),
        matching: find.text('新巡礼计划 2'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('shows a search field with more than eight plans', (
    tester,
  ) async {
    final repository = SamplePilgrimageRepository();
    final ids = <String>[];
    for (var i = 0; i < 9; i++) {
      final plan = await repository.createPlan(
        name: '巡礼计划 ${i + 2}',
        area: '京都市',
      );
      ids.add(plan.id);
    }
    await repository.setActivePlan('sample-uji-hibike');
    await pumpMiriaApp(
      tester,
      location: '/plan',
      size: TestSizes.desktop,
      repository: repository,
    );
    await tester.tap(find.byKey(const ValueKey('plan-switcher-sidebar')));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    await tester.enterText(find.byType(TextField), '巡礼计划 10');
    await tester.pumpAndSettle();
    expect(
      find.byKey(ValueKey('plan-switcher-item-${ids[8]}')),
      findsOneWidget,
    );
    expect(find.byKey(ValueKey('plan-switcher-item-${ids[1]}')), findsNothing);
  });

  testWidgets('manage plans opens the plan library', (tester) async {
    await pumpMiriaApp(tester, location: '/plan', size: TestSizes.phone);
    await tester.tap(find.byKey(const ValueKey('plan-switcher-chip')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('plan-switcher-manage')));
    await tester.pumpAndSettle();
    expect(find.text('管理计划'), findsOneWidget);
    expect(find.byKey(const ValueKey('create-plan')), findsOneWidget);
  });
}
