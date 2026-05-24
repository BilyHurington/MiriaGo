import 'package:drift/drift.dart';
import 'package:latlong2/latlong.dart';

import '../../plan/pilgrimage_models.dart';
import '../pilgrimage_repository.dart';
import '../sample_pilgrimage_repository.dart';
import 'app_database.dart';
import 'database_connection/stub_connection.dart'
    if (dart.library.io) 'database_connection/native_connection.dart';

class SqlitePilgrimageRepository implements PilgrimageRepository {
  SqlitePilgrimageRepository({AppDatabase? database})
    : _database = database ?? AppDatabase(openConnection());

  final AppDatabase _database;

  @override
  Future<List<PilgrimagePlan>> loadPlans() async {
    await _seedIfNeeded();
    final planRows = await (_database.select(
      _database.plans,
    )..orderBy([(table) => OrderingTerm.asc(table.createdAt)])).get();

    return Future.wait(planRows.map(_planFromRow));
  }

  @override
  Future<PilgrimagePlan> loadActivePlan() async {
    await _seedIfNeeded();
    final activePlan =
        await (_database.select(_database.plans)
              ..where((table) => table.active.equals(true))
              ..limit(1))
            .getSingleOrNull();
    final fallbackPlan =
        activePlan ?? await _database.select(_database.plans).getSingle();
    return _planFromRow(fallbackPlan);
  }

  @override
  Future<AppSettings> loadAppSettings() async {
    final row =
        await (_database.select(_database.appSettingsEntries)
              ..where((table) => table.id.equals('default'))
              ..limit(1))
            .getSingleOrNull();
    if (row == null) {
      return const AppSettings();
    }

    return AppSettings(
      uiScale: row.uiScale.clamp(0.5, 2.0),
      cameraAspectRatio: _cameraAspectRatioFromName(row.cameraAspectRatio),
    );
  }

  @override
  Future<List<PilgrimageVisitRecord>> loadVisitRecords(String planId) async {
    await _seedIfNeeded();
    final rows =
        await (_database.select(_database.visitRecords)
              ..where((table) => table.planId.equals(planId))
              ..orderBy([(table) => OrderingTerm.desc(table.capturedAt)]))
            .get();
    return rows.map(_visitRecordFromRow).toList(growable: false);
  }

  @override
  Future<void> setActivePlan(String id) async {
    await _database.transaction(() async {
      await _database
          .update(_database.plans)
          .write(const PlansCompanion(active: Value(false)));
      await (_database.update(_database.plans)
            ..where((table) => table.id.equals(id)))
          .write(const PlansCompanion(active: Value(true)));
    });
  }

  @override
  Future<PilgrimagePlan> createPlan({
    required String name,
    required String area,
  }) async {
    final now = DateTime.now();
    final plan = PilgrimagePlan(
      id: 'local-${now.microsecondsSinceEpoch}',
      name: name,
      area: area,
      works: const [],
      points: const [],
      createdAt: now,
      updatedAt: now,
    );
    await _database.transaction(() async {
      await _database
          .update(_database.plans)
          .write(const PlansCompanion(active: Value(false)));
      await _insertPlan(plan, active: true);
    });
    return plan;
  }

  @override
  Future<PilgrimagePlan> renamePlan({
    required String planId,
    required String name,
  }) async {
    await (_database.update(
      _database.plans,
    )..where((table) => table.id.equals(planId))).write(
      PlansCompanion(name: Value(name), updatedAt: Value(DateTime.now())),
    );
    return _planFromRow(await _planRowById(planId));
  }

  @override
  Future<PilgrimagePlan> addPointToPlan({
    required String planId,
    required PilgrimagePoint point,
  }) async {
    return addPointsToPlan(planId: planId, points: [point]);
  }

