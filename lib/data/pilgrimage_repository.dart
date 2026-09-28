import '../plan/pilgrimage_models.dart';

/// A repository may emit this only after proving the record was not committed.
/// Other failures, including transport errors, have an unknown commit outcome.
class VisitRecordNotCommittedException implements Exception {
  const VisitRecordNotCommittedException(this.cause);
  final Object cause;

  @override
  String toString() => 'Visit record was not committed: $cause';
}

abstract interface class PilgrimageRepository {
  Future<List<PilgrimagePlan>> loadPlans();

  Future<PilgrimagePlan> loadActivePlan();

  Future<AppSettings> loadAppSettings();

  Future<List<PilgrimageVisitRecord>> loadVisitRecords(String planId);

  Future<void> setActivePlan(String id);

  Future<void> reorderPlans({required List<String> orderedPlanIds});

  Future<PilgrimagePlan> createPlan({
    required String name,
    required String area,
  });

  Future<PilgrimagePlan> importPlanPackage({
    required PilgrimagePlan plan,
    required List<PilgrimageVisitRecord> visitRecords,
  });

  Future<PilgrimagePlan> renamePlan({
    required String planId,
    required String name,
  });

  Future<PilgrimagePlan> updatePlanInfo({
    required String planId,
    required String name,
    required String area,
  });

  Future<PilgrimagePlan> updatePlanMemo({
    required String planId,
    required String memo,
  });

  Future<PilgrimagePlan> addPointToPlan({
    required String planId,
    required PilgrimagePoint point,
  });

  Future<PilgrimagePlan> addPointsToPlan({
    required String planId,
    required List<PilgrimagePoint> points,
  });

  Future<PilgrimagePlan> updatePointInPlan({
    required String planId,
    required PilgrimagePoint point,
  });

  Future<PilgrimagePlan> updatePointImageCache({
    required String planId,
    required String pointId,
    String? referenceThumbnailPath,
    String? referenceFullImagePath,
  });

  Future<PilgrimagePlan> updatePointImageCaches({
    required String planId,
    required Map<String, PointImageCacheUpdate> updatesByPointId,
  });

  Future<PilgrimagePlan> addWorkToPlan({
    required String planId,
    required PilgrimageWork work,
  });

  /// Fills fields the stored work is missing (e.g. a cover found later),
  /// never adding a work or overwriting a value. Returns the stored work, or
  /// null when the plan or the work no longer exists.
  Future<PilgrimageWork?> fillMissingWorkFieldsIfPresent({
    required String planId,
    required PilgrimageWork work,
  });

  Future<PilgrimagePlan> createPlanGroup({
    required String planId,
    required PilgrimagePlanGroup group,
  });

  Future<PilgrimagePlan> renamePlanGroup({
    required String planId,
    required String groupId,
    required String name,
  });

  Future<PilgrimagePlan> updatePlanGroup({
    required String planId,
    required PilgrimagePlanGroup group,
  });

  Future<PilgrimagePlan> deletePlanGroup({
    required String planId,
    required String groupId,
  });

  Future<PilgrimagePlan> movePointsToGroup({
    required String planId,
    required Set<String> pointIds,
    required String? groupId,
  });

  /// Sets every group's `orderIndex` to its position in [orderedGroupIds] in
  /// one atomic write. The list must contain each group of the plan once.
  Future<PilgrimagePlan> reorderGroups({
    required String planId,
    required List<String> orderedGroupIds,
  });

  /// Moves several points to their target groups (`null` = ungrouped) in one
  /// atomic write; either every move is stored or none is. Each target group
  /// receives its points like [movePointsToGroup].
  Future<PilgrimagePlan> assignPointsToGroups({
    required String planId,
    required Map<String, String?> groupIdsByPointId,
  });

  Future<PilgrimagePlan> deleteWorkFromPlan({
    required String planId,
    required String workId,
  });

  Future<PilgrimagePlan> deletePointFromPlan({
    required String planId,
    required String pointId,
  });

  Future<PilgrimagePlan> deletePointsFromPlan({
    required String planId,
    required Set<String> pointIds,
  });

  Future<PilgrimagePlan> reorderPoints({
    required String planId,
    required List<String> pointIds,
  });

  Future<PilgrimagePlan> reorderGroupPoints({
    required String planId,
    required String groupId,
    required List<String> pointIds,
  });

  Future<void> setCurrentPoint({
    required String planId,
    required String pointId,
  });

  Future<void> setCurrentGroup({
    required String planId,
    required String? groupId,
  });

  Future<void> completePoint({
    required String planId,
    required String pointId,
    required String? nextCurrentPointId,
  });

  Future<void> completePoints({
    required String planId,
    required Set<String> pointIds,
  });

  Future<void> reopenPoint({required String planId, required String pointId});

  Future<void> reopenPoints({
    required String planId,
    required Set<String> pointIds,
  });

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
  });

  Future<PilgrimageVisitRecord> updateVisitRecordColorGrading({
    required String planId,
    required String recordId,
    required String originalPhotoPath,
    required String gradedPhotoPath,
    required String colorGradingMode,
    required String colorGradingParamsJson,
    required double colorGradingIntensity,
  });

  Future<PilgrimageVisitRecord> clearVisitRecordColorGrading({
    required String planId,
    required String recordId,
  });

  Future<void> deleteVisitRecord({
    required String planId,
    required String recordId,
  });

  Future<void> deletePlan(String id);

  Future<void> saveAppSettings(AppSettings settings);
}

class PointImageCacheUpdate {
  const PointImageCacheUpdate({
    this.referenceThumbnailPath,
    this.referenceFullImagePath,
    this.expectedReferenceImageUrl,
    this.preserveFullImagePath = false,
    this.preserveThumbnailPath = false,
  });

  final String? referenceThumbnailPath;
  final String? referenceFullImagePath;

  /// When set, the update is skipped unless the stored point still has this
  /// reference image URL, so a stale background write-back cannot overwrite a
  /// reference image the user replaced in the meantime.
  final String? expectedReferenceImageUrl;
  final bool preserveFullImagePath;

  /// Keeps the stored thumbnail path instead of writing
  /// [referenceThumbnailPath].
  final bool preserveThumbnailPath;
}
