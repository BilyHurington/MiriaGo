import '../plan/pilgrimage_models.dart';

abstract interface class PilgrimageRepository {
  Future<List<PilgrimagePlan>> loadPlans();

  Future<PilgrimagePlan> loadActivePlan();

  Future<AppSettings> loadAppSettings();

  Future<List<PilgrimageVisitRecord>> loadVisitRecords(String planId);

  Future<void> setActivePlan(String id);

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

  Future<PilgrimagePlan> addPointToPlan({
    required String planId,
    required PilgrimagePoint point,
  });

  Future<PilgrimagePlan> addPointsToPlan({
    required String planId,
    required List<PilgrimagePoint> points,
  });

  Future<PilgrimagePlan> updatePointImageCache({
    required String planId,
    required String pointId,
    String? referenceThumbnailPath,
    String? referenceFullImagePath,
  });

  Future<PilgrimagePlan> addWorkToPlan({
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
