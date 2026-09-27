import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/application/plan_session.dart';
import 'package:miriago/ui/features/points/point_records_page.dart';
import 'package:provider/provider.dart';

import '../go/go_test_helpers.dart';

const _currentId = 'anitabi-115908-7evkbmy2'; // 2 records in the sample

void main() {
  testWidgets('lists the records of a point with time, date and tags', (
    tester,
  ) async {
    await pumpGoApp(tester, location: '/records/point/$_currentId');
    expect(tester.takeException(), isNull);
    expect(find.text('点位拍摄记录'), findsOneWidget);
    final session = tester
        .element(find.byType(PointRecordsPage))
        .read<PlanSession>();
    final records = session.controller.recordsForPoint(_currentId);
    expect(records, isNotEmpty);
    expect(find.byKey(const ValueKey('point-records-count')), findsOneWidget);
    expect(find.textContaining('${records.length}'), findsWidgets);
    expect(find.text('拍摄记录'), findsOneWidget);
    final first = records.first;
    String two(int value) => value.toString().padLeft(2, '0');
    expect(
      find.text(
        '${two(first.capturedAt.hour)}:${two(first.capturedAt.minute)}',
      ),
      findsWidgets,
    );
    expect(find.text(first.referenceMode), findsWidgets);
  });

  testWidgets('shows the empty state for a point without records', (
    tester,
  ) async {
    await pumpGoApp(tester, location: '/records/point/anitabi-115908-3plnxvy');
    final session = tester
        .element(find.byType(PointRecordsPage))
        .read<PlanSession>();
    if (session.controller.recordsForPoint('anitabi-115908-3plnxvy').isEmpty) {
      expect(find.text('这个点位还没有拍摄记录'), findsOneWidget);
    }
  });

  for (final size in [TestSizes.phoneSmall, TestSizes.phoneLandscape]) {
    testWidgets('fits $size with text scale 2', (tester) async {
      await pumpGoApp(
        tester,
        location: '/records/point/$_currentId',
        size: size,
        textScale: 2,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
