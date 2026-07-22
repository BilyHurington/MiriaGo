import 'package:latlong2/latlong.dart';

import '../plan/pilgrimage_models.dart';
import 'pilgrimage_repository.dart';

class SamplePilgrimageRepository implements PilgrimageRepository {
  SamplePilgrimageRepository({
    List<PilgrimagePlan>? plans,
    List<PilgrimageVisitRecord>? visitRecords,
    AppSettings? settings,
    String? activePlanId,
  }) : _plans = List.of(plans ?? [samplePilgrimagePlan]),
       _visitRecords = List.of(visitRecords ?? _sampleVisitRecords),
       _settings = settings ?? const AppSettings(),
       _activePlanId =
           activePlanId ?? (plans?.firstOrNull?.id ?? samplePilgrimagePlan.id);

  final List<PilgrimagePlan> _plans;
  final List<PilgrimageVisitRecord> _visitRecords;
  AppSettings _settings;
  String _activePlanId;

  @override
  Future<List<PilgrimagePlan>> loadPlans() async {
    return List.unmodifiable(_plans);
  }

  @override
  Future<PilgrimagePlan> loadActivePlan() async {
    return _plans.firstWhere(
      (plan) => plan.id == _activePlanId,
      orElse: () => _plans.first,
    );
  }

  @override
  Future<AppSettings> loadAppSettings() async {
    return _settings;
  }

  @override
  Future<List<PilgrimageVisitRecord>> loadVisitRecords(String planId) async {
    return _visitRecords
        .where((record) => record.planId == planId)
        .toList(growable: false)
        .reversed
        .toList(growable: false);
  }

  SamplePilgrimageRepositorySnapshot snapshot() {
    return SamplePilgrimageRepositorySnapshot(
      plans: List.unmodifiable(_plans),
      visitRecords: List.unmodifiable(_visitRecords),
      settings: _settings,
      activePlanId: _activePlanId,
    );
  }

  @override
  Future<void> setActivePlan(String id) async {
    final exists = _plans.any((plan) => plan.id == id);
    if (!exists) {
      throw ArgumentError.value(id, 'id', 'Plan does not exist.');
    }

    _activePlanId = id;
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

    _plans.add(plan);
    _activePlanId = plan.id;
    return plan;
  }

  @override
  Future<PilgrimagePlan> importPlanPackage({
    required PilgrimagePlan plan,
    required List<PilgrimageVisitRecord> visitRecords,
  }) async {
    final now = DateTime.now();
    final existingNames = _plans.map((plan) => plan.name).toSet();
    final importedPlan = plan.copyWith(
      id: 'imported-${now.microsecondsSinceEpoch}',
      name: _uniquePlanName(plan.name, existingNames),
      createdAt: now,
      updatedAt: now,
      currentPointId: plan.currentPointId,
      completedPointIds: plan.completedPointIds,
    );
    _plans.add(importedPlan);
    _visitRecords.addAll(
      visitRecords.map(
        (record) => PilgrimageVisitRecord(
          id: 'imported-${now.microsecondsSinceEpoch}-${record.id}',
          planId: importedPlan.id,
          pointId: record.pointId,
          workId: record.workId,
          workTitle: record.workTitle,
          workSubtitle: record.workSubtitle,
          pointName: record.pointName,
          pointSubtitle: record.pointSubtitle,
          photoPath: record.photoPath,
          originalPhotoPath: record.originalPhotoPath,
          gradedPhotoPath: record.gradedPhotoPath,
          colorGradingMode: record.colorGradingMode,
          colorGradingParamsJson: record.colorGradingParamsJson,
          colorGradingIntensity: record.colorGradingIntensity,
          referenceImagePath: record.referenceImagePath,
          referenceImageUrl: record.referenceImageUrl,
          referenceMode: record.referenceMode,
          capturedAt: record.capturedAt,
        ),
      ),
    );
    _activePlanId = importedPlan.id;
    return importedPlan;
  }

  @override
  Future<PilgrimagePlan> renamePlan({
    required String planId,
    required String name,
  }) async {
    final plan = _plans[_planIndex(planId)];
    return updatePlanInfo(planId: planId, name: name, area: plan.area);
  }

  @override
  Future<PilgrimagePlan> updatePlanInfo({
    required String planId,
    required String name,
    required String area,
  }) async {
    final index = _planIndex(planId);
    final updatedPlan = _plans[index].copyWith(
      name: name,
      area: area,
      updatedAt: DateTime.now(),
    );
    _plans[index] = updatedPlan;
    return updatedPlan;
  }

  @override
  Future<PilgrimagePlan> updatePlanMemo({
    required String planId,
    required String memo,
  }) async {
    final index = _planIndex(planId);
    final updatedPlan = _plans[index].copyWith(
      memo: memo,
      updatedAt: DateTime.now(),
    );
    _plans[index] = updatedPlan;
    return updatedPlan;
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
    final index = _plans.indexWhere((plan) => plan.id == planId);
    if (index == -1) {
      throw ArgumentError.value(planId, 'planId', 'Plan does not exist.');
    }

    final plan = _plans[index];
    var works = plan.works;
    for (final point in points) {
      works = _appendWorkIfMissing(works, point.work);
    }
    final existingIds = plan.points.map((point) => point.id).toSet();
    final newPoints = points
        .where((point) => !existingIds.contains(point.id))
        .toList(growable: false);
    final updatedPoints = [...plan.points, ...newPoints];
    final updatedPlan = plan.copyWith(
      works: works,
      points: updatedPoints,
      currentPointId:
          plan.currentPointId ??
          _firstPendingPointId(updatedPoints, plan.completedPointIds),
      updatedAt: DateTime.now(),
    );
    _plans[index] = updatedPlan;
    return updatedPlan;
  }

