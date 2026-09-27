import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:miriago/app_theme.dart';
import 'package:miriago/data/local/app_database.dart';
import 'package:miriago/data/local/sqlite_pilgrimage_repository.dart';
import 'package:miriago/data/sample_pilgrimage_repository.dart';
import 'package:miriago/plan/nearest_group_assign_screen.dart';
import 'package:miriago/plan/pilgrimage_models.dart';
import 'package:miriago/plan/pilgrimage_plan_controller.dart';
import 'package:miriago/plan/plan_group_manager_screen.dart';
import 'package:miriago/plan/plan_manager_screen.dart';

const _work = PilgrimageWork(
  id: 'work',
  title: 'Work',
  subtitle: '',
  city: '',
  source: WorkSource.manual,
);

PilgrimagePoint _point(
  String id, {
  LatLng position = const LatLng(35, 135),
  String? groupId,
  int? groupOrderIndex,
}) => PilgrimagePoint(
  id: id,
  work: _work,
  name: id,
  subtitle: '',
  position: position,
  episodeLabel: 'EP 1',
  referenceLabel: '',
  groupId: groupId,
  groupOrderIndex: groupOrderIndex,
);

PilgrimagePlanGroup _group(String id, int order, {String? name}) =>
    PilgrimagePlanGroup(
      id: id,
      name: name ?? id,
      orderIndex: order,
      createdAt: DateTime(2026),
    );

class _GatedRecordsRepository extends SamplePilgrimageRepository {
  _GatedRecordsRepository() : super(visitRecords: const []);
  final gate = Completer<void>();

  @override
  Future<List<PilgrimageVisitRecord>> loadVisitRecords(String planId) async {
    await gate.future;
    return super.loadVisitRecords(planId);
  }
}

class _AssignRepository extends SamplePilgrimageRepository {
  _AssignRepository(PilgrimagePlan plan, {this.failAssign = false})
    : super(plans: [plan], visitRecords: const []);
  final bool failAssign;
  final calls = <String>[];

  @override
  Future<PilgrimagePlan> assignPointsToGroups({
    required String planId,
    required Map<String, String?> groupIdsByPointId,
  }) async {
    calls.add('assign');
    if (failAssign) throw StateError('disk full');
    return super.assignPointsToGroups(
      planId: planId,
      groupIdsByPointId: groupIdsByPointId,
    );
  }

  @override
  Future<void> saveAppSettings(AppSettings settings) async {
    calls.add('settings');
    return super.saveAppSettings(settings);
  }
}

class _FailingReorderRepository extends SamplePilgrimageRepository {
  _FailingReorderRepository(PilgrimagePlan plan)
    : super(plans: [plan], visitRecords: const []);

  @override
  Future<PilgrimagePlan> reorderGroups({
    required String planId,
    required List<String> orderedGroupIds,
  }) async => throw StateError('disk full');
}

