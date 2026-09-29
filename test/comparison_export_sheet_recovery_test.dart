import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/data/sample_pilgrimage_repository.dart';
import 'package:miriago/plan/pilgrimage_models.dart';
import 'package:miriago/records/comparison_export_config.dart';
import 'package:miriago/records/comparison_export_result.dart';
import 'package:miriago/records/comparison_export_sheet.dart';
import 'package:miriago/widgets/image_viewer_screen.dart';

class _Repository extends SamplePilgrimageRepository {
  int loads = 0;
  int writes = 0;
  bool failLoad = false;
  bool failWrite = false;
  Completer<void>? pendingWrite;
  @override
  Future<AppSettings> loadAppSettings() async {
    loads++;
    if (failLoad) throw StateError('load');
    return super.loadAppSettings();
  }

  @override
  Future<void> saveAppSettings(AppSettings settings) async {
    writes++;
    await pendingWrite?.future;
    if (failWrite) throw StateError('write');
    return super.saveAppSettings(settings);
  }
}

class _Export {
  int calls = 0;
  bool fail = false;
  Completer<ComparisonExportImageResult>? pending;
  ComparisonExportImageResult result =
      const ComparisonExportImageResult.canceled();
  Future<ComparisonExportImageResult> call({
    required String? referenceImagePath,
    required String? referenceImageUrl,
    required String capturedPath,
    required ComparisonExportConfig config,
    required Map<ComparisonMetadataField, String> metadata,
    required String? colorGradingSummary,
  }) async {
    calls++;
    if (fail) throw StateError('export');
    return pending == null ? result : await pending!.future;
  }
}

Future<void> _open(
  WidgetTester tester,
  _Repository repo,
  _Export exporter,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () => ComparisonExportSheet.show(
                context,
                referenceImagePath: null,
                referenceImageUrl: null,
                capturedPath: 'missing.png',
                metadata: const {},
                colorGradingSummary: null,
                repository: repo,
                exporter: exporter.call,
              ),
              child: const Text('open'),
            );
          },
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void expectReady(WidgetTester tester) {
  expect(
    tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
    isNotNull,
  );
  expect(tester.takeException(), isNull);
}

void main() {
  testWidgets('show closes from top blank area while idle', (tester) async {
    await _open(tester, _Repository(), _Export());
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();
    expect(find.byType(ComparisonExportSheet), findsNothing);
  });

  testWidgets('show closes from header padding while idle', (tester) async {
    await _open(tester, _Repository(), _Export());
    final title = tester.getCenter(find.text('导出对比图').first);
    await tester.tapAt(Offset(8, title.dy));
    await tester.pumpAndSettle();
    expect(find.byType(ComparisonExportSheet), findsNothing);
  });

  for (final phase in ['settings', 'export']) {
    for (final exit in ['drag', 'barrier', 'system back']) {
      testWidgets(
        'show blocks $exit while $phase busy then allows explicit cancel',
        (tester) async {
          final repo = _Repository();
          final exporter = _Export();
          if (phase == 'settings') {
            repo.pendingWrite = Completer<void>();
          } else {
            exporter.pending = Completer<ComparisonExportImageResult>();
          }
          await _open(tester, repo, exporter);
          final bottomSheet = tester.widget<BottomSheet>(
            find.byType(BottomSheet),
          );
          expect(bottomSheet.enableDrag, isFalse);
          expect(bottomSheet.showDragHandle, isFalse);
          await tester.tap(find.byType(FilledButton));
          await tester.pump();
          expect(repo.writes, 1);
          expect(exporter.calls, phase == 'export' ? 1 : 0);
          switch (exit) {
            case 'drag':
              await tester.dragFrom(
                tester.getCenter(find.text('导出对比图').first),
                const Offset(0, 600),
              );
            case 'barrier':
              await tester.tapAt(const Offset(20, 20));
            case 'system back':
              await tester.binding.handlePopRoute();
          }
          await tester.pump(const Duration(milliseconds: 400));
          expect(find.byType(ComparisonExportSheet), findsOneWidget);
          expect(
            tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
            isNull,
          );
          expect(
            tester
                .widget<IconButton>(
                  find.byWidgetPredicate(
                    (widget) => widget is IconButton && widget.tooltip == '关闭',
                  ),
                )
                .onPressed,
            isNull,
          );
          if (phase == 'settings') {
            repo.pendingWrite!.completeError(StateError('settings failed'));
          } else {
            exporter.pending!.completeError(StateError('export failed'));
          }
          await tester.pumpAndSettle();
          expectReady(tester);
          await tester.tap(find.text('取消'));
          await tester.pumpAndSettle();
          expect(find.byType(ComparisonExportSheet), findsNothing);
          expect(exporter.calls, phase == 'export' ? 1 : 0);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('show allows system back while idle', (tester) async {
    final exporter = _Export();
    await _open(tester, _Repository(), exporter);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(ComparisonExportSheet), findsNothing);
    expect(exporter.calls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('forced dispose during export handles late cancellation', (
    tester,
  ) async {
    final exporter = _Export()
      ..pending = Completer<ComparisonExportImageResult>();
    await _open(tester, _Repository(), exporter);
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    expect(exporter.calls, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    exporter.pending!.complete(const ComparisonExportImageResult.canceled());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  for (final failure in ['load', 'write', 'export']) {
    testWidgets(
      '$failure failure releases exporting and allows a second attempt',
      (tester) async {
        final repo = _Repository()
          ..failLoad = failure == 'load'
          ..failWrite = failure == 'write';
        final exporter = _Export()..fail = failure == 'export';
        await _open(tester, repo, exporter);
        await tester.tap(find.byType(FilledButton));
        await tester.pumpAndSettle();
        expectReady(tester);
        expect(exporter.calls, failure == 'export' ? 1 : 0);
        repo.failLoad = false;
        repo.failWrite = false;
        exporter.fail = false;
        await tester.tap(find.byType(FilledButton));
        await tester.pumpAndSettle();
        expectReady(tester);
        expect(exporter.calls, failure == 'export' ? 2 : 1);
      },
    );
  }

  testWidgets(
    'typed budget failure retains precise message and retry controls',
    (tester) async {
      final exporter = _Export()
        ..result = const ComparisonExportImageResult.failure(
          ComparisonExportFailureReason.budgetExceeded,
          message: '16000001 > 16000000 pixels',
        );
      await _open(tester, _Repository(), exporter);
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(find.text('16000001 > 16000000 pixels'), findsOneWidget);
      expect(find.textContaining('不可用'), findsNothing);
      expectReady(tester);
    },
  );

  testWidgets('browser downloaded result closes sheet without local viewer', (
    tester,
  ) async {
    final exporter = _Export()
      ..result = const ComparisonExportImageResult.downloaded();
    await _open(tester, _Repository(), exporter);
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(find.byType(ComparisonExportSheet), findsNothing);
    expect(find.byType(ImageViewerScreen), findsNothing);
    expect(find.text('对比图已交给浏览器下载'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('forced dispose during settings write does not start export', (
    tester,
  ) async {
    final repo = _Repository()..pendingWrite = Completer<void>();
    final exporter = _Export();
    await _open(tester, repo, exporter);
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    expect(repo.writes, 1);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    repo.pendingWrite!.complete();
    await tester.pumpAndSettle();
    expect(exporter.calls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('local result pushes viewer using navigator after sheet pop', (
    tester,
  ) async {
    final exporter = _Export()
      ..result = const ComparisonExportImageResult.success('missing.png');
    await _open(tester, _Repository(), exporter);
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(find.byType(ComparisonExportSheet), findsNothing);
    expect(find.byType(ImageViewerScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
