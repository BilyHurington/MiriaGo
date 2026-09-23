import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:miriago/app_theme.dart';
import 'package:miriago/data/local/app_database.dart';
import 'package:miriago/data/local/sqlite_pilgrimage_repository.dart';
import 'package:miriago/data/sample_pilgrimage_repository.dart';
import 'package:miriago/plan/pilgrimage_models.dart';
import 'package:miriago/plan/pilgrimage_plan_controller.dart';
import 'package:miriago/plan/plan_group_manager_screen.dart';
import 'package:miriago/plan/plan_memo_screen.dart';

class _DelayedMemoRepository extends SamplePilgrimageRepository {
  Completer<void>? pending;
  final writes = <String>[];

  @override
  Future<PilgrimagePlan> updatePlanMemo({
    required String planId,
    required String memo,
  }) async {
    writes.add(memo);
    await pending?.future;
    return super.updatePlanMemo(planId: planId, memo: memo);
  }
}

Future<void> _openMemo(
  WidgetTester tester,
  _DelayedMemoRepository repository,
) async {
  final plan = await repository.loadActivePlan();
  final controller = PilgrimagePlanController(
    plan: plan,
    visitRepository: repository,
  );
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: PlanMemoScreen(controller: controller),
    ),
  );
  await tester.pumpAndSettle();
  addTearDown(controller.dispose);
}

void _saveMemo(WidgetTester tester) {
  tester
      .widget<FilledButton>(find.widgetWithText(FilledButton, '保存'))
      .onPressed!();
}

