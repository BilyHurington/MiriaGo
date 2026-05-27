import 'package:latlong2/latlong.dart';

import '../plan/pilgrimage_models.dart';
import 'pilgrimage_repository.dart';

class SamplePilgrimageRepository implements PilgrimageRepository {
  SamplePilgrimageRepository()
    : _plans = [samplePilgrimagePlan, sampleEmptyPlan],
      _visitRecords = [],
      _settings = const AppSettings(),
      _activePlanId = samplePilgrimagePlan.id;

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
    final index = _planIndex(planId);
    final updatedPlan = _plans[index].copyWith(
      name: name,
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
  Future<PilgrimagePlan> updatePointImageCache({
    required String planId,
    required String pointId,
    String? referenceThumbnailPath,
    String? referenceFullImagePath,
  }) async {
    final index = _planIndex(planId);
    final plan = _plans[index];
    final updatedPlan = plan.copyWith(
      points: [
        for (final point in plan.points)
          point.id == pointId
              ? point.copyWith(
                  referenceThumbnailPath: referenceThumbnailPath,
                  referenceFullImagePath: referenceFullImagePath,
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
    _visitRecords.removeWhere(
      (record) =>
          record.planId == planId &&
          (record.workId == workId || removedPointIds.contains(record.pointId)),
    );
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
    _visitRecords.removeWhere(
      (record) => record.planId == planId && pointIds.contains(record.pointId),
    );
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
      uiScale: settings.uiScale.clamp(0.5, 2.0),
      cameraMinZoom: settings.cameraMinZoom.clamp(0.1, 10.0),
      cameraMaxZoom: settings.cameraMaxZoom.clamp(1.0, 20.0),
      cameraFallbackAspectRatio:
          settings.cameraFallbackAspectRatio == CameraPhotoAspectRatio.auto
          ? CameraPhotoAspectRatio.landscape16x9
          : settings.cameraFallbackAspectRatio,
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

final _sampleCreatedAt = DateTime(2026, 5, 23, 9);

const _hibikeWork = PilgrimageWork(
  id: 'hibike-euphonium',
  bangumiId: 115908,
  title: '吹响吧！上低音号',
  subtitle: '響け！ユーフォニアム',
  city: '宇治市',
  source: WorkSource.bangumi,
);

const _tamakoWork = PilgrimageWork(
  id: 'tamako-market',
  bangumiId: 55113,
  title: '玉子市场',
  subtitle: 'たまこまーけっと',
  city: '京都市',
  source: WorkSource.bangumi,
);

final samplePilgrimagePlan = PilgrimagePlan(
  id: 'sample-uji-hibike',
  name: '京都南部一日巡礼',
  area: '宇治市 / 京都市',
  works: const [_hibikeWork, _tamakoWork],
  createdAt: _sampleCreatedAt,
  updatedAt: _sampleCreatedAt,
  points: const [
    PilgrimagePoint(
      id: 'uji-bridge',
      work: _hibikeWork,
      name: '宇治桥',
      subtitle: '宇治川沿岸',
      position: LatLng(34.8917, 135.8077),
      episodeLabel: '示例点位 1',
      referenceLabel: '参考图待接入',
    ),
    PilgrimagePoint(
      id: 'agata-dori',
      work: _hibikeWork,
      name: 'あがた通り',
      subtitle: '县神社方向街道',
      position: LatLng(34.8899, 135.8081),
      episodeLabel: '示例点位 2',
      referenceLabel: '参考图待接入',
    ),
    PilgrimagePoint(
      id: 'uji-station',
      work: _hibikeWork,
      name: 'JR 宇治站',
      subtitle: 'JR 奈良线车站',
      position: LatLng(34.8905, 135.8008),
      episodeLabel: '示例点位 3',
      referenceLabel: '参考图待接入',
    ),
    PilgrimagePoint(
      id: 'demachi-masugata',
      work: _tamakoWork,
      name: '出町桝形商店街',
      subtitle: '商店街入口',
      position: LatLng(35.0306, 135.7721),
      episodeLabel: '示例点位 4',
      referenceLabel: '参考图待接入',
    ),
  ],
);

final sampleEmptyPlan = PilgrimagePlan(
  id: 'sample-empty-kyoto',
  name: '京都空计划',
  area: '京都市',
  works: const [],
  points: const [],
  createdAt: _sampleCreatedAt,
  updatedAt: _sampleCreatedAt,
);
