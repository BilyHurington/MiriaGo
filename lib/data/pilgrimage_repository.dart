import '../plan/pilgrimage_models.dart';

abstract interface class PilgrimageRepository {
  Future<PilgrimagePlan> loadActivePlan();
}
