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
      await repository._persistInitialState();
    }
    return repository;
  }

  Future<void> _persistInitialState() async {
    final current = snapshot();
    await saveDesktopSettings(
      settingsJson: encodeDesktopAppSettings(current.settings),
    );
    for (final plan in current.plans) {
      await _savePlanBundle(plan);
    }
    await setDesktopActivePlan(planId: current.activePlanId);
  }

  Future<void> _savePlanBundle(PilgrimagePlan plan) async {
    final records = await super.loadVisitRecords(plan.id);
    await saveDesktopPlanBundle(
      planJson: encodeDesktopPlan(plan),
      visitRecordsJson: encodeDesktopVisitRecords(records),
      activePlanId: snapshot().activePlanId,
    );
  }

  Future<PilgrimagePlan> _withPlanSave(
    Future<PilgrimagePlan> Function() action,
  ) async {
    final plan = await action();
    await _savePlanBundle(plan);
    return plan;
  }

  Future<void> _savePlanById(String planId) async {
    final plan = snapshot().plans.firstWhere((plan) => plan.id == planId);
    await _savePlanBundle(plan);
  }

  Future<void> _saveRecord(PilgrimageVisitRecord record) async {
    await saveDesktopVisitRecord(recordJson: encodeDesktopVisitRecord(record));
  }

  @override
  Future<void> setActivePlan(String id) {
    return super
        .setActivePlan(id)
        .then((_) => setDesktopActivePlan(planId: id));
  }

  @override
  Future<PilgrimagePlan> createPlan({
    required String name,
    required String area,
  }) {
    return _withPlanSave(() => super.createPlan(name: name, area: area));
  }

  @override
  Future<PilgrimagePlan> importPlanPackage({
    required PilgrimagePlan plan,
    required List<PilgrimageVisitRecord> visitRecords,
  }) {
    return _withPlanSave(
      () => super.importPlanPackage(plan: plan, visitRecords: visitRecords),
    );
  }

  @override
  Future<PilgrimagePlan> renamePlan({
    required String planId,
    required String name,
  }) {
    return _withPlanSave(() => super.renamePlan(planId: planId, name: name));
  }

  @override
  Future<PilgrimagePlan> addPointToPlan({
    required String planId,
    required PilgrimagePoint point,
  }) {
    return _withPlanSave(
      () => super.addPointToPlan(planId: planId, point: point),
    );
  }

  @override
  Future<PilgrimagePlan> addPointsToPlan({
    required String planId,
    required List<PilgrimagePoint> points,
  }) {
    return _withPlanSave(
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
    return _withPlanSave(
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
    return _withPlanSave(() => super.addWorkToPlan(planId: planId, work: work));
  }

  @override
  Future<PilgrimagePlan> createPlanGroup({
    required String planId,
    required PilgrimagePlanGroup group,
  }) {
    return _withPlanSave(
      () => super.createPlanGroup(planId: planId, group: group),
    );
  }

  @override
  Future<PilgrimagePlan> renamePlanGroup({
    required String planId,
    required String groupId,
    required String name,
  }) {
    return _withPlanSave(
      () => super.renamePlanGroup(planId: planId, groupId: groupId, name: name),
    );
  }

  @override
  Future<PilgrimagePlan> updatePlanGroup({
    required String planId,
    required PilgrimagePlanGroup group,
  }) {
    return _withPlanSave(
      () => super.updatePlanGroup(planId: planId, group: group),
    );
  }

  @override
  Future<PilgrimagePlan> deletePlanGroup({
    required String planId,
    required String groupId,
  }) {
    return _withPlanSave(
      () => super.deletePlanGroup(planId: planId, groupId: groupId),
    );
  }

  @override
  Future<PilgrimagePlan> movePointsToGroup({
    required String planId,
    required Set<String> pointIds,
    required String? groupId,
  }) {
    return _withPlanSave(
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
    return _withPlanSave(
      () => super.deleteWorkFromPlan(planId: planId, workId: workId),
    );
  }

  @override
  Future<PilgrimagePlan> deletePointFromPlan({
    required String planId,
    required String pointId,
  }) {
    return _withPlanSave(
      () => super.deletePointFromPlan(planId: planId, pointId: pointId),
    );
  }

  @override
  Future<PilgrimagePlan> deletePointsFromPlan({
    required String planId,
    required Set<String> pointIds,
  }) {
    return _withPlanSave(
      () => super.deletePointsFromPlan(planId: planId, pointIds: pointIds),
    );
  }

  @override
  Future<PilgrimagePlan> reorderPoints({
    required String planId,
    required List<String> pointIds,
  }) {
    return _withPlanSave(
      () => super.reorderPoints(planId: planId, pointIds: pointIds),
    );
  }

  @override
  Future<PilgrimagePlan> reorderGroupPoints({
    required String planId,
    required String groupId,
    required List<String> pointIds,
  }) {
    return _withPlanSave(
      () => super.reorderGroupPoints(
        planId: planId,
        groupId: groupId,
        pointIds: pointIds,
      ),
    );
  }

  @override
  Future<void> setCurrentPoint({
    required String planId,
    required String pointId,
  }) async {
    await super.setCurrentPoint(planId: planId, pointId: pointId);
    await _savePlanById(planId);
  }

  @override
  Future<void> completePoint({
    required String planId,
    required String pointId,
    required String? nextCurrentPointId,
  }) async {
    await super.completePoint(
      planId: planId,
      pointId: pointId,
      nextCurrentPointId: nextCurrentPointId,
    );
    await _savePlanById(planId);
  }

  @override
  Future<void> completePoints({
    required String planId,
    required Set<String> pointIds,
  }) async {
    await super.completePoints(planId: planId, pointIds: pointIds);
    await _savePlanById(planId);
  }

  @override
  Future<void> reopenPoint({
    required String planId,
    required String pointId,
  }) async {
    await super.reopenPoint(planId: planId, pointId: pointId);
    await _savePlanById(planId);
  }

  @override
  Future<void> reopenPoints({
    required String planId,
    required Set<String> pointIds,
  }) async {
    await super.reopenPoints(planId: planId, pointIds: pointIds);
    await _savePlanById(planId);
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
    final record = await super.createVisitRecord(
      planId: planId,
      pointId: pointId,
      workId: workId,
      photoPath: photoPath,
      referenceImagePath: referenceImagePath,
      referenceImageUrl: referenceImageUrl,
      referenceMode: referenceMode,
      capturedAt: capturedAt,
    );
    await _saveRecord(record);
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
    final record = await super.updateVisitRecordColorGrading(
      planId: planId,
      recordId: recordId,
      originalPhotoPath: originalPhotoPath,
      gradedPhotoPath: gradedPhotoPath,
      colorGradingMode: colorGradingMode,
      colorGradingParamsJson: colorGradingParamsJson,
      colorGradingIntensity: colorGradingIntensity,
    );
    await _saveRecord(record);
    return record;
  }

  @override
  Future<PilgrimageVisitRecord> clearVisitRecordColorGrading({
    required String planId,
    required String recordId,
  }) async {
    final record = await super.clearVisitRecordColorGrading(
      planId: planId,
      recordId: recordId,
    );
    await _saveRecord(record);
    return record;
  }

  @override
  Future<void> deleteVisitRecord({
    required String planId,
    required String recordId,
  }) async {
    await super.deleteVisitRecord(planId: planId, recordId: recordId);
    await deleteDesktopVisitRecord(recordId: recordId);
  }

  @override
  Future<void> deletePlan(String id) async {
    await super.deletePlan(id);
    await deleteDesktopPlan(planId: id, activePlanId: snapshot().activePlanId);
  }

  @override
  Future<void> saveAppSettings(AppSettings settings) async {
    await super.saveAppSettings(settings);
    await saveDesktopSettings(
      settingsJson: encodeDesktopAppSettings(snapshot().settings),
    );
  }
}
