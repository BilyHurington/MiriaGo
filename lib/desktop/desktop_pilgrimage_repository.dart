import '../data/pilgrimage_repository.dart';
import '../data/sample_pilgrimage_repository.dart';
import '../plan/pilgrimage_models.dart';
import 'desktop_repository_state.dart';
import 'tauri_bridge.dart';

class DesktopRepositoryPersistence {
  const DesktopRepositoryPersistence();

  Future<void> saveState(String json) async {
    await saveDesktopState(stateJson: json);
  }

  Future<void> saveSettings(String json) async {
    await saveDesktopSettings(settingsJson: json);
  }

  Future<void> savePlan(String plan, String records, String? activeId) async {
    await saveDesktopPlanBundle(
      planJson: plan,
      visitRecordsJson: records,
      activePlanId: activeId,
    );
  }

  Future<void> setActivePlan(String id) async {
    await setDesktopActivePlan(planId: id);
  }

  Future<void> deletePlan(String id, String? activeId) async {
    await deleteDesktopPlan(planId: id, activePlanId: activeId);
  }

  Future<void> saveRecord(String json) async {
    await saveDesktopVisitRecord(recordJson: json);
  }

  Future<void> deleteRecord(String id) async {
    await deleteDesktopVisitRecord(recordId: id);
  }
}

class DesktopPilgrimageRepository implements PilgrimageRepository {
  DesktopPilgrimageRepository({
    SamplePilgrimageRepositorySnapshot? snapshot,
    this.persistence = const DesktopRepositoryPersistence(),
  }) : _committed = SamplePilgrimageRepository(
         plans: snapshot?.plans,
         visitRecords: snapshot?.visitRecords,
         settings: snapshot?.settings,
         activePlanId: snapshot?.activePlanId,
       );

  final DesktopRepositoryPersistence persistence;
  SamplePilgrimageRepository _committed;
  Future<void> _pendingWrites = Future.value();

  SamplePilgrimageRepositorySnapshot snapshot() => _committed.snapshot();

  @override
  Future<List<PilgrimagePlan>> loadPlans() => _committed.loadPlans();

  @override
  Future<PilgrimagePlan> loadActivePlan() => _committed.loadActivePlan();

  @override
  Future<AppSettings> loadAppSettings() => _committed.loadAppSettings();

  @override
  Future<List<PilgrimageVisitRecord>> loadVisitRecords(String planId) =>
      _committed.loadVisitRecords(planId);

