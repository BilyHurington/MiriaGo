import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/data/app_managed_file_paths_io.dart';
import 'package:latlong2/latlong.dart';
import 'package:miriago/data/pilgrimage_repository.dart';
import 'package:miriago/data/local/app_database.dart';
import 'package:miriago/data/local/sqlite_pilgrimage_repository.dart';
import 'package:miriago/plan/pilgrimage_models.dart';
import 'package:miriago/plan_transfer/plan_export_v2.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this.documentsPath);

  final String documentsPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => documentsPath;

  @override
  Future<String?> getApplicationSupportPath() async =>
      p.join(p.dirname(documentsPath), 'files');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  test('persists work type and cover metadata', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = SqlitePilgrimageRepository(database: database);
    final plan = await repository.createPlan(name: '作品元数据', area: '东京');
    const work = PilgrimageWork(
      id: 'manual-music-work',
      title: '测试音乐',
      subtitle: 'Test Music',
      city: '东京',
      source: WorkSource.manual,
      bangumiSubjectType: BangumiSubjectType.music,
      coverImageUrl: 'https://lain.bgm.tv/r/200/pic/cover/test.jpg',
    );

    await repository.addWorkToPlan(planId: plan.id, work: work);
    final reloaded = (await repository.loadPlans()).singleWhere(
      (candidate) => candidate.id == plan.id,
    );
    final stored = reloaded.works.single;

    expect(stored.bangumiSubjectType, BangumiSubjectType.music);
    expect(stored.coverImageUrl, work.coverImageUrl);
  });

  for (final sourceVersion in [27, 28]) {
    test(
      'schema $sourceVersion migration preserves data and adds work metadata',
      () async {
        final database = AppDatabase(NativeDatabase.memory());
        addTearDown(database.close);
        final repository = SqlitePilgrimageRepository(database: database);
        final plan = await repository.createPlan(
          name: '迁移保留计划 $sourceVersion',
          area: '测试地区',
        );
        const legacyWork = PilgrimageWork(
          id: 'legacy-work',
          bangumiId: 29,
          title: '迁移保留作品',
          subtitle: 'Migration Work',
          city: '测试地区',
          source: WorkSource.bangumi,
        );
        await repository.addWorkToPlan(planId: plan.id, work: legacyWork);
        await repository.saveAppSettings(
          const AppSettings(
            customXyzTileUrl: 'https://example.com/migration/{z}/{x}/{y}.png',
          ),
        );
        await database.customStatement(
          'ALTER TABLE works DROP COLUMN bangumi_subject_type',
        );
        await database.customStatement(
          'ALTER TABLE works DROP COLUMN cover_image_url',
        );
        if (sourceVersion == 28) {
          await database.customStatement(
            'ALTER TABLE app_settings_entries '
            'ADD COLUMN camera_input_source TEXT NULL',
          );
          await database.customStatement(
            "UPDATE app_settings_entries SET camera_input_source = 'usb'",
          );
        }

        await database.migration.onUpgrade(
          database.createMigrator(),
          sourceVersion,
          database.schemaVersion,
        );

        final workColumns = await _tableColumnNames(database, 'works');
        expect(
          workColumns,
          containsAll(['bangumi_subject_type', 'cover_image_url']),
        );
        final migratedPlan = (await repository.loadPlans()).singleWhere(
          (candidate) => candidate.id == plan.id,
        );
        expect(migratedPlan.name, '迁移保留计划 $sourceVersion');
        expect(migratedPlan.works.single.title, legacyWork.title);
        expect(migratedPlan.works.single.bangumiSubjectType, isNull);
        expect(migratedPlan.works.single.coverImageUrl, isNull);
        final settings = await repository.loadAppSettings();
        expect(
          settings.customXyzTileUrl,
          'https://example.com/migration/{z}/{x}/{y}.png',
        );
        if (sourceVersion == 28) {
          final settingColumns = await _tableColumnNames(
            database,
            'app_settings_entries',
          );
          expect(settingColumns, contains('camera_input_source'));
          final cameraSource = await database
              .customSelect(
                'SELECT camera_input_source FROM app_settings_entries LIMIT 1',
              )
              .getSingle();
          expect(cameraSource.read<String?>('camera_input_source'), 'usb');
        }
      },
    );
  }

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
      for (final point in plan.points.skip(3)) point.id,
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
    final sourcePoint = sourcePlan.points.first;
    final pointWithNote = PilgrimagePoint(
      id: sourcePoint.id,
      work: sourcePoint.work,
      name: sourcePoint.name,
      subtitle: sourcePoint.subtitle,
      position: sourcePoint.position,
      episodeLabel: sourcePoint.episodeLabel,
      referenceLabel: sourcePoint.referenceLabel,
      source: sourcePoint.source,
      sourceId: sourcePoint.sourceId,
      referenceImageUrl: sourcePoint.referenceImageUrl,
      referenceThumbnailPath: sourcePoint.referenceThumbnailPath,
      referenceFullImagePath: sourcePoint.referenceFullImagePath,
      sourceUrl: sourcePoint.sourceUrl,
      note: '翻修后外观已有变化',
      groupId: sourcePoint.groupId,
      groupOrderIndex: sourcePoint.groupOrderIndex,
    );

    final updatedPlan = await repository.addPointToPlan(
      planId: emptyPlan.id,
      point: pointWithNote,
    );

    expect(updatedPlan.points, hasLength(1));
    expect(updatedPlan.currentPointId, sourcePlan.points.first.id);
    expect(updatedPlan.points.single.note, '翻修后外观已有变化');
  });

  test(
    'repairs old container visit record image paths when files still exist',
    () async {
      final tempDirectory = await Directory.systemTemp.createTemp(
        'miriago_sqlite_repair_',
      );
      addTearDown(() async {
        setAppManagedFileBaseDirectoriesForTesting(null);
        if (tempDirectory.existsSync()) {
          await tempDirectory.delete(recursive: true);
        }
      });
      final documentsPath = p.join(tempDirectory.path, 'Documents');
      PathProviderPlatform.instance = _FakePathProviderPlatform(documentsPath);
      setAppManagedFileBaseDirectoriesForTesting(null);

      final currentPhoto = File(
        p.join(documentsPath, 'visit_record_images', 'legacy-photo.jpg'),
      );
      final currentOriginal = File(
        p.join(documentsPath, 'visit_record_images', 'legacy-original.jpg'),
      );
      final currentReference = File(
        p.join(documentsPath, 'visit_record_images', 'legacy-reference.jpg'),
      );
      final currentGraded = File(
        p.join(documentsPath, 'graded_photos', 'legacy-graded.jpg'),
      );
      for (final file in [
        currentPhoto,
        currentOriginal,
        currentReference,
        currentGraded,
      ]) {
        await file.parent.create(recursive: true);
        await file.writeAsBytes(<int>[1, 2, 3], flush: true);
      }

      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);

      final repository = SqlitePilgrimageRepository(database: database);
      final plan = await repository.loadActivePlan();
      final point = plan.points.first;
      final oldPrefix = '/var/mobile/Containers/Data/Application/OLD/Documents';
      final record = await repository.createVisitRecord(
        planId: plan.id,
        pointId: point.id,
        workId: point.work.id,
        workTitle: point.work.title,
        pointName: point.name,
        photoPath: '$oldPrefix/visit_record_images/legacy-photo.jpg',
        referenceImagePath:
            '$oldPrefix/visit_record_images/legacy-reference.jpg',
        referenceMode: '上下',
      );
      await repository.updateVisitRecordColorGrading(
        planId: plan.id,
        recordId: record.id,
        originalPhotoPath: '$oldPrefix/visit_record_images/legacy-original.jpg',
        gradedPhotoPath: '$oldPrefix/graded_photos/legacy-graded.jpg',
        colorGradingMode: 'manual',
        colorGradingParamsJson: '{}',
        colorGradingIntensity: 1,
      );

      final repairingRepository = SqlitePilgrimageRepository(
        database: database,
      );
      final records = await repairingRepository.loadVisitRecords(plan.id);
      final repaired = records.firstWhere(
        (candidate) => candidate.id == record.id,
      );

      expect(repaired.photoPath, currentPhoto.path);
      expect(repaired.originalPhotoPath, currentOriginal.path);
      expect(repaired.gradedPhotoPath, currentGraded.path);
      expect(repaired.referenceImagePath, currentReference.path);
    },
  );

  test('keeps same Bangumi work independent across plans', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final repository = SqlitePilgrimageRepository(database: database);
    final planA = await repository.createPlan(name: '计划 A', area: '京都');
    final planB = await repository.createPlan(name: '计划 B', area: '东京');
    const work = PilgrimageWork(
      id: 'bangumi-999001',
      bangumiId: 999001,
      title: '测试作品',
      subtitle: 'Fixture',
      city: '测试市',
      source: WorkSource.bangumi,
    );
    const pointA = PilgrimagePoint(
      id: 'anitabi-999001-point-a',
      work: work,
      name: '点位 A',
      subtitle: '地点 A',
      position: LatLng(35, 135),
      episodeLabel: 'EP 1',
      referenceLabel: 'Anitabi',
      source: PointSource.anitabi,
      sourceId: 'point-a',
    );
    const pointB = PilgrimagePoint(
      id: 'anitabi-999001-point-b',
      work: work,
      name: '点位 B',
      subtitle: '地点 B',
      position: LatLng(36, 136),
      episodeLabel: 'EP 2',
      referenceLabel: 'Anitabi',
      source: PointSource.anitabi,
      sourceId: 'point-b',
    );

    await repository.addPointToPlan(planId: planA.id, point: pointA);
    await repository.addPointToPlan(planId: planB.id, point: pointB);

    final plans = await repository.loadPlans();
    final loadedA = plans.firstWhere((plan) => plan.id == planA.id);
    final loadedB = plans.firstWhere((plan) => plan.id == planB.id);

    expect(loadedA.works.map((work) => work.title), contains('测试作品'));
    expect(loadedA.points.single.work.title, '测试作品');
    expect(loadedA.points.single.id, pointA.id);
    expect(loadedB.works.map((work) => work.title), contains('测试作品'));
    expect(loadedB.points.single.id, pointB.id);
  });

  test('keeps same Anitabi point independent across plans', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final repository = SqlitePilgrimageRepository(database: database);
    final planA = await repository.createPlan(name: '计划 A', area: '京都');
    final planB = await repository.createPlan(name: '计划 B', area: '东京');
    const work = PilgrimageWork(
      id: 'bangumi-999002',
      bangumiId: 999002,
      title: '同点位作品',
      subtitle: 'Fixture',
      city: '测试市',
      source: WorkSource.bangumi,
    );
    const pointA = PilgrimagePoint(
      id: 'anitabi-999002-point-a',
      work: work,
      name: '同一 Anitabi 点位',
      subtitle: '计划 A 版本',
      position: LatLng(35, 135),
      episodeLabel: 'EP 1',
      referenceLabel: 'Anitabi',
      source: PointSource.anitabi,
      sourceId: 'point-a',
      referenceImageUrl: 'https://image.example/a.jpg',
    );
    const pointB = PilgrimagePoint(
      id: 'anitabi-999002-point-a',
      work: work,
      name: '同一 Anitabi 点位',
      subtitle: '计划 B 版本',
      position: LatLng(36, 136),
      episodeLabel: 'EP 1',
      referenceLabel: 'Anitabi',
      source: PointSource.anitabi,
      sourceId: 'point-a',
      referenceImageUrl: 'https://image.example/b.jpg',
    );

    await repository.addPointToPlan(planId: planA.id, point: pointA);
    await repository.addPointToPlan(planId: planB.id, point: pointB);

    final plans = await repository.loadPlans();
    final loadedA = plans.firstWhere((plan) => plan.id == planA.id);
    final loadedB = plans.firstWhere((plan) => plan.id == planB.id);

    expect(loadedA.points.single.id, pointA.id);
    expect(loadedA.points.single.subtitle, '计划 A 版本');
    expect(
      loadedA.points.single.referenceImageUrl,
      'https://image.example/a.jpg',
    );
    expect(loadedB.points.single.id, pointB.id);
    expect(loadedB.points.single.subtitle, '计划 B 版本');
    expect(
      loadedB.points.single.referenceImageUrl,
      'https://image.example/b.jpg',
    );
  });

  test('canonicalizes Anitabi mirror URLs before saving point data', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final repository = SqlitePilgrimageRepository(database: database);
    final plan = await repository.createPlan(name: '图片源计划', area: '东京');
    const work = PilgrimageWork(
      id: 'bangumi-999020',
      bangumiId: 999020,
      title: '图片源作品',
      subtitle: 'Fixture',
      city: '东京',
      source: WorkSource.bangumi,
    );
    const point = PilgrimagePoint(
      id: 'anitabi-999020-point-a',
      work: work,
      name: '图片源点位',
      subtitle: '地点 A',
      position: LatLng(35, 135),
      episodeLabel: 'EP 1',
      referenceLabel: 'Anitabi',
      source: PointSource.anitabi,
      sourceId: 'point-a',
      referenceImageUrl: 'https://img-tc.anitabi.cn/points/999020/a.jpg',
    );

    await repository.addPointToPlan(planId: plan.id, point: point);
    final loaded = await repository.loadActivePlan();

    expect(
      loaded.points.single.referenceImageUrl,
      'https://image.anitabi.cn/points/999020/a.jpg',
    );
  });

  test('normalizes Anitabi mirror URLs during schema 25 migration', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final repository = SqlitePilgrimageRepository(database: database);
    final plan = await repository.createPlan(name: '旧图片源计划', area: '东京');
    const work = PilgrimageWork(
      id: 'bangumi-999021',
      bangumiId: 999021,
      title: '旧图片源作品',
      subtitle: 'Fixture',
      city: '东京',
      source: WorkSource.bangumi,
    );
    const point = PilgrimagePoint(
      id: 'anitabi-999021-point-a',
      work: work,
      name: '旧图片源点位',
      subtitle: '地点 A',
      position: LatLng(35, 135),
      episodeLabel: 'EP 1',
      referenceLabel: 'Anitabi',
      source: PointSource.anitabi,
      sourceId: 'point-a',
      referenceImageUrl: 'https://image.anitabi.cn/points/999021/a.jpg',
    );

    await repository.addPointToPlan(planId: plan.id, point: point);
    await (database.update(
      database.points,
    )..where((table) => table.planId.equals(plan.id))).write(
      const PointsCompanion(
        referenceImageUrl: Value(
          'https://img-tc.anitabi.cn/points/999021/a.jpg',
        ),
      ),
    );

    await database.migration.onUpgrade(
      database.createMigrator(),
      24,
      database.schemaVersion,
    );
    final loaded = await repository.loadActivePlan();

    expect(
      loaded.points.single.referenceImageUrl,
      'https://image.anitabi.cn/points/999021/a.jpg',
    );
  });

  test('adding work to one plan does not move it from another plan', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final repository = SqlitePilgrimageRepository(database: database);
    final planA = await repository.createPlan(name: '计划 A', area: '京都');
    final planB = await repository.createPlan(name: '计划 B', area: '东京');
    const work = PilgrimageWork(
      id: 'bangumi-999003',
      bangumiId: 999003,
      title: '只添加作品测试',
      subtitle: 'Fixture',
      city: '测试市',
      source: WorkSource.bangumi,
    );
    const point = PilgrimagePoint(
      id: 'anitabi-999003-point-a',
      work: work,
      name: '点位 A',
      subtitle: '地点 A',
      position: LatLng(35, 135),
      episodeLabel: 'EP 1',
      referenceLabel: 'Anitabi',
      source: PointSource.anitabi,
      sourceId: 'point-a',
    );

    await repository.addPointToPlan(planId: planA.id, point: point);
    await repository.addWorkToPlan(planId: planB.id, work: work);

    final plans = await repository.loadPlans();
    final loadedA = plans.firstWhere((plan) => plan.id == planA.id);
    final loadedB = plans.firstWhere((plan) => plan.id == planB.id);

    expect(loadedA.works.single.title, '只添加作品测试');
    expect(loadedA.points.single.work.title, '只添加作品测试');
    expect(loadedB.works.single.title, '只添加作品测试');
  });

  test('normalizes legacy unscoped SQLite ids during upgrade', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final repository = SqlitePilgrimageRepository(database: database);
    final planA = await repository.createPlan(name: '旧数据计划', area: '京都');
    final planB = await repository.createPlan(name: '新数据计划', area: '东京');
    const work = PilgrimageWork(
      id: 'bangumi-999004',
      bangumiId: 999004,
      title: '旧版作品',
      subtitle: 'Legacy',
      city: '测试市',
      source: WorkSource.bangumi,
    );
    const point = PilgrimagePoint(
      id: 'anitabi-999004-point-a',
      work: work,
      name: '旧版点位',
      subtitle: '地点 A',
      position: LatLng(35, 135),
      episodeLabel: 'EP 1',
      referenceLabel: 'Anitabi',
      source: PointSource.anitabi,
      sourceId: 'point-a',
      referenceImageUrl: 'https://image.example/legacy.jpg',
    );

    await database
        .into(database.works)
        .insert(
          WorksCompanion.insert(
            id: work.id,
            planId: planA.id,
            bangumiId: Value(work.bangumiId),
            title: work.title,
            subtitle: work.subtitle,
            city: work.city,
            source: work.source.name,
          ),
        );
    await database
        .into(database.points)
        .insert(
          PointsCompanion.insert(
            id: point.id,
            planId: planA.id,
            workId: work.id,
            name: point.name,
            subtitle: point.subtitle,
            latitude: point.position.latitude,
            longitude: point.position.longitude,
            episodeLabel: point.episodeLabel,
            referenceLabel: point.referenceLabel,
            source: point.source.name,
            sourceId: Value(point.sourceId),
            referenceImageUrl: Value(point.referenceImageUrl),
            sortOrder: const Value(0),
          ),
        );

    await database.normalizeScopedStorageIds();

    final normalizedWork = await (database.select(
      database.works,
    )..where((table) => table.planId.equals(planA.id))).getSingle();
    final normalizedPoint = await (database.select(
      database.points,
    )..where((table) => table.planId.equals(planA.id))).getSingle();

    expect(normalizedWork.id, '${planA.id}::${work.id}');
    expect(normalizedPoint.id, '${planA.id}::${point.id}');
    expect(normalizedPoint.workId, '${planA.id}::${work.id}');

    await repository.addWorkToPlan(planId: planB.id, work: work);
    await repository.updatePointImageCache(
      planId: planA.id,
      pointId: point.id,
      referenceThumbnailPath: '/tmp/legacy-thumb.jpg',
    );

    final plans = await repository.loadPlans();
    final loadedA = plans.firstWhere((plan) => plan.id == planA.id);
    final loadedB = plans.firstWhere((plan) => plan.id == planB.id);

    expect(loadedA.works.single.id, work.id);
    expect(loadedA.points.single.id, point.id);
    expect(loadedA.points.single.work.title, '旧版作品');
    expect(
      loadedA.points.single.referenceThumbnailPath,
      '/tmp/legacy-thumb.jpg',
    );
    expect(loadedB.works.single.id, work.id);
  });

  test('normalizes legacy moved work rows during upgrade', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final repository = SqlitePilgrimageRepository(database: database);
    final planA = await repository.createPlan(name: '旧数据计划 A', area: '京都');
    final planB = await repository.createPlan(name: '旧数据计划 B', area: '东京');
    const work = PilgrimageWork(
      id: 'bangumi-999005',
      bangumiId: 999005,
      title: '被移动的旧版作品',
      subtitle: 'Legacy',
      city: '测试市',
      source: WorkSource.bangumi,
    );
    const pointA = PilgrimagePoint(
      id: 'anitabi-plan-a-point',
      work: work,
      name: '计划 A 点位',
      subtitle: '计划 A 说明',
      position: LatLng(35, 135),
      episodeLabel: 'EP 1',
      referenceLabel: 'Anitabi',
      source: PointSource.anitabi,
      sourceId: 'plan-a-point',
      referenceImageUrl: 'https://image.example/a.jpg',
      referenceThumbnailPath: '/legacy/thumb-a.jpg',
      referenceFullImagePath: '/legacy/full-a.jpg',
    );
    const pointB = PilgrimagePoint(
      id: 'anitabi-plan-b-point',
      work: work,
      name: '计划 B 点位',
      subtitle: '计划 B 说明',
      position: LatLng(36, 136),
      episodeLabel: 'EP 2',
      referenceLabel: 'Anitabi',
      source: PointSource.anitabi,
      sourceId: 'plan-b-point',
      referenceImageUrl: 'https://image.example/b.jpg',
      referenceThumbnailPath: '/legacy/thumb-b.jpg',
      referenceFullImagePath: '/legacy/full-b.jpg',
    );

    await _insertLegacyWork(database, planB.id, work);
    await _insertLegacyPoint(database, planA.id, pointA, sortOrder: 0);
    await _insertLegacyPoint(database, planB.id, pointB, sortOrder: 0);

    await database.normalizeScopedStorageIds();

    final scopedWorks = await database.select(database.works).get();
    final scopedPoints = await database.select(database.points).get();
    expect(scopedWorks.map((work) => work.id), isNot(contains(work.id)));
    expect(scopedPoints.map((point) => point.id), isNot(contains(pointA.id)));

    final plans = await repository.loadPlans();
    final loadedA = plans.firstWhere((plan) => plan.id == planA.id);
    final loadedB = plans.firstWhere((plan) => plan.id == planB.id);

    expect(loadedA.works.single.id, work.id);
    expect(loadedA.points.single.id, pointA.id);
    expect(loadedA.points.single.work.title, '被移动的旧版作品');
    expect(loadedA.points.single.referenceThumbnailPath, '/legacy/thumb-a.jpg');
    expect(loadedA.points.single.referenceFullImagePath, '/legacy/full-a.jpg');
    expect(loadedB.works.single.id, work.id);
    expect(loadedB.points.single.id, pointB.id);
    expect(loadedB.points.single.work.title, '被移动的旧版作品');
    expect(loadedB.points.single.referenceThumbnailPath, '/legacy/thumb-b.jpg');
    expect(loadedB.points.single.referenceFullImagePath, '/legacy/full-b.jpg');
  });

  test('schema 22 migration normalizes schema 21 storage ids', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final repository = SqlitePilgrimageRepository(database: database);
    final planA = await repository.createPlan(name: 'Schema 21 A', area: '京都');
    final planB = await repository.createPlan(name: 'Schema 21 B', area: '东京');
    const work = PilgrimageWork(
      id: 'bangumi-999006',
      bangumiId: 999006,
      title: 'Schema 21 作品',
      subtitle: 'Legacy',
      city: '测试市',
      source: WorkSource.bangumi,
    );
    const pointA = PilgrimagePoint(
      id: 'anitabi-schema21-shared-point',
      work: work,
      name: 'Schema 21 点位 A',
      subtitle: '计划 A',
      position: LatLng(35, 135),
      episodeLabel: 'EP 1',
      referenceLabel: 'Anitabi',
      source: PointSource.anitabi,
      sourceId: 'schema21-shared-point',
      referenceImageUrl: 'https://image.example/schema21-a.jpg',
    );
    const pointB = PilgrimagePoint(
      id: 'anitabi-schema21-plan-b-point',
      work: work,
      name: 'Schema 21 点位 B',
      subtitle: '计划 B',
      position: LatLng(36, 136),
      episodeLabel: 'EP 1',
      referenceLabel: 'Anitabi',
      source: PointSource.anitabi,
      sourceId: 'schema21-plan-b-point',
      referenceImageUrl: 'https://image.example/schema21-b.jpg',
    );

    await _insertLegacyWork(database, planB.id, work);
    await _insertLegacyPoint(database, planA.id, pointA, sortOrder: 0);
    await _insertLegacyPoint(database, planB.id, pointB, sortOrder: 0);

    await database.migration.onUpgrade(
      database.createMigrator(),
      21,
      database.schemaVersion,
    );

    final settings = await repository.loadAppSettings();
    expect(settings.fontScale, 1);
    expect(settings.themeMode, AppThemeMode.light);
    expect(settings.navigationApp, NavigationApp.googleMaps);
    expect(settings.customCameraAspectRatioWidth, 1);
    expect(settings.customCameraAspectRatioHeight, 1);

    final scopedWorks = await database.select(database.works).get();
    final scopedPoints = await database.select(database.points).get();
    expect(scopedWorks.map((work) => work.id), isNot(contains(work.id)));
    expect(scopedPoints.map((point) => point.id), isNot(contains(pointA.id)));

    final plans = await repository.loadPlans();
    final loadedA = plans.firstWhere((plan) => plan.id == planA.id);
    final loadedB = plans.firstWhere((plan) => plan.id == planB.id);

    expect(loadedA.works.single.id, work.id);
    expect(loadedA.points.single.id, pointA.id);
    expect(loadedA.points.single.work.title, 'Schema 21 作品');
    expect(
      loadedA.points.single.referenceImageUrl,
      'https://image.example/schema21-a.jpg',
    );
    expect(loadedB.works.single.id, work.id);
    expect(loadedB.points.single.id, pointB.id);
    expect(loadedB.points.single.work.title, 'Schema 21 作品');
    expect(
      loadedB.points.single.referenceImageUrl,
      'https://image.example/schema21-b.jpg',
    );
  });

  test('exports SQLite-loaded plans without scoped storage ids', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final repository = SqlitePilgrimageRepository(database: database);
    final planA = await repository.createPlan(name: '导出计划 A', area: '京都');
    final planB = await repository.createPlan(name: '导出计划 B', area: '东京');
    const work = PilgrimageWork(
      id: 'bangumi-999007',
      bangumiId: 999007,
      title: '导出作品',
      subtitle: 'Export',
      city: '测试市',
      source: WorkSource.bangumi,
    );
    const pointA = PilgrimagePoint(
      id: 'anitabi-export-shared-point',
      work: work,
      name: '导出点位 A',
      subtitle: '计划 A',
      position: LatLng(35, 135),
      episodeLabel: 'EP 1',
      referenceLabel: 'Anitabi',
      source: PointSource.anitabi,
      sourceId: 'export-shared-point',
      referenceImageUrl: 'https://image.example/export-a.jpg',
    );
    const pointB = PilgrimagePoint(
      id: 'anitabi-export-shared-point',
      work: work,
      name: '导出点位 B',
      subtitle: '计划 B',
      position: LatLng(36, 136),
      episodeLabel: 'EP 1',
      referenceLabel: 'Anitabi',
      source: PointSource.anitabi,
      sourceId: 'export-shared-point',
      referenceImageUrl: 'https://image.example/export-b.jpg',
    );

    await repository.addPointToPlan(planId: planA.id, point: pointA);
    await repository.addPointToPlan(planId: planB.id, point: pointB);

    final loadedA = (await repository.loadPlans()).firstWhere(
      (plan) => plan.id == planA.id,
    );
    final export = await buildPlanExportV2Package(
      plan: loadedA,
      visitRecords: const [],
      options: const PlanExportV2Options(
        mode: PlanExportV2Mode.planOnly,
        includeFullReferenceCache: false,
      ),
      networkBytesReader: (_) async => null,
    );
    final archive = ZipDecoder().decodeBytes(export.bytes);
    final planJsonText = utf8.decode(archive.findFile('plan.json')!.content);
    final planJson = jsonDecode(planJsonText) as Map<String, Object?>;
    final planRoot = planJson['plan'] as Map<String, Object?>;
    final works = planRoot['works'] as List<Object?>;
    final points = planRoot['points'] as List<Object?>;

    expect(planJsonText, isNot(contains('${planA.id}::')));
    expect(planJsonText, isNot(contains('${planB.id}::')));
    expect((works.single as Map<String, Object?>)['id'], work.id);
    expect((points.single as Map<String, Object?>)['id'], pointA.id);
    expect((points.single as Map<String, Object?>)['workId'], work.id);
  });

  test(
    'updates point editable fields without changing progress state',
    () async {
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

      final editedPoint = point.copyWith(
        name: '编辑后的点位',
        subtitle: '编辑后的位置说明',
        episodeLabel: 'EP 99 / 9:99',
        referenceLabel: '编辑后的来源',
        position: const LatLng(35.1, 135.2),
        note: '编辑备注',
      );
      final updatedPlan = await repository.updatePointInPlan(
        planId: plan.id,
        point: editedPoint,
      );

      final updatedPoint = updatedPlan.points.firstWhere(
        (candidate) => candidate.id == point.id,
      );
      expect(updatedPoint.name, '编辑后的点位');
      expect(updatedPoint.subtitle, '编辑后的位置说明');
      expect(updatedPoint.episodeLabel, 'EP 99 / 9:99');
      expect(updatedPoint.referenceLabel, '编辑后的来源');
      expect(updatedPoint.position.latitude, 35.1);
      expect(updatedPoint.position.longitude, 135.2);
      expect(updatedPoint.note, '编辑备注');
      expect(updatedPlan.completedPointIds, contains(point.id));
      expect(updatedPlan.currentPointId, plan.points[1].id);
    },
  );

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

  test('batch updates cached reference images', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final repository = SqlitePilgrimageRepository(database: database);
    final sourcePlan = await repository.loadActivePlan();
    final emptyPlan = await repository.createPlan(name: '批量缓存测试', area: '京都');
    final addedPlan = await repository.addPointsToPlan(
      planId: emptyPlan.id,
      points: sourcePlan.points.take(2).toList(growable: false),
    );

    final updatedPlan = await repository.updatePointImageCaches(
      planId: addedPlan.id,
      updatesByPointId: {
        addedPlan.points[0].id: const PointImageCacheUpdate(
          referenceThumbnailPath: '/tmp/thumb-a.jpg',
          referenceFullImagePath: '/tmp/full-a.jpg',
        ),
        addedPlan.points[1].id: const PointImageCacheUpdate(
          referenceThumbnailPath: '/tmp/thumb-b.jpg',
          referenceFullImagePath: '/tmp/full-b.jpg',
        ),
      },
    );

    expect(updatedPlan.currentPointId, addedPlan.currentPointId);
    expect(updatedPlan.points[0].referenceThumbnailPath, '/tmp/thumb-a.jpg');
    expect(updatedPlan.points[0].referenceFullImagePath, '/tmp/full-a.jpg');
    expect(updatedPlan.points[1].referenceThumbnailPath, '/tmp/thumb-b.jpg');
    expect(updatedPlan.points[1].referenceFullImagePath, '/tmp/full-b.jpg');
  });

  test('renames plans and persists app settings', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final repository = SqlitePilgrimageRepository(database: database);
    final plan = await repository.loadActivePlan();

    await repository.updatePlanMemo(planId: plan.id, memo: '上午宇治，下午木幡。');
    await repository.updatePlanInfo(
      planId: plan.id,
      name: '改名后的计划',
      area: '京都市',
    );
    await repository.saveAppSettings(
      const AppSettings(
        uiScale: 1.5,
        cameraCaptureAspectRatio: CameraPhotoAspectRatio.photo3x2,
        cameraFallbackAspectRatio: CameraPhotoAspectRatio.standard4x3,
        mapTileProvider: MapTileProvider.customXyz,
        openFreeMapStyle: OpenFreeMapStyle.dark,
        anitabiImageSource: AnitabiImageSource.mirror,
        customXyzTileUrl: 'https://example.com/{z}/{x}/{y}.png',
        customMapLibreStyleUrl: 'https://example.com/style.json',
        fontScale: 1.2,
        themeMode: AppThemeMode.system,
        navigationApp: NavigationApp.amap,
        saveVisitPhotoToGallery: false,
        autoSaveComparisonToGallery: true,
        comparisonShowPilgrimName: true,
        comparisonPilgrimName: 'BilyHurington',
        customThemeColorName: '薄荷',
        customThemeColorValue: 0xFF00AA99,
        customThemeColors: [
          CustomThemeColor(name: '薄荷', value: 0xFF00AA99),
          CustomThemeColor(name: '夜樱', value: 0xFFCC6699),
        ],
        customCameraAspectRatioWidth: 21,
        customCameraAspectRatioHeight: 9,
        mapThumbnailVisibleThreshold: 55,
        mapThumbnailConcurrentLoads: 12,
      ),
    );

    final reloadedPlan = await repository.loadActivePlan();
    final settings = await repository.loadAppSettings();

    expect(reloadedPlan.name, '改名后的计划');
    expect(reloadedPlan.area, '京都市');
    expect(reloadedPlan.memo, '上午宇治，下午木幡。');
    expect(settings.uiScale, 1.0);
    expect(settings.cameraCaptureAspectRatio, CameraPhotoAspectRatio.photo3x2);
    expect(
      settings.cameraFallbackAspectRatio,
      CameraPhotoAspectRatio.standard4x3,
    );
    expect(settings.mapTileProvider, MapTileProvider.customXyz);
    expect(settings.openFreeMapStyle, OpenFreeMapStyle.dark);
    expect(settings.anitabiImageSource, AnitabiImageSource.mirror);
    expect(settings.customXyzTileUrl, 'https://example.com/{z}/{x}/{y}.png');
    expect(settings.customMapLibreStyleUrl, 'https://example.com/style.json');
    expect(settings.fontScale, 1.2);
    expect(settings.themeMode, AppThemeMode.system);
    expect(settings.navigationApp, NavigationApp.amap);
    expect(settings.saveVisitPhotoToGallery, isFalse);
    expect(settings.autoSaveComparisonToGallery, isTrue);
    expect(settings.comparisonShowPilgrimName, isTrue);
    expect(settings.comparisonPilgrimName, 'BilyHurington');
    expect(settings.customThemeColorName, '薄荷');
    expect(settings.customThemeColorValue, 0xFF00AA99);
    expect(settings.customThemeColors, hasLength(2));
    expect(settings.customThemeColors.first.name, '薄荷');
    expect(settings.customThemeColors.first.value, 0xFF00AA99);
    expect(settings.customCameraAspectRatioWidth, 21);
    expect(settings.customCameraAspectRatioHeight, 9);
    expect(settings.mapThumbnailVisibleThreshold, 55);
    expect(settings.mapThumbnailConcurrentLoads, 12);
  });

  test(
    'deletes work and points while preserving visit record history',
    () async {
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
        workTitle: work.title,
        workSubtitle: work.subtitle,
        pointName: point.name,
        pointSubtitle: point.subtitle,
        photoPath: '/tmp/photo.jpg',
        referenceMode: '小窗',
      );

      final updatedPlan = await repository.deleteWorkFromPlan(
        planId: plan.id,
        workId: work.id,
      );
      final records = await repository.loadVisitRecords(plan.id);

      expect(
        updatedPlan.works.map((work) => work.id),
        isNot(contains(work.id)),
      );
      expect(
        updatedPlan.points.map((point) => point.work.id),
        isNot(contains(work.id)),
      );
      expect(records, hasLength(1));
      expect(records.single.workId, work.id);
      expect(records.single.workTitle, work.title);
      expect(records.single.pointId, point.id);
      expect(records.single.pointName, point.name);
    },
  );

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
      workTitle: point.work.title,
      workSubtitle: point.work.subtitle,
      pointName: point.name,
      pointSubtitle: point.subtitle,
      photoPath: '/tmp/photo.jpg',
      referenceImagePath: '/tmp/reference.jpg',
      referenceImageUrl: 'https://example.com/reference.jpg',
      referenceMode: '叠影',
    );

    final repairingRepository = SqlitePilgrimageRepository(database: database);
    final records = await repairingRepository.loadVisitRecords(plan.id);

    expect(records, hasLength(1));
    expect(records.single.id, record.id);
    expect(records.single.pointId, point.id);
    expect(records.single.workTitle, point.work.title);
    expect(records.single.pointName, point.name);
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

  test('persists manual order inside a plan group', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final repository = SqlitePilgrimageRepository(database: database);
    final plan = await repository.loadActivePlan();
    final group = PilgrimagePlanGroup(
      id: 'group-manual-order',
      name: '手动排序片区',
      orderIndex: 0,
      orderMode: PlanGroupOrderMode.manual,
      createdAt: DateTime(2026, 6),
    );
    final pointIds = [
      plan.points.first.id,
      plan.points[1].id,
      plan.points[2].id,
    ];

    await repository.createPlanGroup(planId: plan.id, group: group);
    await repository.movePointsToGroup(
      planId: plan.id,
      pointIds: pointIds.toSet(),
      groupId: group.id,
    );
    await repository.reorderGroupPoints(
      planId: plan.id,
      groupId: group.id,
      pointIds: pointIds.reversed.toList(growable: false),
    );

    final reloadedPlan = await repository.loadActivePlan();
    final orderedIds =
        reloadedPlan.points.where((point) => point.groupId == group.id).toList()
          ..sort(
            (a, b) =>
                (a.groupOrderIndex ?? 999).compareTo(b.groupOrderIndex ?? 999),
          );

    expect(orderedIds.map((point) => point.id), pointIds.reversed);
  });

  test('moves points to the end of a non-empty plan group', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final repository = SqlitePilgrimageRepository(database: database);
    final plan = await repository.loadActivePlan();
    final group = PilgrimagePlanGroup(
      id: 'group-append-target',
      name: '追加目标片区',
      orderIndex: 0,
      orderMode: PlanGroupOrderMode.manual,
      createdAt: DateTime(2026, 6),
    );
    final initialPointIds = [
      plan.points.first.id,
      plan.points[1].id,
      plan.points[2].id,
    ];
    final appendedPointIds = [plan.points[3].id, plan.points[4].id];

    await repository.createPlanGroup(planId: plan.id, group: group);
    await repository.movePointsToGroup(
      planId: plan.id,
      pointIds: initialPointIds.toSet(),
      groupId: group.id,
    );
    final reorderedInitialPointIds = initialPointIds.reversed.toList(
      growable: false,
    );
    await repository.reorderGroupPoints(
      planId: plan.id,
      groupId: group.id,
      pointIds: reorderedInitialPointIds,
    );

    final updatedPlan = await repository.movePointsToGroup(
      planId: plan.id,
      pointIds: appendedPointIds.toSet(),
      groupId: group.id,
    );
    final groupPoints =
        updatedPlan.points.where((point) => point.groupId == group.id).toList()
          ..sort(
            (a, b) =>
                (a.groupOrderIndex ?? 999).compareTo(b.groupOrderIndex ?? 999),
          );

    expect(groupPoints.map((point) => point.id), [
      ...reorderedInitialPointIds,
      ...appendedPointIds,
    ]);
    expect(
      groupPoints.map((point) => point.groupOrderIndex),
      List<int>.generate(groupPoints.length, (index) => index),
    );
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

Future<Set<String>> _tableColumnNames(
  AppDatabase database,
  String tableName,
) async {
  final rows = await database
      .customSelect('PRAGMA table_info($tableName)')
      .get();
  return rows.map((row) => row.read<String>('name')).toSet();
}

Future<void> _insertLegacyWork(
  AppDatabase database,
  String planId,
  PilgrimageWork work,
) {
  return database
      .into(database.works)
      .insert(
        WorksCompanion.insert(
          id: work.id,
          planId: planId,
          bangumiId: Value(work.bangumiId),
          title: work.title,
          subtitle: work.subtitle,
          city: work.city,
          source: work.source.name,
        ),
      );
}

Future<void> _insertLegacyPoint(
  AppDatabase database,
  String planId,
  PilgrimagePoint point, {
  required int sortOrder,
}) {
  return database
      .into(database.points)
      .insert(
        PointsCompanion.insert(
          id: point.id,
          planId: planId,
          workId: point.work.id,
          name: point.name,
          subtitle: point.subtitle,
          latitude: point.position.latitude,
          longitude: point.position.longitude,
          episodeLabel: point.episodeLabel,
          referenceLabel: point.referenceLabel,
          source: point.source.name,
          sourceId: Value(point.sourceId),
          referenceImageUrl: Value(point.referenceImageUrl),
          referenceThumbnailPath: Value(point.referenceThumbnailPath),
          referenceFullImagePath: Value(point.referenceFullImagePath),
          sourceUrl: Value(point.sourceUrl),
          note: Value(point.note),
          groupId: Value(point.groupId),
          groupOrderIndex: Value(point.groupOrderIndex),
          sortOrder: Value(sortOrder),
        ),
      );
}
