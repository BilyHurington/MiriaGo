import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seichi_junrei_helper/data/local/app_database.dart';
import 'package:seichi_junrei_helper/data/local/sqlite_pilgrimage_repository.dart';

void main() {
  test('persists completed point and next current target', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final repository = SqlitePilgrimageRepository(database: database);
    final plan = await repository.loadActivePlan();

    await repository.completePoint(
      planId: plan.id,
      pointId: plan.points.first.id,
      nextCurrentPointId: plan.points[1].id,
    );

    final reloadedPlan = await repository.loadActivePlan();

    expect(reloadedPlan.completedPointIds, contains(plan.points.first.id));
    expect(reloadedPlan.currentPointId, plan.points[1].id);
  });
}