  @override
  Future<PilgrimagePlan> addPointsToPlan({
    required String planId,
    required List<PilgrimagePoint> points,
  }) async {
    await _database.transaction(() async {
      final plan = await _planRowById(planId);
      for (var index = 0; index < points.length; index += 1) {
        final point = points[index];
        await _upsertWork(planId: planId, work: point.work);
        await _database
            .into(_database.points)
            .insertOnConflictUpdate(
              _pointCompanion(
                planId: planId,
                point: point,
                sortOrder: plan.updatedAt.microsecondsSinceEpoch + index,
              ),
            );
      }
      await _touchPlan(planId);
    });
    return _planFromRow(await _planRowById(planId));
  }

  @override
  Future<PilgrimagePlan> addWorkToPlan({
    required String planId,
    required PilgrimageWork work,
  }) async {
    await _database.transaction(() async {
      await _upsertWork(planId: planId, work: work);
      await _touchPlan(planId);
    });
    return _planFromRow(await _planRowById(planId));
  }

  @override
  Future<PilgrimagePlan> deleteWorkFromPlan({
    required String planId,
    required String workId,
  }) async {
    await _database.transaction(() async {
      final pointRows =
          await (_database.select(_database.points)..where(
                (table) =>
                    table.planId.equals(planId) & table.workId.equals(workId),
              ))
              .get();
      final pointIds = pointRows.map((point) => point.id).toSet();
      final deletedCurrentPoint = pointRows.any((point) => point.isCurrent);

      if (pointIds.isNotEmpty) {
        await (_database.delete(_database.visitRecords)..where(
              (table) =>
                  table.planId.equals(planId) & table.pointId.isIn(pointIds),
            ))
            .go();
        await (_database.delete(_database.points)..where(
              (table) =>
                  table.planId.equals(planId) & table.workId.equals(workId),
            ))
            .go();
      }

      await (_database.delete(_database.works)..where(
            (table) => table.planId.equals(planId) & table.id.equals(workId),
          ))
          .go();

      if (deletedCurrentPoint) {
        await _setFirstPendingPointCurrent(planId);
      }
      await _touchPlan(planId);
    });

    return _planFromRow(await _planRowById(planId));
  }

  @override
  Future<void> setCurrentPoint({
    required String planId,
    required String pointId,
  }) async {
    await _database.transaction(() async {
      await _clearCurrentPoint(planId);
      await (_database.update(_database.points)..where(
            (table) => table.planId.equals(planId) & table.id.equals(pointId),
          ))
          .write(
            const PointsCompanion(
              isCurrent: Value(true),
              completedAt: Value(null),
            ),
          );
      await _touchPlan(planId);
    });
  }

  @override
  Future<void> completePoint({
    required String planId,
    required String pointId,
    required String? nextCurrentPointId,
  }) async {
    await _database.transaction(() async {
      await _clearCurrentPoint(planId);
      await (_database.update(_database.points)..where(
            (table) => table.planId.equals(planId) & table.id.equals(pointId),
          ))
          .write(
            PointsCompanion(
              isCurrent: const Value(false),
              completedAt: Value(DateTime.now()),
            ),
          );

      if (nextCurrentPointId != null) {
        await (_database.update(_database.points)..where(
              (table) =>
                  table.planId.equals(planId) &
                  table.id.equals(nextCurrentPointId),
            ))
            .write(const PointsCompanion(isCurrent: Value(true)));
      }

      await _touchPlan(planId);
    });
  }

  @override
  Future<void> completePoints({
    required String planId,
    required Set<String> pointIds,
  }) async {
    if (pointIds.isEmpty) {
      return;
    }

    await _database.transaction(() async {
      final completedCurrentPoint =
          await (_database.select(_database.points)
                ..where(
                  (table) =>
                      table.planId.equals(planId) &
                      table.id.isIn(pointIds) &
                      table.isCurrent.equals(true),
                )
                ..limit(1))
              .getSingleOrNull() !=
          null;

      await (_database.update(_database.points)..where(
            (table) => table.planId.equals(planId) & table.id.isIn(pointIds),
          ))
          .write(
            PointsCompanion(
              isCurrent: const Value(false),
              completedAt: Value(DateTime.now()),
            ),
          );

      if (completedCurrentPoint) {
        await _setFirstPendingPointCurrent(planId);
      }

      await _touchPlan(planId);
    });
  }

