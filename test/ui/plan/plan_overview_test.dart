import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/data/sample_pilgrimage_repository.dart';

import '../../helpers/pump_app.dart';

void main() {
  for (final (name, size) in [
    ('phone', TestSizes.phone),
    ('tablet', TestSizes.tablet),
    ('desktop', TestSizes.desktop),
  ]) {
    testWidgets('overview renders stats and readiness on $name', (
      tester,
    ) async {
      await pumpMiriaApp(tester, location: '/plan', size: size);
      expect(find.byKey(const ValueKey('plan-switcher-chip')), findsOneWidget);
      expect(find.byKey(const ValueKey('plan-overview-stats')), findsOneWidget);
      expect(find.text('7 片区 · 27 点位 · 1 部作品 · 15 条记录'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('plan-overview-readiness')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('plan-readiness-ungrouped')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('plan-readiness-cache')),
        findsOneWidget,
      );
      expect(find.text('建议出发前导出一份备份'), findsOneWidget);
      expect(find.byKey(const ValueKey('plan-content-memo')), findsOneWidget);
    });
  }

  testWidgets('desktop shows the plan secondary navigation', (tester) async {
    await pumpMiriaApp(tester, location: '/plan', size: TestSizes.desktop);
    expect(find.text('概览'), findsOneWidget);
    expect(find.text('导入导出'), findsWidgets);
    await tester.tap(find.text('作品').first);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('works-summary')), findsOneWidget);
  });

  testWidgets('phone has no secondary navigation', (tester) async {
    await pumpMiriaApp(tester, location: '/plan', size: TestSizes.phone);
    expect(find.text('概览'), findsNothing);
  });

  testWidgets('cache item asks for confirmation first', (tester) async {
    await pumpMiriaApp(tester, location: '/plan', size: TestSizes.phone);
    await tester.tap(find.text('缓存'));
    await tester.pumpAndSettle();
    expect(find.text('缓存完整参考图'), findsOneWidget);
    expect(find.text('开始缓存'), findsOneWidget);
    expect(find.text('建议在 Wi-Fi 环境下进行缓存'), findsOneWidget);
    expect(
      find.textContaining('完整参考图，可能需要较长时间和网络流量。', findRichText: true),
      findsOneWidget,
    );
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.text('开始缓存'), findsNothing);
  });

  testWidgets('more menu lists the plan actions', (tester) async {
    await pumpMiriaApp(tester, location: '/plan', size: TestSizes.phone);
    await tester.tap(find.byKey(const ValueKey('plan-overview-more')));
    await tester.pumpAndSettle();
    for (final label in ['编辑计划信息', '复制计划', '导入导出', '删除计划']) {
      expect(find.text(label), findsWidgets);
    }
    expect(find.text('至少需要保留一个计划'), findsOneWidget);
  });

  testWidgets('edit plan info from the more menu', (tester) async {
    final repository = await pumpMiriaApp(
      tester,
      location: '/plan',
      size: TestSizes.phone,
    );
    await tester.tap(find.byKey(const ValueKey('plan-overview-more')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('编辑计划信息'));
    await tester.pumpAndSettle();
    expect(find.text('计划名称'), findsOneWidget);
    expect(find.text('地区 / 区域'), findsOneWidget);
    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('plan-info-name')),
        matching: find.byType(EditableText),
      ),
      '京都之旅',
    );
    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('plan-info-area')),
        matching: find.byType(EditableText),
      ),
      '',
    );
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    final plan = await repository.loadActivePlan();
    expect(plan.name, '京都之旅');
    expect(plan.area, '未设置区域');
    expect(find.text('京都之旅'), findsWidgets);
  });

  testWidgets('empty plan shows the three-step onboarding', (tester) async {
    final repository = SamplePilgrimageRepository();
    await repository.createPlan(name: '新巡礼计划 2', area: '未设置区域');
    await pumpMiriaApp(
      tester,
      location: '/plan',
      size: TestSizes.phone,
      repository: repository,
    );
    expect(
      find.byKey(const ValueKey('plan-overview-onboarding')),
      findsOneWidget,
    );
    expect(find.text('还没有点位'), findsOneWidget);
    for (final step in ['加作品', '选点位', '划片区']) {
      expect(find.text(step), findsOneWidget);
    }
    expect(find.text('从 Anitabi 导入点位'), findsOneWidget);
    expect(find.byKey(const ValueKey('plan-overview-stats')), findsNothing);
  });
}
