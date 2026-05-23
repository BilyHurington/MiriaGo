import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:seichi_junrei_helper/main.dart';

void main() {
  testWidgets('shows the pilgrimage plan workflow shell', (tester) async {
    await tester.pumpWidget(const SeichiJunreiHelperApp());
    await tester.pump();

    expect(find.text('计划'), findsWidgets);
    expect(find.text('地图'), findsWidgets);
    expect(find.text('记录'), findsWidgets);
    expect(find.text('吹响吧！上低音号'), findsOneWidget);
    expect(find.text('当前目标 0/3'), findsOneWidget);
    expect(find.text('宇治桥'), findsWidgets);
  });

  testWidgets('opens camera reference from current target', (tester) async {
    await tester.pumpWidget(const SeichiJunreiHelperApp());
    await tester.pump();

    await tester.tap(find.text('拍摄参考'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('宇治桥'), findsWidgets);
    expect(find.text('参考图待接入'), findsOneWidget);
    expect(find.text('Split'), findsOneWidget);
    expect(find.text('Overlay'), findsOneWidget);
  });

  testWidgets('opens shared point detail sheet from plan list', (tester) async {
    await tester.pumpWidget(const SeichiJunreiHelperApp());
    await tester.pump();

    await tester.scrollUntilVisible(
      find.text('あがた通り'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('あがた通り'));
    await tester.pumpAndSettle();

    expect(find.text('待访问'), findsOneWidget);
    expect(find.text('坐标'), findsOneWidget);
    expect(find.text('来源'), findsOneWidget);
    expect(find.text('导航'), findsOneWidget);
    expect(find.text('拍摄参考'), findsWidgets);
    expect(find.text('设为当前'), findsOneWidget);
    expect(find.text('标记完成'), findsWidgets);
  });

  testWidgets('switches plans and shows empty plan add-points shell', (
    tester,
  ) async {
    await tester.pumpWidget(const SeichiJunreiHelperApp());
    await tester.pump();

    await tester.tap(find.byTooltip('切换计划'));
    await tester.pumpAndSettle();

    expect(find.text('切换计划'), findsOneWidget);
    expect(find.textContaining('京都空计划'), findsOneWidget);

    await tester.tap(find.text('切换'));
    await tester.pumpAndSettle();

    expect(find.textContaining('京都空计划'), findsOneWidget);
    expect(find.text('还没有点位'), findsOneWidget);
    expect(find.text('添加第一个点位'), findsOneWidget);

    await tester.tap(find.text('添加第一个点位'));
    await tester.pumpAndSettle();

    expect(find.text('添加点位'), findsOneWidget);
    expect(find.text('从 Anitabi 添加'), findsOneWidget);
    expect(find.text('手动添加点位'), findsOneWidget);
  });

  testWidgets('creates a new plan from the plan manager', (tester) async {
    await tester.pumpWidget(const SeichiJunreiHelperApp());
    await tester.pump();

    await tester.tap(find.byTooltip('切换计划'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('新建计划'));
    await tester.pumpAndSettle();

    expect(find.text('新巡礼计划 3'), findsOneWidget);
    expect(find.textContaining('自定义巡礼'), findsOneWidget);
  });

  testWidgets('adds a manual point to an empty plan', (tester) async {
    await tester.pumpWidget(const SeichiJunreiHelperApp());
    await tester.pump();

    await tester.tap(find.byTooltip('切换计划'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('切换'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('添加第一个点位'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('手动添加点位'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, '点位名称'), '鸭川三条');
    await tester.enterText(find.widgetWithText(TextFormField, '位置说明'), '鸭川沿岸');
    await tester.enterText(
      find.widgetWithText(TextFormField, '集数/场景标签'),
      '自定义场景 1',
    );
    await tester.enterText(find.widgetWithText(TextFormField, '参考来源'), '手动录入');
    await tester.enterText(find.widgetWithText(TextFormField, '纬度'), '35.0089');
    await tester.enterText(
      find.widgetWithText(TextFormField, '经度'),
      '135.7711',
    );
    await tester.ensureVisible(find.text('保存点位'));
    await tester.tap(find.text('保存点位'));
    await tester.pumpAndSettle();

    expect(find.text('当前目标 0/1'), findsOneWidget);
    expect(find.text('鸭川三条'), findsWidgets);
    expect(find.text('鸭川沿岸 / 自定义场景 1'), findsWidgets);
  });
}
