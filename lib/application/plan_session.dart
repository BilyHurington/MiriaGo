import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/pilgrimage_repository.dart';
import '../plan/pilgrimage_models.dart';
import '../plan/pilgrimage_plan_controller.dart';

/// Signature of a repository write scoped to the active plan. It must
/// return the updated plan (most repository methods do).
typedef PlanMutation =
    Future<PilgrimagePlan> Function(
      PilgrimageRepository repository,
      String planId,
    );

/// Single source of truth for the active plan.
///
/// Wraps [PilgrimagePlanController] (runtime state: current/selected point,
/// completion, visit records) and funnels every structural write through
/// [mutate], so all panes that show the plan update together. This
/// replaces the old "push a page, pop, reload everything" pattern.
///
/// Listen to the session (not the controller): it relays controller
/// notifications and also notifies when the controller is replaced after a
/// plan switch.
class PlanSession extends ChangeNotifier {
  PlanSession({required this.repository});

  final PilgrimageRepository repository;

  PilgrimagePlanController? _controller;
  Object? _loadError;
  bool _loading = false;
  int _generation = 0;
  int _loadSequence = 0;
  PilgrimagePlan? _lastPlan;
  bool _disposed = false;

  /// Increments whenever the plan structure changes through the session
  /// (mutate/refresh/load). Useful as a cheap cache key.
  int get revision => _generation;

  bool get isReady => _controller != null;
  bool get isLoading => _loading;
  Object? get loadError => _loadError;

  PilgrimagePlanController get controller {
    final controller = _controller;
    if (controller == null) {
      throw StateError('PlanSession used before the plan was loaded');
    }
    return controller;
  }

  PilgrimagePlan get plan => controller.plan;

  /// Loads (or reloads) the active plan and builds a fresh controller.
  ///
  /// Overlapping loads are serialised by sequence: only the most recent
  /// call publishes its result, so an older read can't win the race.
  Future<void> load() async {
    final sequence = ++_loadSequence;
    _loading = true;
    _loadError = null;
    notifyListeners();
    try {
      final plan = await repository.loadActivePlan();
      if (_disposed || sequence != _loadSequence) return;
      final previous = _controller;
      previous?.removeListener(_relay);
      _controller = PilgrimagePlanController(
        plan: plan,
        visitRepository: repository,
      )..addListener(_relay);
      previous?.dispose();
      _lastPlan = plan;
      _generation++;
    } catch (error, stackTrace) {
      if (sequence != _loadSequence) return;
      debugPrint('Failed to load active pilgrimage plan: $error');
      debugPrint(stackTrace.toString());
      _loadError = error;
    } finally {
      if (sequence == _loadSequence) {
        _loading = false;
        if (!_disposed) notifyListeners();
      }
    }
  }

  /// Re-reads the active plan into the existing controller (keeps runtime
  /// selection). Falls back to [load] if the active plan id changed.
  Future<void> refresh() async {
    final controller = _controller;
    if (controller == null) return load();
    final plan = await repository.loadActivePlan();
    if (_disposed) return;
    if (plan.id != controller.plan.id) return load();
    _generation++;
    _lastPlan = plan;
    controller.replacePlan(plan);
  }

  /// Runs a repository write for the active plan and publishes the result.
  Future<PilgrimagePlan> mutate(PlanMutation mutation) async {
    final controller = this.controller;
    final planId = controller.plan.id;
    final updated = await mutation(repository, planId);
    if (!_disposed &&
        identical(_controller, controller) &&
        updated.id == controller.plan.id) {
      _generation++;
      _lastPlan = updated;
      controller.replacePlan(updated);
    }
    return updated;
  }

  /// Publishes a plan obtained elsewhere (e.g. from a background task).
  void publish(PilgrimagePlan plan) {
    final controller = _controller;
    if (controller == null || plan.id != controller.plan.id) return;
    _generation++;
    _lastPlan = plan;
    controller.replacePlan(plan);
  }

  void _relay() {
    if (_disposed) return;
    // Writes made directly through the controller (move, delete, memo…)
    // replace the plan object; count them as a structural revision too so
    // caches keyed on [revision] refresh.
    final plan = _controller?.plan;
    if (plan != null && !identical(plan, _lastPlan)) {
      _lastPlan = plan;
      _generation++;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _controller?.removeListener(_relay);
    _controller?.dispose();
    super.dispose();
  }
}
