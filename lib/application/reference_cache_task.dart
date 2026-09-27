import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/pilgrimage_repository.dart';
import '../plan/pilgrimage_models.dart';
import '../plan/reference_full_cache_runner.dart';
import 'plan_session.dart';

typedef ReferenceCacheRun =
    Future<void> Function(ValueChangedProgress onProgress);

/// Background "cache full reference images" task.
///
/// One task per (repository, plan). Its state outlives any view that shows
/// it: closing the progress UI never cancels the download. Ported from the
/// old `reference_cache_progress_dialog.dart`.
class ReferenceCacheTask extends ChangeNotifier {
  ReferenceCacheTask({required this.planId, required this.planName});

  static final _tasks = Expando<Map<String, ReferenceCacheTask>>();

  static ReferenceCacheTask forPlan(
    Object repository,
    String planId, {
    String planName = '',
  }) {
    final tasks = _tasks[repository] ??= {};
    return tasks.putIfAbsent(
      planId,
      () => ReferenceCacheTask(planId: planId, planName: planName),
    );
  }

  final String planId;
  String planName;

  ReferenceFullCacheProgress? progress;
  PilgrimagePlan? updatedPlan;
  bool isRunning = false;
  bool hasError = false;
  ReferenceCacheRun? _lastRun;

  Future<void> _finished = Future.value();
  Future<void> get finished => _finished;

  ReferenceCacheStatus get status {
    final progress = this.progress;
    if (isRunning || progress == null) return ReferenceCacheStatus.running;
    if (hasError) return ReferenceCacheStatus.interrupted;
    if (progress.failed == 0) return ReferenceCacheStatus.success;
    if (progress.succeeded == 0) return ReferenceCacheStatus.failed;
    return ReferenceCacheStatus.partial;
  }

  /// Whether the task has been started at least once in this app session.
  bool get hasStarted => progress != null;

  Future<void> start(ReferenceCacheRun run) {
    if (isRunning) return _finished;
    _lastRun = run;
    final done = Completer<void>();
    _finished = done.future;
    isRunning = true;
    hasError = false;
    updatedPlan = null;
    progress = ReferenceFullCacheProgress(total: progress?.total ?? 0);
    notifyListeners();
    unawaited(_execute(run, done));
    return _finished;
  }

  /// Re-runs the last run (「重试失败 / 重试全部」). Already cached images
  /// are skipped by the runner.
  Future<void> retry() {
    final run = _lastRun;
    if (run == null) return Future.value();
    return start(run);
  }

  Future<void> _execute(ReferenceCacheRun run, Completer<void> done) async {
    try {
      await run((value) {
        progress = value;
        notifyListeners();
      });
    } catch (_) {
      hasError = true;
    } finally {
      isRunning = false;
      notifyListeners();
      done.complete();
    }
  }
}

enum ReferenceCacheStatus { running, success, partial, failed, interrupted }

/// Tracks reference-cache tasks for the app and starts them.
class ReferenceCacheCenter extends ChangeNotifier {
  ReferenceCacheCenter({required this.repository, required this.session});

  final PilgrimageRepository repository;
  final PlanSession session;
  final List<ReferenceCacheTask> _tasks = [];

  /// Tasks started in this session (most recent last).
  List<ReferenceCacheTask> get tasks => List.unmodifiable(_tasks);

  List<ReferenceCacheTask> get running =>
      _tasks.where((task) => task.isRunning).toList(growable: false);

  ReferenceCacheTask taskFor(PilgrimagePlan plan) =>
      ReferenceCacheTask.forPlan(repository, plan.id, planName: plan.name);

  /// Points of [plan] whose full reference image still needs caching.
  List<PilgrimagePoint> pointsNeedingCache(PilgrimagePlan plan) =>
      pointsNeedingFullReferenceCache(plan.points);

  /// Starts (or rejoins) caching for [plan]. The caller is responsible for
  /// the confirmation dialog (「缓存完整参考图」…).
  ReferenceCacheTask start(
    PilgrimagePlan plan, {
    required AnitabiImageSource imageSource,
    required int maxConcurrent,
  }) {
    final task = taskFor(plan)..planName = plan.name;
    if (!_tasks.contains(task)) {
      _tasks.add(task);
      task.addListener(() => _onTaskChanged(task));
    }
    if (task.isRunning) return task;
    final planId = plan.id;
    unawaited(
      task.start((onProgress) async {
        final latest = (await repository.loadPlans()).firstWhere(
          (candidate) => candidate.id == planId,
        );
        await cacheFullReferenceImages(
          plan: latest,
          repository: repository,
          onPlanUpdated: (updated) {
            task.updatedPlan = updated;
            session.publish(updated);
          },
          imageSource: imageSource,
          maxConcurrent: maxConcurrent,
          onProgress: onProgress,
        );
      }),
    );
    notifyListeners();
    return task;
  }

  void dismiss(ReferenceCacheTask task) {
    if (task.isRunning) return;
    _tasks.remove(task);
    notifyListeners();
  }

  void _onTaskChanged(ReferenceCacheTask task) {
    final updated = task.updatedPlan;
    if (updated != null) session.publish(updated);
    notifyListeners();
  }
}
