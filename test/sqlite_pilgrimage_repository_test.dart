import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seichi_junrei_helper/data/local/app_database.dart';
import 'package:seichi_junrei_helper/data/local/sqlite_pilgrimage_repository.dart';
import 'package:seichi_junrei_helper/plan/pilgrimage_models.dart';

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

  test('deletes current point and promotes first pending point', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final repository = SqlitePilgrimageRepository(database: database);
    final plan = await repository.loadActivePlan();

    await repository.setCurrentPoint(
      planId: plan.id,
      pointId: plan.points.first.id,
    );

    final updatedPlan = await repository.deletePointFromPlan(
      planId: plan.id,
      pointId: plan.points.first.id,
    );

    expect(
      updatedPlan.points.map((point) => point.id),
      isNot(contains(plan.points.first.id)),
    );
    expect(updatedPlan.currentPointId, plan.points[1].id);
  });

  test('persists reordered point sequence', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final repository = SqlitePilgrimageRepository(database: database);
    final plan = await repository.loadActivePlan();
    final reorderedIds = [
      plan.points[2].id,
      plan.points[0].id,
      plan.points[1].id,
      plan.points[3].id,
    ];

    await repository.reorderPoints(planId: plan.id, pointIds: reorderedIds);

    final reloadedPlan = await repository.loadActivePlan();

    expect(reloadedPlan.points.map((point) => point.id), reorderedIds);
  });

  test('renames plans and persists app settings', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final repository = SqlitePilgrimageRepository(database: database);
    final plan = await repository.loadActivePlan();

    await repository.renamePlan(planId: plan.id, name: '改名后的计划');
    await repository.saveAppSettings(
      const AppSettings(
        uiScale: 1.5,
        cameraAspectRatio: CameraPhotoAspectRatio.square1x1,
      ),
    );

    final reloadedPlan = await repository.loadActivePlan();
    final settings = await repository.loadAppSettings();

    expect(reloadedPlan.name, '改名后的计划');
    expect(settings.uiScale, 1.5);
    expect(settings.cameraAspectRatio, CameraPhotoAspectRatio.square1x1);
  });

  test('deletes work with related points and visit records', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final repository = SqlitePilgrimageRepository(database: database);
    final plan = await repository.loadActivePlan();
    final work = plan.works.first;
    final point = plan.points.firstWhere((point) => point.work.id == work.id);

    await repository.createVisitRecord(
      planId: plan.id,
      pointId: point.id,
      workId: work.id,
      photoPath: '/tmp/photo.jpg',
      referenceMode: '小窗',
    );

    final updatedPlan = await repository.deleteWorkFromPlan(
      planId: plan.id,
      workId: work.id,
    );
    final records = await repository.loadVisitRecords(plan.id);

    expect(updatedPlan.works.map((work) => work.id), isNot(contains(work.id)));
    expect(
      updatedPlan.points.map((point) => point.work.id),
      isNot(contains(work.id)),
    );
    expect(records, isEmpty);
  });

  test('reopens completed point as current target', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final repository = SqlitePilgrimageRepository(database: database);
    final plan = await repository.loadActivePlan();

    await repository.completePoint(
      planId: plan.id,
      pointId: plan.points.first.id,
      nextCurrentPointId: plan.points[1].id,
    );
    await repository.reopenPoint(
      planId: plan.id,
      pointId: plan.points.first.id,
    );

    final reloadedPlan = await repository.loadActivePlan();

    expect(
      reloadedPlan.completedPointIds,
      isNot(contains(plan.points.first.id)),
    );
    expect(reloadedPlan.currentPointId, plan.points.first.id);
  });

  test('persists visit records for captured photos', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final repository = SqlitePilgrimageRepository(database: database);
    final plan = await repository.loadActivePlan();
    final point = plan.points.first;

    final record = await repository.createVisitRecord(
      planId: plan.id,
      pointId: point.id,
      workId: point.work.id,
      photoPath: '/tmp/photo.jpg',
      referenceImagePath: '/tmp/reference.jpg',
      referenceImageUrl: 'https://example.com/reference.jpg',
      referenceMode: '叠影',
    );

    final records = await repository.loadVisitRecords(plan.id);

    expect(records, hasLength(1));
    expect(records.single.id, record.id);
    expect(records.single.pointId, point.id);
    expect(records.single.photoPath, '/tmp/photo.jpg');
    expect(records.single.referenceImagePath, '/tmp/reference.jpg');
    expect(
      records.single.referenceImageUrl,
      'https://example.com/reference.jpg',
    );
    expect(records.single.referenceMode, '叠影');
  });

  test('deletes visit records without changing point completion', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final repository = SqlitePilgrimageRepository(database: database);
    final plan = await repository.loadActivePlan();
    final point = plan.points.first;

    final record = await repository.createVisitRecord(
      planId: plan.id,
      pointId: point.id,
      workId: point.work.id,
      photoPath: '/tmp/photo.jpg',
      referenceMode: '小窗',
    );
    await repository.completePoint(
      planId: plan.id,
      pointId: point.id,
      nextCurrentPointId: plan.points[1].id,
    );
    await repository.deleteVisitRecord(planId: plan.id, recordId: record.id);

    final records = await repository.loadVisitRecords(plan.id);
    final reloadedPlan = await repository.loadActivePlan();

    expect(records, isEmpty);
    expect(reloadedPlan.completedPointIds, contains(point.id));
  });

  test('bulk completes points and promotes next pending target', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final repository = SqlitePilgrimageRepository(database: database);
    final plan = await repository.loadActivePlan();
    final completedIds = {plan.points[0].id, plan.points[1].id};

    await repository.setCurrentPoint(
      planId: plan.id,
      pointId: plan.points.first.id,
    );
    await repository.completePoints(planId: plan.id, pointIds: completedIds);

    final reloadedPlan = await repository.loadActivePlan();

    expect(reloadedPlan.completedPointIds, containsAll(completedIds));
    expect(reloadedPlan.currentPointId, plan.points[2].id);
  });

  test('bulk deletes points and promotes next pending target', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final repository = SqlitePilgrimageRepository(database: database);
    final plan = await repository.loadActivePlan();
    final deletedIds = {plan.points[0].id, plan.points[1].id};

    await repository.setCurrentPoint(
      planId: plan.id,
      pointId: plan.points.first.id,
    );
    final updatedPlan = await repository.deletePointsFromPlan(
      planId: plan.id,
      pointIds: deletedIds,
    );

    expect(
      updatedPlan.points.map((point) => point.id),
      isNot(contains(plan.points[0].id)),
    );
    expect(
      updatedPlan.points.map((point) => point.id),
      isNot(contains(plan.points[1].id)),
    );
    expect(updatedPlan.currentPointId, plan.points[2].id);
  });

  test('bulk reopens points and uses first selected point as target', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final repository = SqlitePilgrimageRepository(database: database);
    final plan = await repository.loadActivePlan();
    final reopenedIds = {plan.points[0].id, plan.points[1].id};

    await repository.completePoints(planId: plan.id, pointIds: reopenedIds);
    await repository.reopenPoints(planId: plan.id, pointIds: reopenedIds);

    final reloadedPlan = await repository.loadActivePlan();

    expect(reloadedPlan.completedPointIds, isNot(contains(plan.points[0].id)));
    expect(reloadedPlan.completedPointIds, isNot(contains(plan.points[1].id)));
    expect(reloadedPlan.currentPointId, plan.points.first.id);
  });

  test('imports plan package as active plan with records', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final repository = SqlitePilgrimageRepository(database: database);
    final plan = await repository.loadActivePlan();
    final point = plan.points.first;
    await repository.completePoint(
      planId: plan.id,
      pointId: point.id,
      nextCurrentPointId: plan.points[1].id,
    );
    final record = await repository.createVisitRecord(
      planId: plan.id,
      pointId: point.id,
      workId: point.work.id,
      photoPath: '/tmp/photo.jpg',
      referenceMode: '叠影',
    );
    final exportedPlan = await repository.loadActivePlan();

    final imported = await repository.importPlanPackage(
      plan: exportedPlan,
      visitRecords: [record],
    );
    final active = await repository.loadActivePlan();
    final records = await repository.loadVisitRecords(active.id);

    expect(imported.id, isNot(plan.id));
    expect(active.id, imported.id);
    expect(active.name, '${exportedPlan.name} (2)');
    expect(
      active.points.map((point) => point.name),
      plan.points.map((point) => point.name),
    );
    expect(active.completedPointIds, contains(active.points.first.id));
    expect(active.currentPointId, active.points[1].id);
    expect(records, hasLength(1));
    expect(records.single.planId, imported.id);
    expect(records.single.pointId, active.points.first.id);
  });
}
