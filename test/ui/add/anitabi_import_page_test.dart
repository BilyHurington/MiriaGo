import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/ui/app/router.dart';

import 'add_test_helpers.dart';

void main() {
  testWidgets('import all: confirm → points added → organize dialog', (
    tester,
  ) async {
    final repository = await pumpAddApp(tester, location: Routes.anitabiImport);
    final before = (await activePlan(repository)).points.length;
    expect(find.text('吹响吧！上低音号'), findsOneWidget);
    expect(find.text('已导入 0 / 当前显示 3 / 共 0'), findsOneWidget);
    // The first point is pre-selected.
    expect(find.byKey(const ValueKey('anitabi-point-card-a1')), findsOneWidget);
    expect(find.text('加入计划'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('anitabi-import-all')));
    await settle(tester);
    expect(find.text('添加所有点位'), findsWidgets);
    expect(find.textContaining('将把当前作品中 3 个还不在计划里的点位加入计划'), findsOneWidget);
    await tester.tap(find.text('添加全部'));
    await settle(tester, frames: 20);

    expect(find.text('整理刚导入的点位'), findsOneWidget);
    expect(find.text('最近分配'), findsOneWidget);
    expect(find.text('分配到片区'), findsOneWidget);
    await tester.tap(find.text('稍后'));
    await settle(tester);

    final plan = await activePlan(repository);
    expect(plan.points.length, before + 3);
    final imported = plan.points.firstWhere(
      (p) => p.id == 'anitabi-$sampleBangumiId-a1',
    );
    expect(imported.referenceThumbnailPath, '/cache/${imported.id}.jpg');
    expect(find.text('已导入 3 / 当前显示 3 / 共 0'), findsOneWidget);
    expect(find.text('已加入计划'), findsOneWidget);
    expect(find.text('已添加所有未加入的点位。'), findsOneWidget);
  });

  testWidgets('single import needs no confirmation and no organize dialog', (
    tester,
  ) async {
    final repository = await pumpAddApp(tester, location: Routes.anitabiImport);
    await tester.tap(find.byKey(const ValueKey('anitabi-point-import-a1')));
    await settle(tester);
    expect(find.text('整理刚导入的点位'), findsNothing);
    expect(find.text('已加入计划，可继续选择点位。'), findsOneWidget);
    final plan = await activePlan(repository);
    expect(
      plan.points.any((p) => p.id == 'anitabi-$sampleBangumiId-a1'),
      isTrue,
    );
  });

  testWidgets('back is blocked while importing', (tester) async {
    final repository = ScriptedRepository()..addGate = Completer<void>();
    await pumpAddApp(
      tester,
      location: Routes.anitabiImport,
      repository: repository,
    );
    await tester.tap(find.byKey(const ValueKey('anitabi-point-import-a1')));
    await settle(tester, frames: 2);
    final back = tester.widget<PopScope>(find.byType(PopScope).last);
    expect(back.canPop, isFalse);
    expect(find.text('正在导入 1 个点位...'), findsWidgets);
    repository.addGate!.complete();
    await settle(tester);
    expect(tester.widget<PopScope>(find.byType(PopScope).last).canPop, isTrue);
  });

  testWidgets('load errors show the old title, detail and reload', (
    tester,
  ) async {
    await pumpAddApp(
      tester,
      location: Routes.anitabiImport,
      anitabi: FakeAnitabiClient(points: const {}),
    );
    expect(find.text('Anitabi 中没有找到这个作品'), findsOneWidget);
    expect(find.text('清除缓存并重新加载 Anitabi 点位'), findsOneWidget);
  });

  testWidgets('wide layout lists the points in view', (tester) async {
    await pumpAddApp(
      tester,
      location: Routes.anitabiImport,
      size: TestSizes.desktop,
    );
    expect(find.text('视野内的点位'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('anitabi-in-view-import-a2')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('anitabi-in-view-import-a2')));
    await settle(tester);
    expect(
      find.byKey(const ValueKey('anitabi-in-view-import-a2')),
      findsNothing,
    );
  });
}
