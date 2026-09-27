import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/data/sample_pilgrimage_repository.dart';
import 'package:miriago/ui/features/records/record_detail_page.dart';

import '../../helpers/pump_app.dart';

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('phone: summary, filters and group sections', (tester) async {
    await pumpMiriaApp(tester, location: '/records', size: TestSizes.phone);
    await _settle(tester);
    expect(find.text('条巡礼记录'), findsOneWidget);
    expect(find.text('已完成'), findsWidgets);
    expect(find.byKey(const ValueKey('records-completion-progress')), findsOne);
    expect(find.byKey(const ValueKey('records-status-filter')), findsOneWidget);
    expect(find.byKey(const ValueKey('records-work-filter')), findsOneWidget);
    expect(find.byKey(const ValueKey('records-group-filter')), findsOneWidget);
    expect(find.text('搜索点位、作品、场景'), findsOneWidget);
    expect(find.byType(RecordDetailView), findsNothing);
    // Sections are grouped; the first one is visible with its cards.
    expect(
      find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey &&
            '${(w.key! as ValueKey).value}'.startsWith('records-group-'),
      ),
      findsWidgets,
    );
    expect(
      find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey &&
            '${(w.key! as ValueKey).value}'.startsWith('record-card-'),
      ),
      findsWidgets,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('search without results shows the empty state and clears', (
    tester,
  ) async {
    await pumpMiriaApp(tester, location: '/records', size: TestSizes.phone);
    await _settle(tester);
    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('records-search')),
        matching: find.byType(EditableText),
      ),
      'zzzz-no-match',
    );
    await _settle(tester);
    expect(find.text('没有找到相关记录'), findsOneWidget);
    expect(
      find.text('没有与当前关键词匹配的点位、作品或场景。试试更换关键词，或清除搜索查看全部记录。'),
      findsOneWidget,
    );
    await tester.tap(find.text('清除搜索'));
    await _settle(tester);
    expect(find.text('没有找到相关记录'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty plan shows 还没有巡礼记录', (tester) async {
    await pumpMiriaApp(
      tester,
      location: '/records',
      repository: SamplePilgrimageRepository(visitRecords: []),
    );
    await _settle(tester);
    expect(find.text('还没有巡礼记录'), findsOneWidget);
    expect(find.text('完成一次点位拍摄后，记录会自动汇总到这里。'), findsOneWidget);
  });

  testWidgets('status filter narrows to completed records', (tester) async {
    await pumpMiriaApp(tester, location: '/records', size: TestSizes.desktop);
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('records-status-filter')));
    await _settle(tester);
    await tester.tap(find.text('已完成').last);
    await _settle(tester);
    expect(find.byKey(const ValueKey('records-reset-filters')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('records-reset-filters')));
    await _settle(tester);
    expect(find.byKey(const ValueKey('records-reset-filters')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop: selecting a record shows the detail pane', (
    tester,
  ) async {
    await pumpMiriaApp(tester, location: '/records', size: TestSizes.desktop);
    await _settle(tester);
    expect(find.text('选择一条记录'), findsOneWidget);
    await tester.tap(
      find
          .byWidgetPredicate(
            (w) =>
                w.key is ValueKey &&
                '${(w.key! as ValueKey).value}'.startsWith('record-card-'),
          )
          .first,
    );
    await _settle(tester);
    expect(find.byType(RecordDetailView), findsOneWidget);
    expect(find.text('记录详情'), findsOneWidget);
    expect(find.text('自动调色'), findsOneWidget);
    expect(find.text('选择一条记录'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('grid/list toggle and collapse all', (tester) async {
    await pumpMiriaApp(tester, location: '/records', size: TestSizes.tablet);
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('records-view-toggle')));
    await _settle(tester);
    await tester.tap(find.byTooltip('收起全部片区'));
    await _settle(tester);
    expect(find.byTooltip('展开全部片区'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey &&
            '${(w.key! as ValueKey).value}'.startsWith('record-card-'),
      ),
      findsNothing,
    );
    await tester.tap(find.byKey(const ValueKey('records-view-toggle')));
    await _settle(tester);
    expect(tester.takeException(), isNull);
  });

  for (final size in [TestSizes.phoneSmall, TestSizes.phoneLandscape]) {
    testWidgets('no overflow at $size with text scale 2.0', (tester) async {
      await pumpMiriaApp(
        tester,
        location: '/records',
        size: size,
        textScale: 2.0,
      );
      await _settle(tester);
      expect(tester.takeException(), isNull);
      await tester.drag(
        find.byType(CustomScrollView).first,
        const Offset(0, -600),
      );
      await _settle(tester);
      expect(tester.takeException(), isNull);
    });
  }
}
