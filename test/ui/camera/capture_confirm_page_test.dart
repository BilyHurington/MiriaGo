import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/application/capture/visit_record_commit.dart';
import 'package:miriago/camera_reference/photo_location.dart';
import 'package:miriago/plan/pilgrimage_models.dart';
import 'package:miriago/ui/features/camera/capture_confirm_page.dart';

import '../../helpers/pump_app.dart' show TestSizes;
import 'camera_test_harness.dart';

class _Launcher extends StatelessWidget {
  const _Launcher({required this.onResult, required this.builder});

  final ValueChanged<VisitRecordConfirmationResult?> onResult;
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: TextButton(
          onPressed: () async {
            final result = await Navigator.of(context)
                .push<VisitRecordConfirmationResult>(
                  MaterialPageRoute(builder: builder),
                );
            onResult(result);
          },
          child: const Text('打开确认'),
        ),
      ),
    );
  }
}

void main() {
  late FeatureTestStores stores;

  Future<List<VisitRecordConfirmationResult?>> pumpConfirm(
    WidgetTester tester, {
    Size size = TestSizes.phone,
    double textScale = 1,
    PhotoLocationStrategy strategy = PhotoLocationStrategy.disabled,
    Future<PhotoLocationData> Function()? resolve,
  }) async {
    setTestWindow(tester, size, textScale: textScale);
    stores = await FeatureTestStores.load();
    final controller = stores.session.controller;
    final point = controller.plan.points.first;
    final results = <VisitRecordConfirmationResult?>[];
    await tester.pumpWidget(
      featureTestApp(
        stores: stores,
        home: _Launcher(
          onResult: results.add,
          builder: (_) => CaptureConfirmPage(
            retainPhotoPreview: (_, _) async {},
            commit: VisitRecordCommit(
              point: point,
              controller: controller,
              photoPath: '/draft/capture.jpg',
              referenceMode: '叠影',
              photoLocationStrategy: strategy,
              resolvePhotoLocation: resolve,
              writePhotoLocation: (_, _) async => true,
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开确认'));
    // A spinner may run (location), so pump the route transition only.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    return results;
  }

  for (final (size, scale) in [
    (TestSizes.phone, 1.0),
    (TestSizes.desktop, 1.0),
    (TestSizes.tablet, 1.0),
    (TestSizes.phoneLandscape, 1.0),
    (TestSizes.phoneLandscape, 2.0),
    (TestSizes.phoneSmall, 2.0),
  ]) {
    testWidgets('renders at $size x$scale', (tester) async {
      await pumpConfirm(tester, size: size, textScale: scale);
      expect(tester.takeException(), isNull);
      expect(find.text('确认记录'), findsOneWidget);
      expect(find.text('参考模式'), findsOneWidget);
      expect(find.text('叠影'), findsOneWidget);
      // Labels may collapse to their short form on tiny windows.
      for (final key in [
        'capture-confirm-save',
        'capture-confirm-complete',
        'capture-confirm-cancel',
      ]) {
        expect(find.byKey(ValueKey(key)), findsOneWidget);
      }
    });
  }

  testWidgets('cancel returns null', (tester) async {
    final results = await pumpConfirm(tester);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(results, [null]);
  });

  testWidgets('保存记录 returns saved and shows the message', (tester) async {
    final results = await pumpConfirm(tester);
    await tester.tap(find.text('保存记录'));
    await tester.pumpAndSettle();
    expect(results, [VisitRecordConfirmationResult.saved]);
    expect(toastTitles(stores), ['记录已保存']);
    clearToasts(stores);
  });

  testWidgets('保存并标记完成 returns completed', (tester) async {
    final results = await pumpConfirm(tester);
    await tester.tap(find.text('保存并标记完成'));
    await tester.pumpAndSettle();
    expect(results, [VisitRecordConfirmationResult.completed]);
    expect(toastTitles(stores).single, startsWith('已保存并标记完成'));
    clearToasts(stores);
  });

  testWidgets('waiting for a location blocks saving until skipped', (
    tester,
  ) async {
    final location = Completer<PhotoLocationData>();
    await pumpConfirm(
      tester,
      strategy: PhotoLocationStrategy.waitOnConfirmation,
      resolve: () => location.future,
    );
    expect(find.text('正在获取拍摄位置...'), findsOneWidget);
    await tester.tap(find.text('保存记录'));
    await tester.pump();
    expect(find.text('确认记录'), findsOneWidget);
    await tester.tap(find.text('跳过'));
    await tester.pump();
    expect(find.text('已跳过定位，本次不添加位置，保留照片原有信息。'), findsOneWidget);
    expect(find.text('跳过'), findsNothing);
    location.complete(
      PhotoLocationData(
        latitude: 35,
        longitude: 139,
        accuracy: 5,
        timestamp: DateTime(2026, 8, 13),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('已跳过定位，本次不添加位置，保留照片原有信息。'), findsOneWidget);
  });
}