PilgrimagePlan _plan({
  List<PilgrimagePlanGroup> groups = const [],
  List<PilgrimagePoint> points = const [],
}) => PilgrimagePlan(
  id: 'plan',
  name: 'Plan',
  area: 'Area',
  works: const [_work],
  groups: groups,
  points: points,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

void main() {
  test('a disposed controller ignores a load that completes later', () async {
    final repository = _GatedRecordsRepository();
    final controller = PilgrimagePlanController(
      plan: await repository.loadActivePlan(),
      visitRepository: repository,
    );
    var notifications = 0;
    controller.addListener(() => notifications++);
    controller.dispose();
    expect(controller.isDisposed, isTrue);
    repository.gate.complete();
    await Future<void>.delayed(Duration.zero);
    await controller.loadVisitRecords();
    expect(notifications, 0);
  });

  group('SQLite batch writes are atomic across a reopen', () {
    late Directory directory;
    late File file;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('miriago-batch-');
      file = File('${directory.path}/plan.sqlite');
    });

    tearDown(() => directory.delete(recursive: true));

    Future<PilgrimagePlan> reopenPlan(String planId) async {
      final database = AppDatabase(NativeDatabase(file));
      try {
        return (await SqlitePilgrimageRepository(
          database: database,
        ).loadPlans()).singleWhere((plan) => plan.id == planId);
      } finally {
        await database.close();
      }
    }

    test('a failing group reorder leaves every group order untouched', () async {
      final database = AppDatabase(NativeDatabase(file));
      final repository = SqlitePilgrimageRepository(database: database);
      var plan = await repository.createPlan(name: 'Groups', area: 'Area');
      for (var index = 0; index < 3; index++) {
        plan = await repository.createPlanGroup(
          planId: plan.id,
          group: _group('g$index', index),
        );
      }
      await database.customStatement(
        "CREATE TRIGGER fail_reorder BEFORE UPDATE OF order_index "
        "ON plan_groups WHEN NEW.id = 'g0' "
        "BEGIN SELECT RAISE(ABORT, 'disk full'); END",
      );
      await expectLater(
        repository.reorderGroups(
          planId: plan.id,
          orderedGroupIds: ['g2', 'g1', 'g0'],
        ),
        throwsA(anything),
      );
      await database.customStatement('DROP TRIGGER fail_reorder');
      await database.close();

      final restored = await reopenPlan(plan.id);
      expect({for (final group in restored.groups) group.id: group.orderIndex}, {
        'g0': 0,
        'g1': 1,
        'g2': 2,
      });
    });

    test('a failing batch assignment moves no point at all', () async {
      final database = AppDatabase(NativeDatabase(file));
      final repository = SqlitePilgrimageRepository(database: database);
      var plan = await repository.createPlan(name: 'Assign', area: 'Area');
      plan = await repository.createPlanGroup(
        planId: plan.id,
        group: _group('g', 0),
      );
      await repository.addPointsToPlan(
        planId: plan.id,
        points: [_point('p-ok'), _point('p-fail')],
      );
      await database.customStatement(
        "CREATE TRIGGER fail_assign BEFORE UPDATE OF group_id ON points "
        "WHEN NEW.id LIKE '%p-fail' "
        "BEGIN SELECT RAISE(ABORT, 'disk full'); END",
      );
      await expectLater(
        repository.assignPointsToGroups(
          planId: plan.id,
          groupIdsByPointId: {'p-ok': 'g', 'p-fail': 'g'},
        ),
        throwsA(anything),
      );
      await database.customStatement('DROP TRIGGER fail_assign');
      await repository.assignPointsToGroups(
        planId: plan.id,
        groupIdsByPointId: {'p-fail': 'g'},
      );
      await database.close();

      final restored = await reopenPlan(plan.id);
      final byId = {for (final point in restored.points) point.id: point};
      expect(byId['p-ok']!.groupId, isNull);
      expect(byId['p-fail']!.groupId, 'g');
      expect(byId['p-fail']!.groupOrderIndex, 0);
    });
  });

  group('nearest assignment', () {
    // The stored anchor copy is stale (0, 0); the linked key point is next to
    // the ungrouped point, so assignment must measure from the key point.
    final plan = _plan(
      groups: [
        PilgrimagePlanGroup(
          id: 'g',
          name: '片区',
          orderIndex: 0,
          anchorName: 'anchor',
          anchorLatitude: 0,
          anchorLongitude: 0,
          anchorPointId: 'anchor',
          createdAt: DateTime(2026),
        ),
      ],
      points: [
        _point('anchor', groupId: 'g', groupOrderIndex: 0),
        _point('loose', position: const LatLng(35.0005, 135)),
      ],
    );

    Future<void> assign(WidgetTester tester, _AssignRepository repository) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: NearestGroupAssignScreen(
            plan: plan,
            repository: repository,
            settings: const AppSettings(nearestAssignDistanceMeters: 300),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '分配'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('开始分配'));
      await tester.pumpAndSettle();
    }

    testWidgets('uses the linked key point and saves distance afterwards', (
      tester,
    ) async {
      final repository = _AssignRepository(plan);
      await assign(tester, repository);

      expect(repository.calls, ['assign', 'settings']);
      final stored = await repository.loadActivePlan();
      expect(
        stored.points.singleWhere((point) => point.id == 'loose').groupId,
        'g',
      );
      expect(find.text('已分配 1 个点位'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a failed assignment does not save the distance setting', (
      tester,
    ) async {
      final repository = _AssignRepository(plan, failAssign: true);
      await assign(tester, repository);

      expect(repository.calls, ['assign']);
      expect(find.text('最近分配失败'), findsOneWidget);
      final stored = await repository.loadActivePlan();
      expect(
        stored.points.singleWhere((point) => point.id == 'loose').groupId,
        isNull,
      );
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('group manager orders equal indexes by name like the plan', (
    tester,
  ) async {
    final plan = _plan(
      groups: [
        _group('b', 0, name: 'B 片区'),
        _group('a', 0, name: 'A 片区'),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: PlanGroupManagerScreen(
          plan: plan,
          repository: SamplePilgrimageRepository(plans: [plan]),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('A 片区')).dy,
      lessThan(tester.getTopLeft(find.text('B 片区')).dy),
    );
  });

  testWidgets('a failed group reorder reports and keeps the stored order', (
    tester,
  ) async {
    final plan = _plan(groups: [_group('a', 0), _group('b', 1)]);
    final repository = _FailingReorderRepository(plan);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: PlanGroupManagerScreen(plan: plan, repository: repository),
      ),
    );
    await tester.pumpAndSettle();
    final reorder =
        tester
                .widget<SliverReorderableList>(
                  find.byType(SliverReorderableList),
                )
                .onReorderItem!
            as Future<void> Function(int, int);
    await reorder(0, 1);
    await tester.pumpAndSettle();

    expect(find.text('片区顺序保存失败'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('a')).dy,
      lessThan(tester.getTopLeft(find.text('b')).dy),
    );
    final stored = await repository.loadActivePlan();
    expect({for (final group in stored.groups) group.id: group.orderIndex}, {
      'a': 0,
      'b': 1,
    });
  });

  testWidgets('renaming a group survives the dialog exit animation', (
    tester,
  ) async {
    final plan = _plan(groups: [_group('g', 0, name: '旧名称')]);
    final repository = SamplePilgrimageRepository(plans: [plan]);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: PlanGroupManagerScreen(plan: plan, repository: repository),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('plan-group-actions-g')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('重命名'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '新名称');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    for (var frame = 0; frame < 20; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect((await repository.loadActivePlan()).groups.single.name, '新名称');
    expect(find.text('新名称'), findsOneWidget);
  });

  testWidgets('editing plan info survives the dialog exit animation', (
    tester,
  ) async {
    final repository = SamplePilgrimageRepository(visitRecords: const []);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: PlanManagerScreen(repository: repository),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('编辑计划信息').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '改名后的计划');
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    for (var frame = 0; frame < 20; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect((await repository.loadActivePlan()).name, '改名后的计划');
  });
}
