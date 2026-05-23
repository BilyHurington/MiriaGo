import 'package:latlong2/latlong.dart';

import '../plan/pilgrimage_models.dart';
import 'pilgrimage_repository.dart';

class SamplePilgrimageRepository implements PilgrimageRepository {
  SamplePilgrimageRepository()
    : _plans = [samplePilgrimagePlan, sampleEmptyPlan],
      _activePlanId = samplePilgrimagePlan.id;

  final List<PilgrimagePlan> _plans;
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
    required PilgrimageWork work,
  }) async {
    final now = DateTime.now();
    final plan = PilgrimagePlan(
      id: 'local-${now.microsecondsSinceEpoch}',
      work: work,
      name: name,
      points: const [],
      createdAt: now,
      updatedAt: now,
    );

    _plans.add(plan);
    _activePlanId = plan.id;
    return plan;
  }

  @override
  Future<PilgrimagePlan> addPointToPlan({
    required String planId,
    required PilgrimagePoint point,
  }) async {
    final index = _plans.indexWhere((plan) => plan.id == planId);
    if (index == -1) {
      throw ArgumentError.value(planId, 'planId', 'Plan does not exist.');
    }

    final plan = _plans[index];
    final updatedPlan = plan.copyWith(
      points: [...plan.points, point],
      updatedAt: DateTime.now(),
    );
    _plans[index] = updatedPlan;
    return updatedPlan;
  }

  @override
  Future<void> deletePlan(String id) async {
    if (_plans.length == 1) {
      throw StateError('At least one plan is required.');
    }

    _plans.removeWhere((plan) => plan.id == id);
    if (_activePlanId == id) {
      _activePlanId = _plans.first.id;
    }
  }
}

final _sampleCreatedAt = DateTime(2026, 5, 23, 9);

final samplePilgrimagePlan = PilgrimagePlan(
  id: 'sample-uji-hibike',
  work: const PilgrimageWork(
    id: 'hibike-euphonium',
    title: '吹响吧！上低音号',
    subtitle: '響け！ユーフォニアム',
    city: '宇治市',
  ),
  name: '宇治示例巡礼',
  createdAt: _sampleCreatedAt,
  updatedAt: _sampleCreatedAt,
  points: const [
    PilgrimagePoint(
      id: 'uji-bridge',
      name: '宇治桥',
      subtitle: '宇治川沿岸',
      position: LatLng(34.8917, 135.8077),
      episodeLabel: '示例点位 1',
      referenceLabel: '参考图待接入',
    ),
    PilgrimagePoint(
      id: 'agata-dori',
      name: 'あがた通り',
      subtitle: '县神社方向街道',
      position: LatLng(34.8899, 135.8081),
      episodeLabel: '示例点位 2',
      referenceLabel: '参考图待接入',
    ),
    PilgrimagePoint(
      id: 'uji-station',
      name: 'JR 宇治站',
      subtitle: 'JR 奈良线车站',
      position: LatLng(34.8905, 135.8008),
      episodeLabel: '示例点位 3',
      referenceLabel: '参考图待接入',
    ),
  ],
);

final sampleEmptyPlan = PilgrimagePlan(
  id: 'sample-empty-kyoto',
  work: const PilgrimageWork(
    id: 'manual-kyoto',
    title: '自定义京都巡礼',
    subtitle: 'Manual Plan',
    city: '京都市',
  ),
  name: '京都空计划',
  points: const [],
  createdAt: _sampleCreatedAt,
  updatedAt: _sampleCreatedAt,
);