  @override
  Future<void> reopenPoint({required String planId, required String pointId}) {
    return setCurrentPoint(planId: planId, pointId: pointId);
  }

  @override
  Future<void> reopenPoints({
    required String planId,
    required Set<String> pointIds,
  }) async {
    if (pointIds.isEmpty) {
      return;
    }

    await _database.transaction(() async {
      await _clearCurrentPoint(planId);
      await (_database.update(_database.points)..where(
            (table) => table.planId.equals(planId) & table.id.isIn(pointIds),
          ))
          .write(
            const PointsCompanion(
              isCurrent: Value(false),
              completedAt: Value(null),
            ),
          );

      final firstSelectedPoint =
          await (_database.select(_database.points)
                ..where(
                  (table) =>
                      table.planId.equals(planId) & table.id.isIn(pointIds),
                )
                ..orderBy([(table) => OrderingTerm.asc(table.sortOrder)])
                ..limit(1))
              .getSingleOrNull();
      if (firstSelectedPoint != null) {
        await (_database.update(_database.points)
              ..where((table) => table.id.equals(firstSelectedPoint.id)))
            .write(const PointsCompanion(isCurrent: Value(true)));
      }

      await _touchPlan(planId);
    });
  }

  @override
  Future<PilgrimageVisitRecord> createVisitRecord({
    required String planId,
    required String pointId,
    required String workId,
    required String photoPath,
    String? referenceImagePath,
    String? referenceImageUrl,
    required String referenceMode,
  }) async {
    final now = DateTime.now();
    final record = PilgrimageVisitRecord(
      id: 'record-${now.microsecondsSinceEpoch}',
      planId: planId,
      pointId: pointId,
      workId: workId,
      photoPath: photoPath,
      referenceImagePath: referenceImagePath,
      referenceImageUrl: referenceImageUrl,
      referenceMode: referenceMode,
      capturedAt: now,
    );
    await _database
        .into(_database.visitRecords)
        .insert(
          VisitRecordsCompanion.insert(
            id: record.id,
            planId: record.planId,
            pointId: record.pointId,
            workId: record.workId,
            photoPath: record.photoPath,
            referenceImagePath: Value(record.referenceImagePath),
            referenceImageUrl: Value(record.referenceImageUrl),
            referenceMode: record.referenceMode,
            capturedAt: record.capturedAt,
          ),
        );
    await _touchPlan(planId);
    return record;
  }

  @override
  Future<void> deleteVisitRecord({
    required String planId,
    required String recordId,
  }) async {
    await (_database.delete(_database.visitRecords)..where(
          (table) => table.planId.equals(planId) & table.id.equals(recordId),
        ))
        .go();
    await _touchPlan(planId);
  }

  @override
  Future<void> deletePlan(String id) async {
    await _database.transaction(() async {
      final count = await _database.plans.count().getSingle();
      if (count <= 1) {
        throw StateError('At least one plan is required.');
      }

      await (_database.delete(
        _database.visitRecords,
      )..where((table) => table.planId.equals(id))).go();
      await (_database.delete(
        _database.points,
      )..where((table) => table.planId.equals(id))).go();
      await (_database.delete(
        _database.works,
      )..where((table) => table.planId.equals(id))).go();
      await (_database.delete(
        _database.plans,
      )..where((table) => table.id.equals(id))).go();

      final activeExists =
          await (_database.select(_database.plans)
                ..where((table) => table.active.equals(true))
                ..limit(1))
              .getSingleOrNull();
      if (activeExists == null) {
        final nextPlan = await (_database.select(
          _database.plans,
        )..limit(1)).getSingle();
        await (_database.update(_database.plans)
              ..where((table) => table.id.equals(nextPlan.id)))
            .write(const PlansCompanion(active: Value(true)));
      }
    });
  }

  @override
  Future<void> saveAppSettings(AppSettings settings) async {
    await _database
        .into(_database.appSettingsEntries)
        .insertOnConflictUpdate(
          AppSettingsEntriesCompanion.insert(
            id: 'default',
            uiScale: Value(settings.uiScale.clamp(0.5, 2.0)),
            cameraAspectRatio: Value(settings.cameraAspectRatio.name),
          ),
        );
  }