  @override
  Future<PilgrimagePlan> updatePointInPlan({
    required String planId,
    required PilgrimagePoint point,
  }) async {
    final index = _planIndex(planId);
    final plan = _plans[index];
    if (!plan.points.any((candidate) => candidate.id == point.id)) {
      throw ArgumentError.value(point.id, 'point.id', 'Point does not exist.');
    }

    final updatedWorks = _appendWorkIfMissing(plan.works, point.work);
    final updatedPlan = plan.copyWith(
      works: updatedWorks,
      points: [
        for (final candidate in plan.points)
          candidate.id == point.id ? point : candidate,
      ],
      updatedAt: DateTime.now(),
    );
    _plans[index] = updatedPlan;
    return updatedPlan;
  }

  @override
  Future<PilgrimagePlan> updatePointImageCache({
    required String planId,
    required String pointId,
    String? referenceThumbnailPath,
    String? referenceFullImagePath,
  }) async {
    return updatePointImageCaches(
      planId: planId,
      updatesByPointId: {
        pointId: PointImageCacheUpdate(
          referenceThumbnailPath: referenceThumbnailPath,
          referenceFullImagePath: referenceFullImagePath,
        ),
      },
    );
  }

  @override
  Future<PilgrimagePlan> updatePointImageCaches({
    required String planId,
    required Map<String, PointImageCacheUpdate> updatesByPointId,
  }) async {
    final index = _planIndex(planId);
    final plan = _plans[index];
    if (updatesByPointId.isEmpty) {
      return plan;
    }
    final updatedPlan = plan.copyWith(
      points: [
        for (final point in plan.points)
          updatesByPointId.containsKey(point.id)
              ? point.copyWith(
                  referenceThumbnailPath:
                      updatesByPointId[point.id]!.referenceThumbnailPath,
                  referenceFullImagePath:
                      updatesByPointId[point.id]!.referenceFullImagePath,
                )
              : point,
      ],
      updatedAt: DateTime.now(),
    );
    _plans[index] = updatedPlan;
    return updatedPlan;
  }

  @override
  Future<PilgrimagePlan> addWorkToPlan({
    required String planId,
    required PilgrimageWork work,
  }) async {
    final index = _plans.indexWhere((plan) => plan.id == planId);
    if (index == -1) {
      throw ArgumentError.value(planId, 'planId', 'Plan does not exist.');
    }

    final plan = _plans[index];
    final updatedPlan = plan.copyWith(
      works: _appendWorkIfMissing(plan.works, work),
      updatedAt: DateTime.now(),
    );
    _plans[index] = updatedPlan;
    return updatedPlan;
  }

  @override
  Future<PilgrimagePlan> createPlanGroup({
    required String planId,
    required PilgrimagePlanGroup group,
  }) async {
    final index = _planIndex(planId);
    final plan = _plans[index];
    final updatedPlan = plan.copyWith(
      groups: [...plan.groups, group],
      updatedAt: DateTime.now(),
    );
    _plans[index] = updatedPlan;
    return updatedPlan;
  }

  @override
  Future<PilgrimagePlan> renamePlanGroup({
    required String planId,
    required String groupId,
    required String name,
  }) async {
    final index = _planIndex(planId);
    final plan = _plans[index];
    final updatedPlan = plan.copyWith(
      groups: [
        for (final group in plan.groups)
          group.id == groupId
              ? PilgrimagePlanGroup(
                  id: group.id,
                  name: name,
                  orderIndex: group.orderIndex,
                  orderMode: group.orderMode,
                  anchorName: group.anchorName,
                  anchorLatitude: group.anchorLatitude,
                  anchorLongitude: group.anchorLongitude,
                  anchorPointId: group.anchorPointId,
                  note: group.note,
                  createdAt: group.createdAt,
                )
              : group,
      ],
      updatedAt: DateTime.now(),
    );
    _plans[index] = updatedPlan;
    return updatedPlan;
  }

  @override
  Future<PilgrimagePlan> updatePlanGroup({
    required String planId,
    required PilgrimagePlanGroup group,
  }) async {
    final index = _planIndex(planId);
    final plan = _plans[index];
    final updatedPlan = plan.copyWith(
      groups: [
        for (final candidate in plan.groups)
          candidate.id == group.id ? group : candidate,
      ],
      updatedAt: DateTime.now(),
    );
    _plans[index] = updatedPlan;
    return updatedPlan;
  }

  @override
  Future<PilgrimagePlan> deletePlanGroup({
    required String planId,
    required String groupId,
  }) async {
    final index = _planIndex(planId);
    final plan = _plans[index];
    final updatedPlan = plan.copyWith(
      groups: plan.groups
          .where((group) => group.id != groupId)
          .toList(growable: false),
      points: [
        for (final point in plan.points)
          point.groupId == groupId
              ? point.copyWith(groupId: null, groupOrderIndex: null)
              : point,
      ],
      currentGroupId: plan.currentGroupId == groupId
          ? null
          : plan.currentGroupId,
      updatedAt: DateTime.now(),
    );
    _plans[index] = updatedPlan;
    return updatedPlan;
  }

  @override
  Future<PilgrimagePlan> movePointsToGroup({
    required String planId,
    required Set<String> pointIds,
    required String? groupId,
  }) async {
    final index = _planIndex(planId);
    final plan = _plans[index];
    var orderIndex = groupId == null
        ? 0
        : plan.points
                  .where(
                    (point) =>
                        point.groupId == groupId &&
                        !pointIds.contains(point.id),
                  )
                  .fold<int>(
                    -1,
                    (maxOrder, point) =>
                        (point.groupOrderIndex ?? -1) > maxOrder
                        ? point.groupOrderIndex!
                        : maxOrder,
                  ) +
              1;
    final updatedPlan = plan.copyWith(
      points: [
        for (final point in plan.points)
          pointIds.contains(point.id)
              ? point.copyWith(
                  groupId: groupId,
                  groupOrderIndex: groupId == null ? null : orderIndex++,
                )
              : point,
      ],
      updatedAt: DateTime.now(),
    );
    _plans[index] = updatedPlan;
    return updatedPlan;
  }

