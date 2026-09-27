import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/plan_transfer/plan_import_package.dart';
import 'package:miriago/plan_transfer/plan_package.dart';
import 'package:miriago/ui/features/transfer/import_preview_page.dart';
import 'package:miriago/ui/features/transfer/transfer_page.dart';

import '../../helpers/pump_app.dart';

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

void main() {
  testWidgets('transfer page shows import, package options and estimate', (
    tester,
  ) async {
    await pumpMiriaApp(tester, location: '/plan/transfer');
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await _settle(tester);
    expect(find.byType(TransferPage), findsOneWidget);
    expect(find.text('导入 MiriaGo 文件'), findsOneWidget);
    expect(find.text('支持 v2 数据包和旧版 v1 JSON 计划包。'), findsOneWidget);
    expect(find.text('纯计划'), findsOneWidget);
    expect(find.text('计划+记录'), findsOneWidget);
    expect(find.text('包含完整参考图缓存'), findsOneWidget);
    expect(find.text('导出 MiriaGo 数据包'), findsOneWidget);
    expect(find.text('导出 My Maps CSV'), findsOneWidget);
    expect(find.textContaining(' 个片区 / '), findsOneWidget);
    final estimate = tester.widget<Text>(
      find.byKey(const ValueKey('export-size-estimate')),
    );
    expect(estimate.data, startsWith('预计数据包大小'));

    await tester.tap(find.text('计划+记录'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await _settle(tester);
    expect(tester.takeException(), isNull);
  });

  for (final size in [TestSizes.phoneSmall, TestSizes.desktop]) {
    testWidgets('transfer page has no overflow at $size, text scale 2', (
      tester,
    ) async {
      await pumpMiriaApp(
        tester,
        location: '/plan/transfer',
        size: size,
        textScale: 2,
      );
      await _settle(tester);
      expect(find.byType(TransferPage), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('import preview imports a v1 package and pops true', (
    tester,
  ) async {
    final repository = await pumpMiriaApp(tester, location: '/plan/transfer');
    final plan = await repository.loadActivePlan();
    final before = (await repository.loadPlans()).length;
    final package = readPlanImportPackageFromBytes(
      utf8.encode(
        PlanPackage(plan: plan, visitRecords: const []).toJsonString(),
      ),
      sourceName: 'shared.sjhplan',
    );
    bool? result;
    final context = tester.element(find.byType(TransferPage));
    openImportPreview(context, package).then((value) => result = value);
    await _settle(tester);

    expect(find.byType(ImportPreviewPage), findsOneWidget);
    expect(find.textContaining('shared.sjhplan'), findsOneWidget);
    expect(find.text('计划结构'), findsOneWidget);
    expect(find.text('v1 文件不包含照片资源，仅导入计划结构。'), findsOneWidget);
    expect(find.text('这个包里没有可恢复的资源文件。'), findsOneWidget);
    expect(find.text('点位 ${plan.points.length}'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('import-selected-button')));
    await _settle(tester);
    expect(result, isTrue);
    expect((await repository.loadPlans()).length, before + 1);
    expect(find.textContaining('已导入计划「'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('import preview has no overflow on a small phone', (
    tester,
  ) async {
    final repository = await pumpMiriaApp(
      tester,
      location: '/plan/transfer',
      size: TestSizes.phoneSmall,
      textScale: 2,
    );
    final plan = await repository.loadActivePlan();
    final package = readPlanImportPackageFromBytes(
      utf8.encode(
        PlanPackage(plan: plan, visitRecords: const []).toJsonString(),
      ),
      sourceName: 'a-very-long-package-file-name-from-chat.sjhplan',
    );
    openImportPreview(tester.element(find.byType(TransferPage)), package);
    await _settle(tester);
    expect(find.byType(ImportPreviewPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