void main() {
  const nestedTasks =
      '```md\n- [ ] example\n```\n\n'
      '- [ ] parent\n  - [x] child\n    - [ ] grandchild\n\n'
      '> - [ ] quoted';
  for (final task in ['parent', 'child', 'grandchild', 'quoted']) {
    testWidgets('rendered nested checkbox persists only $task', (tester) async {
      final repository = _DelayedMemoRepository();
      final plan = await repository.loadActivePlan();
      await repository.updatePlanMemo(planId: plan.id, memo: nestedTasks);
      await _openMemo(tester, repository);
      final checkboxes = find.byWidgetPredicate(
        (widget) =>
            widget is Icon &&
            (widget.icon == LucideIcons.square ||
                widget.icon == LucideIcons.squareCheckBig),
      );
      expect(checkboxes, findsNWidgets(4));
      // Locate by visual order, not by the renderer's internal callback order.
      final visualOrder =
          checkboxes
              .evaluate()
              .map(
                (element) => find.byElementPredicate(
                  (other) => identical(other, element),
                ),
              )
              .toList()
            ..sort(
              (a, b) =>
                  tester.getCenter(a).dy.compareTo(tester.getCenter(b).dy),
            );
      final index = ['parent', 'child', 'grandchild', 'quoted'].indexOf(task);
      await tester.tap(visualOrder[index]);
      await tester.pumpAndSettle();
      final before = task == 'child' ? '[x] $task' : '[ ] $task';
      final after = task == 'child' ? '[ ] $task' : '[x] $task';
      expect(
        (await repository.loadActivePlan()).memo,
        nestedTasks.replaceFirst(before, after),
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('non-rendered loose tasks do not shift a later checkbox', (
    tester,
  ) async {
    const text =
        '- [ ] parent\n\n  ```\n  - [ ] example\n  ```\n\n---\n\n- [ ] next';
    final repository = _DelayedMemoRepository();
    final plan = await repository.loadActivePlan();
    await repository.updatePlanMemo(planId: plan.id, memo: text);
    await _openMemo(tester, repository);
    expect(find.byIcon(LucideIcons.square), findsOneWidget);
    await tester.tap(find.byIcon(LucideIcons.square));
    await tester.pumpAndSettle();
    expect(
      (await repository.loadActivePlan()).memo,
      text.replaceFirst('[ ] next', '[x] next'),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'edits during a pending memo save remain unsaved and can be saved next',
    (tester) async {
      final repository = _DelayedMemoRepository();
      await _openMemo(tester, repository);
      await tester.tap(find.byTooltip('编辑'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'First snapshot');
      final gate = Completer<void>();
      repository.pending = gate;
      _saveMemo(tester);
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'Newer draft');
      expect(
        tester
            .widget<PopScope>(
              find.byWidgetPredicate((widget) => widget is PopScope),
            )
            .canPop,
        isFalse,
      );
      gate.complete();
      await tester.pumpAndSettle();
      expect((await repository.loadActivePlan()).memo, 'First snapshot');
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Newer draft',
      );
      expect(find.text('已保存，后续输入仍待保存'), findsOneWidget);
      repository.pending = null;
      _saveMemo(tester);
      await tester.pumpAndSettle();
      expect(repository.writes, ['First snapshot', 'Newer draft']);
      expect((await repository.loadActivePlan()).memo, 'Newer draft');
      expect(find.byType(TextField), findsNothing);
    },
  );

  testWidgets('failed memo save preserves latest draft and allows retry', (
    tester,
  ) async {
    final repository = _DelayedMemoRepository();
    await _openMemo(tester, repository);
    await tester.tap(find.byTooltip('编辑'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'First');
    final gate = Completer<void>();
    repository.pending = gate;
    _saveMemo(tester);
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'Latest');
    gate.completeError(StateError('disk full'));
    await tester.pumpAndSettle();
    expect((await repository.loadActivePlan()).memo, isEmpty);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Latest',
    );
    expect(find.text('计划备忘录保存失败'), findsOneWidget);
    repository.pending = null;
    _saveMemo(tester);
    await tester.pumpAndSettle();
    expect((await repository.loadActivePlan()).memo, 'Latest');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'checkbox index ignores code examples and locks editing until persistence',
    (tester) async {
      final repository = _DelayedMemoRepository();
      final plan = await repository.loadActivePlan();
      const text = '```md\n- [ ] example\n```\n\n- [ ] actual\n- [ ] second';
      await repository.updatePlanMemo(planId: plan.id, memo: text);
      await _openMemo(tester, repository);
      final gate = Completer<void>();
      repository.pending = gate;
      await tester.tap(find.byIcon(LucideIcons.square).first);
      await tester.pump();
      final edit = tester.widget<IconButton>(
        find.byWidgetPredicate(
          (widget) => widget is IconButton && widget.tooltip == '编辑',
        ),
      );
      expect(edit.onPressed, isNull);
      gate.complete();
      await tester.pumpAndSettle();
      expect(
        (await repository.loadActivePlan()).memo,
        text.replaceFirst('[ ] actual', '[x] actual'),
      );
      expect(find.byIcon(LucideIcons.squareCheckBig), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final indices in [(0, 3), (3, 0), (0, 1), (2, 1)]) {
    testWidgets(
      'group reorder $indices uses final destination and persists across restart',
      (tester) async {
        late Directory directory;
        late AppDatabase database;
        late SqlitePilgrimageRepository repository;
        late PilgrimagePlan plan;
        await tester.runAsync(() async {
          directory = await Directory.systemTemp.createTemp('miriago-reorder-');
          database = AppDatabase(
            NativeDatabase(File('${directory.path}/plan.sqlite')),
          );
          repository = SqlitePilgrimageRepository(database: database);
          plan = await repository.createPlan(name: 'Groups', area: 'Area');
          for (var index = 0; index < 4; index++) {
            plan = await repository.createPlanGroup(
              planId: plan.id,
              group: PilgrimagePlanGroup(
                id: 'group-$index',
                name: 'Group $index',
                orderIndex: index,
                createdAt: DateTime(2026),
              ),
            );
          }
        });
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: PlanGroupManagerScreen(plan: plan, repository: repository),
          ),
        );
        await tester.pumpAndSettle();
        final expected = plan.groups.map((group) => group.id).toList();
        expected.insert(indices.$2, expected.removeAt(indices.$1));
        final reorder =
            tester
                    .widget<SliverReorderableList>(
                      find.byType(SliverReorderableList),
                    )
                    .onReorderItem!
                as Future<void> Function(int, int);
        await tester.runAsync(() => reorder(indices.$1, indices.$2));
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          await database.close();
          final reopened = AppDatabase(
            NativeDatabase(File('${directory.path}/plan.sqlite')),
          );
          try {
            final restored = await SqlitePilgrimageRepository(
              database: reopened,
            ).loadPlans();
            final groups =
                restored
                    .singleWhere((candidate) => candidate.id == plan.id)
                    .groups
                    .toList()
                  ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
            expect(groups.map((group) => group.id), expected);
            expect(groups.map((group) => group.orderIndex), [0, 1, 2, 3]);
          } finally {
            await reopened.close();
            await directory.delete(recursive: true);
          }
        });
        expect(tester.takeException(), isNull);
      },
    );
  }
}
