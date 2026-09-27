import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:miriago/plan/pilgrimage_models.dart';
import 'package:miriago/ui/app/router.dart';
import 'package:miriago/ui/features/add/point_form_page.dart';

import 'add_test_helpers.dart';

Finder field(String key) => find.descendant(
  of: find.byKey(ValueKey(key)),
  matching: find.byType(EditableText),
);

Future<void> tapKey(WidgetTester tester, String key) async {
  final target = find.byKey(ValueKey(key));
  // Let keyboard-driven scroll animations finish (they ignore pointers).
  await settle(tester);
  await tester.ensureVisible(target);
  await settle(tester);
  await tester.tap(target);
  await settle(tester);
}

Future<void> tapSave(WidgetTester tester) async {
  await tapKey(tester, 'point-form-save');
}

void main() {
  testWidgets('only 作品 and 名称 are required; coordinates are paired', (
    tester,
  ) async {
    final repository = await pumpAddApp(tester, location: Routes.newPoint);
    expect(find.text('添加点位'), findsWidgets);
    expect(find.text('吹响吧！上低音号'), findsOneWidget);
    // 更多信息 starts collapsed for new points.
    expect(
      tester
          .widget<Offstage>(
            find
                .ancestor(
                  of: find.byKey(
                    const ValueKey('point-form-note'),
                    skipOffstage: false,
                  ),
                  matching: find.byType(Offstage),
                )
                .first,
          )
          .offstage,
      isTrue,
    );

    await tapSave(tester);
    expect(find.text('请填写此项'), findsOneWidget);
    expect(find.text('请填写纬度'), findsOneWidget);
    expect(find.text('请填写经度'), findsOneWidget);

    await tester.enterText(field('point-form-name'), '宇治橋');
    await tester.enterText(field('point-form-latitude'), '34.89');
    await tapSave(tester);
    expect(find.text('请同时填写经度'), findsOneWidget);

    await tester.enterText(field('point-form-longitude'), 'abc');
    await tapSave(tester);
    expect(find.text('经度格式不正确'), findsOneWidget);

    await tester.enterText(field('point-form-longitude'), '135.80');
    await tapSave(tester);
    expect(find.byType(PointFormPage), findsNothing);
    final plan = await activePlan(repository);
    final point = plan.points.firstWhere((p) => p.name == '宇治橋');
    expect(point.id, startsWith('manual-'));
    expect(point.position, const LatLng(34.89, 135.80));
    expect(point.referenceLabel, '手动录入');
    expect(point.source, PointSource.manual);
  });

  testWidgets('坐标待补充 saves a pending position', (tester) async {
    final repository = await pumpAddApp(tester, location: Routes.newPoint);
    await tester.enterText(field('point-form-name'), '未知地点');
    await tapKey(tester, 'point-form-pending');
    await tapSave(tester);
    final plan = await activePlan(repository);
    final point = plan.points.firstWhere((p) => p.name == '未知地点');
    expect(point.hasCoordinate, isFalse);
  });

  testWidgets('a plan without works creates the work inline', (tester) async {
    final repository = await pumpAddApp(
      tester,
      location: Routes.newPoint,
      repository: emptyPlanRepository(),
    );
    expect(find.byKey(const ValueKey('point-form-new-work')), findsOneWidget);
    await tester.enterText(field('point-form-name'), '丰乡小学');
    await tapKey(tester, 'point-form-pending');
    await tapSave(tester);
    expect(find.text('请填写此项'), findsOneWidget, reason: '作品名称 required');
    await tester.enterText(field('point-form-work-title'), '轻音少女');
    await tapSave(tester);
    final plan = await activePlan(repository);
    expect(plan.works.single.title, '轻音少女');
    expect(plan.works.single.id, startsWith('manual-work-'));
    expect(plan.points.single.work.id, plan.works.single.id);
  });

  testWidgets('edit prefills, expands 更多信息 and updates', (tester) async {
    final original = (await ScriptedRepository().loadActivePlan()).points.first;
    final repository = await pumpAddApp(
      tester,
      location: Routes.editPoint(original.id),
    );
    expect(find.text('编辑点位'), findsWidgets);
    expect(find.text('保存修改'), findsOneWidget);
    expect(
      tester.widget<EditableText>(field('point-form-name')).controller.text,
      original.name,
    );
    expect(
      tester
          .widget<Offstage>(
            find
                .ancestor(
                  of: find.byKey(
                    const ValueKey('point-form-note'),
                    skipOffstage: false,
                  ),
                  matching: find.byType(Offstage),
                )
                .first,
          )
          .offstage,
      isFalse,
    );
    await tester.enterText(field('point-form-name'), '新名字');
    await tapSave(tester);
    final plan = await activePlan(repository);
    final updated = plan.points.firstWhere((p) => p.id == original.id);
    expect(updated.name, '新名字');
    expect(updated.position, original.position);
  });

  testWidgets('uncertain new save locks the button with the old toast', (
    tester,
  ) async {
    final repository = ScriptedRepository()..failAfterAdd = true;
    await pumpAddApp(tester, location: Routes.newPoint, repository: repository);
    await tester.enterText(field('point-form-name'), 'X');
    await tapKey(tester, 'point-form-pending');
    await tapSave(tester);
    expect(find.text('保存结果未确认，请返回并刷新计划，检查点位是否已添加。'), findsOneWidget);
    expect(find.byType(PointFormPage), findsOneWidget);
    await tapSave(tester);
    expect(repository.addPointCalls, 1);
  });

  testWidgets('reference image: pick, status texts, remove', (tester) async {
    final images = FakeImageStore();
    await pumpAddApp(tester, location: Routes.newPoint, images: images);
    expect(find.text('可选，保存时会复制到 App 本地目录。'), findsOneWidget);
    final pick = find.byKey(const ValueKey('point-form-pick-image'));
    await tester.ensureVisible(pick);
    await tester.pump();
    await tester.tap(pick);
    await settle(tester);
    expect(find.text('已选择新图片，保存后生效。'), findsOneWidget);
    expect(find.text('重新选择'), findsOneWidget);
    await tapKey(tester, 'point-form-remove-image');
    await settle(tester);
    expect(find.text('可选，保存时会复制到 App 本地目录。'), findsOneWidget);
    expect(images.deleted, hasLength(1));
  });

  group('plan side navigation', () {
    testWidgets('cannot leave while a reference image is being picked', (
      tester,
    ) async {
      final images = FakeImageStore()..storeGate = Completer<void>();
      await pumpAddApp(
        tester,
        location: Routes.newPoint,
        size: TestSizes.desktop,
        images: images,
      );
      final pick = find.byKey(const ValueKey('point-form-pick-image'));
      await tester.ensureVisible(pick);
      await tester.pump();
      await tester.tap(pick);
      await settle(tester, frames: 2);
      await tester.tap(find.text('备忘录'));
      await settle(tester);
      expect(find.byType(PointFormPage), findsOneWidget);

      images.storeGate!.complete();
      await settle(tester);
      expect(find.text('已选择新图片，保存后生效。'), findsOneWidget);
      await tester.tap(find.text('备忘录'));
      await settle(tester);
      expect(find.byType(PointFormPage), findsNothing);
      // Leaving drops the unsaved draft image, like back.
      expect(images.deleted, hasLength(1));
    });

    testWidgets('cannot leave while saving', (tester) async {
      final repository = ScriptedRepository()..addGate = Completer<void>();
      await pumpAddApp(
        tester,
        location: Routes.newPoint,
        size: TestSizes.desktop,
        repository: repository,
      );
      await tester.enterText(field('point-form-name'), '新点位');
      await tester.enterText(field('point-form-latitude'), '34.89');
      await tester.enterText(field('point-form-longitude'), '135.80');
      await tapSave(tester);
      expect(repository.addPointCalls, 1);
      await tester.tap(find.text('备忘录'));
      await settle(tester);
      expect(find.byType(PointFormPage), findsOneWidget);
      repository.addGate!.complete();
      await settle(tester);
    });
  });
}