  PilgrimageVisitRecord _visitRecordFromRow(VisitRecord row) {
    return PilgrimageVisitRecord(
      id: row.id,
      planId: row.planId,
      pointId: row.pointId,
      workId: row.workId,
      photoPath: row.photoPath,
      referenceImagePath: row.referenceImagePath,
      referenceImageUrl: row.referenceImageUrl,
      referenceMode: row.referenceMode,
      capturedAt: row.capturedAt,
    );
  }

  @override
  Future<PilgrimagePlan> deletePointFromPlan({
    required String planId,
    required String pointId,
  }) async {
    return deletePointsFromPlan(planId: planId, pointIds: {pointId});
  }

  @override
  Future<PilgrimagePlan> deletePointsFromPlan({
    required String planId,
    required Set<String> pointIds,
  }) async {
    if (pointIds.isEmpty) {
      return _planFromRow(await _planRowById(planId));
    }

    await _database.transaction(() async {
      final deletedCurrentPoint =
          await (_database.select(_database.points)
                ..where(
                  (table) =>
                      table.planId.equals(planId) &
                      table.id.isIn(pointIds) &
                      table.isCurrent.equals(true),
                )
                ..limit(1))
              .getSingleOrNull() !=
          null;

      await (_database.delete(_database.points)..where(
            (table) => table.planId.equals(planId) & table.id.isIn(pointIds),
          ))
          .go();
      await (_database.delete(_database.visitRecords)..where(
            (table) =>
                table.planId.equals(planId) & table.pointId.isIn(pointIds),
          ))
          .go();

      if (deletedCurrentPoint) {
        await _setFirstPendingPointCurrent(planId);
      }

      await _touchPlan(planId);
    });

    return _planFromRow(await _planRowById(planId));
  }

  @override
  Future<PilgrimagePlan> reorderPoints({
    required String planId,
    required List<String> pointIds,
  }) async {
    await _database.transaction(() async {
      for (var index = 0; index < pointIds.length; index += 1) {
        await (_database.update(_database.points)..where(
              (table) =>
                  table.planId.equals(planId) &
                  table.id.equals(pointIds[index]),
            ))
            .write(PointsCompanion(sortOrder: Value(index)));
      }

      await _touchPlan(planId);
    });

    return _planFromRow(await _planRowById(planId));
  }

  Future<void> _seedIfNeeded() async {
    final count = await _database.plans.count().getSingle();
    if (count > 0) {
      return;
    }

    await _database.transaction(() async {
      await _insertPlan(samplePilgrimagePlan, active: true);
      await _insertPlan(sampleEmptyPlan, active: false);
    });
  }

  Future<void> _insertPlan(PilgrimagePlan plan, {required bool active}) async {
    await _database
        .into(_database.plans)
        .insert(
          PlansCompanion.insert(
            id: plan.id,
            name: plan.name,
            area: plan.area,
            active: Value(active),
            createdAt: plan.createdAt,
            updatedAt: plan.updatedAt,
          ),
        );

    for (final work in plan.works) {
      await _upsertWork(planId: plan.id, work: work);
    }

    for (var index = 0; index < plan.points.length; index += 1) {
      final point = plan.points[index];
      await _upsertWork(planId: plan.id, work: point.work);
      await _database
          .into(_database.points)
          .insert(
            _pointCompanion(planId: plan.id, point: point, sortOrder: index),
          );
    }
  }

