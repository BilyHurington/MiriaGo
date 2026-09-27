import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

void main() {
  testWidgets('empty memo shows suggestions and starts editing', (
    tester,
  ) async {
    await pumpMiriaApp(tester, location: '/plan/memo', size: TestSizes.phone);
    expect(find.text('还没有计划备忘'), findsOneWidget);
    expect(find.text('可记录内容'), findsOneWidget);
    for (final item in ['交通安排', '酒店预约', '活动门票', '拍摄计划', '注意事项']) {
      expect(find.text(item), findsOneWidget);
    }
    await tester.tap(find.byKey(const ValueKey('memo-start')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('plan-memo-editor')), findsOneWidget);
    for (final tool in ['标题', '加粗', '列表', '待办', '引用', '分割线', '链接', '代码']) {
      expect(find.byTooltip(tool), findsOneWidget);
    }
  });

  testWidgets('edit, save, then toggle a task in the reader', (tester) async {
    final repository = await pumpMiriaApp(
      tester,
      location: '/plan/memo',
      size: TestSizes.phone,
    );
    await tester.tap(find.byKey(const ValueKey('memo-start')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('plan-memo-editor')),
      '## 行程\n- [ ] 买票',
    );
    await tester.tap(find.byKey(const ValueKey('memo-tool-bold')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('memo-save')));
    await tester.pumpAndSettle();
    expect(find.text('计划备忘录已保存'), findsOneWidget);
    expect((await repository.loadActivePlan()).memo, '## 行程\n- [ ] 买票**加粗文字**');
    expect(find.byKey(const ValueKey('memo-reader')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('memo-task-0')));
    await tester.pumpAndSettle();
    expect((await repository.loadActivePlan()).memo, '## 行程\n- [x] 买票**加粗文字**');
  });

  testWidgets('leaving with unsaved changes asks first', (tester) async {
    final repository = await pumpMiriaApp(
      tester,
      location: '/plan/memo',
      size: TestSizes.phone,
    );
    await tester.tap(find.byKey(const ValueKey('memo-start')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('plan-memo-editor')),
      '草稿',
    );
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('放弃未保存内容？'), findsOneWidget);
    await tester.tap(find.text('继续编辑'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('plan-memo-editor')), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('放弃'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('plan-memo-editor')), findsNothing);
    expect(find.byKey(const ValueKey('plan-overview-stats')), findsOneWidget);
    expect((await repository.loadActivePlan()).memo, '');
  });

  testWidgets('desktop editor shows a live preview', (tester) async {
    await pumpMiriaApp(tester, location: '/plan/memo', size: TestSizes.desktop);
    await tester.tap(find.byKey(const ValueKey('memo-start')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('plan-memo-editor')),
      '# 标题\n![图](x.png)',
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('memo-live-preview')), findsOneWidget);
    expect(find.text('备忘录不支持图片：图'), findsOneWidget);
  });

  testWidgets('secondary navigation asks before leaving a draft', (
    tester,
  ) async {
    await pumpMiriaApp(tester, location: '/plan/memo', size: TestSizes.desktop);
    await tester.tap(find.byKey(const ValueKey('memo-start')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('plan-memo-editor')),
      '草稿',
    );
    await tester.pump();
    await tester.tap(find.text('概览'));
    await tester.pumpAndSettle();
    expect(find.text('放弃未保存内容？'), findsOneWidget);
    await tester.tap(find.text('放弃'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('plan-overview-stats')), findsOneWidget);
  });
}
