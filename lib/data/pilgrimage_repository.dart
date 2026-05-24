import '../plan/pilgrimage_models.dart';

abstract interface class PilgrimageRepository {
  Future<List<PilgrimagePlan>> loadPlans();

  Future<PilgrimagePlan> loadActivePlan();

  Future<List<PilgrimageVisitRecord>> loadVisitRecords(String planId);

  Future<void> setActivePlan(String id);

  Future<PilgrimagePlan> createPlan({
    required String name,
    required String area,
  });

  Future<PilgrimagePlan> addPointToPlan({
    required String planId,
    required PilgrimagePoint point,
  });

  Future<PilgrimagePlan> addPointsToPlan({
    required String planId,
    required List<PilgrimagePoint> points,
  });

  Future<PilgrimagePlan> addWorkToPlan({
    required String planId,
    required PilgrimageWork work,
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
    required String photoPath,
    required String referenceMode,
  });

  Future<void> deleteVisitRecord({
    required String planId,
    required String recordId,
  });

  Future<void> deletePlan(String id);
}