  Future<T> _write<T>(
    Future<T> Function(SamplePilgrimageRepository draft) action,
    Future<void> Function(SamplePilgrimageRepository draft, T result) persist,
  ) {
    // Stage each mutation separately; readers only see successfully persisted state.
    final result = _pendingWrites.then((_) async {
      final previous = snapshot();
      final draft = SamplePilgrimageRepository(
        plans: previous.plans,
        visitRecords: previous.visitRecords,
        settings: previous.settings,
        activePlanId: previous.activePlanId,
      );
      final value = await action(draft);
      await persist(draft, value);
      _committed = draft;
      return value;
    });
    _pendingWrites = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  static Future<PilgrimageRepository> create() async {
    final stored = await loadDesktopState();
    final snapshot = decodeDesktopRepositoryState(stored?.stateJson);
    final repository = DesktopPilgrimageRepository(snapshot: snapshot);
    if (snapshot == null) {
      await repository._persistInitialState();
    }
    return repository;
  }

  Future<void> _persistInitialState() async {
    await persistence.saveState(encodeDesktopRepositoryState(snapshot()));
  }

  Future<void> _savePlanBundle(
    SamplePilgrimageRepository draft,
    PilgrimagePlan plan,
  ) async {
    final records = await draft.loadVisitRecords(plan.id);
    await persistence.savePlan(
      encodeDesktopPlan(plan),
      encodeDesktopVisitRecords(records),
      draft.snapshot().activePlanId,
    );
  }

  Future<PilgrimagePlan> _withPlanSave(
    Future<PilgrimagePlan> Function(SamplePilgrimageRepository draft) action,
  ) {
    return _write(action, _savePlanBundle);
  }

  Future<void> _withPlanMutation(
    String planId,
    Future<void> Function(SamplePilgrimageRepository draft) action,
  ) {
    return _write<void>(
      action,
      (draft, _) => _savePlanBundle(
        draft,
        draft.snapshot().plans.firstWhere((plan) => plan.id == planId),
      ),
    );
  }

  @override
  Future<void> setActivePlan(String id) {
    return _write<void>(
      (draft) => draft.setActivePlan(id),
      (_, _) => persistence.setActivePlan(id),
    );
  }

  @override
  Future<void> reorderPlans({required List<String> orderedPlanIds}) {
    return _write<void>(
      (draft) => draft.reorderPlans(orderedPlanIds: orderedPlanIds),
      (draft, _) =>
          persistence.saveState(encodeDesktopRepositoryState(draft.snapshot())),
    );
  }

  @override
  Future<PilgrimagePlan> createPlan({
    required String name,
    required String area,
  }) {
    return _withPlanSave((draft) => draft.createPlan(name: name, area: area));
  }

  @override
  Future<PilgrimagePlan> importPlanPackage({
    required PilgrimagePlan plan,
    required List<PilgrimageVisitRecord> visitRecords,
  }) {
    return _withPlanSave(
      (draft) =>
          draft.importPlanPackage(plan: plan, visitRecords: visitRecords),
    );
  }

  @override
  Future<PilgrimagePlan> renamePlan({
    required String planId,
    required String name,
  }) {
    return _withPlanSave(
      (draft) => draft.renamePlan(planId: planId, name: name),
    );
  }

  @override
  Future<PilgrimagePlan> updatePlanInfo({
    required String planId,
    required String name,
    required String area,
  }) {
    return _withPlanSave(
      (draft) => draft.updatePlanInfo(planId: planId, name: name, area: area),
    );
  }

  @override
  Future<PilgrimagePlan> updatePlanMemo({
    required String planId,
    required String memo,
  }) {
    return _withPlanSave(
      (draft) => draft.updatePlanMemo(planId: planId, memo: memo),
    );
  }

  @override
  Future<PilgrimagePlan> addPointToPlan({
    required String planId,
    required PilgrimagePoint point,
  }) {
    return _withPlanSave(
      (draft) => draft.addPointToPlan(planId: planId, point: point),
    );
  }

  @override
  Future<PilgrimagePlan> addPointsToPlan({
    required String planId,
    required List<PilgrimagePoint> points,
  }) {
    return _withPlanSave(
      (draft) => draft.addPointsToPlan(planId: planId, points: points),
    );
  }

  @override
  Future<PilgrimagePlan> updatePointInPlan({
    required String planId,
    required PilgrimagePoint point,
  }) => _withPlanSave(
    (draft) => draft.updatePointInPlan(planId: planId, point: point),
  );

  @override
  Future<PilgrimagePlan> updatePointImageCache({
    required String planId,
    required String pointId,
    String? referenceThumbnailPath,
    String? referenceFullImagePath,
  }) {
    return _withPlanSave(
      (draft) => draft.updatePointImageCache(
        planId: planId,
        pointId: pointId,
        referenceThumbnailPath: referenceThumbnailPath,
        referenceFullImagePath: referenceFullImagePath,
      ),
    );
  }

  @override
  Future<PilgrimagePlan> updatePointImageCaches({
    required String planId,
    required Map<String, PointImageCacheUpdate> updatesByPointId,
  }) {
    return _withPlanSave(
      (draft) => draft.updatePointImageCaches(
        planId: planId,
        updatesByPointId: updatesByPointId,
      ),
    );
  }

  @override
  Future<PilgrimagePlan> addWorkToPlan({
    required String planId,
    required PilgrimageWork work,
  }) {
    return _withPlanSave(
      (draft) => draft.addWorkToPlan(planId: planId, work: work),
    );
  }

  @override
  Future<PilgrimageWork?> fillMissingWorkFieldsIfPresent({
    required String planId,
    required PilgrimageWork work,
  }) {
    return _write<PilgrimageWork?>(
      (draft) =>
          draft.fillMissingWorkFieldsIfPresent(planId: planId, work: work),
      (draft, stored) async {
        if (stored == null) {
          return;
        }
        await _savePlanBundle(
          draft,
          draft.snapshot().plans.firstWhere((plan) => plan.id == planId),
        );
      },
    );
  }

  @override
  Future<PilgrimagePlan> createPlanGroup({
    required String planId,
    required PilgrimagePlanGroup group,
  }) {
    return _withPlanSave(
      (draft) => draft.createPlanGroup(planId: planId, group: group),
    );
  }

  @override
  Future<PilgrimagePlan> renamePlanGroup({
    required String planId,
    required String groupId,
    required String name,
  }) {
    return _withPlanSave(
      (draft) =>
          draft.renamePlanGroup(planId: planId, groupId: groupId, name: name),
    );
  }

  @override
  Future<PilgrimagePlan> updatePlanGroup({
    required String planId,
    required PilgrimagePlanGroup group,
  }) {
    return _withPlanSave(
      (draft) => draft.updatePlanGroup(planId: planId, group: group),
    );
  }

  @override
  Future<PilgrimagePlan> deletePlanGroup({
    required String planId,
    required String groupId,
  }) {
    return _withPlanSave(
      (draft) => draft.deletePlanGroup(planId: planId, groupId: groupId),
    );
  }

  @override
  Future<PilgrimagePlan> movePointsToGroup({
    required String planId,
    required Set<String> pointIds,
    required String? groupId,
  }) {
    return _withPlanSave(
      (draft) => draft.movePointsToGroup(
        planId: planId,
        pointIds: pointIds,
        groupId: groupId,
      ),
    );
  }

  @override
  Future<PilgrimagePlan> reorderGroups({
    required String planId,
    required List<String> orderedGroupIds,
  }) {
    return _withPlanSave(
      (draft) =>
          draft.reorderGroups(planId: planId, orderedGroupIds: orderedGroupIds),
    );
  }

  @override
  Future<PilgrimagePlan> assignPointsToGroups({
    required String planId,
    required Map<String, String?> groupIdsByPointId,
  }) {
    return _withPlanSave(
      (draft) => draft.assignPointsToGroups(
        planId: planId,
        groupIdsByPointId: groupIdsByPointId,
      ),
    );
  }

  @override
  Future<PilgrimagePlan> deleteWorkFromPlan({
    required String planId,
    required String workId,
  }) {
    return _withPlanSave(
      (draft) => draft.deleteWorkFromPlan(planId: planId, workId: workId),
    );
  }

  @override
  Future<PilgrimagePlan> deletePointFromPlan({
    required String planId,
    required String pointId,
  }) {
    return _withPlanSave(
      (draft) => draft.deletePointFromPlan(planId: planId, pointId: pointId),
    );
  }

  @override
  Future<PilgrimagePlan> deletePointsFromPlan({
    required String planId,
    required Set<String> pointIds,
  }) {
    return _withPlanSave(
      (draft) => draft.deletePointsFromPlan(planId: planId, pointIds: pointIds),
    );
  }

  @override
  Future<PilgrimagePlan> reorderPoints({
    required String planId,
    required List<String> pointIds,
  }) {
    return _withPlanSave(
      (draft) => draft.reorderPoints(planId: planId, pointIds: pointIds),
    );
  }

  @override
  Future<PilgrimagePlan> reorderGroupPoints({
    required String planId,
    required String groupId,
    required List<String> pointIds,
  }) {
    return _withPlanSave(
      (draft) => draft.reorderGroupPoints(
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
  }) {
    return _withPlanMutation(
      planId,
      (draft) => draft.setCurrentPoint(planId: planId, pointId: pointId),
    );
  }

  @override
  Future<void> setCurrentGroup({
    required String planId,
    required String? groupId,
  }) {
    return _withPlanMutation(
      planId,
      (draft) => draft.setCurrentGroup(planId: planId, groupId: groupId),
    );
  }

  @override
  Future<void> completePoint({
    required String planId,
    required String pointId,
    required String? nextCurrentPointId,
  }) {
    return _withPlanMutation(
      planId,
      (draft) => draft.completePoint(
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
    return _withPlanMutation(
      planId,
      (draft) => draft.completePoints(planId: planId, pointIds: pointIds),
    );
  }

  @override
  Future<void> reopenPoint({required String planId, required String pointId}) {
    return _withPlanMutation(
      planId,
      (draft) => draft.reopenPoint(planId: planId, pointId: pointId),
    );
  }

  @override
  Future<void> reopenPoints({
    required String planId,
    required Set<String> pointIds,
  }) {
    return _withPlanMutation(
      planId,
      (draft) => draft.reopenPoints(planId: planId, pointIds: pointIds),
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
  }) {
    return _write<PilgrimageVisitRecord>(
      (draft) => draft.createVisitRecord(
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
        capturedAt: capturedAt,
      ),
      (_, record) => persistence.saveRecord(encodeDesktopVisitRecord(record)),
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
    return _write<PilgrimageVisitRecord>(
      (draft) => draft.updateVisitRecordColorGrading(
        planId: planId,
        recordId: recordId,
        originalPhotoPath: originalPhotoPath,
        gradedPhotoPath: gradedPhotoPath,
        colorGradingMode: colorGradingMode,
        colorGradingParamsJson: colorGradingParamsJson,
        colorGradingIntensity: colorGradingIntensity,
      ),
      (_, record) => persistence.saveRecord(encodeDesktopVisitRecord(record)),
    );
  }

  @override
  Future<PilgrimageVisitRecord> clearVisitRecordColorGrading({
    required String planId,
    required String recordId,
  }) {
    return _write<PilgrimageVisitRecord>(
      (draft) => draft.clearVisitRecordColorGrading(
        planId: planId,
        recordId: recordId,
      ),
      (_, record) => persistence.saveRecord(encodeDesktopVisitRecord(record)),
    );
  }

  @override
  Future<void> deleteVisitRecord({
    required String planId,
    required String recordId,
  }) {
    return _write<void>(
      (draft) => draft.deleteVisitRecord(planId: planId, recordId: recordId),
      (_, _) => persistence.deleteRecord(recordId),
    );
  }

  @override
  Future<void> deletePlan(String id) {
    return _write<void>(
      (draft) => draft.deletePlan(id),
      (draft, _) => persistence.deletePlan(id, draft.snapshot().activePlanId),
    );
  }

  @override
  Future<void> saveAppSettings(AppSettings settings) {
    return _write<void>(
      (draft) => draft.saveAppSettings(settings),
      (draft, _) => persistence.saveSettings(
        encodeDesktopAppSettings(draft.snapshot().settings),
      ),
    );
  }
}
