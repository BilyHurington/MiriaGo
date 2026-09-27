import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/data/pilgrimage_repository.dart';
import 'package:miriago/ui/devtools/preview_seeds.dart';
import 'package:miriago/ui/features/organize/organize_common.dart';
import 'package:miriago/ui/features/organize/organize_map_pane.dart';

import '../../helpers/pump_app.dart';

const _station = 'sample-group-uji-station';
const _daikichi = 'sample-group-daikichiyama';
const _ungrouped = 'anitabi-115908-sample-unassigned-02';

Future<void> _settle(WidgetTester tester, [int frames = 12]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

Future<void> _tapText(WidgetTester tester, String text) async {
  await tester.tap(find.text(text).last);
  await _settle(tester);
}

final _listScrollable = find
    .descendant(
      of: find.byKey(const ValueKey('organize-list')),
      matching: find.byType(Scrollable),
    )
    .first;

Future<String?> _groupOf(PilgrimageRepository repo, String pointId) async {
  final plan = await repo.loadActivePlan();
  return plan.points.firstWhere((point) => point.id == pointId).groupId;
}

void main() {
  setUp(() => OrganizeDebug.disableMapTiles = true);
  tearDown(() => OrganizeDebug.disableMapTiles = false);

  testWidgets('phone: inbox on top and every group as a section', (
    tester,
  ) async {
    await pumpMiriaApp(tester, location: '/plan/organize');
    await _settle(tester);

    expect(find.text('片区与点位'), findsWidgets);
    expect(find.byKey(const ValueKey('organize-section-ungrouped')), findsOne);
    expect(find.text('1 个点位等待整理'), findsOne);
    expect(find.byKey(const ValueKey('organize-nearest-assign')), findsOne);
    expect(find.byKey(const ValueKey('organize-box-assign')), findsOne);
    expect(find.byKey(const ValueKey('organize-section-$_station')), findsOne);
    expect(find.text('宇治上神社参道'), findsOne);
    expect(
      find.byKey(const ValueKey('organize-section-meta-$_station')),
      findsOne,
    );
    expect(find.textContaining('关键点：JR 宇治站'), findsOne);
    expect(find.byType(OrganizeMapPane), findsNothing);
  });

  testWidgets('filter chip and ?group= limit the list to one section', (
    tester,
  ) async {
    await pumpMiriaApp(tester, location: '/plan/organize?group=$_daikichi');
    await _settle(tester);
    expect(find.byKey(const ValueKey('organize-section-$_daikichi')), findsOne);
    expect(
      find.byKey(const ValueKey('organize-section-$_station')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('organize-section-ungrouped')),
      findsNothing,
    );

    await _tapText(tester, '全部');
    expect(find.byKey(const ValueKey('organize-section-$_station')), findsOne);
  });

  testWidgets('search filters points', (tester) async {
    await pumpMiriaApp(tester, location: '/plan/organize');
    await _settle(tester);
    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('organize-search')),
        matching: find.byType(TextField),
      ),
      '展望台',
    );
    await _settle(tester);
    expect(find.text('大吉山展望台'), findsOne);
    expect(
      find.byKey(const ValueKey('organize-section-$_station')),
      findsNothing,
    );
  });

  testWidgets('multi-select: move, complete and delete', (tester) async {
    final repo = await pumpMiriaApp(tester, location: '/plan/organize');
    await _settle(tester);

    // Long press starts the selection.
    await tester.longPress(find.text('宇治上神社参道'));
    await _settle(tester);
    expect(find.text('已选 1'), findsOne);
    expect(find.byKey(const ValueKey('organize-batch-bar')), findsOne);

    // Move to a group.
    await tester.tap(find.byKey(const ValueKey('organize-batch-move')));
    await _settle(tester);
    expect(find.text('移动到片区'), findsOne);
    await tester.tap(
      find.byKey(const ValueKey('group-picker-option-$_station')),
    );
    await _settle(tester);
    expect(await _groupOf(repo, _ungrouped), _station);
    // Selection stays for the moved point.
    expect(find.text('已选 1'), findsOne);

    // Complete it.
    await tester.tap(find.byKey(const ValueKey('organize-batch-complete')));
    await _settle(tester);
    var plan = await repo.loadActivePlan();
    expect(plan.completedPointIds, contains(_ungrouped));
    expect(find.text('已选 1'), findsNothing, reason: 'status batch ends');

    // Select again and delete.
    await tester.tap(find.byKey(const ValueKey('organize-select-mode')));
    await _settle(tester);
    await tester.scrollUntilVisible(
      find.text('宇治上神社参道'),
      200,
      scrollable: _listScrollable,
    );
    await tester.tap(find.text('宇治上神社参道'));
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('organize-batch-delete')));
    await _settle(tester);
    expect(find.text('批量删除点位'), findsOne);
    expect(find.text('此操作无法撤销'), findsOne);
    await _tapText(tester, '删除');
    plan = await repo.loadActivePlan();
    expect(plan.points.any((point) => point.id == _ungrouped), isFalse);
    expect(find.text('宇治上神社参道'), findsNothing);
  });

  testWidgets('create, rename and delete a group', (tester) async {
    final repo = await pumpMiriaApp(tester, location: '/plan/organize');
    await _settle(tester);

    // Create from the page menu; empty names are rejected.
    await tester.tap(find.byKey(const ValueKey('organize-page-menu')));
    await _settle(tester);
    await _tapText(tester, '新建片区');
    expect(find.text('片区名称'), findsOne);
    await _tapText(tester, '创建');
    expect(find.text('片区名不能为空'), findsOne);
    await tester.enterText(find.byType(TextField).last, '测试片区');
    await _tapText(tester, '创建');
    var plan = await repo.loadActivePlan();
    final created = plan.groups.firstWhere((group) => group.name == '测试片区');
    expect(find.text('测试片区'), findsWidgets);

    // Rename through the section menu.
    await tester.scrollUntilVisible(
      find.byKey(ValueKey('organize-section-menu-${created.id}')),
      300,
      scrollable: _listScrollable,
    );
    await tester.tap(
      find.byKey(ValueKey('organize-section-menu-${created.id}')),
    );
    await _settle(tester);
    await _tapText(tester, '重命名');
    expect(find.text('重命名片区'), findsOne);
    await tester.enterText(find.byType(TextField).last, '改名片区');
    await _tapText(tester, '保存');
    plan = await repo.loadActivePlan();
    expect(
      plan.groups.firstWhere((group) => group.id == created.id).name,
      '改名片区',
    );
    expect(
      find.byKey(ValueKey('organize-section-empty-${created.id}')),
      findsOne,
      reason: '空 tag for empty groups',
    );

    // Delete.
    await tester.tap(
      find.byKey(ValueKey('organize-section-menu-${created.id}')),
    );
    await _settle(tester);
    await _tapText(tester, '删除片区');
    expect(find.text('将删除「改名片区」，其中 0 个点位会移入未分配点位。'), findsOne);
    await _tapText(tester, '删除');
    plan = await repo.loadActivePlan();
    expect(plan.groups.any((group) => group.id == created.id), isFalse);
  });

  testWidgets('desktop: list, map pane and inline box assign', (tester) async {
    await pumpMiriaApp(
      tester,
      location: '/plan/organize',
      size: TestSizes.desktop,
    );
    await _settle(tester);
    expect(find.byType(OrganizeMapPane), findsOne);
    expect(find.byKey(const ValueKey('organize-section-$_station')), findsOne);

    // Tapping a row opens the inline inspector next to the map.
    await tester.tap(find.text('宇治上神社参道'));
    await _settle(tester);
    expect(find.byKey(const ValueKey('point-inspector-$_ungrouped')), findsOne);

    await tester.tap(find.byKey(const ValueKey('organize-box-assign')));
    await _settle(tester);
    expect(find.byKey(const ValueKey('box-assign-panel')), findsOne);
    expect(find.text('已框选 0 / 待分配 1'), findsOne);
    await tester.tap(find.byKey(const ValueKey('box-assign-close')));
    await _settle(tester);
    expect(find.byKey(const ValueKey('box-assign-panel')), findsNothing);
  });

  testWidgets('group order mode', (tester) async {
    final repo = await pumpMiriaApp(tester, location: '/plan/organize');
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('organize-page-menu')));
    await _settle(tester);
    await _tapText(tester, '调整片区顺序');
    expect(find.text('调整片区顺序'), findsOne);
    expect(find.byKey(const ValueKey('organize-group-order')), findsOne);

    final handle = find.byKey(const ValueKey('organize-group-drag-$_station'));
    final gesture = await tester.startGesture(tester.getCenter(handle));
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.moveBy(const Offset(0, 140));
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.up();
    await _settle(tester);
    final plan = await repo.loadActivePlan();
    final sorted = plan.groups.toList()
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    expect(sorted.first.id, isNot(_station));

    await _tapText(tester, '完成');
    expect(find.byKey(const ValueKey('organize-group-order')), findsNothing);
  });

  for (final size in [TestSizes.phoneSmall, TestSizes.phoneLandscape]) {
    testWidgets('no overflow at $size with text scale 2', (tester) async {
      await pumpMiriaApp(
        tester,
        location: '/plan/organize',
        size: size,
        textScale: 2,
      );
      await _settle(tester);
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.text('宇治上神社参道'),
        100,
        scrollable: _listScrollable,
      );
      await tester.longPress(find.text('宇治上神社参道'));
      await _settle(tester);
      expect(find.byKey(const ValueKey('organize-batch-bar')), findsOne);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('600 points stay lazy', (tester) async {
    final repo = await PreviewSeeds.build(PreviewSeeds.stress);
    await pumpMiriaApp(tester, location: '/plan/organize', repository: repo);
    await _settle(tester);
    expect(tester.takeException(), isNull);
    // Only a handful of rows are built.
    final rows = find.byWidgetPredicate(
      (widget) =>
          widget.key is ValueKey<String> &&
          (widget.key! as ValueKey<String>).value.startsWith(
            'organize-point-stress',
          ),
    );
    expect(rows.evaluate().length, inInclusiveRange(1, 40));
  });
}
