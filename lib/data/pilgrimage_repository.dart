import '../plan/pilgrimage_models.dart';

abstract interface class PilgrimageRepository {
  Future<List<PilgrimagePlan>> loadPlans();

  Future<PilgrimagePlan> loadActivePlan();

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

  Future<void> reopenPoint({required String planId, required String pointId});

  Future<void> deletePlan(String id);
}
