import '../data/pilgrimage_repository.dart';
import '../data/sample_pilgrimage_repository.dart';
import '../plan/pilgrimage_models.dart';
import 'desktop_repository_state.dart';
import 'tauri_bridge.dart';

class DesktopPilgrimageRepository extends SamplePilgrimageRepository {
  DesktopPilgrimageRepository._({SamplePilgrimageRepositorySnapshot? snapshot})
    : super(
        plans: snapshot?.plans,
        visitRecords: snapshot?.visitRecords,
        settings: snapshot?.settings,
        activePlanId: snapshot?.activePlanId,
      );

  static Future<PilgrimageRepository> create() async {
    final stored = await loadDesktopState();
    final snapshot = decodeDesktopRepositoryState(stored?.stateJson);
    final repository = DesktopPilgrimageRepository._(snapshot: snapshot);
    if (snapshot == null) {
      await repository._persist();
    }
    return repository;
  }

  Future<T> _withPersist<T>(Future<T> Function() action) async {
    final result = await action();
    await _persist();
    return result;
  }

  Future<void> _persist() async {
    await saveDesktopState(stateJson: encodeDesktopRepositoryState(snapshot()));
  }

  @override
  Future<void> setActivePlan(String id) {
    return _withPersist(() => super.setActivePlan(id));
  }

  @override
  Future<PilgrimagePlan> createPlan({
    required String name,
    required String area,
  }) {
    return _withPersist(() => super.createPlan(name: name, area: area));
  }

  @override
  Future<PilgrimagePlan> importPlanPackage({
    required PilgrimagePlan plan,
    required List<PilgrimageVisitRecord> visitRecords,
  }) {
    return _withPersist(
      () => super.importPlanPackage(plan: plan, visitRecords: visitRecords),
    );
  }

  @override
  Future<PilgrimagePlan> renamePlan({
    required String planId,
    required String name,
  }) {
    return _withPersist(() => super.renamePlan(planId: planId, name: name));
  }

  @override
  Future<PilgrimagePlan> addPointToPlan({
    required String planId,
    required PilgrimagePoint point,
  }) {
    return _withPersist(
      () => super.addPointToPlan(planId: planId, point: point),
    );
  }

  @override
  Future<PilgrimagePlan> addPointsToPlan({
    required String planId,
    required List<PilgrimagePoint> points,
  }) {
    return _withPersist(
      () => super.addPointsToPlan(planId: planId, points: points),
    );
  }

  @override
  Future<PilgrimagePlan> updatePointImageCache({
    required String planId,
    required String pointId,
    String? referenceThumbnailPath,
    String? referenceFullImagePath,
  }) {
    return _withPersist(
      () => super.updatePointImageCache(
        planId: planId,
        pointId: pointId,
        referenceThumbnailPath: referenceThumbnailPath,
        referenceFullImagePath: referenceFullImagePath,
      ),
    );
  }

  @override
  Future<PilgrimagePlan> addWorkToPlan({
    required String planId,
    required PilgrimageWork work,
  }) {
    return _withPersist(() => super.addWorkToPlan(planId: planId, work: work));
  }

  @override
  Future<PilgrimagePlan> createPlanGroup({
    required String planId,
    required PilgrimagePlanGroup group,
  }) {
    return _withPersist(
      () => super.createPlanGroup(planId: planId, group: group),
    );
  }

  @override
  Future<PilgrimagePlan> renamePlanGroup({
    required String planId,
    required String groupId,
    required String name,
  }) {
    return _withPersist(
      () => super.renamePlanGroup(planId: planId, groupId: groupId, name: name),
    );
  }

  @override
  Future<PilgrimagePlan> updatePlanGroup({
    required String planId,
    required PilgrimagePlanGroup group,
  }) {
    return _withPersist(
      () => super.updatePlanGroup(planId: planId, group: group),
    );
  }

  @override
  Future<PilgrimagePlan> deletePlanGroup({
    required String planId,
    required String groupId,
  }) {
    return _withPersist(
      () => super.deletePlanGroup(planId: planId, groupId: groupId),
    );
  }

