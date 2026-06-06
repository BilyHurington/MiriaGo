import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:miriago/main.dart';
import 'package:miriago/data/sample_pilgrimage_repository.dart';

Future<void> _pumpApp(WidgetTester tester) async {
  await tester.pumpWidget(MiriaGoApp(repository: SamplePilgrimageRepository()));
  await tester.pumpAndSettle();
}

Future<void> _pumpAppWithEmptyPlan(WidgetTester tester) async {
  final repository = SamplePilgrimageRepository();
  await repository.createPlan(name: '新巡礼计划 2', area: '未设置区域');
  await tester.pumpWidget(MiriaGoApp(repository: repository));
  await tester.pumpAndSettle();
}

Future<void> _openPlanMenu(WidgetTester tester) async {
  await tester.tap(find.byTooltip('计划操作').first);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the pilgrimage plan workflow shell', (tester) async {
    await _pumpApp(tester);

    expect(find.text('计划'), findsWidgets);
    expect(find.text('地图'), findsWidgets);
    expect(find.text('记录'), findsWidgets);
    expect(find.text('示例计划'), findsWidgets);
    expect(find.text('宇治站附近'), findsWidgets);
    expect(find.text('默认计划'), findsOneWidget);
    expect(find.text('井用机前步行道'), findsWidgets);
    expect(find.textContaining('1 部作品'), findsOneWidget);
  });

  testWidgets('opens camera reference from current target', (tester) async {
    await _pumpApp(tester);

    await tester.tap(find.byIcon(Icons.photo_camera_outlined).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('叠影'), findsWidgets);
    expect(find.text('上下'), findsWidgets);
    expect(find.text('小窗'), findsNothing);
  });

  testWidgets('opens shared point detail sheet from plan list', (tester) async {
    await _pumpApp(tester);

    await tester.tap(find.text('井用机前步行道').first);
    await tester.pumpAndSettle();

    expect(find.text('当前目标'), findsWidgets);
    expect(find.text('坐标'), findsOneWidget);
    expect(find.text('来源'), findsOneWidget);
    expect(find.text('导航'), findsOneWidget);
    expect(find.text('拍摄参考'), findsWidgets);
    expect(find.text('标记完成'), findsWidgets);
  });

  testWidgets('shows group filters on the map', (tester) async {
    await _pumpApp(tester);

    await tester.tap(find.byIcon(Icons.map_outlined).last);
    await tester.pumpAndSettle();

    expect(find.textContaining('宇治站附近'), findsWidgets);
    expect(find.byTooltip('当前目标'), findsOneWidget);
    expect(find.text('井用机前步行道'), findsWidgets);
  });

  testWidgets('shows plan manager', (tester) async {
    await _pumpApp(tester);

    await _openPlanMenu(tester);
    await tester.tap(find.text('管理计划'));
    await tester.pumpAndSettle();

    expect(find.text('管理计划'), findsOneWidget);
    expect(find.textContaining('关键点'), findsWidgets);
    expect(find.text('无序'), findsWidgets);
    expect(find.text('井用机前步行道'), findsOneWidget);
  });

  testWidgets('creates empty plan and shows add-points shell', (tester) async {
    await _pumpAppWithEmptyPlan(tester);

    expect(find.textContaining('新巡礼计划 2'), findsWidgets);
    expect(find.text('还没有点位'), findsOneWidget);
    expect(find.text('添加点位'), findsOneWidget);

    await tester.tap(find.text('添加点位'));
    await tester.pumpAndSettle();

    expect(find.text('添加内容'), findsOneWidget);
    expect(find.text('作品管理'), findsOneWidget);
    expect(find.text('手动添加点位'), findsOneWidget);
  });

  testWidgets('creates a new plan from the plan manager', (tester) async {
    await _pumpApp(tester);

    await _openPlanMenu(tester);
    await tester.tap(find.text('切换计划'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '新建计划'));
    await tester.pumpAndSettle();

    expect(find.text('新巡礼计划 2'), findsOneWidget);
    expect(find.textContaining('未设置区域'), findsOneWidget);
  });

  testWidgets('adds a manual work to an empty plan', (tester) async {
    await _pumpAppWithEmptyPlan(tester);

    await tester.tap(find.text('添加点位'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('作品管理'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('手动添加'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, '作品名称'), '原创短片');
    await tester.enterText(
      find.widgetWithText(TextFormField, '作品原名'),
      'Original',
    );
    await tester.enterText(find.widgetWithText(TextFormField, '主要地区'), '京都市');
    await tester.tap(find.text('保存作品'));
    await tester.pumpAndSettle();

    expect(find.text('原创短片'), findsOneWidget);
    expect(find.textContaining('0 个点位'), findsOneWidget);
  });

  testWidgets('adds a manual point to an empty plan', (tester) async {
    await _pumpAppWithEmptyPlan(tester);

    await tester.tap(find.text('添加点位'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('手动添加点位'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, '动画/作品名称'),
      '轻音少女',
    );
    await tester.enterText(find.widgetWithText(TextFormField, '点位名称'), '鸭川三条');
    await tester.enterText(find.widgetWithText(TextFormField, '位置说明'), '鸭川沿岸');
    await tester.enterText(
      find.widgetWithText(TextFormField, '集数/场景标签'),
      '自定义场景 1',
    );
    await tester.enterText(find.widgetWithText(TextFormField, '参考来源'), '手动录入');
    await tester.scrollUntilVisible(
      find.widgetWithText(TextFormField, '纬度'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(find.widgetWithText(TextFormField, '纬度'), '35.0089');
    await tester.enterText(
      find.widgetWithText(TextFormField, '经度'),
      '135.7711',
    );
    await tester.ensureVisible(find.text('保存点位'));
    await tester.tap(find.text('保存点位'));
    await tester.pumpAndSettle();

    expect(find.text('未分组'), findsWidgets);
    expect(find.text('鸭川三条'), findsWidgets);
    expect(find.text('轻音少女 / 鸭川沿岸 / 自定义场景 1'), findsWidgets);
  });
}
