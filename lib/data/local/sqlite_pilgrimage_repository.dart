import 'package:drift/drift.dart';
import 'dart:convert';
import 'package:latlong2/latlong.dart';

import '../../plan/pilgrimage_models.dart';
import '../anitabi_image_url.dart';
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

    return Future.wait(planRows.map(_loadPlanWithCurrentTargetRepair));
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
    return _loadPlanWithCurrentTargetRepair(fallbackPlan);
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
      fontScale: row.fontScale.clamp(0.7, 1.4),
      themeMode: _themeModeFromName(row.themeMode),
      cameraCaptureAspectRatio: _cameraAspectRatioFromName(
        row.cameraCaptureAspectRatio,
      ),
      cameraFallbackAspectRatio: _fallbackCameraAspectRatioFromName(
        row.cameraAspectRatio,
      ),
      cameraMinZoom: row.cameraMinZoom.clamp(0.1, 20.0),
      cameraMaxZoom: row.cameraMaxZoom.clamp(1.0, 20.0),
      referenceImageScale: row.referenceImageScale.clamp(0.8, 1.0),
      nearestAssignDistanceMeters: row.nearestAssignDistanceMeters.clamp(
        50.0,
        5000.0,
      ),
      themePalette: _themePaletteFromName(row.themePalette),
      mapTileProvider: _mapTileProviderFromName(row.mapTileProvider),
      openFreeMapStyle: _openFreeMapStyleFromName(row.openFreeMapStyle),
      anitabiImageSource: _anitabiImageSourceFromName(row.anitabiImageSource),
      navigationApp: _navigationAppFromName(row.navigationApp),
      customXyzTileUrl: row.customXyzTileUrl,
      customMapLibreStyleUrl: row.customMapLibreStyleUrl,
      saveVisitPhotoToGallery: row.saveVisitPhotoToGallery,
      autoSaveComparisonToGallery: row.autoSaveComparisonToGallery,
      comparisonShowPilgrimName: row.comparisonShowPilgrimName,
      comparisonPilgrimName: row.comparisonPilgrimName,
      customThemeColorName: row.customThemeColorName,
      customThemeColorValue: row.customThemeColorValue,
      customThemeColors: _customThemeColorsFromJson(row.customThemeColorsJson),
      customCameraAspectRatioWidth: row.customCameraAspectRatioWidth.clamp(
        0.1,
        99.0,
      ),
      customCameraAspectRatioHeight: row.customCameraAspectRatioHeight.clamp(
        0.1,
        99.0,
      ),
      mapThumbnailVisibleThreshold: row.mapThumbnailVisibleThreshold.clamp(
        0,
        200,
      ),
      mapThumbnailConcurrentLoads: row.mapThumbnailConcurrentLoads.clamp(1, 30),
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
  Future<PilgrimagePlan> importPlanPackage({
    required PilgrimagePlan plan,
    required List<PilgrimageVisitRecord> visitRecords,
  }) async {
    final now = DateTime.now();
    final importedId = 'imported-${now.microsecondsSinceEpoch}';
    final idPrefix = '$importedId-';
    final workIdMap = {
      for (final work in plan.works) work.id: '$idPrefix${work.id}',
    };
    final pointIdMap = {
      for (final point in plan.points) point.id: '$idPrefix${point.id}',
    };
    final groupIdMap = {
      for (final group in plan.groups) group.id: '$idPrefix${group.id}',
    };
    final existingNames = (await _database.select(_database.plans).get())
        .map((plan) => plan.name)
        .toSet();
    final importedPlan = plan.copyWith(
      id: importedId,
      name: _uniquePlanName(plan.name, existingNames),
      works: _remapWorks(plan.works, workIdMap),
      groups: _remapGroups(plan.groups, groupIdMap, pointIdMap),
      points: _remapPoints(plan.points, workIdMap, pointIdMap, groupIdMap),
      createdAt: now,
      updatedAt: now,
      currentPointId: plan.currentPointId == null
          ? null
          : pointIdMap[plan.currentPointId],
      currentGroupId: plan.currentGroupId == null
          ? null
          : groupIdMap[plan.currentGroupId],
      completedPointIds: {
        for (final pointId in plan.completedPointIds)
          if (pointIdMap[pointId] != null) pointIdMap[pointId]!,
      },
    );

    await _database.transaction(() async {
      await _database
          .update(_database.plans)
          .write(const PlansCompanion(active: Value(false)));
      await _insertPlan(importedPlan, active: true);

      for (final record in visitRecords) {
        await _database
            .into(_database.visitRecords)
            .insert(
              VisitRecordsCompanion.insert(
                id: _importedRecordId(record.id, now),
                planId: importedId,
                pointId: pointIdMap[record.pointId] ?? record.pointId,
                workId: workIdMap[record.workId] ?? record.workId,
                workTitle: Value(record.workTitle),
                workSubtitle: Value(record.workSubtitle),
                pointName: Value(record.pointName),
                pointSubtitle: Value(record.pointSubtitle),
                photoPath: record.photoPath,
                originalPhotoPath: Value(record.originalPhotoPath),
                gradedPhotoPath: Value(record.gradedPhotoPath),
                colorGradingMode: Value(record.colorGradingMode),
                colorGradingParamsJson: Value(record.colorGradingParamsJson),
                colorGradingIntensity: Value(record.colorGradingIntensity),
                referenceImagePath: Value(record.referenceImagePath),
                referenceImageUrl: Value(
                  _canonicalReferenceUrl(record.referenceImageUrl),
                ),
                referenceMode: record.referenceMode,
                capturedAt: record.capturedAt,
              ),
            );
      }
    });

    return _planFromRow(await _planRowById(importedId));
  }

  @override
  Future<PilgrimagePlan> renamePlan({
    required String planId,
    required String name,
  }) async {
    final plan = await _planFromRow(await _planRowById(planId));
    return updatePlanInfo(planId: planId, name: name, area: plan.area);
  }

  @override
  Future<PilgrimagePlan> updatePlanInfo({
    required String planId,
    required String name,
    required String area,
  }) async {
    await (_database.update(
      _database.plans,
    )..where((table) => table.id.equals(planId))).write(
      PlansCompanion(
        name: Value(name),
        area: Value(area),
        updatedAt: Value(DateTime.now()),
      ),
    );
    return _planFromRow(await _planRowById(planId));
  }

  @override
  Future<PilgrimagePlan> updatePlanMemo({
    required String planId,
    required String memo,
  }) async {
    await (_database.update(
      _database.plans,
    )..where((table) => table.id.equals(planId))).write(
      PlansCompanion(memo: Value(memo), updatedAt: Value(DateTime.now())),
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
      final hadCurrentPoint = await _hasCurrentPoint(planId);
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
      if (!hadCurrentPoint && points.isNotEmpty) {
        await _setFirstPendingPointCurrent(planId);
      }
      await _touchPlan(planId);
    });
    return _planFromRow(await _planRowById(planId));
  }

  @override
  Future<PilgrimagePlan> updatePointInPlan({
    required String planId,
    required PilgrimagePoint point,
  }) async {
    final storagePointId = _storageId(planId, point.id);
    await _database.transaction(() async {
      final existing =
          await (_database.select(_database.points)
                ..where(
                  (table) =>
                      table.planId.equals(planId) &
                      table.id.equals(storagePointId),
                )
                ..limit(1))
              .getSingleOrNull();
      if (existing == null) {
        throw ArgumentError.value(
          point.id,
          'point.id',
          'Point does not exist.',
        );
      }

      await _upsertWork(planId: planId, work: point.work);
      await (_database.update(_database.points)..where(
            (table) =>
                table.planId.equals(planId) & table.id.equals(storagePointId),
          ))
          .write(
            PointsCompanion(
              workId: Value(_storageId(planId, point.work.id)),
              name: Value(point.name),
              subtitle: Value(point.subtitle),
              latitude: Value(point.position.latitude),
              longitude: Value(point.position.longitude),
              episodeLabel: Value(point.episodeLabel),
              referenceLabel: Value(point.referenceLabel),
              source: Value(point.source.name),
              sourceId: Value(point.sourceId),
              referenceImageUrl: Value(
                _canonicalReferenceUrl(point.referenceImageUrl),
              ),
              referenceThumbnailPath: Value(point.referenceThumbnailPath),
              referenceFullImagePath: Value(point.referenceFullImagePath),
              sourceUrl: Value(point.sourceUrl),
              note: Value(point.note),
            ),
          );
      await _touchPlan(planId);
    });
    return _planFromRow(await _planRowById(planId));
  }

  @override
  Future<PilgrimagePlan> updatePointImageCache({
    required String planId,
    required String pointId,
    String? referenceThumbnailPath,
    String? referenceFullImagePath,
  }) async {
    final storagePointId = _storageId(planId, pointId);
    await (_database.update(_database.points)..where(
          (table) =>
              table.planId.equals(planId) & table.id.equals(storagePointId),
        ))
        .write(
          PointsCompanion(
            referenceThumbnailPath: Value(referenceThumbnailPath),
            referenceFullImagePath: Value(referenceFullImagePath),
          ),
        );
    await _touchPlan(planId);
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
  Future<PilgrimagePlan> createPlanGroup({
    required String planId,
    required PilgrimagePlanGroup group,
  }) async {
    await _insertPilgrimagePlanGroup(planId: planId, group: group);
    await _touchPlan(planId);
    return _planFromRow(await _planRowById(planId));
  }

  @override
  Future<PilgrimagePlan> renamePlanGroup({
    required String planId,
    required String groupId,
    required String name,
  }) async {
    await (_database.update(_database.planGroups)..where(
          (table) => table.planId.equals(planId) & table.id.equals(groupId),
        ))
        .write(PlanGroupsCompanion(name: Value(name)));
    await _touchPlan(planId);
    return _planFromRow(await _planRowById(planId));
  }

  @override
  Future<PilgrimagePlan> updatePlanGroup({
    required String planId,
    required PilgrimagePlanGroup group,
  }) async {
    await (_database.update(_database.planGroups)..where(
          (table) => table.planId.equals(planId) & table.id.equals(group.id),
        ))
        .write(
          PlanGroupsCompanion(
            name: Value(group.name),
            orderIndex: Value(group.orderIndex),
            orderMode: Value(group.orderMode.name),
            anchorName: Value(group.anchorName),
            anchorLatitude: Value(group.anchorLatitude),
            anchorLongitude: Value(group.anchorLongitude),
            anchorPointId: Value(
              group.anchorPointId == null
                  ? null
                  : _storageId(planId, group.anchorPointId!),
            ),
            note: Value(group.note),
          ),
        );
    await _touchPlan(planId);
    return _planFromRow(await _planRowById(planId));
  }

  @override
  Future<PilgrimagePlan> deletePlanGroup({
    required String planId,
    required String groupId,
  }) async {
    await _database.transaction(() async {
      await (_database.update(_database.points)..where(
            (table) =>
                table.planId.equals(planId) & table.groupId.equals(groupId),
          ))
          .write(
            const PointsCompanion(
              groupId: Value(null),
              groupOrderIndex: Value(null),
            ),
          );
      await (_database.update(_database.plans)..where(
            (table) =>
                table.id.equals(planId) & table.currentGroupId.equals(groupId),
          ))
          .write(const PlansCompanion(currentGroupId: Value(null)));
      await (_database.delete(_database.planGroups)..where(
            (table) => table.planId.equals(planId) & table.id.equals(groupId),
          ))
          .go();
      await _touchPlan(planId);
    });
    return _planFromRow(await _planRowById(planId));
  }

  @override
  Future<PilgrimagePlan> movePointsToGroup({
    required String planId,
    required Set<String> pointIds,
    required String? groupId,
  }) async {
    if (pointIds.isEmpty) {
      return _planFromRow(await _planRowById(planId));
    }

    final storagePointIds = _storageIds(planId, pointIds);
    await _database.transaction(() async {
      final movingPoints =
          await (_database.select(_database.points)
                ..where(
                  (table) =>
                      table.planId.equals(planId) &
                      table.id.isIn(storagePointIds),
                )
                ..orderBy([(table) => OrderingTerm.asc(table.sortOrder)]))
              .get();
      var nextGroupOrderIndex = 0;
      if (groupId != null) {
        final targetGroupPoints =
            await (_database.select(_database.points)..where(
                  (table) =>
                      table.planId.equals(planId) &
                      table.groupId.equals(groupId),
                ))
                .get();
        nextGroupOrderIndex =
            targetGroupPoints
                .where((point) => !storagePointIds.contains(point.id))
                .fold<int>(
                  -1,
                  (maxOrder, point) => (point.groupOrderIndex ?? -1) > maxOrder
                      ? point.groupOrderIndex!
                      : maxOrder,
                ) +
            1;
      }
      for (final point in movingPoints) {
        await (_database.update(_database.points)..where(
              (table) =>
                  table.planId.equals(planId) & table.id.equals(point.id),
            ))
            .write(
              PointsCompanion(
                groupId: Value(groupId),
                groupOrderIndex: Value(
                  groupId == null ? null : nextGroupOrderIndex++,
                ),
              ),
            );
      }
      await _touchPlan(planId);
    });
    return _planFromRow(await _planRowById(planId));
  }

  @override
  Future<PilgrimagePlan> deleteWorkFromPlan({
    required String planId,
    required String workId,
  }) async {
    final storageWorkId = _storageId(planId, workId);
    await _database.transaction(() async {
      final pointRows =
          await (_database.select(_database.points)..where(
                (table) =>
                    table.planId.equals(planId) &
                    table.workId.equals(storageWorkId),
              ))
              .get();
      final pointIds = pointRows.map((point) => point.id).toSet();
      final deletedCurrentPoint = pointRows.any((point) => point.isCurrent);

      if (pointIds.isNotEmpty) {
        await (_database.delete(_database.points)..where(
              (table) =>
                  table.planId.equals(planId) &
                  table.workId.equals(storageWorkId),
            ))
            .go();
      }

      await (_database.delete(_database.works)..where(
            (table) =>
                table.planId.equals(planId) & table.id.equals(storageWorkId),
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
    final storagePointId = _storageId(planId, pointId);
    await _database.transaction(() async {
      await _clearCurrentPoint(planId);
      await (_database.update(_database.points)..where(
            (table) =>
                table.planId.equals(planId) & table.id.equals(storagePointId),
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
    final storagePointId = _storageId(planId, pointId);
    final storageNextCurrentPointId = nextCurrentPointId == null
        ? null
        : _storageId(planId, nextCurrentPointId);
    await _database.transaction(() async {
      await _clearCurrentPoint(planId);
      await (_database.update(_database.points)..where(
            (table) =>
                table.planId.equals(planId) & table.id.equals(storagePointId),
          ))
          .write(
            PointsCompanion(
              isCurrent: const Value(false),
              completedAt: Value(DateTime.now()),
            ),
          );

      if (storageNextCurrentPointId != null) {
        await (_database.update(_database.points)..where(
              (table) =>
                  table.planId.equals(planId) &
                  table.id.equals(storageNextCurrentPointId),
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

    final storagePointIds = _storageIds(planId, pointIds);
    await _database.transaction(() async {
      final completedCurrentPoint =
          await (_database.select(_database.points)
                ..where(
                  (table) =>
                      table.planId.equals(planId) &
                      table.id.isIn(storagePointIds) &
                      table.isCurrent.equals(true),
                )
                ..limit(1))
              .getSingleOrNull() !=
          null;

      await (_database.update(_database.points)..where(
            (table) =>
                table.planId.equals(planId) & table.id.isIn(storagePointIds),
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

    final storagePointIds = _storageIds(planId, pointIds);
    await _database.transaction(() async {
      await _clearCurrentPoint(planId);
      await (_database.update(_database.points)..where(
            (table) =>
                table.planId.equals(planId) & table.id.isIn(storagePointIds),
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
                      table.planId.equals(planId) &
                      table.id.isIn(storagePointIds),
                )
                ..orderBy([(table) => OrderingTerm.asc(table.sortOrder)])
                ..limit(1))
              .getSingleOrNull();
      if (firstSelectedPoint != null) {
        await (_database.update(_database.points)..where(
              (table) =>
                  table.planId.equals(planId) &
                  table.id.equals(firstSelectedPoint.id),
            ))
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
    String? workTitle,
    String? workSubtitle,
    String? pointName,
    String? pointSubtitle,
    required String photoPath,
    String? referenceImagePath,
    String? referenceImageUrl,
    required String referenceMode,
    DateTime? capturedAt,
  }) async {
    final now = DateTime.now();
    final recordCapturedAt = capturedAt ?? now;
    final record = PilgrimageVisitRecord(
      id: 'record-${now.microsecondsSinceEpoch}',
      planId: planId,
      pointId: pointId,
      workId: workId,
      workTitle: workTitle,
      workSubtitle: workSubtitle,
      pointName: pointName,
      pointSubtitle: pointSubtitle,
      photoPath: photoPath,
      referenceImagePath: referenceImagePath,
      referenceImageUrl: _canonicalReferenceUrl(referenceImageUrl),
      referenceMode: referenceMode,
      capturedAt: recordCapturedAt,
    );
    await _database
        .into(_database.visitRecords)
        .insert(
          VisitRecordsCompanion.insert(
            id: record.id,
            planId: record.planId,
            pointId: record.pointId,
            workId: record.workId,
            workTitle: Value(record.workTitle),
            workSubtitle: Value(record.workSubtitle),
            pointName: Value(record.pointName),
            pointSubtitle: Value(record.pointSubtitle),
            photoPath: record.photoPath,
            originalPhotoPath: Value(record.originalPhotoPath),
            gradedPhotoPath: Value(record.gradedPhotoPath),
            colorGradingMode: Value(record.colorGradingMode),
            colorGradingParamsJson: Value(record.colorGradingParamsJson),
            colorGradingIntensity: Value(record.colorGradingIntensity),
            referenceImagePath: Value(record.referenceImagePath),
            referenceImageUrl: Value(
              _canonicalReferenceUrl(record.referenceImageUrl),
            ),
            referenceMode: record.referenceMode,
            capturedAt: record.capturedAt,
          ),
        );
    await _touchPlan(planId);
    return record;
  }

  @override
  Future<PilgrimageVisitRecord> updateVisitRecordColorGrading({
    required String planId,
    required String recordId,
    required String originalPhotoPath,
    required String gradedPhotoPath,
    required String colorGradingMode,
    required String colorGradingParamsJson,
    required double colorGradingIntensity,
  }) async {
    await (_database.update(_database.visitRecords)..where(
          (table) => table.planId.equals(planId) & table.id.equals(recordId),
        ))
        .write(
          VisitRecordsCompanion(
            originalPhotoPath: Value(originalPhotoPath),
            gradedPhotoPath: Value(gradedPhotoPath),
            colorGradingMode: Value(colorGradingMode),
            colorGradingParamsJson: Value(colorGradingParamsJson),
            colorGradingIntensity: Value(colorGradingIntensity),
          ),
        );
    await _touchPlan(planId);
    return _visitRecordFromRow(await _visitRecordRowById(planId, recordId));
  }

  @override
  Future<PilgrimageVisitRecord> clearVisitRecordColorGrading({
    required String planId,
    required String recordId,
  }) async {
    await (_database.update(_database.visitRecords)..where(
          (table) => table.planId.equals(planId) & table.id.equals(recordId),
        ))
        .write(
          const VisitRecordsCompanion(
            originalPhotoPath: Value(null),
            gradedPhotoPath: Value(null),
            colorGradingMode: Value(null),
            colorGradingParamsJson: Value(null),
            colorGradingIntensity: Value(null),
          ),
        );
    await _touchPlan(planId);
    return _visitRecordFromRow(await _visitRecordRowById(planId, recordId));
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
        _database.planGroups,
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
            fontScale: Value(settings.fontScale.clamp(0.7, 1.4)),
            themeMode: Value(settings.themeMode.name),
            cameraAspectRatio: Value(settings.cameraFallbackAspectRatio.name),
            cameraCaptureAspectRatio: Value(
              settings.cameraCaptureAspectRatio.name,
            ),
            cameraMinZoom: Value(settings.cameraMinZoom.clamp(0.1, 20.0)),
            cameraMaxZoom: Value(settings.cameraMaxZoom.clamp(1.0, 20.0)),
            referenceImageScale: Value(
              settings.referenceImageScale.clamp(0.8, 1.0),
            ),
            nearestAssignDistanceMeters: Value(
              settings.nearestAssignDistanceMeters.clamp(50.0, 5000.0),
            ),
            themePalette: Value(settings.themePalette.name),
            mapTileProvider: Value(settings.mapTileProvider.name),
            openFreeMapStyle: Value(settings.openFreeMapStyle.name),
            anitabiImageSource: Value(settings.anitabiImageSource.name),
            navigationApp: Value(settings.navigationApp.name),
            customXyzTileUrl: Value(settings.customXyzTileUrl.trim()),
            customMapLibreStyleUrl: Value(
              settings.customMapLibreStyleUrl.trim(),
            ),
            saveVisitPhotoToGallery: Value(settings.saveVisitPhotoToGallery),
            autoSaveComparisonToGallery: Value(
              settings.autoSaveComparisonToGallery,
            ),
            comparisonShowPilgrimName: Value(
              settings.comparisonShowPilgrimName,
            ),
            comparisonPilgrimName: Value(settings.comparisonPilgrimName.trim()),
            customThemeColorName: Value(settings.customThemeColorName.trim()),
            customThemeColorValue: Value(settings.customThemeColorValue),
            customThemeColorsJson: Value(
              jsonEncode(
                settings.customThemeColors
                    .map((color) => color.toJson())
                    .toList(growable: false),
              ),
            ),
            customCameraAspectRatioWidth: Value(
              settings.customCameraAspectRatioWidth.clamp(0.1, 99.0),
            ),
            customCameraAspectRatioHeight: Value(
              settings.customCameraAspectRatioHeight.clamp(0.1, 99.0),
            ),
            mapThumbnailVisibleThreshold: Value(
              settings.mapThumbnailVisibleThreshold.clamp(0, 200),
            ),
            mapThumbnailConcurrentLoads: Value(
              settings.mapThumbnailConcurrentLoads.clamp(1, 30),
            ),
          ),
        );
  }

  PilgrimageVisitRecord _visitRecordFromRow(VisitRecord row) {
    return PilgrimageVisitRecord(
      id: row.id,
      planId: row.planId,
      pointId: row.pointId,
      workId: row.workId,
      workTitle: row.workTitle,
      workSubtitle: row.workSubtitle,
      pointName: row.pointName,
      pointSubtitle: row.pointSubtitle,
      photoPath: row.photoPath,
      originalPhotoPath: row.originalPhotoPath,
      gradedPhotoPath: row.gradedPhotoPath,
      colorGradingMode: row.colorGradingMode,
      colorGradingParamsJson: row.colorGradingParamsJson,
      colorGradingIntensity: row.colorGradingIntensity,
      referenceImagePath: row.referenceImagePath,
      referenceImageUrl: _canonicalReferenceUrl(row.referenceImageUrl),
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

    final storagePointIds = _storageIds(planId, pointIds);
    await _database.transaction(() async {
      final deletedCurrentPoint =
          await (_database.select(_database.points)
                ..where(
                  (table) =>
                      table.planId.equals(planId) &
                      table.id.isIn(storagePointIds) &
                      table.isCurrent.equals(true),
                )
                ..limit(1))
              .getSingleOrNull() !=
          null;

      await (_database.delete(_database.points)..where(
            (table) =>
                table.planId.equals(planId) & table.id.isIn(storagePointIds),
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
        final storagePointId = _storageId(planId, pointIds[index]);
        await (_database.update(_database.points)..where(
              (table) =>
                  table.planId.equals(planId) & table.id.equals(storagePointId),
            ))
            .write(PointsCompanion(sortOrder: Value(index)));
      }

      await _touchPlan(planId);
    });

    return _planFromRow(await _planRowById(planId));
  }

  @override
  Future<PilgrimagePlan> reorderGroupPoints({
    required String planId,
    required String groupId,
    required List<String> pointIds,
  }) async {
    await _database.transaction(() async {
      for (var index = 0; index < pointIds.length; index += 1) {
        final storagePointId = _storageId(planId, pointIds[index]);
        await (_database.update(_database.points)..where(
              (table) =>
                  table.planId.equals(planId) &
                  table.groupId.equals(groupId) &
                  table.id.equals(storagePointId),
            ))
            .write(PointsCompanion(groupOrderIndex: Value(index)));
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
            memo: Value(plan.memo),
            currentGroupId: Value(plan.currentGroupId),
            active: Value(active),
            createdAt: plan.createdAt,
            updatedAt: plan.updatedAt,
          ),
        );

    for (final group in plan.groups) {
      await _insertPilgrimagePlanGroup(planId: plan.id, group: group);
    }

    for (final work in plan.works) {
      await _upsertWork(planId: plan.id, work: work);
    }

    for (var index = 0; index < plan.points.length; index += 1) {
      final point = plan.points[index];
      await _upsertWork(planId: plan.id, work: point.work);
      await _database
          .into(_database.points)
          .insert(
            _pointCompanion(
              planId: plan.id,
              point: point,
              sortOrder: index,
              isCurrent: plan.currentPointId == point.id,
              completedAt: plan.completedPointIds.contains(point.id)
                  ? plan.updatedAt
                  : null,
            ),
          );
    }

    if (plan.points.isNotEmpty && plan.currentPointId == null) {
      await _setFirstPendingPointCurrent(plan.id);
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
            id: _storageId(planId, work.id),
            planId: planId,
            bangumiId: Value(work.bangumiId),
            title: work.title,
            subtitle: work.subtitle,
            city: work.city,
            source: work.source.name,
          ),
        );
  }

  Future<void> _insertPilgrimagePlanGroup({
    required String planId,
    required PilgrimagePlanGroup group,
  }) async {
    await _database
        .into(_database.planGroups)
        .insert(
          PlanGroupsCompanion.insert(
            id: group.id,
            planId: planId,
            name: group.name,
            orderIndex: Value(group.orderIndex),
            orderMode: Value(group.orderMode.name),
            anchorName: Value(group.anchorName),
            anchorLatitude: Value(group.anchorLatitude),
            anchorLongitude: Value(group.anchorLongitude),
            anchorPointId: Value(
              group.anchorPointId == null
                  ? null
                  : _storageId(planId, group.anchorPointId!),
            ),
            note: Value(group.note),
            createdAt: group.createdAt,
          ),
        );
  }

  PointsCompanion _pointCompanion({
    required String planId,
    required PilgrimagePoint point,
    required int sortOrder,
    bool isCurrent = false,
    DateTime? completedAt,
  }) {
    return PointsCompanion.insert(
      id: _storageId(planId, point.id),
      planId: planId,
      workId: _storageId(planId, point.work.id),
      name: point.name,
      subtitle: point.subtitle,
      latitude: point.position.latitude,
      longitude: point.position.longitude,
      episodeLabel: point.episodeLabel,
      referenceLabel: point.referenceLabel,
      source: point.source.name,
      sourceId: Value(point.sourceId),
      referenceImageUrl: Value(_canonicalReferenceUrl(point.referenceImageUrl)),
      referenceThumbnailPath: Value(point.referenceThumbnailPath),
      referenceFullImagePath: Value(point.referenceFullImagePath),
      sourceUrl: Value(point.sourceUrl),
      note: Value(point.note),
      groupId: Value(point.groupId),
      groupOrderIndex: Value(point.groupOrderIndex),
      sortOrder: Value(sortOrder),
      isCurrent: Value(isCurrent),
      completedAt: Value(completedAt),
    );
  }

  String _uniquePlanName(String baseName, Set<String> existingNames) {
    final trimmed = baseName.trim().isEmpty ? '导入的巡礼计划' : baseName.trim();
    if (!existingNames.contains(trimmed)) {
      return trimmed;
    }

    var index = 2;
    while (existingNames.contains('$trimmed ($index)')) {
      index += 1;
    }
    return '$trimmed ($index)';
  }

  String _importedRecordId(String recordId, DateTime now) {
    return 'imported-${now.microsecondsSinceEpoch}-$recordId';
  }

  List<PilgrimageWork> _remapWorks(
    List<PilgrimageWork> works,
    Map<String, String> workIdMap,
  ) {
    return [
      for (final work in works)
        PilgrimageWork(
          id: workIdMap[work.id] ?? work.id,
          bangumiId: work.bangumiId,
          title: work.title,
          subtitle: work.subtitle,
          city: work.city,
          source: work.source,
        ),
    ];
  }

  List<PilgrimagePlanGroup> _remapGroups(
    List<PilgrimagePlanGroup> groups,
    Map<String, String> groupIdMap,
    Map<String, String> pointIdMap,
  ) {
    return [
      for (final group in groups)
        PilgrimagePlanGroup(
          id: groupIdMap[group.id] ?? group.id,
          name: group.name,
          orderIndex: group.orderIndex,
          orderMode: group.orderMode,
          anchorName: group.anchorName,
          anchorLatitude: group.anchorLatitude,
          anchorLongitude: group.anchorLongitude,
          anchorPointId: group.anchorPointId == null
              ? null
              : pointIdMap[group.anchorPointId] ?? group.anchorPointId,
          note: group.note,
          createdAt: group.createdAt,
        ),
    ];
  }

  List<PilgrimagePoint> _remapPoints(
    List<PilgrimagePoint> points,
    Map<String, String> workIdMap,
    Map<String, String> pointIdMap,
    Map<String, String> groupIdMap,
  ) {
    return [
      for (final point in points)
        PilgrimagePoint(
          id: pointIdMap[point.id] ?? point.id,
          work: PilgrimageWork(
            id: workIdMap[point.work.id] ?? point.work.id,
            bangumiId: point.work.bangumiId,
            title: point.work.title,
            subtitle: point.work.subtitle,
            city: point.work.city,
            source: point.work.source,
          ),
          name: point.name,
          subtitle: point.subtitle,
          position: point.position,
          episodeLabel: point.episodeLabel,
          referenceLabel: point.referenceLabel,
          source: point.source,
          sourceId: point.sourceId,
          referenceImageUrl: _canonicalReferenceUrl(point.referenceImageUrl),
          referenceThumbnailPath: point.referenceThumbnailPath,
          referenceFullImagePath: point.referenceFullImagePath,
          sourceUrl: point.sourceUrl,
          note: point.note,
          groupId: point.groupId == null
              ? null
              : groupIdMap[point.groupId] ?? point.groupId,
          groupOrderIndex: point.groupOrderIndex,
        ),
    ];
  }

  Future<PilgrimagePlan> _planFromRow(Plan row) async {
    final works = await (_database.select(
      _database.works,
    )..where((table) => table.planId.equals(row.id))).get();
    final workById = {
      for (final work in works) work.id: _workFromRow(work, row.id),
    };
    final groups =
        await (_database.select(_database.planGroups)
              ..where((table) => table.planId.equals(row.id))
              ..orderBy([(table) => OrderingTerm.asc(table.orderIndex)]))
            .get();
    final points =
        await (_database.select(_database.points)
              ..where((table) => table.planId.equals(row.id))
              ..orderBy([(table) => OrderingTerm.asc(table.sortOrder)]))
            .get();

    final completedPointIds = {
      for (final point in points)
        if (point.completedAt != null) _modelId(row.id, point.id),
    };
    final currentPointId = points
        .where((point) => point.isCurrent && point.completedAt == null)
        .firstOrNull
        ?.id;

    return PilgrimagePlan(
      id: row.id,
      name: row.name,
      area: row.area,
      memo: row.memo,
      works: workById.values.toList(growable: false),
      groups: groups
          .map((group) => _groupFromRow(group, row.id))
          .toList(growable: false),
      points: points
          .map((point) => _pointFromRow(point, workById[point.workId], row.id))
          .toList(growable: false),
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      currentPointId: currentPointId == null
          ? null
          : _modelId(row.id, currentPointId),
      currentGroupId: row.currentGroupId,
      completedPointIds: completedPointIds,
    );
  }

  Future<PilgrimagePlan> _loadPlanWithCurrentTargetRepair(Plan row) async {
    var plan = await _planFromRow(row);
    if (plan.currentPointId != null || plan.points.isEmpty) {
      return plan;
    }

    final hasPendingPoint = plan.points.any(
      (point) => !plan.completedPointIds.contains(point.id),
    );
    if (!hasPendingPoint) {
      return plan;
    }

    await _setFirstPendingPointCurrent(plan.id);
    plan = await _planFromRow(await _planRowById(plan.id));
    return plan;
  }

  PilgrimageWork _workFromRow(Work row, String planId) {
    return PilgrimageWork(
      id: _modelId(planId, row.id),
      bangumiId: row.bangumiId,
      title: row.title,
      subtitle: row.subtitle,
      city: row.city,
      source: _workSourceFromName(row.source),
    );
  }

  PilgrimagePlanGroup _groupFromRow(PlanGroup row, String planId) {
    return PilgrimagePlanGroup(
      id: row.id,
      name: row.name,
      orderIndex: row.orderIndex,
      orderMode: _groupOrderModeFromName(row.orderMode),
      anchorName: row.anchorName,
      anchorLatitude: row.anchorLatitude,
      anchorLongitude: row.anchorLongitude,
      anchorPointId: row.anchorPointId == null
          ? null
          : _modelId(planId, row.anchorPointId!),
      note: row.note,
      createdAt: row.createdAt,
    );
  }

  PilgrimagePoint _pointFromRow(
    Point row,
    PilgrimageWork? work,
    String planId,
  ) {
    final resolvedWork =
        work ??
        PilgrimageWork(
          id: _modelId(planId, row.workId),
          title: '未知作品',
          subtitle: 'Unknown Work',
          city: '未设置地区',
          source: WorkSource.manual,
        );

    return PilgrimagePoint(
      id: _modelId(planId, row.id),
      work: resolvedWork,
      name: row.name,
      subtitle: row.subtitle,
      position: LatLng(row.latitude, row.longitude),
      episodeLabel: row.episodeLabel,
      referenceLabel: row.referenceLabel,
      source: _pointSourceFromName(row.source),
      sourceId: row.sourceId,
      referenceImageUrl: _canonicalReferenceUrl(row.referenceImageUrl),
      referenceThumbnailPath: row.referenceThumbnailPath,
      referenceFullImagePath: row.referenceFullImagePath,
      sourceUrl: row.sourceUrl,
      note: row.note,
      groupId: row.groupId,
      groupOrderIndex: row.groupOrderIndex,
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

  PlanGroupOrderMode _groupOrderModeFromName(String name) {
    return PlanGroupOrderMode.values.firstWhere(
      (mode) => mode.name == name,
      orElse: () => PlanGroupOrderMode.unordered,
    );
  }

  CameraPhotoAspectRatio _cameraAspectRatioFromName(String name) {
    return CameraPhotoAspectRatio.values.firstWhere(
      (ratio) => ratio.name == name,
      orElse: () => CameraPhotoAspectRatio.auto,
    );
  }

  CameraPhotoAspectRatio _fallbackCameraAspectRatioFromName(String name) {
    final ratio = _cameraAspectRatioFromName(name);
    return ratio == CameraPhotoAspectRatio.auto ||
            ratio == CameraPhotoAspectRatio.landscape16x9
        ? CameraPhotoAspectRatio.native
        : ratio;
  }

  AppThemePalette _themePaletteFromName(String name) {
    return AppThemePalette.values.firstWhere(
      (palette) => palette.name == name,
      orElse: () => AppThemePalette.classicGreen,
    );
  }

  AppThemeMode _themeModeFromName(String name) {
    return AppThemeMode.values.firstWhere(
      (mode) => mode.name == name,
      orElse: () => AppThemeMode.light,
    );
  }

  List<CustomThemeColor> _customThemeColorsFromJson(String source) {
    try {
      final decoded = jsonDecode(source);
      if (decoded is! List) {
        return const [];
      }
      return decoded
          .map(CustomThemeColor.fromJson)
          .whereType<CustomThemeColor>()
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  MapTileProvider _mapTileProviderFromName(String name) {
    return MapTileProvider.values.firstWhere(
      (provider) => provider.name == name,
      orElse: () => MapTileProvider.openFreeMap,
    );
  }

  OpenFreeMapStyle _openFreeMapStyleFromName(String name) {
    return OpenFreeMapStyle.values.firstWhere(
      (style) => style.name == name,
      orElse: () => OpenFreeMapStyle.liberty,
    );
  }

  AnitabiImageSource _anitabiImageSourceFromName(String name) {
    return AnitabiImageSource.values.firstWhere(
      (source) => source.name == name,
      orElse: () => AnitabiImageSource.auto,
    );
  }

  NavigationApp _navigationAppFromName(String name) {
    return NavigationApp.values.firstWhere(
      (app) => app.name == name,
      orElse: () => NavigationApp.googleMaps,
    );
  }

  static const _storageIdSeparator = '::';

  String _storageId(String planId, String modelId) {
    final prefix = '$planId$_storageIdSeparator';
    if (modelId.startsWith(prefix)) {
      return modelId;
    }
    return '$prefix$modelId';
  }

  List<String> _storageIds(String planId, Iterable<String> modelIds) {
    return modelIds
        .map((modelId) => _storageId(planId, modelId))
        .toList(growable: false);
  }

  String _modelId(String planId, String storageId) {
    final prefix = '$planId$_storageIdSeparator';
    if (storageId.startsWith(prefix)) {
      return storageId.substring(prefix.length);
    }
    return storageId;
  }

  Future<Plan> _planRowById(String planId) {
    return (_database.select(
      _database.plans,
    )..where((table) => table.id.equals(planId))).getSingle();
  }

  Future<VisitRecord> _visitRecordRowById(String planId, String recordId) {
    return (_database.select(_database.visitRecords)..where(
          (table) => table.planId.equals(planId) & table.id.equals(recordId),
        ))
        .getSingle();
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

  Future<bool> _hasCurrentPoint(String planId) async {
    final currentPoint =
        await (_database.select(_database.points)
              ..where(
                (table) =>
                    table.planId.equals(planId) &
                    table.isCurrent.equals(true) &
                    table.completedAt.isNull(),
              )
              ..limit(1))
            .getSingleOrNull();
    return currentPoint != null;
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

    await (_database.update(_database.points)..where(
          (table) =>
              table.planId.equals(planId) & table.id.equals(nextPoint.id),
        ))
        .write(const PointsCompanion(isCurrent: Value(true)));
  }
}

String? _canonicalReferenceUrl(String? url) {
  final normalized = canonicalAnitabiImageUrl(url);
  if (normalized == null || normalized.trim().isEmpty) {
    return null;
  }
  return normalized;
}