  @override
  Future<PilgrimagePlan> deleteWorkFromPlan({
    required String planId,
    required String workId,
  }) async {
    final index = _planIndex(planId);
    final plan = _plans[index];
    final removedPointIds = plan.points
        .where((point) => point.work.id == workId)
        .map((point) => point.id)
        .toSet();
    final points = plan.points
        .where((point) => point.work.id != workId)
        .toList(growable: false);
    final completedPointIds = {...plan.completedPointIds}
      ..removeAll(removedPointIds);
    final removedCurrentPoint =
        plan.currentPointId != null &&
        removedPointIds.contains(plan.currentPointId);
    final updatedPlan = plan.copyWith(
      works: plan.works
          .where((work) => work.id != workId)
          .toList(growable: false),
      points: points,
      currentPointId: removedCurrentPoint
          ? _firstPendingPointId(points, completedPointIds)
          : plan.currentPointId,
      completedPointIds: completedPointIds,
      updatedAt: DateTime.now(),
    );
    _plans[index] = updatedPlan;
    return updatedPlan;
  }

  @override
  Future<void> deletePlan(String id) async {
    if (_plans.length == 1) {
      throw StateError('At least one plan is required.');
    }

    _plans.removeWhere((plan) => plan.id == id);
    _visitRecords.removeWhere((record) => record.planId == id);
    if (_activePlanId == id) {
      _activePlanId = _plans.first.id;
    }
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
    final index = _planIndex(planId);
    final plan = _plans[index];
    final points = plan.points
        .where((point) => !pointIds.contains(point.id))
        .toList(growable: false);
    final completedPointIds = {...plan.completedPointIds}..removeAll(pointIds);
    final removedCurrentPoint =
        plan.currentPointId != null && pointIds.contains(plan.currentPointId);
    final updatedPlan = plan.copyWith(
      points: points,
      currentPointId: removedCurrentPoint
          ? _firstPendingPointId(points, completedPointIds)
          : plan.currentPointId,
      completedPointIds: completedPointIds,
      updatedAt: DateTime.now(),
    );
    _plans[index] = updatedPlan;
    return updatedPlan;
  }

  @override
  Future<PilgrimagePlan> reorderPoints({
    required String planId,
    required List<String> pointIds,
  }) async {
    final index = _planIndex(planId);
    final plan = _plans[index];
    final pointById = {for (final point in plan.points) point.id: point};
    final orderedPoints = [
      for (final pointId in pointIds)
        if (pointById[pointId] != null) pointById[pointId]!,
      for (final point in plan.points)
        if (!pointIds.contains(point.id)) point,
    ];
    final updatedPlan = plan.copyWith(
      points: orderedPoints,
      updatedAt: DateTime.now(),
    );
    _plans[index] = updatedPlan;
    return updatedPlan;
  }

  @override
  Future<PilgrimagePlan> reorderGroupPoints({
    required String planId,
    required String groupId,
    required List<String> pointIds,
  }) async {
    final index = _planIndex(planId);
    final plan = _plans[index];
    final orderById = {
      for (var index = 0; index < pointIds.length; index += 1)
        pointIds[index]: index,
    };
    final updatedPlan = plan.copyWith(
      points: [
        for (final point in plan.points)
          point.groupId == groupId && orderById.containsKey(point.id)
              ? point.copyWith(groupOrderIndex: orderById[point.id])
              : point,
      ],
      updatedAt: DateTime.now(),
    );
    _plans[index] = updatedPlan;
    return updatedPlan;
  }

