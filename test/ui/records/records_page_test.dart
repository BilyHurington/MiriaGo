import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:miriago/data/sample_pilgrimage_repository.dart';
import 'package:miriago/plan/pilgrimage_models.dart';
import 'package:miriago/ui/components/components.dart';
import 'package:miriago/ui/features/records/record_detail_page.dart';
import 'package:miriago/ui/features/records/records_page.dart';

import '../../helpers/pump_app.dart';

/// Sample data whose active plan can fail to load, and whose record
/// deletion can be held open and leave photos behind.
class _RecordsRepository extends SamplePilgrimageRepository {
  bool failActivePlan = false;
  Completer<void>? deleteGate;

  /// Makes the photo clean-up after a deletion fail (it scans all plans).
  bool failPlanScan = false;

  @override
  Future<PilgrimagePlan> loadActivePlan() {
    if (failActivePlan) throw StateError('disk unavailable');
    return super.loadActivePlan();
  }

  @override
  Future<List<PilgrimagePlan>> loadPlans() {
    if (failPlanScan) throw StateError('scan failed');
    return super.loadPlans();
  }

  @override
  Future<void> deleteVisitRecord({
    required String planId,
    required String recordId,
  }) async {
    await deleteGate?.future;
    return super.deleteVisitRecord(planId: planId, recordId: recordId);
  }
}

const _recordId = 'sample-record-agata-01';

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

  testWidgets('a failed plan load shows an error with retry', (tester) async {
    final repository = _RecordsRepository()..failActivePlan = true;
    await pumpMiriaApp(tester, location: '/records', repository: repository);
    await _settle(tester);
    expect(find.byKey(const ValueKey('records-load-error')), findsOneWidget);
    expect(find.text('计划加载失败'), findsOneWidget);
    expect(find.textContaining('请稍后重试。'), findsOneWidget);
    expect(find.byType(ProgressRing), findsNothing);

    repository.failActivePlan = false;
    await tester.tap(find.text('重试'));
    await _settle(tester);
    expect(find.byKey(const ValueKey('records-load-error')), findsNothing);
    expect(find.byKey(const ValueKey('records-summary')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop: deleting in the detail pane warns and clears it', (
    tester,
  ) async {
    final repository = _RecordsRepository()..deleteGate = Completer<void>();
    await pumpMiriaApp(
      tester,
      location: recordsLocation(_recordId),
      size: TestSizes.desktop,
      repository: repository,
    );
    await _settle(tester);
    expect(find.byType(RecordDetailView), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('record-detail-delete')));
    await _settle(tester);
    await tester.tap(find.text('同时删除照片文件'));
    await tester.pump();
    await tester.tap(find.text('删除').last);
    await _settle(tester);

    // While deleting, browsing to another record is disabled.
    for (final key in ['record-detail-previous', 'record-detail-next']) {
      final button = find.byKey(ValueKey(key));
      if (button.evaluate().isEmpty) continue;
      expect(tester.widget<MiriaIconButton>(button).onPressed, isNull);
    }

    repository.failPlanScan = true;
    repository.deleteGate!.complete();
    await _settle(tester);
    repository.failPlanScan = false;

    expect(find.text('记录已删除，部分照片未清理'), findsOneWidget);
    expect(find.byType(RecordDetailView), findsNothing);
    expect(find.text('选择一条记录'), findsOneWidget);
    final router = GoRouter.of(tester.element(find.byType(RecordsPage)));
    expect(router.state.uri.queryParameters['record'], isNull);
    final plan = await repository.loadActivePlan();
    final records = await repository.loadVisitRecords(plan.id);
    expect(records.any((record) => record.id == _recordId), isFalse);
    await tester.pump(const Duration(seconds: 4));
    expect(tester.takeException(), isNull);
  });
}
