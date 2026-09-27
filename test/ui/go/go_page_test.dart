import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:miriago/application/go/go_queue.dart';
import 'package:miriago/application/plan_session.dart';
import 'package:miriago/data/sample_pilgrimage_repository.dart';
import 'package:miriago/plan/pilgrimage_models.dart';
import 'package:miriago/ui/features/go/go_page.dart';
import 'package:miriago/ui/features/points/point_detail_entry.dart';
import 'package:miriago/ui/components/components.dart';
import 'package:miriago/ui/map/map.dart';
import 'package:provider/provider.dart';

import 'go_test_helpers.dart';

/// Pulls the phone bottom sheet up to its full snap.
Future<void> _expandSheet(WidgetTester tester) async {
  await tester.drag(
    find.byKey(const ValueKey('go-group-name')),
    const Offset(0, -800),
  );
  await settle(tester, frames: 16);
}

PlanSession _session(WidgetTester tester) =>
    tester.element(find.byType(GoPage)).read<PlanSession>();

const _kohataId = 'anitabi-115908-sample-kohata-01'; // 木幡站前

/// Fails loading the active plan while [fail] is set.
class _FlakyLoadRepository extends SamplePilgrimageRepository {
  bool fail = true;

  @override
  Future<PilgrimagePlan> loadActivePlan() async {
    if (fail) throw StateError('disk unavailable');
    return super.loadActivePlan();
  }
}

double _distance(LatLng a, LatLng b) =>
    const Distance().as(LengthUnit.Meter, a, b);

LatLng? _mapCenter(WidgetTester tester) =>
    tester.widget<PlanMap>(find.byType(PlanMap)).controller?.camera?.center;

List<PlanGroupBucket> _buckets(WidgetTester tester) {
  final controller = _session(tester).controller;
  return planGroupBuckets(controller.plan, controller.completedPointIds);
}