  @override
  Future<void> setCurrentPoint({
    required String planId,
    required String pointId,
  }) async {
    final index = _planIndex(planId);
    final plan = _plans[index];
    _plans[index] = plan.copyWith(
      currentPointId: pointId,
      completedPointIds: {...plan.completedPointIds}..remove(pointId),
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<void> completePoint({
    required String planId,
    required String pointId,
    required String? nextCurrentPointId,
  }) async {
    final index = _planIndex(planId);
    final plan = _plans[index];
    _plans[index] = plan.copyWith(
      currentPointId: nextCurrentPointId,
      completedPointIds: {...plan.completedPointIds, pointId},
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<void> completePoints({
    required String planId,
    required Set<String> pointIds,
  }) async {
    final index = _planIndex(planId);
    final plan = _plans[index];
    final completedPointIds = {...plan.completedPointIds, ...pointIds};
    final currentPointId =
        plan.currentPointId != null && pointIds.contains(plan.currentPointId)
        ? plan.points
              .where((point) => !completedPointIds.contains(point.id))
              .firstOrNull
              ?.id
        : plan.currentPointId;
    _plans[index] = plan.copyWith(
      currentPointId: currentPointId,
      completedPointIds: completedPointIds,
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<void> reopenPoint({
    required String planId,
    required String pointId,
  }) async {
    await setCurrentPoint(planId: planId, pointId: pointId);
  }

  @override
  Future<void> reopenPoints({
    required String planId,
    required Set<String> pointIds,
  }) async {
    if (pointIds.isEmpty) {
      return;
    }

    final index = _planIndex(planId);
    final plan = _plans[index];
    final currentPointId = plan.points
        .where((point) => pointIds.contains(point.id))
        .firstOrNull
        ?.id;
    _plans[index] = plan.copyWith(
      currentPointId: currentPointId,
      completedPointIds: {...plan.completedPointIds}..removeAll(pointIds),
      updatedAt: DateTime.now(),
    );
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
      referenceImageUrl: referenceImageUrl,
      referenceMode: referenceMode,
      capturedAt: capturedAt ?? now,
    );
    _visitRecords.add(record);
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
    final index = _visitRecords.indexWhere(
      (record) => record.planId == planId && record.id == recordId,
    );
    if (index == -1) {
      throw ArgumentError.value(recordId, 'recordId', 'Record does not exist.');
    }

    final updated = _visitRecords[index].copyWith(
      originalPhotoPath: originalPhotoPath,
      gradedPhotoPath: gradedPhotoPath,
      colorGradingMode: colorGradingMode,
      colorGradingParamsJson: colorGradingParamsJson,
      colorGradingIntensity: colorGradingIntensity,
    );
    _visitRecords[index] = updated;
    return updated;
  }

  @override
  Future<PilgrimageVisitRecord> clearVisitRecordColorGrading({
    required String planId,
    required String recordId,
  }) async {
    final index = _visitRecords.indexWhere(
      (record) => record.planId == planId && record.id == recordId,
    );
    if (index == -1) {
      throw ArgumentError.value(recordId, 'recordId', 'Record does not exist.');
    }

    final updated = _visitRecords[index].copyWith(
      originalPhotoPath: null,
      gradedPhotoPath: null,
      colorGradingMode: null,
      colorGradingParamsJson: null,
      colorGradingIntensity: null,
    );
    _visitRecords[index] = updated;
    return updated;
  }

  @override
  Future<void> deleteVisitRecord({
    required String planId,
    required String recordId,
  }) async {
    _visitRecords.removeWhere(
      (record) => record.planId == planId && record.id == recordId,
    );
  }

  @override
  Future<void> saveAppSettings(AppSettings settings) async {
    _settings = settings.copyWith(
      uiScale: settings.uiScale.clamp(0.8, 1.0),
      fontScale: settings.fontScale.clamp(0.7, 1.4),
      themeMode: settings.themeMode,
      cameraMinZoom: settings.cameraMinZoom.clamp(0.1, 20.0),
      cameraMaxZoom: settings.cameraMaxZoom.clamp(1.0, 20.0),
      referenceImageScale: settings.referenceImageScale.clamp(0.8, 1.0),
      nearestAssignDistanceMeters: settings.nearestAssignDistanceMeters.clamp(
        50.0,
        5000.0,
      ),
      cameraFallbackAspectRatio:
          settings.cameraFallbackAspectRatio == CameraPhotoAspectRatio.auto
          ? CameraPhotoAspectRatio.native
          : settings.cameraFallbackAspectRatio,
      saveVisitPhotoToGallery: settings.saveVisitPhotoToGallery,
      autoSaveComparisonToGallery: settings.autoSaveComparisonToGallery,
      comparisonShowPilgrimName: settings.comparisonShowPilgrimName,
      comparisonPilgrimName: settings.comparisonPilgrimName.trim(),
      mapTileProvider: settings.mapTileProvider,
      openFreeMapStyle: settings.openFreeMapStyle,
      anitabiImageSource: settings.anitabiImageSource,
      navigationApp: settings.navigationApp,
      customXyzTileUrl: settings.customXyzTileUrl.trim(),
      customMapLibreStyleUrl: settings.customMapLibreStyleUrl.trim(),
      customThemeColorName: settings.customThemeColorName.trim().isEmpty
          ? '\u81ea\u5b9a\u4e49'
          : settings.customThemeColorName.trim(),
      customThemeColorValue: settings.customThemeColorValue,
      customThemeColors: settings.customThemeColors,
      customCameraAspectRatioWidth: settings.customCameraAspectRatioWidth.clamp(
        0.1,
        99.0,
      ),
      customCameraAspectRatioHeight: settings.customCameraAspectRatioHeight
          .clamp(0.1, 99.0),
      mapThumbnailVisibleThreshold: settings.mapThumbnailVisibleThreshold.clamp(
        0,
        200,
      ),
      mapThumbnailConcurrentLoads: settings.mapThumbnailConcurrentLoads.clamp(
        1,
        30,
      ),
      mapMarkerClusteringEnabled: settings.mapMarkerClusteringEnabled,
      mapMarkerClusterRadius: settings.mapMarkerClusterRadius.clamp(32, 120),
      mapMarkerClusterMaxZoom: settings.mapMarkerClusterMaxZoom.clamp(10, 22),
    );
  }

  List<PilgrimageWork> _appendWorkIfMissing(
    List<PilgrimageWork> works,
    PilgrimageWork work,
  ) {
    final exists = works.any((candidate) => candidate.id == work.id);
    if (exists) {
      return works;
    }

    return [...works, work];
  }

  int _planIndex(String planId) {
    final index = _plans.indexWhere((plan) => plan.id == planId);
    if (index == -1) {
      throw ArgumentError.value(planId, 'planId', 'Plan does not exist.');
    }

    return index;
  }

  String? _firstPendingPointId(
    List<PilgrimagePoint> points,
    Set<String> completedPointIds,
  ) {
    return points
        .where((point) => !completedPointIds.contains(point.id))
        .firstOrNull
        ?.id;
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
}

class SamplePilgrimageRepositorySnapshot {
  const SamplePilgrimageRepositorySnapshot({
    required this.plans,
    required this.visitRecords,
    required this.settings,
    required this.activePlanId,
  });

  final List<PilgrimagePlan> plans;
  final List<PilgrimageVisitRecord> visitRecords;
  final AppSettings settings;
  final String activePlanId;
}

final _sampleCreatedAt = DateTime(2026, 5, 23, 9);

const _hibikeWork = PilgrimageWork(
  id: 'hibike-euphonium',
  bangumiId: 115908,
  title: '吹响吧！上低音号',
  subtitle: '響け！ユーフォニアム',
  city: '宇治市',
  source: WorkSource.bangumi,
);

final samplePilgrimagePlan = PilgrimagePlan(
  id: 'sample-uji-hibike',
  name: '示例计划',
  area: '宇治市',
  works: const [_hibikeWork],
  groups: [
    PilgrimagePlanGroup(
      id: 'sample-group-uji-station',
      name: '宇治站附近',
      orderIndex: 0,
      orderMode: PlanGroupOrderMode.unordered,
      anchorName: 'JR 宇治站',
      anchorLatitude: 34.8903,
      anchorLongitude: 135.8009,
      anchorPointId: 'anitabi-115908-3plnxvy',
      createdAt: _sampleCreatedAt,
    ),
    PilgrimagePlanGroup(
      id: 'sample-group-daikichiyama',
      name: '大吉山',
      orderIndex: 1,
      orderMode: PlanGroupOrderMode.manual,
      anchorName: '大吉山展望台',
      anchorLatitude: 34.8927,
      anchorLongitude: 135.812,
      anchorPointId: 'anitabi-115908-7mt52rr',
      createdAt: _sampleCreatedAt,
    ),
    PilgrimagePlanGroup(
      id: 'sample-group-byodoin',
      name: '平等院表参道',
      orderIndex: 2,
      orderMode: PlanGroupOrderMode.unordered,
      anchorName: '平等院表门',
      anchorLatitude: 34.8892,
      anchorLongitude: 135.8074,
      anchorPointId: 'anitabi-115908-sample-byodoin-01',
      createdAt: _sampleCreatedAt,
    ),
    PilgrimagePlanGroup(
      id: 'sample-group-agata',
      name: '县神社周边',
      orderIndex: 3,
      orderMode: PlanGroupOrderMode.manual,
      anchorName: '縣神社',
      anchorLatitude: 34.8884,
      anchorLongitude: 135.8058,
      anchorPointId: 'anitabi-115908-qys7ix',
      createdAt: _sampleCreatedAt,
    ),
    PilgrimagePlanGroup(
      id: 'sample-group-rokuchizo',
      name: '六地藏方向',
      orderIndex: 4,
      orderMode: PlanGroupOrderMode.unordered,
      anchorName: '六地藏站',
      anchorLatitude: 34.9326,
      anchorLongitude: 135.7933,
      anchorPointId: 'anitabi-115908-sample-rokuchizo-01',
      createdAt: _sampleCreatedAt,
    ),
    PilgrimagePlanGroup(
      id: 'sample-group-obaku',
      name: '黄檗方向',
      orderIndex: 5,
      orderMode: PlanGroupOrderMode.unordered,
      anchorName: '黄檗站',
      anchorLatitude: 34.9134,
      anchorLongitude: 135.8026,
      anchorPointId: 'anitabi-115908-sample-obaku-01',
      createdAt: _sampleCreatedAt,
    ),
    PilgrimagePlanGroup(
      id: 'sample-group-kohata',
      name: '木幡方向',
      orderIndex: 6,
      orderMode: PlanGroupOrderMode.manual,
      anchorName: '木幡站',
      anchorLatitude: 34.925,
      anchorLongitude: 135.7962,
      anchorPointId: 'anitabi-115908-sample-kohata-01',
      createdAt: _sampleCreatedAt,
    ),
  ],
  createdAt: _sampleCreatedAt,
  updatedAt: _sampleCreatedAt,
  currentGroupId: 'sample-group-uji-station',
  currentPointId: 'anitabi-115908-7evkbmy2',
  points: const [
    PilgrimagePoint(
      id: 'anitabi-115908-7evkbmy2',
      work: _hibikeWork,
      name: '井用机前步行道',
      subtitle: 'あじろぎの道',
      position: LatLng(34.8899, 135.8081),
      episodeLabel: 'EP 1 / 2:08',
      referenceLabel: 'Anitabi@卜卜口',
      source: PointSource.anitabi,
      sourceId: '7evkbmy2',
      referenceImageUrl: 'https://image.anitabi.cn/points/115908/7evkbmy2.jpg',
      sourceUrl: 'https://anitabi.cn/',
      groupId: 'sample-group-uji-station',
      groupOrderIndex: 0,
    ),
    PilgrimagePoint(
      id: 'anitabi-115908-7gs3o1mm',
      work: _hibikeWork,
      name: '宇治桥',
      subtitle: '宇治橋',
      position: LatLng(34.8929, 135.8065),
      episodeLabel: 'EP 2 / 13:29',
      referenceLabel: 'Anitabi@卜卜口',
      source: PointSource.anitabi,
      sourceId: '7gs3o1mm',
      referenceImageUrl: 'https://image.anitabi.cn/points/115908/7gs3o1mm.jpg',
      sourceUrl: 'https://anitabi.cn/',
      groupId: 'sample-group-uji-station',
      groupOrderIndex: 1,
    ),
    PilgrimagePoint(
      id: 'anitabi-115908-3plnxvy',
      work: _hibikeWork,
      name: 'JR 宇治站',
      subtitle: 'JR宇治駅',
      position: LatLng(34.8903, 135.8009),
      episodeLabel: 'EP 8 / 11:53',
      referenceLabel: 'Anitabi',
      source: PointSource.anitabi,
      sourceId: '3plnxvy',
      referenceImageUrl:
          'https://image.anitabi.cn/user/0/bangumi/115908/points/3plnxvy-1755088794974.jpg',
      sourceUrl: 'https://anitabi.cn/',
      groupId: 'sample-group-uji-station',
      groupOrderIndex: 2,
    ),
    PilgrimagePoint(
      id: 'anitabi-115908-qys7ia',
      work: _hibikeWork,
      name: '大吉山（仏徳山）登山口',
      subtitle: '大吉山（仏徳山）登山口',
      position: LatLng(34.8928, 135.8107),
      episodeLabel: 'EP 8 / 14:23',
      referenceLabel: 'Google Maps',
      source: PointSource.anitabi,
      sourceId: 'qys7ia',
      referenceImageUrl:
          'https://image.anitabi.cn/user/0/bangumi/115908/points/qys7ia-1697123425329.jpg',
      sourceUrl:
          'https://www.google.com/maps/d/viewer?mid=13mgdlajJV0HxpqKf6ri2NnEHFBc&ll=34.892848%2C135.810794&z=17',
      groupId: 'sample-group-daikichiyama',
      groupOrderIndex: 0,
    ),
    PilgrimagePoint(
      id: 'anitabi-115908-7mt52rr',
      work: _hibikeWork,
      name: '大吉山展望台',
      subtitle: '大吉山展望台',
      position: LatLng(34.8927, 135.812),
      episodeLabel: 'EP 8 / 19:57',
      referenceLabel: 'Anitabi',
      source: PointSource.anitabi,
      sourceId: '7mt52rr',
      referenceImageUrl:
          'https://image.anitabi.cn/user/0/bangumi/115908/points/7mt52rr-1763627079224.jpg',
      sourceUrl: 'https://anitabi.cn/',
      groupId: 'sample-group-daikichiyama',
      groupOrderIndex: 1,
    ),
    PilgrimagePoint(
      id: 'anitabi-115908-qys7ix',
      work: _hibikeWork,
      name: '縣神社',
      subtitle: '縣神社',
      position: LatLng(34.8884, 135.8058),
      episodeLabel: 'EP 8 / 15:19',
      referenceLabel: 'Google Maps',
      source: PointSource.anitabi,
      sourceId: 'qys7ix',
      referenceImageUrl:
          'https://image.anitabi.cn/points/115908/75cc58c61b40fdd8a8e64bd8b9bacd0c.png',
      sourceUrl:
          'https://www.google.com/maps/d/viewer?mid=13mgdlajJV0HxpqKf6ri2NnEHFBc&ll=34.888488%2C135.80587&z=17',
      groupId: 'sample-group-agata',
      groupOrderIndex: 0,
    ),
    PilgrimagePoint(
      id: 'anitabi-115908-sample-uji-01',
      work: _hibikeWork,
      name: '宇治文化中心 停车场',
      subtitle: '宇治文化中心 停车场',
      position: LatLng(34.8951, 135.8019),
      episodeLabel: 'EP 11 / 12:49',
      referenceLabel: 'Anitabi@卜卜口',
      source: PointSource.anitabi,
      sourceId: 'sample-uji-01',
      referenceImageUrl: 'https://image.anitabi.cn/points/115908/7evkbmy2.jpg',
      sourceUrl: 'https://anitabi.cn/',
      groupId: 'sample-group-uji-station',
      groupOrderIndex: 4,
    ),
    PilgrimagePoint(
      id: 'anitabi-115908-sample-uji-02',
      work: _hibikeWork,
      name: '宇治川河畔',
      subtitle: '宇治川沿い',
      position: LatLng(34.8916, 135.8076),
      episodeLabel: 'EP 3 / 8:21',
      referenceLabel: 'Anitabi',
      source: PointSource.anitabi,
      sourceId: 'sample-uji-02',
      referenceImageUrl: 'https://image.anitabi.cn/points/115908/7gs3o1mm.jpg',
      sourceUrl: 'https://anitabi.cn/',
      groupId: 'sample-group-uji-station',
      groupOrderIndex: 5,
    ),
    PilgrimagePoint(
      id: 'anitabi-115908-sample-uji-03',
      work: _hibikeWork,
      name: '京阪宇治站前',
      subtitle: '京阪宇治駅前',
      position: LatLng(34.8942, 135.8069),
      episodeLabel: 'EP 5 / 4:36',
      referenceLabel: 'Anitabi',
      source: PointSource.anitabi,
      sourceId: 'sample-uji-03',
      referenceImageUrl:
          'https://image.anitabi.cn/user/0/bangumi/115908/points/3plnxvy-1755088794974.jpg',
      sourceUrl: 'https://anitabi.cn/',
      groupId: 'sample-group-uji-station',
      groupOrderIndex: 6,
    ),
    PilgrimagePoint(
      id: 'anitabi-115908-sample-uji-04',
      work: _hibikeWork,
      name: '朝雾桥',
      subtitle: '朝霧橋',
      position: LatLng(34.8902, 135.8106),
      episodeLabel: 'EP 7 / 6:12',
      referenceLabel: 'Anitabi',
      source: PointSource.anitabi,
      sourceId: 'sample-uji-04',
      referenceImageUrl:
          'https://image.anitabi.cn/points/115908/75cc58c61b40fdd8a8e64bd8b9bacd0c.png',
      sourceUrl: 'https://anitabi.cn/',
      groupId: 'sample-group-byodoin',
      groupOrderIndex: 0,
    ),
    PilgrimagePoint(
      id: 'anitabi-115908-sample-daikichi-01',
      work: _hibikeWork,
      name: '大吉山步道',
      subtitle: '大吉山登山道',
      position: LatLng(34.8936, 135.8114),
      episodeLabel: 'EP 8 / 16:08',
      referenceLabel: 'Anitabi',
      source: PointSource.anitabi,
      sourceId: 'sample-daikichi-01',
      referenceImageUrl:
          'https://image.anitabi.cn/user/0/bangumi/115908/points/qys7ia-1697123425329.jpg',
      sourceUrl: 'https://anitabi.cn/',
      groupId: 'sample-group-daikichiyama',
      groupOrderIndex: 2,
    ),
    PilgrimagePoint(
      id: 'anitabi-115908-sample-daikichi-02',
      work: _hibikeWork,
      name: '大吉山休息处',
      subtitle: '大吉山休憩所',
      position: LatLng(34.8931, 135.8127),
      episodeLabel: 'EP 8 / 18:42',
      referenceLabel: 'Anitabi',
      source: PointSource.anitabi,
      sourceId: 'sample-daikichi-02',
      referenceImageUrl:
          'https://image.anitabi.cn/user/0/bangumi/115908/points/7mt52rr-1763627079224.jpg',
      sourceUrl: 'https://anitabi.cn/',
      groupId: 'sample-group-daikichiyama',
      groupOrderIndex: 3,
    ),
    PilgrimagePoint(
      id: 'anitabi-115908-sample-unassigned-01',
      work: _hibikeWork,
      name: '平等院表参道',
      subtitle: '平等院表参道',
      position: LatLng(34.8892, 135.8074),
      episodeLabel: 'EP 4 / 10:16',
      referenceLabel: 'Anitabi',
      source: PointSource.anitabi,
      sourceId: 'sample-unassigned-01',
      referenceImageUrl: 'https://image.anitabi.cn/points/115908/7evkbmy2.jpg',
      sourceUrl: 'https://anitabi.cn/',
      groupId: 'sample-group-byodoin',
      groupOrderIndex: 1,
    ),
    PilgrimagePoint(
      id: 'anitabi-115908-sample-unassigned-02',
      work: _hibikeWork,
      name: '宇治上神社参道',
      subtitle: '宇治上神社参道',
      position: LatLng(34.8918, 135.8112),
      episodeLabel: 'EP 9 / 7:55',
      referenceLabel: 'Anitabi',
      source: PointSource.anitabi,
      sourceId: 'sample-unassigned-02',
      referenceImageUrl: 'https://image.anitabi.cn/points/115908/7gs3o1mm.jpg',
      sourceUrl: 'https://anitabi.cn/',
    ),
    PilgrimagePoint(
      id: 'anitabi-115908-sample-byodoin-01',
      work: _hibikeWork,
      name: '平等院表门',
      subtitle: '平等院表門',
      position: LatLng(34.8897, 135.8072),
      episodeLabel: 'EP 4 / 11:02',
      referenceLabel: 'Anitabi',
      source: PointSource.anitabi,
      sourceId: 'sample-byodoin-01',
      referenceImageUrl: 'https://image.anitabi.cn/points/115908/7evkbmy2.jpg',
      sourceUrl: 'https://anitabi.cn/',
      groupId: 'sample-group-byodoin',
      groupOrderIndex: 2,
    ),
    PilgrimagePoint(
      id: 'anitabi-115908-sample-byodoin-02',
      work: _hibikeWork,
      name: '橘桥西侧',
      subtitle: '橘橋西詰',
      position: LatLng(34.8899, 135.8088),
      episodeLabel: 'EP 4 / 12:35',
      referenceLabel: 'Anitabi',
      source: PointSource.anitabi,
      sourceId: 'sample-byodoin-02',
      referenceImageUrl: 'https://image.anitabi.cn/points/115908/7gs3o1mm.jpg',
      sourceUrl: 'https://anitabi.cn/',
      groupId: 'sample-group-byodoin',
      groupOrderIndex: 3,
    ),
    PilgrimagePoint(
      id: 'anitabi-115908-sample-agata-01',
      work: _hibikeWork,
      name: '县通商店街',
      subtitle: '県通商店街',
      position: LatLng(34.8887, 135.8051),
      episodeLabel: 'EP 8 / 15:58',
      referenceLabel: 'Anitabi',
      source: PointSource.anitabi,
      sourceId: 'sample-agata-01',
      referenceImageUrl:
          'https://image.anitabi.cn/points/115908/75cc58c61b40fdd8a8e64bd8b9bacd0c.png',
      sourceUrl: 'https://anitabi.cn/',
      groupId: 'sample-group-agata',
      groupOrderIndex: 1,
    ),
    PilgrimagePoint(
      id: 'anitabi-115908-sample-agata-02',
      work: _hibikeWork,
      name: '县神社参道口',
      subtitle: '縣神社参道口',
      position: LatLng(34.8881, 135.8056),
      episodeLabel: 'EP 8 / 16:31',
      referenceLabel: 'Anitabi',
      source: PointSource.anitabi,
      sourceId: 'sample-agata-02',
      referenceImageUrl: 'https://image.anitabi.cn/points/115908/7evkbmy2.jpg',
      sourceUrl: 'https://anitabi.cn/',
      groupId: 'sample-group-agata',
      groupOrderIndex: 2,
    ),
    PilgrimagePoint(
      id: 'anitabi-115908-sample-rokuchizo-01',
      work: _hibikeWork,
      name: '六地藏站前',
      subtitle: '六地蔵駅前',
      position: LatLng(34.9326, 135.7933),
      episodeLabel: 'EP 12 / 5:04',
      referenceLabel: '测试点位',
      source: PointSource.manual,
      groupId: 'sample-group-rokuchizo',
      groupOrderIndex: 0,
    ),
    PilgrimagePoint(
      id: 'anitabi-115908-sample-rokuchizo-02',
      work: _hibikeWork,
      name: '六地藏住宅街',
      subtitle: '六地蔵住宅街',
      position: LatLng(34.9318, 135.7947),
      episodeLabel: 'EP 12 / 6:22',
      referenceLabel: '测试点位',
      source: PointSource.manual,
      groupId: 'sample-group-rokuchizo',
      groupOrderIndex: 1,
    ),
    PilgrimagePoint(
      id: 'anitabi-115908-sample-rokuchizo-03',
      work: _hibikeWork,
      name: '六地藏河岸',
      subtitle: '六地蔵川沿い',
      position: LatLng(34.9309, 135.7956),
      episodeLabel: 'EP 12 / 7:40',
      referenceLabel: '测试点位',
      source: PointSource.manual,
      groupId: 'sample-group-rokuchizo',
      groupOrderIndex: 2,
    ),
    PilgrimagePoint(
      id: 'anitabi-115908-sample-obaku-01',
      work: _hibikeWork,
      name: '黄檗站前',
      subtitle: '黄檗駅前',
      position: LatLng(34.9134, 135.8026),
      episodeLabel: 'EP 10 / 9:11',
      referenceLabel: '测试点位',
      source: PointSource.manual,
      groupId: 'sample-group-obaku',
      groupOrderIndex: 0,
    ),
    PilgrimagePoint(
      id: 'anitabi-115908-sample-obaku-02',
      work: _hibikeWork,
      name: '黄檗公园入口',
      subtitle: '黄檗公園入口',
      position: LatLng(34.9124, 135.8041),
      episodeLabel: 'EP 10 / 10:03',
      referenceLabel: '测试点位',
      source: PointSource.manual,
      groupId: 'sample-group-obaku',
      groupOrderIndex: 1,
    ),
    PilgrimagePoint(
      id: 'anitabi-115908-sample-obaku-03',
      work: _hibikeWork,
      name: '黄檗街角',
      subtitle: '黄檗の街角',
      position: LatLng(34.9141, 135.8017),
      episodeLabel: 'EP 10 / 12:28',
      referenceLabel: '测试点位',
      source: PointSource.manual,
      groupId: 'sample-group-obaku',
      groupOrderIndex: 2,
    ),
    PilgrimagePoint(
      id: 'anitabi-115908-sample-kohata-01',
      work: _hibikeWork,
      name: '木幡站前',
      subtitle: '木幡駅前',
      position: LatLng(34.925, 135.7962),
      episodeLabel: 'EP 6 / 6:51',
      referenceLabel: '测试点位',
      source: PointSource.manual,
      groupId: 'sample-group-kohata',
      groupOrderIndex: 0,
    ),
    PilgrimagePoint(
      id: 'anitabi-115908-sample-kohata-02',
      work: _hibikeWork,
      name: '木幡商店前',
      subtitle: '木幡商店前',
      position: LatLng(34.9242, 135.7971),
      episodeLabel: 'EP 6 / 7:36',
      referenceLabel: '测试点位',
      source: PointSource.manual,
      groupId: 'sample-group-kohata',
      groupOrderIndex: 1,
    ),
    PilgrimagePoint(
      id: 'anitabi-115908-sample-kohata-03',
      work: _hibikeWork,
      name: '木幡住宅街',
      subtitle: '木幡住宅街',
      position: LatLng(34.9236, 135.7955),
      episodeLabel: 'EP 6 / 8:08',
      referenceLabel: '测试点位',
      source: PointSource.manual,
      groupId: 'sample-group-kohata',
      groupOrderIndex: 2,
    ),
  ],
);

final _sampleVisitRecords = <PilgrimageVisitRecord>[
  _sampleVisitRecord(
    id: 'sample-record-uji-walk-01',
    pointId: 'anitabi-115908-7evkbmy2',
    referenceMode: '叠影',
    capturedAt: DateTime(2026, 6, 1, 9, 18),
  ),
  _sampleVisitRecord(
    id: 'sample-record-uji-walk-02',
    pointId: 'anitabi-115908-7evkbmy2',
    referenceMode: '上下',
    capturedAt: DateTime(2026, 6, 1, 9, 26),
    graded: true,
  ),
  _sampleVisitRecord(
    id: 'sample-record-uji-bridge-01',
    pointId: 'anitabi-115908-7gs3o1mm',
    referenceMode: '叠影',
    capturedAt: DateTime(2026, 6, 1, 10, 8),
  ),
  _sampleVisitRecord(
    id: 'sample-record-jr-uji-01',
    pointId: 'anitabi-115908-3plnxvy',
    referenceMode: '上下',
    capturedAt: DateTime(2026, 6, 1, 10, 42),
  ),
  _sampleVisitRecord(
    id: 'sample-record-daikichi-gate-01',
    pointId: 'anitabi-115908-qys7ia',
    referenceMode: '叠影',
    capturedAt: DateTime(2026, 6, 1, 13, 14),
  ),
  _sampleVisitRecord(
    id: 'sample-record-daikichi-view-01',
    pointId: 'anitabi-115908-7mt52rr',
    referenceMode: '上下',
    capturedAt: DateTime(2026, 6, 1, 14, 2),
    graded: true,
  ),
  _sampleVisitRecord(
    id: 'sample-record-daikichi-view-02',
    pointId: 'anitabi-115908-7mt52rr',
    referenceMode: '叠影',
    capturedAt: DateTime(2026, 6, 1, 14, 18),
  ),
  _sampleVisitRecord(
    id: 'sample-record-byodoin-01',
    pointId: 'anitabi-115908-sample-byodoin-01',
    referenceMode: '叠影',
    capturedAt: DateTime(2026, 6, 2, 9, 40),
  ),
  _sampleVisitRecord(
    id: 'sample-record-byodoin-02',
    pointId: 'anitabi-115908-sample-byodoin-02',
    referenceMode: '上下',
    capturedAt: DateTime(2026, 6, 2, 9, 58),
  ),
  _sampleVisitRecord(
    id: 'sample-record-agata-01',
    pointId: 'anitabi-115908-qys7ix',
    referenceMode: '叠影',
    capturedAt: DateTime(2026, 6, 2, 11, 15),
  ),
  _sampleVisitRecord(
    id: 'sample-record-agata-02',
    pointId: 'anitabi-115908-sample-agata-01',
    referenceMode: '上下',
    capturedAt: DateTime(2026, 6, 2, 11, 42),
    graded: true,
  ),
  _sampleVisitRecord(
    id: 'sample-record-rokuchizo-01',
    pointId: 'anitabi-115908-sample-rokuchizo-01',
    referenceMode: '叠影',
    capturedAt: DateTime(2026, 6, 3, 8, 30),
  ),
  _sampleVisitRecord(
    id: 'sample-record-obaku-01',
    pointId: 'anitabi-115908-sample-obaku-01',
    referenceMode: '上下',
    capturedAt: DateTime(2026, 6, 3, 10, 4),
  ),
  _sampleVisitRecord(
    id: 'sample-record-kohata-01',
    pointId: 'anitabi-115908-sample-kohata-01',
    referenceMode: '叠影',
    capturedAt: DateTime(2026, 6, 3, 12, 25),
  ),
  _sampleVisitRecord(
    id: 'sample-record-ungrouped-01',
    pointId: 'anitabi-115908-sample-unassigned-02',
    referenceMode: '上下',
    capturedAt: DateTime(2026, 6, 3, 15, 6),
  ),
];

PilgrimageVisitRecord _sampleVisitRecord({
  required String id,
  required String pointId,
  required String referenceMode,
  required DateTime capturedAt,
  bool graded = false,
}) {
  final point = samplePilgrimagePlan.points.firstWhere(
    (candidate) => candidate.id == pointId,
  );
  final photoPath = _sampleVisitPhotoPath(id);
  return PilgrimageVisitRecord(
    id: id,
    planId: samplePilgrimagePlan.id,
    pointId: pointId,
    workId: point.work.id,
    workTitle: point.work.title,
    workSubtitle: point.work.subtitle,
    pointName: point.name,
    pointSubtitle: point.subtitle,
    photoPath: photoPath,
    originalPhotoPath: graded ? photoPath : null,
    gradedPhotoPath: graded ? photoPath : null,
    colorGradingMode: graded ? '自动调色' : null,
    colorGradingParamsJson: graded
        ? '{"exposure":0.04,"contrast":0.08,"saturation":0.12}'
        : null,
    colorGradingIntensity: graded ? 0.72 : null,
    referenceImageUrl: point.referenceImageUrl,
    referenceMode: referenceMode,
    capturedAt: capturedAt,
  );
}

String _sampleVisitPhotoPath(String recordId) {
  return 'docs/sample_images/sample_visit_records/$recordId.jpg';
}
