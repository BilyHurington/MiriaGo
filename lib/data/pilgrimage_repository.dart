import '../plan/pilgrimage_models.dart';

abstract interface class PilgrimageRepository {
  Future<List<PilgrimagePlan>> loadPlans();

  Future<PilgrimagePlan> loadActivePlan();

  Future<void> setActivePlan(String id);

  Future<PilgrimagePlan> createPlan({
    required String name,
    required PilgrimageWork work,
  });

  Future<void> deletePlan(String id);
}