  @override
  Future<PilgrimagePlan> movePointsToGroup({
    required String planId,
    required Set<String> pointIds,
    required String? groupId,
  }) {
    return _withPersist(
      () => super.movePointsToGroup(
        planId: planId,
        pointIds: pointIds,
        groupId: groupId,
      ),
    );
  }

  @override
  Future<PilgrimagePlan> deleteWorkFromPlan({
    required String planId,
    required String workId,
  }) {
    return _withPersist(
      () => super.deleteWorkFromPlan(planId: planId, workId: workId),
    );
  }

  @override
  Future<PilgrimagePlan> deletePointFromPlan({
    required String planId,
    required String pointId,
  }) {
    return _withPersist(
      () => super.deletePointFromPlan(planId: planId, pointId: pointId),
    );
  }

  @override
  Future<PilgrimagePlan> deletePointsFromPlan({
    required String planId,
    required Set<String> pointIds,
  }) {
    return _withPersist(
      () => super.deletePointsFromPlan(planId: planId, pointIds: pointIds),
    );
  }

  @override
  Future<PilgrimagePlan> reorderPoints({
    required String planId,
    required List<String> pointIds,
  }) {
    return _withPersist(
      () => super.reorderPoints(planId: planId, pointIds: pointIds),
    );
  }

  @override
  Future<void> setCurrentPoint({
    required String planId,
    required String pointId,
  }) {
    return _withPersist(
      () => super.setCurrentPoint(planId: planId, pointId: pointId),
    );
  }

  @override
  Future<void> completePoint({
    required String planId,
    required String pointId,
    required String? nextCurrentPointId,
  }) {
    return _withPersist(
      () => super.completePoint(
        planId: planId,
        pointId: pointId,
        nextCurrentPointId: nextCurrentPointId,
      ),
    );
  }

  @override
  Future<void> completePoints({
    required String planId,
    required Set<String> pointIds,
  }) {
    return _withPersist(
      () => super.completePoints(planId: planId, pointIds: pointIds),
    );
  }

  @override
  Future<void> reopenPoint({required String planId, required String pointId}) {
    return _withPersist(
      () => super.reopenPoint(planId: planId, pointId: pointId),
    );
  }

  @override
  Future<void> reopenPoints({
    required String planId,
    required Set<String> pointIds,
  }) {
    return _withPersist(
      () => super.reopenPoints(planId: planId, pointIds: pointIds),
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
  }) {
    return _withPersist(
      () => super.createVisitRecord(
        planId: planId,
        pointId: pointId,
        workId: workId,
        photoPath: photoPath,
        referenceImagePath: referenceImagePath,
        referenceImageUrl: referenceImageUrl,
        referenceMode: referenceMode,
        capturedAt: capturedAt,
      ),
    );
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
  }) {
    return _withPersist(
      () => super.updateVisitRecordColorGrading(
        planId: planId,
        recordId: recordId,
        originalPhotoPath: originalPhotoPath,
        gradedPhotoPath: gradedPhotoPath,
        colorGradingMode: colorGradingMode,
        colorGradingParamsJson: colorGradingParamsJson,
        colorGradingIntensity: colorGradingIntensity,
      ),
    );
  }

  @override
  Future<PilgrimageVisitRecord> clearVisitRecordColorGrading({
    required String planId,
    required String recordId,
  }) {
    return _withPersist(
      () => super.clearVisitRecordColorGrading(
        planId: planId,
        recordId: recordId,
      ),
    );
  }

  @override
  Future<void> deleteVisitRecord({
    required String planId,
    required String recordId,
  }) {
    return _withPersist(
      () => super.deleteVisitRecord(planId: planId, recordId: recordId),
    );
  }

  @override
  Future<void> deletePlan(String id) {
    return _withPersist(() => super.deletePlan(id));
  }

  @override
  Future<void> saveAppSettings(AppSettings settings) {
    return _withPersist(() => super.saveAppSettings(settings));
  }
}
