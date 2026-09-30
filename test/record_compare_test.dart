import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/app_theme.dart';
import 'package:miriago/data/sample_pilgrimage_repository.dart';
import 'package:miriago/plan/pilgrimage_models.dart';
import 'package:miriago/plan/pilgrimage_plan_controller.dart';
import 'package:miriago/records/photo_compare_slider.dart';
import 'package:miriago/records/records_screen.dart';
import 'package:miriago/records/visit_record_detail_screen.dart';
import 'package:miriago/settings/app_settings_updater.dart';

PilgrimageVisitRecord _record(
  String id, {
  bool graded = false,
  String? referenceImageUrl =
      'https://image.anitabi.cn/points/115908/qys7fu.jpg',
}) {
  final point = samplePilgrimagePlan.points.first;
  return PilgrimageVisitRecord(
    id: id,
    planId: samplePilgrimagePlan.id,
    pointId: point.id,
    workId: point.work.id,
    photoPath: '/missing/$id.jpg',
    gradedPhotoPath: graded ? '/missing/$id-graded.jpg' : null,
    colorGradingParamsJson: graded ? '{}' : null,
    referenceImageUrl: referenceImageUrl,
    referenceMode: 'overlay',
    capturedAt: DateTime(2026, 6, 1, 10),
  );
}

void main() {
  group('PhotoCompareSlider', () {
    Future<List<String>> pumpSlider(WidgetTester tester) async {
      final taps = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: 400,
              child: PhotoCompareSlider(
                reference: const ColoredBox(color: Colors.red),
                photo: const ColoredBox(color: Colors.blue),
                onTapReference: () => taps.add('reference'),
                onTapPhoto: () => taps.add('photo'),
              ),
            ),
          ),
        ),
      );
      return taps;
    }

    String value(WidgetTester tester) => tester
        .getSemantics(find.byKey(const ValueKey('photo-compare-slider')))
        .value;

    testWidgets('dragging moves the divider', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpSlider(tester);
      expect(value(tester), '50%');
      final slider = find.byKey(const ValueKey('photo-compare-slider'));
      final left = tester.getTopLeft(slider);
      await tester.dragFrom(tester.getCenter(slider), const Offset(100, 0));
      await tester.pump();
      expect(value(tester), '75%');
      await tester.dragFrom(
        left + const Offset(200, 50),
        const Offset(-500, 0),
      );
      await tester.pump();
      expect(value(tester), '0%');
      handle.dispose();
    });

    testWidgets('arrow keys move the divider', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpSlider(tester);
      final focus = find.descendant(
        of: find.byKey(const ValueKey('photo-compare-slider')),
        matching: find.byType(Focus),
      );
      Focus.of(tester.element(find.byType(Stack).last)).requestFocus();
      expect(focus, findsWidgets);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(value(tester), '55%');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(value(tester), '45%');
      handle.dispose();
    });

    testWidgets('taps open the side that was tapped', (tester) async {
      final taps = await pumpSlider(tester);
      final slider = find.byKey(const ValueKey('photo-compare-slider'));
      final left = tester.getTopLeft(slider);
      await tester.tapAt(left + const Offset(50, 50));
      await tester.tapAt(left + const Offset(350, 50));
      expect(taps, ['reference', 'photo']);
    });
  });

  group('record detail compare mode', () {
    tearDown(() => AppSettingsUpdater.handler = null);

    Future<void> pumpDetail(
      WidgetTester tester,
      PilgrimageVisitRecord record, {
      AppSettings settings = const AppSettings(),
      bool withPoint = true,
    }) async {
      final repository = SamplePilgrimageRepository(visitRecords: [record]);
      final controller = PilgrimagePlanController(
        plan: samplePilgrimagePlan,
        visitRepository: repository,
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: VisitRecordDetailScreen(
            record: record,
            point: withPoint ? samplePilgrimagePlan.points.first : null,
            controller: controller,
            settings: settings,
            onDelete: () async {},
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('switching to the slider is remembered', (tester) async {
      AppSettings stored = const AppSettings();
      AppSettingsUpdater.handler = (update) async {
        stored = update(stored);
        return true;
      };
      await pumpDetail(tester, _record('r1'));
      expect(find.byKey(const ValueKey('record-compare-stacked')), findsOne);

      await tester.tap(find.text('滑动对比'));
      await tester.pumpAndSettle();
      expect(find.byType(PhotoCompareSlider), findsOneWidget);
      expect(stored.recordCompareMode, RecordCompareMode.slider);
    });

    testWidgets('opens in the remembered mode', (tester) async {
      await pumpDetail(
        tester,
        _record('r1'),
        settings: const AppSettings(
          recordCompareMode: RecordCompareMode.slider,
        ),
      );
      expect(find.byType(PhotoCompareSlider), findsOneWidget);
    });

    testWidgets('a failed save goes back to the previous mode', (tester) async {
      AppSettingsUpdater.handler = (_) async => false;
      await pumpDetail(tester, _record('r1'));
      await tester.tap(find.text('滑动对比'));
      await tester.pumpAndSettle();
      expect(find.byType(PhotoCompareSlider), findsNothing);
      expect(find.byKey(const ValueKey('record-compare-stacked')), findsOne);
    });

    testWidgets('without a reference there is no slider', (tester) async {
      await pumpDetail(
        tester,
        _record('r1', referenceImageUrl: null),
        settings: const AppSettings(
          recordCompareMode: RecordCompareMode.slider,
        ),
        // The point's own reference would otherwise be used.
        withPoint: false,
      );
      expect(find.byKey(const ValueKey('record-compare-mode')), findsNothing);
      expect(find.byType(PhotoCompareSlider), findsNothing);
    });
  });

  testWidgets('records list marks graded records', (tester) async {
    final repository = SamplePilgrimageRepository(
      visitRecords: [_record('plain'), _record('graded', graded: true)],
    );
    final controller = PilgrimagePlanController(
      plan: samplePilgrimagePlan,
      visitRepository: repository,
    );
    addTearDown(controller.dispose);
    await tester.runAsync(controller.loadVisitRecords);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: RecordsScreen(
          controller: controller,
          settings: const AppSettings(),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('record-graded-badge-graded')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('record-graded-badge-plain')),
      findsNothing,
    );
    expect(find.byTooltip('已调色'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
