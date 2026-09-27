import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/data/sample_pilgrimage_repository.dart';
import 'package:miriago/plan/pilgrimage_models.dart';
import 'package:miriago/plan_transfer/my_maps_csv_export.dart';

void main() {
  test('skips points whose coordinates are still pending', () async {
    final repository = SamplePilgrimageRepository();
    final plan = await repository.loadActivePlan();
    final positionedPoint = plan.points.first;
    final pendingPoint = positionedPoint.copyWith(
      id: 'pending-coordinate',
      name: '待补充坐标',
      position: PilgrimagePoint.pendingPosition,
    );

    final result = buildMyMapsCsvExport(
      plan: plan.copyWith(points: [positionedPoint, pendingPoint]),
      exportedAt: DateTime.utc(2026, 7, 27),
    );
    final csv = utf8.decode(result.bytes);

    expect(csv, contains(positionedPoint.name));
    expect(csv, isNot(contains(pendingPoint.name)));
    expect(csv, isNot(contains(',-90.0000000,0.0000000,')));
    expect(result.skippedPointCount, 1);
  });
}
