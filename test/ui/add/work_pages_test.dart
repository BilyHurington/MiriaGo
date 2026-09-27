import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/plan/pilgrimage_models.dart';
import 'package:miriago/ui/features/add/anitabi_import_page.dart';

import 'add_test_helpers.dart';

void main() {
  group('Bangumi search', () {
    testWidgets('type filter keeps one type and collapses on search', (
      tester,
    ) async {
      final bangumi = FakeBangumiClient(results: [bangumiResult]);
      await pumpAddApp(
        tester,
        location: '/plan/works/bangumi',
        bangumi: bangumi,
      );
      expect(find.text('搜索说明'), findsOneWidget);
      expect(find.text('Bangumi需要国际网络环境才能正常搜索。'), findsOneWidget);
      expect(find.text('已选 2 项'), findsOneWidget);
      await tester.tap(find.text('动画'));
      await settle(tester);
      expect(find.text('已选 1 项'), findsOneWidget);
      await tester.tap(find.text('游戏'));
      await settle(tester);
      expect(find.text('已选 1 项'), findsOneWidget, reason: 'min one type');

      await tester.enterText(find.byType(EditableText).first, '轻音');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await settle(tester);
      expect(bangumi.requestedTypes.single, {BangumiSubjectType.game});
      expect(find.text('书籍'), findsNothing, reason: 'filter collapsed');
      expect(find.text('轻音少女'), findsOneWidget);
      expect(find.text('けいおん！'), findsOneWidget);
      expect(find.text('搜索说明'), findsNothing);

      await tester.tap(find.text('加入'));
      await settle(tester);
      expect(find.text('已添加'), findsOneWidget);
      expect(find.text('已添加「轻音少女」。'), findsOneWidget);
      expect(find.byType(AnitabiImportPage), findsNothing);
    });

    testWidgets('search failure shows the error card', (tester) async {
      await pumpAddApp(
        tester,
        location: '/plan/works/bangumi',
        bangumi: FakeBangumiClient(error: Exception('offline')),
      );
      await tester.enterText(find.byType(EditableText).first, 'x');
      await tester.tap(find.text('搜索作品'));
      await settle(tester);
      expect(find.text('Bangumi 搜索失败，请检查网络后重试。'), findsOneWidget);
    });

    testWidgets('works already in the plan show 已添加', (tester) async {
      const existing = PilgrimageWork(
        id: 'hibike-euphonium',
        bangumiId: 115908,
        title: '吹响吧！上低音号',
        subtitle: '響け！ユーフォニアム',
        city: '宇治市',
        source: WorkSource.bangumi,
      );
      await pumpAddApp(
        tester,
        location: '/plan/works/bangumi',
        bangumi: FakeBangumiClient(results: [existing]),
      );
      await tester.enterText(find.byType(EditableText).first, '上低音号');
      await tester.tap(find.text('搜索作品'));
      await settle(tester);
      expect(find.text('已添加'), findsOneWidget);
      expect(find.text('加入'), findsNothing);
    });
  });

  group('Manual work', () {
    testWidgets('validates, saves, clears and stays on the page', (
      tester,
    ) async {
      final repository = await pumpAddApp(tester, location: '/plan/works/new');
      await tester.tap(find.text('保存作品'));
      await settle(tester);
      expect(find.text('请填写此项'), findsOneWidget);

      await tester.enterText(
        find.descendant(
          of: find.byKey(const ValueKey('manual-work-title')),
          matching: find.byType(EditableText),
        ),
        '轻音少女',
      );
      await tester.tap(find.text('保存作品'));
      await settle(tester);
      expect(find.text('已添加「轻音少女」。'), findsOneWidget);
      expect(find.text('手动添加作品'), findsWidgets);
      final title = tester.widget<EditableText>(
        find.descendant(
          of: find.byKey(const ValueKey('manual-work-title')),
          matching: find.byType(EditableText),
        ),
      );
      expect(title.controller.text, isEmpty);
      final plan = await activePlan(repository);
      final work = plan.works.firstWhere((w) => w.title == '轻音少女');
      expect(work.id, startsWith('manual-work-'));
      expect(work.subtitle, '暂无作品原名');
      expect(work.city, plan.area);
      expect(work.bangumiSubjectType, BangumiSubjectType.anime);
    });

    testWidgets('guide is an in-form collapsible explanation', (tester) async {
      await pumpAddApp(tester, location: '/plan/works/new');
      expect(find.text('作品填写指南'), findsOneWidget);
      expect(find.text('填写作品本身的信息，点位名称、场景说明和具体地址请在添加点位时录入。'), findsNothing);
      await tester.ensureVisible(find.text('作品填写指南'));
      await tester.pump();
      await tester.tap(find.text('作品填写指南'));
      await settle(tester);
      expect(find.text('填写作品本身的信息，点位名称、场景说明和具体地址请在添加点位时录入。'), findsOneWidget);
    });
  });

  group('Link import', () {
    testWidgets('validates links and opens the import map', (tester) async {
      await pumpAddApp(
        tester,
        location: '/plan/import/link',
        anitabi: FakeAnitabiClient(
          points: {
            115908: [anitabiPoint('pa1'), anitabiPoint('pa2', lat: 34.9)],
          },
        ),
      );
      expect(find.text('有效链接示例'), findsOneWidget);
      expect(find.text('bangumiId=186515'), findsOneWidget);
      expect(find.text('pid=95ff4037'), findsOneWidget);
      expect(find.byTooltip('粘贴'), findsOneWidget);

      await tester.tap(find.text('打开 Anitabi 点位'));
      await settle(tester);
      expect(find.text('请输入 Anitabi 链接'), findsOneWidget);

      final field = find.byType(EditableText).first;
      await tester.enterText(field, 'hello');
      await tester.tap(find.text('打开 Anitabi 点位'));
      await settle(tester);
      expect(find.text('请输入有效的 Anitabi 地图链接'), findsOneWidget);
      expect(find.byTooltip('清除搜索框'), findsOneWidget);

      await tester.enterText(field, 'https://anitabi.cn/map?pid=abc');
      await tester.tap(find.text('打开 Anitabi 点位'));
      await settle(tester);
      expect(find.text('链接缺少作品 ID，请先在 Anitabi 进入对应作品后复制链接'), findsOneWidget);

      await tester.enterText(
        field,
        'https://anitabi.cn/map?bangumiId=115908&pid=pa2',
      );
      await tester.tap(find.text('打开 Anitabi 点位'));
      await settle(tester, frames: 20);
      final page = tester.widget<AnitabiImportPage>(
        find.byType(AnitabiImportPage),
      );
      expect(page.bangumiId, 115908);
      expect(page.pointId, 'pa2');
      expect(
        find.byKey(const ValueKey('anitabi-point-card-pa2')),
        findsOneWidget,
      );
    });
  });
}
