import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/application/plan_session.dart';
import 'package:miriago/application/settings_store.dart';
import 'package:miriago/plan/pilgrimage_models.dart';
import 'package:miriago/ui/features/go/go_page.dart';
import 'package:miriago/ui/features/points/point_detail_entry.dart';
import 'package:provider/provider.dart';

import '../go/go_test_helpers.dart';

const _bridgeId = 'anitabi-115908-7gs3o1mm'; // 宇治桥, 1 record

/// A context outside any [PointInspectorScope] (the page's own element),
/// so details open as the adaptive modal.
BuildContext _hostContext(WidgetTester tester) =>
    tester.element(find.byType(GoPage));

PlanSession _session(WidgetTester tester) =>
    _hostContext(tester).read<PlanSession>();

Future<void> _openModal(
  WidgetTester tester, {
  String pointId = _bridgeId,
  PointDetailScope scope = PointDetailScope.go,
}) async {
  showPointDetail(_hostContext(tester), pointId: pointId, scope: scope);
  await settle(tester, frames: 12);
}

Future<void> _openMore(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('point-detail-more')));
  await settle(tester);
}

void main() {
  testWidgets('modal details show info rows and the records strip', (
    tester,
  ) async {
    await pumpGoApp(tester, size: TestSizes.phone);
    await _openModal(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('点位详情'), findsOneWidget);
    expect(find.byKey(const ValueKey('point-detail-status-badge')), findsOne);
    expect(find.text('34.89290, 135.80650'), findsOneWidget);
    expect(find.text('宇治站附近'), findsWidgets);
    expect(find.text('更改'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('point-detail-all-records')),
      100,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('point-detail-list-$_bridgeId')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('全部 ›'), findsOneWidget);
  });

  testWidgets('external navigation uses the chosen app and reports failure', (
    tester,
  ) async {
    final launcher = FakeNavigationLauncher();
    await pumpGoApp(tester, size: TestSizes.desktop, launcher: launcher);
    await _openModal(tester);
    final app = _hostContext(
      tester,
    ).read<SettingsStore>().settings.navigationApp;

    await tester.tap(
      find.byKey(const ValueKey('point-detail-external-navigation-button')),
    );
    await settle(tester);
    expect(launcher.opened, [(_bridgeId, app)]);

    launcher.result = false;
    await tester.tap(
      find.byKey(const ValueKey('point-detail-external-navigation-button')),
    );
    await settle(tester);
    expect(find.text('无法打开${app.label}。'), findsOneWidget);
  });

  testWidgets('completing from the modal closes it with an undo toast', (
    tester,
  ) async {
    await pumpGoApp(tester, size: TestSizes.phone);
    await _openModal(tester);
    await tester.tap(find.byKey(const ValueKey('point-detail-complete')));
    await settle(tester, frames: 12);
    final controller = _session(tester).controller;
    final point = controller.pointById(_bridgeId)!;
    expect(controller.statusFor(point), VisitStatus.completed);
    expect(find.text('点位详情'), findsNothing);
    expect(find.text('撤销'), findsOneWidget);
  });

  testWidgets('delete confirms, explains that records stay, and deletes', (
    tester,
  ) async {
    await pumpGoApp(tester, size: TestSizes.desktop);
    await _openModal(tester);
    await _openMore(tester);
    await tester.tap(find.text('删除点位'));
    await settle(tester);
    expect(find.textContaining('已有巡礼记录及照片将保留。'), findsOneWidget);
    expect(find.text('此操作无法撤销'), findsOneWidget);

    await tester.tap(find.text('取消'));
    await settle(tester);
    expect(_session(tester).controller.pointById(_bridgeId), isNotNull);

    await _openMore(tester);
    await tester.tap(find.text('删除点位'));
    await settle(tester);
    await tester.tap(find.text('删除点位').last);
    await settle(tester, frames: 12);
    expect(_session(tester).controller.pointById(_bridgeId), isNull);
    expect(find.text('点位详情'), findsNothing);
    // Records of the point are kept.
    expect(
      _session(
        tester,
      ).controller.visitRecords.any((record) => record.pointId == _bridgeId),
      isTrue,
    );
  });

  testWidgets('the assign scope offers only navigation, move, replace and '
      'delete', (tester) async {
    await pumpGoApp(tester, size: TestSizes.desktop);
    await _openModal(tester, scope: PointDetailScope.assign);
    expect(find.byKey(const ValueKey('point-detail-camera')), findsNothing);
    expect(find.byKey(const ValueKey('point-detail-complete')), findsNothing);
    expect(
      find.byKey(const ValueKey('point-detail-in-app-navigation-button')),
      findsOneWidget,
    );
    await _openMore(tester);
    expect(find.text('设为当前目标'), findsNothing);
    expect(find.text('编辑点位'), findsNothing);
    expect(find.text('移动到片区'), findsOneWidget);
    expect(find.text('替换参考图'), findsOneWidget);
    expect(find.text('删除点位'), findsOneWidget);
  });

  testWidgets('the full scope menu offers 设为当前目标 and 编辑点位', (tester) async {
    await pumpGoApp(tester, size: TestSizes.desktop);
    await _openModal(tester, scope: PointDetailScope.organize);
    expect(find.byKey(const ValueKey('point-detail-camera')), findsOneWidget);
    await _openMore(tester);
    expect(find.text('设为当前目标'), findsOneWidget);
    expect(find.text('编辑点位'), findsOneWidget);
    await tester.tap(find.text('设为当前目标'));
    await settle(tester, frames: 12);
    expect(_session(tester).controller.currentPoint?.id, _bridgeId);
  });

  testWidgets('points without coordinates cannot navigate', (tester) async {
    await pumpGoApp(tester, size: TestSizes.phone);
    final controller = _session(tester).controller;
    final point = controller.pointById(_bridgeId)!;
    await controller.updatePoint(
      point.copyWith(position: PilgrimagePoint.pendingPosition),
    );
    await settle(tester);
    await _openModal(tester);
    expect(find.text('坐标待补充'), findsOneWidget);
    expect(find.text('待补充'), findsOneWidget);
    expect(find.text('坐标待补充，补充坐标后即可导航。'), findsOneWidget);
    await _openMore(tester);
    expect(find.text('设为当前目标'), findsNothing);
  });

  testWidgets('a failed reference replacement is reported', (tester) async {
    await pumpGoApp(
      tester,
      size: TestSizes.desktop,
      pickReferenceImage: () async => '/nonexistent/picked.jpg',
    );
    await _openModal(tester);
    await tester.tap(find.byKey(const ValueKey('point-detail-replace')));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await settle(tester);
    expect(find.text('参考图替换失败，请稍后重试。'), findsOneWidget);
  });

  for (final entry in {
    'small phone': TestSizes.phoneSmall,
    'landscape phone': TestSizes.phoneLandscape,
  }.entries) {
    testWidgets('modal details fit on ${entry.key} with text scale 2', (
      tester,
    ) async {
      await pumpGoApp(tester, size: entry.value, textScale: 2);
      await _openModal(tester);
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('point-detail-group')),
        100,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('point-detail-list-$_bridgeId')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await settle(tester);
      expect(tester.takeException(), isNull);
    });
  }
}
