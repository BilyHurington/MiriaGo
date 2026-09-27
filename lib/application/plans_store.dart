import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/app_file_reclamation.dart';
import '../data/pilgrimage_repository.dart';
import '../plan/pilgrimage_models.dart';
import 'plan_session.dart';

/// Plan library: list, create, switch, edit, duplicate, delete, reorder.
///
/// Logic ported from the old `PlanManagerScreen`.
class PlansStore extends ChangeNotifier {
  PlansStore({required this.repository, required this.session}) {
    session.addListener(_onSessionChanged);
  }

  final PilgrimageRepository repository;
  final PlanSession session;

  List<PilgrimagePlan> _plans = const [];
  bool _loading = false;
  Object? _error;
  int _seenRevision = -1;
  bool _disposed = false;

  List<PilgrimagePlan> get plans => _plans;
  bool get isLoading => _loading;
  Object? get error => _error;

  String? get activePlanId => session.isReady ? session.plan.id : null;

  Future<void> refresh() async {
    _loading = true;
    _error = null;
    _notify();
    try {
      _plans = await repository.loadPlans();
      _seenRevision = session.revision;
    } catch (error) {
      _error = error;
    } finally {
      _loading = false;
      _notify();
    }
  }

  /// Switches the active plan. Throws on failure (caller shows
  /// 「切换计划失败，请稍后重试。」).
  Future<void> switchTo(String planId) async {
    if (planId == activePlanId) return;
    await repository.setActivePlan(planId);
    await session.load();
    await refresh();
  }

  /// Creates a plan and makes it active.
  Future<PilgrimagePlan> create({
    required String name,
    required String area,
  }) async {
    final plan = await repository.createPlan(
      name: name,
      area: area.trim().isEmpty ? '未设置区域' : area.trim(),
    );
    await repository.setActivePlan(plan.id);
    await session.load();
    await refresh();
    return plan;
  }

  /// Default name for a new plan: 「新巡礼计划 N」.
  String suggestedNewPlanName() => '新巡礼计划 ${_plans.length + 1}';

  /// Empty name is ignored (returns without change); empty area becomes
  /// 「未设置区域」.
  Future<void> updateInfo({
    required String planId,
    required String name,
    required String area,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) return;
    final updated = await repository.updatePlanInfo(
      planId: planId,
      name: trimmedName,
      area: area.trim().isEmpty ? '未设置区域' : area.trim(),
    );
    if (updated.id == activePlanId) session.publish(updated);
    await refresh();
  }

  /// Duplicates a plan including its visit records as 「{name} 副本」.
  Future<PilgrimagePlan> duplicate(PilgrimagePlan plan) async {
    final records = await repository.loadVisitRecords(plan.id);
    final copy = await repository.importPlanPackage(
      plan: plan.copyWith(name: '${plan.name} 副本'),
      visitRecords: records,
    );
    // importPlanPackage may activate the copy; keep the session in sync.
    await session.load();
    await refresh();
    return copy;
  }

  bool get canDelete => _plans.length > 1;

  /// Deletes a plan and reclaims files nothing else references.
  Future<void> delete(PilgrimagePlan plan) async {
    await deletePlanReclaimingFiles(repository: repository, planId: plan.id);
    await session.load();
    await refresh();
  }

  /// Optimistic reorder; rolls back and rethrows on failure
  /// (「保存计划顺序失败，已恢复原来的顺序。」).
  Future<void> reorder(List<String> orderedIds) async {
    final previous = _plans;
    final byId = {for (final plan in _plans) plan.id: plan};
    _plans = [
      for (final id in orderedIds)
        if (byId[id] != null) byId[id]!,
    ];
    _notify();
    try {
      await repository.reorderPlans(orderedPlanIds: orderedIds);
    } catch (_) {
      _plans = previous;
      _notify();
      rethrow;
    }
  }

  void _onSessionChanged() {
    if (_seenRevision != -1 && session.revision != _seenRevision) {
      _seenRevision = session.revision;
      unawaited(refresh());
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    session.removeListener(_onSessionChanged);
    super.dispose();
  }
}
