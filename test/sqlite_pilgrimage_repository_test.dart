import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/data/local/app_database.dart';
import 'package:miriago/data/local/sqlite_pilgrimage_repository.dart';
import 'package:miriago/plan/pilgrimage_models.dart';

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
      plan.points[4].id,
      plan.points[5].id,
    ];

    await repository.reorderPoints(planId: plan.id, pointIds: reorderedIds);

    final reloadedPlan = await repository.loadActivePlan();

    expect(reloadedPlan.points.map((point) => point.id), reorderedIds);
    expect(reloadedPlan.currentPointId, plan.currentPointId);
  });

  test('sets first added point as current target for empty plan', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final repository = SqlitePilgrimageRepository(database: database);
    final sourcePlan = await repository.loadActivePlan();
    final emptyPlan = await repository.createPlan(name: '空计划', area: '京都');

    final updatedPlan = await repository.addPointToPlan(
      planId: emptyPlan.id,
      point: sourcePlan.points.first,
    );

    expect(updatedPlan.points, hasLength(1));
    expect(updatedPlan.currentPointId, sourcePlan.points.first.id);
  });

  test('repairs missing current target when loading persisted plan', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final repository = SqlitePilgrimageRepository(database: database);
    final sourcePlan = await repository.loadActivePlan();
    final emptyPlan = await repository.createPlan(name: '旧数据', area: '京都');
    final addedPlan = await repository.addPointToPlan(
      planId: emptyPlan.id,
      point: sourcePlan.points.first,
    );
    await database
        .update(database.points)
        .write(const PointsCompanion(isCurrent: Value(false)));

    final reloadedPlan = await repository.loadActivePlan();

    expect(reloadedPlan.currentPointId, addedPlan.points.first.id);
  });

  test('keeps current target when updating cached reference image', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final repository = SqlitePilgrimageRepository(database: database);
    final sourcePlan = await repository.loadActivePlan();
    final emptyPlan = await repository.createPlan(name: '缓存测试', area: '京都');
    final addedPlan = await repository.addPointToPlan(
      planId: emptyPlan.id,
      point: sourcePlan.points.first,
    );

    final updatedPlan = await repository.updatePointImageCache(
      planId: addedPlan.id,
      pointId: addedPlan.points.first.id,
      referenceThumbnailPath: addedPlan.points.first.referenceThumbnailPath,
      referenceFullImagePath: '/tmp/reference-full.jpg',
    );

    expect(updatedPlan.currentPointId, addedPlan.points.first.id);
    expect(
      updatedPlan.points.first.referenceFullImagePath,
      '/tmp/reference-full.jpg',
    );
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
        cameraCaptureAspectRatio: CameraPhotoAspectRatio.photo3x2,
        cameraFallbackAspectRatio: CameraPhotoAspectRatio.standard4x3,
      ),
    );

    final reloadedPlan = await repository.loadActivePlan();
    final settings = await repository.loadAppSettings();

    expect(reloadedPlan.name, '改名后的计划');
    expect(settings.uiScale, 1.5);
    expect(settings.cameraCaptureAspectRatio, CameraPhotoAspectRatio.photo3x2);
    expect(
      settings.cameraFallbackAspectRatio,
      CameraPhotoAspectRatio.standard4x3,
    );
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

  test('persists color grading metadata for visit records', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final repository = SqlitePilgrimageRepository(database: database);
    final plan = await repository.loadActivePlan();
    final point = plan.points.first;

    final record = await repository.createVisitRecord(
      planId: plan.id,
      pointId: point.id,
      workId: point.work.id,
      photoPath: '/tmp/original.jpg',
      referenceMode: '叠影',
    );

    await repository.updateVisitRecordColorGrading(
      planId: plan.id,
      recordId: record.id,
      originalPhotoPath: '/tmp/original.jpg',
      gradedPhotoPath: '/tmp/graded.jpg',
      colorGradingMode: 'strong',
      colorGradingParamsJson: '{"exposure":0.2}',
      colorGradingIntensity: 0.7,
    );

    final records = await repository.loadVisitRecords(plan.id);

    expect(records.single.sourcePhotoPath, '/tmp/original.jpg');
    expect(records.single.displayPhotoPath, '/tmp/graded.jpg');
    expect(records.single.colorGradingMode, 'strong');
    expect(records.single.colorGradingParamsJson, '{"exposure":0.2}');
    expect(records.single.colorGradingIntensity, 0.7);

    await repository.clearVisitRecordColorGrading(
      planId: plan.id,
      recordId: record.id,
    );

    final clearedRecords = await repository.loadVisitRecords(plan.id);

    expect(clearedRecords.single.sourcePhotoPath, '/tmp/original.jpg');
    expect(clearedRecords.single.displayPhotoPath, '/tmp/original.jpg');
    expect(clearedRecords.single.colorGradingMode, isNull);
    expect(clearedRecords.single.colorGradingParamsJson, isNull);
    expect(clearedRecords.single.colorGradingIntensity, isNull);
  });

  test('uses explicit captured time when creating visit records', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final repository = SqlitePilgrimageRepository(database: database);
    final plan = await repository.loadActivePlan();
    final point = plan.points.first;
    final capturedAt = DateTime(2024, 7, 8, 9, 10, 11);

    await repository.createVisitRecord(
      planId: plan.id,
      pointId: point.id,
      workId: point.work.id,
      photoPath: '/tmp/imported.jpg',
      referenceMode: '相册导入',
      capturedAt: capturedAt,
    );

    final records = await repository.loadVisitRecords(plan.id);

    expect(records.single.capturedAt, capturedAt);
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

  test('deleting unrelated points keeps current target', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final repository = SqlitePilgrimageRepository(database: database);
    final plan = await repository.loadActivePlan();

    await repository.setCurrentPoint(
      planId: plan.id,
      pointId: plan.points[2].id,
    );
    final updatedPlan = await repository.deletePointFromPlan(
      planId: plan.id,
      pointId: plan.points[0].id,
    );

    expect(
      updatedPlan.points.map((point) => point.id),
      isNot(contains(plan.points[0].id)),
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

  test('persists plan groups and point group assignment', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final repository = SqlitePilgrimageRepository(database: database);
    final plan = await repository.loadActivePlan();
    final group = PilgrimagePlanGroup(
      id: 'group-uji',
      name: '宇治站附近',
      orderIndex: 0,
      orderMode: PlanGroupOrderMode.manual,
      anchorName: 'JR 宇治站',
      anchorLatitude: 34.8903,
      anchorLongitude: 135.8009,
      anchorPointId: plan.points.first.id,
      note: '上午扫点',
      createdAt: DateTime(2026, 6),
    );

    await repository.createPlanGroup(planId: plan.id, group: group);
    await repository.movePointsToGroup(
      planId: plan.id,
      pointIds: {plan.points.first.id, plan.points[1].id},
      groupId: group.id,
    );

    final reloadedPlan = await repository.loadActivePlan();

    expect(reloadedPlan.groups, hasLength(plan.groups.length + 1));
    final reloadedGroup = reloadedPlan.groups.firstWhere(
      (candidate) => candidate.id == group.id,
    );
    expect(reloadedGroup.name, group.name);
    expect(reloadedGroup.orderMode, PlanGroupOrderMode.manual);
    expect(reloadedGroup.anchorPointId, plan.points.first.id);
    expect(reloadedGroup.note, '上午扫点');
    expect(reloadedPlan.points.first.groupId, group.id);
    expect(reloadedPlan.points.first.groupOrderIndex, 0);
    expect(reloadedPlan.points[1].groupId, group.id);
    expect(reloadedPlan.points[1].groupOrderIndex, 1);
  });

  test('deleting plan group moves points back to ungrouped', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final repository = SqlitePilgrimageRepository(database: database);
    final plan = await repository.loadActivePlan();
    final group = PilgrimagePlanGroup(
      id: 'group-daikichiyama',
      name: '大吉山',
      orderIndex: 1,
      createdAt: DateTime(2026, 6),
    );

    await repository.createPlanGroup(planId: plan.id, group: group);
    await repository.movePointsToGroup(
      planId: plan.id,
      pointIds: {plan.points.first.id},
      groupId: group.id,
    );
    final updatedPlan = await repository.deletePlanGroup(
      planId: plan.id,
      groupId: group.id,
    );

    expect(
      updatedPlan.groups.map((group) => group.id),
      isNot(contains(group.id)),
    );
    expect(updatedPlan.points.first.groupId, isNull);
    expect(updatedPlan.points.first.groupOrderIndex, isNull);
  });
}
