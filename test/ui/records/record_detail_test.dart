import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/data/sample_pilgrimage_repository.dart';
import 'package:miriago/plan/pilgrimage_models.dart';
import 'package:miriago/ui/features/export/comparison_export.dart';

import '../../helpers/pump_app.dart';

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

class _DeleteRepository extends SamplePilgrimageRepository {
  Completer<void>? pendingDelete;
  bool failDelete = false;

  @override
  Future<void> deleteVisitRecord({
    required String planId,
    required String recordId,
  }) async {
    await pendingDelete?.future;
    if (failDelete) throw StateError('disk full');
    return super.deleteVisitRecord(planId: planId, recordId: recordId);
  }
}

const _recordId = 'sample-record-agata-01';

void main() {
  testWidgets('detail shows compare, info and actions', (tester) async {
    await pumpMiriaApp(
      tester,
      location: '/records/$_recordId',
      size: TestSizes.phone,
    );
    await _settle(tester);
    expect(find.text('记录详情'), findsOneWidget);
    expect(find.byKey(const ValueKey('record-photo-compare')), findsOneWidget);
    expect(find.text('拍摄时间'), findsOneWidget);
    expect(find.text('片区'), findsOneWidget);
    await tester.ensureVisible(
      find.byKey(const ValueKey('record-action-export')),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('导出对比图'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('delete asks for confirmation and removes the record', (
    tester,
  ) async {
    final repository = _DeleteRepository();
    await pumpMiriaApp(
      tester,
      location: '/records/$_recordId',
      repository: repository,
    );
    await _settle(tester);
    await tester.tap(find.byTooltip('删除记录'));
    await _settle(tester);
    expect(find.text('同时删除照片文件'), findsOneWidget);
    expect(find.textContaining('不会改变点位完成状态'), findsOneWidget);
    await tester.tap(find.text('删除').last);
    await _settle(tester);
    final records = await repository.loadVisitRecords(
      (await repository.loadActivePlan()).id,
    );
    expect(records.any((PilgrimageVisitRecord r) => r.id == _recordId), false);
    expect(find.text('记录详情'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed deletion keeps the page and shows the old message', (
    tester,
  ) async {
    final repository = _DeleteRepository()..failDelete = true;
    await pumpMiriaApp(
      tester,
      location: '/records/$_recordId',
      repository: repository,
    );
    await _settle(tester);
    await tester.tap(find.byTooltip('删除记录'));
    await _settle(tester);
    await tester.tap(find.text('删除').last);
    await _settle(tester);
    expect(find.text('删除记录失败，照片未删除，请重试'), findsOneWidget);
    expect(find.text('记录详情'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('export panel opens with every option and cancels', (
    tester,
  ) async {
    await pumpMiriaApp(
      tester,
      location: '/records/$_recordId',
      size: TestSizes.phone,
    );
    await _settle(tester);
    await tester.ensureVisible(
      find.byKey(const ValueKey('record-action-export')),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byKey(const ValueKey('record-action-export')));
    await _settle(tester);
    expect(find.byType(ComparisonExportPanel), findsOneWidget);
    expect(find.text('边框宽度'), findsOneWidget);
    expect(find.text('白色'), findsOneWidget);
    expect(find.text('黑色'), findsOneWidget);
    expect(find.text('主题色'), findsOneWidget);
    expect(find.text('自动输出宽度'), findsOneWidget);
    expect(find.text('显示标签'), findsOneWidget);
    await tester.ensureVisible(find.text('Anitabi ID'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('显示内容'), findsOneWidget);
    expect(find.text('Anitabi ID'), findsOneWidget);
    expect(find.text('图片格式与质量'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('comparison-export-cancel')));
    await _settle(tester);
    expect(find.byType(ComparisonExportPanel), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('system back closes the idle export panel', (tester) async {
    await pumpMiriaApp(
      tester,
      location: '/records/$_recordId',
      size: TestSizes.phone,
    );
    await _settle(tester);
    await tester.ensureVisible(
      find.byKey(const ValueKey('record-action-export')),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byKey(const ValueKey('record-action-export')));
    await _settle(tester);
    expect(find.byType(ComparisonExportPanel), findsOneWidget);
    // Not dismissible by tapping outside.
    await tester.tapAt(const Offset(20, 20));
    await _settle(tester);
    expect(find.byType(ComparisonExportPanel), findsOneWidget);
    await tester.binding.handlePopRoute();
    await _settle(tester);
    expect(find.byType(ComparisonExportPanel), findsNothing);
    expect(find.text('记录详情'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('export panel on desktop has a preview and no overflow', (
    tester,
  ) async {
    await pumpMiriaApp(
      tester,
      location: '/records/$_recordId',
      size: TestSizes.desktop,
    );
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('record-action-export')));
    await _settle(tester);
    expect(find.text('预览'), findsOneWidget);
    await tester.tap(find.byTooltip('关闭'));
    await _settle(tester);
    expect(find.byType(ComparisonExportPanel), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('detail has no overflow on a small phone at 2.0 text', (
    tester,
  ) async {
    await pumpMiriaApp(
      tester,
      location: '/records/$_recordId',
      size: TestSizes.phoneSmall,
      textScale: 2.0,
    );
    await _settle(tester);
    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -800));
    await _settle(tester);
    expect(tester.takeException(), isNull);
  });
}
