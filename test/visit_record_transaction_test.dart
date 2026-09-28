import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/data/local/app_database.dart';
import 'package:miriago/data/local/sqlite_pilgrimage_repository.dart';
import 'package:miriago/data/pilgrimage_repository.dart';

void main() {
  for (final stage in ['insert', 'touch']) {
    test(
      'record $stage failure rolls back; retry creates exactly one record',
      () async {
        final database = AppDatabase(NativeDatabase.memory());
        addTearDown(database.close);
        final repository = SqlitePilgrimageRepository(database: database);
        final plan = await repository.createPlan(name: 'Atomic save', area: '');
        final before = await (database.select(database.plans)).getSingle();
        await database.customStatement(
          stage == 'insert'
              ? "CREATE TRIGGER fail_save BEFORE INSERT ON visit_records BEGIN SELECT RAISE(ABORT, 'insert failure'); END"
              : "CREATE TRIGGER fail_save BEFORE UPDATE ON plans BEGIN SELECT RAISE(ABORT, 'touch failure'); END",
        );
        Future<dynamic> save() => repository.createVisitRecord(
          planId: plan.id,
          pointId: 'point',
          workId: 'work',
          photoPath: '/test/owned/photo.jpg',
          referenceMode: 'test',
        );
        await expectLater(
          save(),
          throwsA(isA<VisitRecordNotCommittedException>()),
        );
        expect(await repository.loadVisitRecords(plan.id), isEmpty);
        expect(
          (await database.select(database.plans).getSingle()).updatedAt,
          before.updatedAt,
        );
        await database.customStatement('DROP TRIGGER fail_save');
        final record = await save();
        expect(
          (await repository.loadVisitRecords(plan.id)).single.id,
          record.id,
        );
      },
    );
  }
}
