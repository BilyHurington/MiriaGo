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

  test('escapes formulas and cell references but keeps plain names', () async {
    final plan = await SamplePilgrimageRepository().loadActivePlan();
    final base = plan.points.first;
    const names = {
      '=HYPERLINK("x")': "'=HYPERLINK(\"\"x\"\")",
      '+A1': "'+A1",
      r'-$B$2+1': r"'-$B$2+1",
      '-A1+B1': "'-A1+B1",
      '+1+2': "'+1+2",
      '+81 Cafe': '+81 Cafe',
      '-Tokyo-': '-Tokyo-',
      '+Anime': '+Anime',
      '-ABCD1 Exit': '-ABCD1 Exit',
    };
    final result = buildMyMapsCsvExport(
      plan: plan.copyWith(
        points: [
          for (final (index, name) in names.keys.indexed)
            base.copyWith(id: 'p$index', name: name),
        ],
      ),
      exportedAt: DateTime.utc(2026, 9, 28),
    );
    final lines = const LineSplitter().convert(utf8.decode(result.bytes));
    for (final MapEntry(key: name, value: cell) in names.entries) {
      final escaped = cell.contains('"') ? '"$cell"' : cell;
      expect(
        lines.any((line) => line.startsWith('$escaped,')),
        isTrue,
        reason: name,
      );
    }
  });
}
