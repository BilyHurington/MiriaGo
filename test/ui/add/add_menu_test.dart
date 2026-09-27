import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/ui/app/shell.dart';
import 'package:miriago/ui/features/add/add_menu.dart';
import 'package:miriago/ui/features/add/anitabi_import_page.dart';
import 'package:miriago/ui/features/add/bangumi_search_page.dart';
import 'package:miriago/ui/features/add/link_import_page.dart';
import 'package:miriago/ui/features/add/manual_work_page.dart';
import 'package:miriago/ui/features/add/point_form_page.dart';

import 'add_test_helpers.dart';

Future<void> openMenu(
  WidgetTester tester, {
  AddMenuSection section = AddMenuSection.all,
}) async {
  final context = tester.element(find.byType(AppShell));
  // ignore: unawaited_futures
  showAddMenu(context, section: section);
  await settle(tester);
}

void main() {
  testWidgets('menu lists point and work entries with descriptions', (
    tester,
  ) async {
    await pumpAddApp(tester, location: '/plan');
    await openMenu(tester);
    expect(find.text('添加到「示例计划」'), findsOneWidget);
    expect(find.text('点位'), findsWidgets);
    expect(find.text('作品'), findsWidgets);
    for (final text in [
      '从 Anitabi 作品地图导入',
      '在地图上挑选点位（推荐）',
      '推荐',
      '粘贴 Anitabi 链接',
      '同时导入作品和点位',
      '手动添加点位',
      '不在 Anitabi 上的地点',
      '搜索 Bangumi',
      '自动获取作品信息',
      '手动添加作品',
      '未收录的作品',
    ]) {
      expect(find.text(text), findsOneWidget, reason: text);
    }
  });

  testWidgets('sections can be limited', (tester) async {
    await pumpAddApp(tester, location: '/plan');
    await openMenu(tester, section: AddMenuSection.works);
    expect(find.text('搜索 Bangumi'), findsOneWidget);
    expect(find.text('手动添加点位'), findsNothing);
  });

  testWidgets('Anitabi import opens the map when a Bangumi work exists', (
    tester,
  ) async {
    await pumpAddApp(tester, location: '/plan');
    await openMenu(tester);
    await tester.tap(find.text('从 Anitabi 作品地图导入'));
    await settle(tester);
    final page = tester.widget<AnitabiImportPage>(
      find.byType(AnitabiImportPage),
    );
    expect(page.bangumiId, isNull);
  });

  testWidgets('Δ2: without a Bangumi work, search first then continue', (
    tester,
  ) async {
    await pumpAddApp(
      tester,
      location: '/plan',
      repository: emptyPlanRepository(),
      bangumi: FakeBangumiClient(results: [bangumiResult]),
      anitabi: FakeAnitabiClient(
        points: {
          1424: [anitabiPoint('k1', bangumiId: 1424)],
        },
      ),
    );
    await openMenu(tester);
    expect(find.text('添加到「空计划」'), findsOneWidget);
    await tester.tap(find.text('从 Anitabi 作品地图导入'));
    await settle(tester);
    final search = tester.widget<BangumiSearchPage>(
      find.byType(BangumiSearchPage),
    );
    expect(search.continueToImport, isTrue);

    await tester.enterText(find.byType(EditableText).first, '轻音');
    await tester.tap(find.text('搜索作品'));
    await settle(tester);
    await tester.tap(find.text('加入'));
    await settle(tester, frames: 20);
    final import = tester.widget<AnitabiImportPage>(
      find.byType(AnitabiImportPage),
    );
    expect(import.bangumiId, 1424);
    expect(find.byType(BangumiSearchPage), findsNothing);
  });

  testWidgets('other entries open their pages', (tester) async {
    await pumpAddApp(tester, location: '/plan');
    final entries = <String, Type>{
      '粘贴 Anitabi 链接': LinkImportPage,
      '手动添加点位': PointFormPage,
      '搜索 Bangumi': BangumiSearchPage,
      '手动添加作品': ManualWorkPage,
    };
    for (final entry in entries.entries) {
      await openMenu(tester);
      await tester.tap(find.text(entry.key));
      await settle(tester);
      expect(find.byType(entry.value), findsOneWidget, reason: entry.key);
      GoRouter.of(tester.element(find.byType(entry.value))).go('/plan');
      await settle(tester);
    }
  });
}