void main() {
  for (final entry in {
    'phone': TestSizes.phone,
    'tablet': TestSizes.tablet,
    'desktop': TestSizes.desktop,
  }.entries) {
    testWidgets('renders the current target and the queue on ${entry.key}', (
      tester,
    ) async {
      await pumpGoApp(tester, size: entry.value);
      expect(tester.takeException(), isNull);
      expect(find.byType(PlanMap), findsOneWidget);
      expect(find.byType(MapControls), findsOneWidget);
      expect(find.byKey(const ValueKey('go-current-card')), findsOneWidget);
      final current = _session(tester).controller.currentPoint!;
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('go-current-card')),
          matching: find.text(current.name),
        ),
        findsOneWidget,
      );
      expect(find.text('接下来'), findsOneWidget);
      expect(
        find.byKey(ValueKey('go-queue-row-${current.id}')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('go-group-name')), findsOneWidget);
    });
  }

  testWidgets('completing shows an undo toast that restores the target', (
    tester,
  ) async {
    await pumpGoApp(tester, size: TestSizes.desktop);
    final controller = _session(tester).controller;
    final current = controller.currentPoint!;

    await tester.tap(find.byKey(const ValueKey('go-card-complete')));
    await settle(tester);
    expect(controller.statusFor(current), VisitStatus.completed);
    expect(controller.currentPoint?.id, isNot(current.id));
    expect(find.text('已完成「${current.name}」。'), findsOneWidget);

    await tester.tap(find.text('撤销'));
    await settle(tester);
    expect(controller.statusFor(current), VisitStatus.current);
    expect(controller.currentPoint?.id, current.id);
  });

  testWidgets('queue rows complete and reopen points', (tester) async {
    await pumpGoApp(tester, size: TestSizes.desktop);
    final controller = _session(tester).controller;
    final point = _buckets(tester).first.points[1];

    await tester.tap(find.byKey(ValueKey('go-queue-complete-${point.id}')));
    await settle(tester);
    expect(controller.statusFor(point), VisitStatus.completed);
    expect(find.byTooltip('取消完成'), findsWidgets);

    await tester.tap(find.byKey(ValueKey('go-queue-complete-${point.id}')));
    await settle(tester);
    // 取消完成 makes a positioned point the current target (old behaviour).
    expect(controller.statusFor(point), VisitStatus.current);
  });

  testWidgets('previous / next switch groups without wrapping', (tester) async {
    await pumpGoApp(tester, size: TestSizes.phone);
    final buckets = _buckets(tester);
    final controller = _session(tester).controller;
    final start = goGroupIndex(buckets, controller.plan.currentGroupId);
    expect(start, 0);

    final previous = tester.widget<MiriaIconButton>(
      find.byKey(const ValueKey('go-group-previous')),
    );
    expect(previous.onPressed, isNull);

    await tester.tap(find.byKey(const ValueKey('go-group-next')));
    await settle(tester);
    expect(controller.plan.currentGroupId, buckets[1].id);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('go-group-name')),
        matching: find.text(buckets[1].name),
      ),
      findsOneWidget,
    );

    // Walk to the last group; next is disabled there.
    for (var i = 1; i < buckets.length - 1; i++) {
      await tester.tap(find.byKey(const ValueKey('go-group-next')));
      await settle(tester, frames: 4);
    }
    expect(controller.plan.currentGroupId, buckets.last.id);
    final next = tester.widget<MiriaIconButton>(
      find.byKey(const ValueKey('go-group-next')),
    );
    expect(next.onPressed, isNull);

    await tester.tap(find.byKey(const ValueKey('go-group-previous')));
    await settle(tester);
    expect(controller.plan.currentGroupId, buckets[buckets.length - 2].id);
  });

  testWidgets('tapping a row opens details inside the sheet on phones', (
    tester,
  ) async {
    await pumpGoApp(tester, size: TestSizes.phone);
    await _expandSheet(tester);
    final point = _buckets(tester).first.points[1];
    await tester.tap(find.byKey(ValueKey('go-queue-row-${point.id}')));
    await settle(tester, frames: 16);
    expect(find.byKey(const ValueKey('point-detail-status-badge')), findsOne);
    expect(find.text('点位详情'), findsOneWidget);
    expect(find.text('34.89290, 135.80650'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('point-detail-close')));
    await settle(tester, frames: 16);
    expect(
      find.byKey(const ValueKey('point-detail-status-badge')),
      findsNothing,
    );
    expect(find.text('接下来'), findsOneWidget);
  });

  testWidgets('tapping a row opens the inspector on desktop', (tester) async {
    await pumpGoApp(tester, size: TestSizes.desktop);
    final point = _buckets(tester).first.points[1];
    await tester.tap(find.byKey(ValueKey('go-queue-row-${point.id}')));
    await settle(tester, frames: 16);
    // Selection card in the panel + details in the inspector.
    expect(find.byKey(const ValueKey('go-selected-card')), findsOneWidget);
    expect(find.byKey(const ValueKey('point-detail-status-badge')), findsOne);
    expect(find.byKey(const ValueKey('go-queue')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('go-card-set-current')));
    await settle(tester);
    expect(_session(tester).controller.currentPoint?.id, point.id);
  });

  testWidgets('selecting a marker shows it; tapping again opens details', (
    tester,
  ) async {
    await pumpGoApp(tester, size: TestSizes.desktop);
    final controller = _session(tester).controller;
    final currentId = controller.currentPoint!.id;
    final marker = find.byWidgetPredicate((widget) {
      final key = widget.key;
      return key is ValueKey<String> &&
          key.value.startsWith('plan-map-marker-') &&
          key.value != 'plan-map-marker-$currentId';
    });
    expect(marker, findsWidgets);
    await tester.tap(marker.first, warnIfMissed: false);
    await settle(tester);
    expect(find.byKey(const ValueKey('go-selected-card')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('point-detail-status-badge')),
      findsNothing,
    );

    await tester.tap(find.byKey(const ValueKey('go-selected-back')));
    await settle(tester);
    expect(find.byKey(const ValueKey('go-selected-card')), findsNothing);
    expect(find.byKey(const ValueKey('go-current-card')), findsOneWidget);
  });

  testWidgets('the current-target control centres and toasts when missing', (
    tester,
  ) async {
    await pumpGoApp(tester, size: TestSizes.phone);
    await tester.tap(find.byKey(const ValueKey('map-control-target')));
    await settle(tester);
    expect(find.text('当前计划还没有点位。'), findsNothing);
  });

  testWidgets('设为当前目标 from the details recentres on the point', (tester) async {
    await pumpGoApp(tester, size: TestSizes.desktop);
    final controller = _session(tester).controller;
    final point = controller.pointById(_kohataId)!;
    final before = _mapCenter(tester)!;
    expect(_distance(before, point.position), greaterThan(2000));

    // Modal details (the page element is above the inspector scope).
    showPointDetail(
      tester.element(find.byType(GoPage)),
      pointId: _kohataId,
      scope: PointDetailScope.organize,
    );
    await settle(tester, frames: 12);
    await tester.tap(find.byKey(const ValueKey('point-detail-more')));
    await settle(tester);
    await tester.tap(find.text('设为当前目标'));
    await settle(tester, frames: 30);

    expect(controller.currentPoint?.id, _kohataId);
    expect(controller.plan.currentGroupId, 'sample-group-kohata');
    expect(find.text('木幡方向'), findsWidgets);
    expect(_distance(_mapCenter(tester)!, point.position), lessThan(1000));
  });

  testWidgets('the first map centre is the controller selection', (
    tester,
  ) async {
    await pumpGoApp(tester, location: '/plan', size: TestSizes.phone);
    final context = tester.element(find.byType(Scaffold).first);
    final controller = context.read<PlanSession>().controller;
    final point = controller.pointById(_kohataId)!;
    controller.selectPoint(point);
    GoRouter.of(context).go('/go');
    await settle(tester);
    final map = tester.widget<PlanMap>(find.byType(PlanMap));
    expect(map.initialCenter, point.position);
  });

  testWidgets('a failed plan load shows the old error with 重试', (tester) async {
    final repository = _FlakyLoadRepository();
    await pumpGoApp(tester, repository: repository);
    expect(find.byKey(const ValueKey('go-load-error')), findsOneWidget);
    expect(find.text('计划加载失败'), findsOneWidget);
    // Debug builds (tests) add the raw error below the old detail.
    expect(find.textContaining('请稍后重试。'), findsOneWidget);
    expect(find.textContaining('disk unavailable'), findsOneWidget);

    repository.fail = false;
    await tester.tap(find.text('重试'));
    await settle(tester);
    expect(find.byKey(const ValueKey('go-load-error')), findsNothing);
    expect(find.byKey(const ValueKey('go-current-card')), findsOneWidget);
  });

  testWidgets('record badges show one photo or a stack of photos', (
    tester,
  ) async {
    await pumpGoApp(tester, size: TestSizes.desktop);
    // 井用机前步行道 (current) has 2 records, 宇治桥 1, 宇治川河畔 none.
    Finder badgeIn(String pointId, String badge) => find.descendant(
      of: find.byKey(ValueKey('go-queue-row-$pointId')),
      matching: find.byKey(ValueKey(badge)),
    );
    expect(
      badgeIn('anitabi-115908-7evkbmy2', 'go-record-badge-many'),
      findsOneWidget,
    );
    expect(
      badgeIn('anitabi-115908-7gs3o1mm', 'go-record-badge-one'),
      findsOneWidget,
    );
    expect(
      badgeIn('anitabi-115908-sample-uji-02', 'go-record-badge-one'),
      findsNothing,
    );
    expect(
      badgeIn('anitabi-115908-sample-uji-02', 'go-record-badge-many'),
      findsNothing,
    );
  });

  testWidgets('the collapsed sheet camera button shows the record badge', (
    tester,
  ) async {
    await pumpGoApp(tester, size: TestSizes.phone);
    await tester.drag(
      find.byKey(const ValueKey('go-group-name')),
      const Offset(0, 800),
    );
    await settle(tester, frames: 16);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('go-compact-target')),
        matching: find.byKey(const ValueKey('go-record-badge-many')),
      ),
      findsOneWidget,
    );
  });

  testWidgets('an empty plan offers 去添加 instead of a queue', (tester) async {
    final repository = SamplePilgrimageRepository();
    final plan = await repository.createPlan(name: '空计划', area: '未设置区域');
    await repository.setActivePlan(plan.id);
    await pumpGoApp(tester, size: TestSizes.phone, repository: repository);
    expect(find.byKey(const ValueKey('go-empty-plan')), findsOneWidget);
    expect(find.text('还没有点位'), findsOneWidget);
    expect(find.text('去添加'), findsOneWidget);
    expect(find.byKey(const ValueKey('go-current-card')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('map-control-target')));
    await settle(tester);
    expect(find.text('当前计划还没有点位。'), findsOneWidget);
  });

  testWidgets('the sort menu switches to distance order', (tester) async {
    await pumpGoApp(tester, size: TestSizes.desktop);
    expect(find.text('默认计划 · 正序'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('go-sort')));
    await settle(tester);
    await tester.tap(find.text('按距离当前位置'));
    await settle(tester);
    expect(find.text('按距离 · 近到远'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('go-sort')));
    await settle(tester);
    await tester.tap(find.text('远到近'));
    await settle(tester);
    expect(find.text('按距离 · 远到近'), findsOneWidget);
  });

  for (final entry in {
    'small phone': TestSizes.phoneSmall,
    'landscape phone': TestSizes.phoneLandscape,
  }.entries) {
    testWidgets('no overflow on ${entry.key} with text scale 2', (
      tester,
    ) async {
      await pumpGoApp(tester, size: entry.value, textScale: 2);
      final error = tester.takeException();
      if (error is FlutterError) debugPrint(error.toStringDeep());
      expect(error, isNull);
      final original = FlutterError.onError;
      FlutterError.onError = (details) {
        debugPrint('DETAILS: ${details.toString()}');
        original?.call(details);
      };
      addTearDown(() => FlutterError.onError = original);
      final point = _buckets(tester).first.points[1];
      final row = find.byKey(ValueKey('go-queue-row-${point.id}'));
      if (entry.value == TestSizes.phoneSmall) await _expandSheet(tester);
      await tester.scrollUntilVisible(
        row,
        120,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('go-queue')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await settle(tester);
      await tester.tap(row, warnIfMissed: false);
      await settle(tester, frames: 16);
      final detailError = tester.takeException();
      if (detailError is FlutterError) debugPrint(detailError.toStringDeep());
      expect(detailError, isNull);
      expect(find.byKey(const ValueKey('point-detail-status-badge')), findsOne);
    });
  }
}