  Future<void> _upsertWork({
    required String planId,
    required PilgrimageWork work,
  }) async {
    await _database
        .into(_database.works)
        .insertOnConflictUpdate(
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

  PointsCompanion _pointCompanion({
    required String planId,
    required PilgrimagePoint point,
    required int sortOrder,
  }) {
    return PointsCompanion.insert(
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
      sourceUrl: Value(point.sourceUrl),
      sortOrder: Value(sortOrder),
      isCurrent: const Value(false),
      completedAt: const Value(null),
    );
  }

  Future<PilgrimagePlan> _planFromRow(Plan row) async {
    final works = await (_database.select(
      _database.works,
    )..where((table) => table.planId.equals(row.id))).get();
    final workById = {for (final work in works) work.id: _workFromRow(work)};
    final points =
        await (_database.select(_database.points)
              ..where((table) => table.planId.equals(row.id))
              ..orderBy([(table) => OrderingTerm.asc(table.sortOrder)]))
            .get();

    final completedPointIds = {
      for (final point in points)
        if (point.completedAt != null) point.id,
    };
    final currentPointId = points
        .where((point) => point.isCurrent && point.completedAt == null)
        .firstOrNull
        ?.id;

    return PilgrimagePlan(
      id: row.id,
      name: row.name,
      area: row.area,
      works: workById.values.toList(growable: false),
      points: points
          .map((point) => _pointFromRow(point, workById[point.workId]))
          .toList(growable: false),
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      currentPointId: currentPointId,
      completedPointIds: completedPointIds,
    );
  }

  PilgrimageWork _workFromRow(Work row) {
    return PilgrimageWork(
      id: row.id,
      bangumiId: row.bangumiId,
      title: row.title,
      subtitle: row.subtitle,
      city: row.city,
      source: _workSourceFromName(row.source),
    );
  }

  PilgrimagePoint _pointFromRow(Point row, PilgrimageWork? work) {
    final resolvedWork =
        work ??
        PilgrimageWork(
          id: row.workId,
          title: '未知作品',
          subtitle: 'Unknown Work',
          city: '未设置地区',
          source: WorkSource.manual,
        );

    return PilgrimagePoint(
      id: row.id,
      work: resolvedWork,
      name: row.name,
      subtitle: row.subtitle,
      position: LatLng(row.latitude, row.longitude),
      episodeLabel: row.episodeLabel,
      referenceLabel: row.referenceLabel,
      source: _pointSourceFromName(row.source),
      sourceId: row.sourceId,
      referenceImageUrl: row.referenceImageUrl,
      sourceUrl: row.sourceUrl,
    );
  }

  WorkSource _workSourceFromName(String name) {
    return WorkSource.values.firstWhere(
      (source) => source.name == name,
      orElse: () => WorkSource.manual,
    );
  }

  PointSource _pointSourceFromName(String name) {
    return PointSource.values.firstWhere(
      (source) => source.name == name,
      orElse: () => PointSource.manual,
    );
  }

  CameraPhotoAspectRatio _cameraAspectRatioFromName(String name) {
    return CameraPhotoAspectRatio.values.firstWhere(
      (ratio) => ratio.name == name,
      orElse: () => CameraPhotoAspectRatio.landscape16x9,
    );
  }

  Future<Plan> _planRowById(String planId) {
    return (_database.select(
      _database.plans,
    )..where((table) => table.id.equals(planId))).getSingle();
  }

  Future<void> _touchPlan(String planId) {
    return (_database.update(_database.plans)
          ..where((table) => table.id.equals(planId)))
        .write(PlansCompanion(updatedAt: Value(DateTime.now())));
  }

  Future<void> _clearCurrentPoint(String planId) {
    return (_database.update(_database.points)
          ..where((table) => table.planId.equals(planId)))
        .write(const PointsCompanion(isCurrent: Value(false)));
  }

  Future<void> _setFirstPendingPointCurrent(String planId) async {
    await _clearCurrentPoint(planId);
    final nextPoint =
        await (_database.select(_database.points)
              ..where(
                (table) =>
                    table.planId.equals(planId) & table.completedAt.isNull(),
              )
              ..orderBy([(table) => OrderingTerm.asc(table.sortOrder)])
              ..limit(1))
            .getSingleOrNull();

    if (nextPoint == null) {
      return;
    }

    await (_database.update(_database.points)
          ..where((table) => table.id.equals(nextPoint.id)))
        .write(const PointsCompanion(isCurrent: Value(true)));
  }
}
