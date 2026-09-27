import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/data/sample_pilgrimage_repository.dart';

import '../../helpers/pump_app.dart';

class _FailingOrderRepository extends SamplePilgrimageRepository {
  @override
  Future<void> reorderPlans({required List<String> orderedPlanIds}) async {
    throw StateError('write failed');
  }
}

Future<String> _addPlan(SamplePilgrimageRepository repository) async {
  final other = await repository.createPlan(name: '镰仓之旅', area: '镰仓市');
  await repository.setActivePlan('sample-uji-hibike');
  return other.id;
}

void main() {
  testWidgets('lists every plan once and marks the current one', (
    tester,
  ) async {
    final repository = SamplePilgrimageRepository();
    final otherId = await _addPlan(repository);
    await pumpMiriaApp(
      tester,
      location: '/plans',
      size: TestSizes.phone,
      repository: repository,
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('plan-card-sample-uji-hibike')),
      findsOneWidget,
    );
    expect(find.byKey(ValueKey('plan-card-$otherId')), findsOneWidget);
    expect(find.byKey(const ValueKey('plan-status-current')), findsOneWidget);
    expect(find.text('宇治市  /  27 个点位  /  1 部作品'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('plan-card-drag-handle-sample-uji-hibike')),
      findsOneWidget,
    );
  });

  testWidgets('delete asks with the old destructive message', (tester) async {
    final repository = SamplePilgrimageRepository();
    final otherId = await _addPlan(repository);
    await pumpMiriaApp(
      tester,
      location: '/plans',
      size: TestSizes.phone,
      repository: repository,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('plan-card-more-$otherId')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除计划'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('将删除「镰仓之旅」及其中的点位、片区、作品和巡礼记录。', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('此操作无法撤销'), findsOneWidget);
    await tester.tap(find.text('删除').last);
    await tester.pumpAndSettle();
    expect(await repository.loadPlans(), hasLength(1));
    expect(find.byKey(ValueKey('plan-card-$otherId')), findsNothing);
  });

  testWidgets('tapping another plan switches to it', (tester) async {
    final repository = SamplePilgrimageRepository();
    final otherId = await _addPlan(repository);
    await pumpMiriaApp(
      tester,
      location: '/plan',
      size: TestSizes.phone,
      repository: repository,
    );
    await tester.tap(find.byKey(const ValueKey('plan-switcher-chip')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('plan-switcher-manage')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('plan-card-title-$otherId')));
    await tester.pumpAndSettle();
    expect((await repository.loadActivePlan()).id, otherId);
    // Back on the overview after switching.
    expect(find.byKey(const ValueKey('create-plan')), findsNothing);
  });

  testWidgets('failed reorder restores the order and says so', (tester) async {
    final repository = _FailingOrderRepository();
    final otherId = await _addPlan(repository);
    await pumpMiriaApp(
      tester,
      location: '/plans',
      size: TestSizes.phone,
      repository: repository,
    );
    await tester.pumpAndSettle();
    final handle = find.byKey(ValueKey('plan-card-drag-handle-$otherId'));
    final gesture = await tester.startGesture(tester.getCenter(handle));
    await tester.pump(const Duration(milliseconds: 50));
    for (var i = 0; i < 12; i++) {
      await gesture.moveBy(const Offset(0, -25));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.text('保存计划顺序失败，已恢复原来的顺序。'), findsOneWidget);
    final first = tester.getTopLeft(
      find.byKey(const ValueKey('plan-card-sample-uji-hibike')),
    );
    final second = tester.getTopLeft(
      find.byKey(ValueKey('plan-card-$otherId')),
    );
    expect(first.dy, lessThan(second.dy));
  });
}
