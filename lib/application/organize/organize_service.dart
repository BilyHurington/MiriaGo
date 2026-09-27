import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../../data/app_file_reclamation.dart';
import '../../data/pilgrimage_repository.dart';
import '../../plan/pilgrimage_models.dart';
import '../../plan/plan_order.dart';
import '../plan_session.dart';

/// A write of the 片区与点位 page failed; [message] is the old toast text
/// (e.g. 「移动片区失败」).
class OrganizeFailure implements Exception {
  const OrganizeFailure(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() =>
      'OrganizeFailure($message${cause == null ? '' : ': $cause'})';
}

/// Signature of `reclaimDeletedPointFiles` (replaceable in tests).
typedef ReclaimPointFiles =
    Future<void> Function({
      required PilgrimageRepository repository,
      required Iterable<PilgrimagePoint> points,
    });

/// Result of 最近分配.
typedef NearestAssignResult = ({int count, bool settingsSaved});

/// Next `orderIndex` for a new group (old: max + 1, or 0).
int nextGroupOrderIndex(Iterable<PilgrimagePlanGroup> groups) {
  var next = 0;
  for (final group in groups) {
    if (group.orderIndex + 1 > next) next = group.orderIndex + 1;
  }
  return next;
}

/// Creates a group named [name] (trimmed) at the end of the active plan
/// through the session and returns it. Throws [OrganizeFailure]
/// 「片区创建失败」 on failure. This is the only group creation path of the
/// app (FEATURE_CHECKLIST §D / §K).
Future<PilgrimagePlanGroup> createPlanGroupInSession(
  PlanSession session,
  String name, {
  DateTime? now,
}) async {
  final trimmed = name.trim();
  if (trimmed.isEmpty) throw const OrganizeFailure('片区名不能为空');
  final time = now ?? DateTime.now();
  final group = PilgrimagePlanGroup(
    id: 'group-${time.microsecondsSinceEpoch}',
    name: trimmed,
    orderIndex: nextGroupOrderIndex(session.plan.groups),
    createdAt: time,
  );
  try {
    final updated = await session.mutate(
      (repository, planId) =>
          repository.createPlanGroup(planId: planId, group: group),
    );
    return updated.groups.firstWhere(
      (candidate) => candidate.id == group.id,
      orElse: () => group,
    );
  } catch (error) {
    throw OrganizeFailure('片区创建失败', error);
  }
}

/// Business flows of 片区与点位 and the assignment tools, ported from the
/// old `PointManagerScreen`, `PlanGroupManagerScreen`,
/// `NearestGroupAssignScreen` and `BoxGroupAssignScreen`.
///
/// Every write goes through [PlanSession] so all panes update together.
/// Only one write runs at a time ([isSaving]); a call made while another
/// write is running is ignored and returns `null` / `false`. Failures throw
/// [OrganizeFailure] carrying the old toast text.
class OrganizeService extends ChangeNotifier {
  OrganizeService({
    required this.session,
    ReclaimPointFiles reclaimFiles = reclaimDeletedPointFiles,
  }) : _reclaimFiles = reclaimFiles; // ignore: prefer_initializing_formals

  final PlanSession session;
  final ReclaimPointFiles _reclaimFiles;

  bool _saving = false;
  bool _disposed = false;

  /// A write is in progress (block leaving the page, disable actions).
  bool get isSaving => _saving;

  PilgrimageRepository get repository => session.repository;
  PilgrimagePlan get plan => session.plan;

  void _setSaving(bool value) {
    if (_saving == value) return;
    _saving = value;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// Runs [action] as the single in-flight write. Returns null when another
  /// write is running.
  Future<T?> _run<T>(
    Future<T> Function() action, {
    required String failureMessage,
    bool reloadOnFailure = false,
  }) async {
    if (_saving) return null;
    _setSaving(true);
    try {
      return await action();
    } catch (error) {
      if (error is OrganizeFailure) rethrow;
      if (reloadOnFailure) {
        // Show what is actually stored, not an optimistic local state.
        try {
          await session.refresh();
        } catch (_) {}
      }
      throw OrganizeFailure(failureMessage, error);
    } finally {
      _setSaving(false);
    }
  }

  Future<PilgrimagePlan?> _mutate(
    PlanMutation mutation, {
    required String failureMessage,
    bool reloadOnFailure = false,
  }) => _run(
    () => session.mutate(mutation),
    failureMessage: failureMessage,
    reloadOnFailure: reloadOnFailure,
  );

  /// Status writes (current / complete / reopen) are not returned by the
  /// repository, so the plan is re-read afterwards (old `_saveStatusChange`).
  Future<bool> _statusChange(
    Future<void> Function(PilgrimageRepository repository, String planId)
    action, {
    required String failureMessage,
  }) async {
    final done = await _run(() async {
      await action(repository, plan.id);
      await session.refresh();
      return true;
    }, failureMessage: failureMessage);
    return done ?? false;
  }

  // ---------------------------------------------------------------------
  // Groups
  // ---------------------------------------------------------------------

  /// 新建片区. Returns the created group (null when busy).
  Future<PilgrimagePlanGroup?> createGroup(String name) => _run(
    () => createPlanGroupInSession(session, name),
    failureMessage: '片区创建失败',
  );

  /// 重命名片区. Blank names and unchanged names are ignored.
  Future<bool> renameGroup(PilgrimagePlanGroup group, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed == group.name) return false;
    final updated = await _mutate(
      (repository, planId) => repository.renamePlanGroup(
        planId: planId,
        groupId: group.id,
        name: trimmed,
      ),
      failureMessage: '片区改名失败',
    );
    return updated != null;
  }

  /// 片区内顺序 (无序 / 手动排序).
  Future<bool> setOrderMode(
    PilgrimagePlanGroup group,
    PlanGroupOrderMode mode,
  ) async {
    if (group.orderMode == mode) return false;
    final updated = await _mutate(
      (repository, planId) => repository.updatePlanGroup(
        planId: planId,
        group: group.copyWith(orderMode: mode),
      ),
      failureMessage: '排序方式保存失败',
    );
    return updated != null;
  }

  /// Sets or clears (Δ6: all fields null) a group's key point.
  Future<bool> setAnchor(
    PilgrimagePlanGroup group, {
    required String? name,
    required LatLng? position,
    required String? pointId,
  }) async {
    final updated = await _mutate(
      (repository, planId) => repository.updatePlanGroup(
        planId: planId,
        group: group.copyWith(
          anchorName: position == null ? null : name,
          anchorLatitude: position?.latitude,
          anchorLongitude: position?.longitude,
          anchorPointId: position == null ? null : pointId,
        ),
      ),
      failureMessage: '关键点保存失败',
    );
    return updated != null;
  }

  /// 删除片区: its points move to 未分配点位.
  Future<bool> deleteGroup(PilgrimagePlanGroup group) async {
    final updated = await _mutate(
      (repository, planId) =>
          repository.deletePlanGroup(planId: planId, groupId: group.id),
      failureMessage: '片区删除失败',
    );
    return updated != null;
  }

  /// Saves the group order in one atomic write. On failure the stored
  /// order is reloaded.
  Future<bool> reorderGroups(List<String> orderedGroupIds) async {
    final updated = await _mutate(
      (repository, planId) => repository.reorderGroups(
        planId: planId,
        orderedGroupIds: orderedGroupIds,
      ),
      failureMessage: '片区顺序保存失败',
      reloadOnFailure: true,
    );
    return updated != null;
  }

  /// Point order inside a manually ordered group.
  Future<bool> reorderGroupPoints(
    String groupId,
    List<String> orderedPointIds,
  ) async {
    final updated = await _mutate(
      (repository, planId) => repository.reorderGroupPoints(
        planId: planId,
        groupId: groupId,
        pointIds: orderedPointIds,
      ),
      failureMessage: '点位顺序保存失败',
    );
    return updated != null;
  }

  // ---------------------------------------------------------------------
  // Points
  // ---------------------------------------------------------------------

  /// 移动到片区 ([groupId] null = 未分入片区).
  Future<bool> movePoints(
    Set<String> pointIds,
    String? groupId, {
    String failureMessage = '移动片区失败',
  }) async {
    if (pointIds.isEmpty) return false;
    final updated = await _mutate(
      (repository, planId) => repository.movePointsToGroup(
        planId: planId,
        pointIds: pointIds,
        groupId: groupId,
      ),
      failureMessage: failureMessage,
    );
    return updated != null;
  }

  Future<bool> setCurrent(PilgrimagePoint point) => _statusChange(
    (repository, planId) =>
        repository.setCurrentPoint(planId: planId, pointId: point.id),
    failureMessage: '当前目标保存失败',
  );

  /// 标记完成. When the point is the current target, the next pending point
  /// in plan order becomes current (old `_complete`).
  Future<bool> complete(PilgrimagePoint point) {
    final controller = session.controller;
    final completed = {...controller.completedPointIds, point.id};
    final currentId = controller.currentPoint?.id ?? plan.currentPointId;
    final nextCurrentPointId = currentId == point.id
        ? nextPendingPointAfterCompletion(
            points: plan.points,
            groups: plan.groups,
            completedPoint: point,
            completedPointIds: completed,
          )?.id
        : currentId;
    return _statusChange(
      (repository, planId) => repository.completePoint(
        planId: planId,
        pointId: point.id,
        nextCurrentPointId: nextCurrentPointId,
      ),
      failureMessage: '完成状态保存失败',
    );
  }

  /// 取消完成.
  Future<bool> reopen(PilgrimagePoint point) => _statusChange(
    (repository, planId) =>
        repository.reopenPoint(planId: planId, pointId: point.id),
    failureMessage: '点位状态保存失败',
  );

  Future<bool> completePoints(Set<String> pointIds) async {
    if (pointIds.isEmpty) return false;
    return _statusChange(
      (repository, planId) =>
          repository.completePoints(planId: planId, pointIds: pointIds),
      failureMessage: '批量完成失败',
    );
  }

  /// Δ8 取消完成 (old 「重置」, same failure text).
  Future<bool> reopenPoints(Set<String> pointIds) async {
    if (pointIds.isEmpty) return false;
    return _statusChange(
      (repository, planId) =>
          repository.reopenPoints(planId: planId, pointIds: pointIds),
      failureMessage: '批量重置失败',
    );
  }

  /// Deletes one point; its reference files are reclaimed only after the
  /// deletion committed.
  Future<bool> deletePoint(PilgrimagePoint point) async {
    final updated = await _mutate((repository, planId) async {
      final updated = await repository.deletePointFromPlan(
        planId: planId,
        pointId: point.id,
      );
      unawaited(_reclaimFiles(repository: repository, points: [point]));
      return updated;
    }, failureMessage: '点位删除失败');
    return updated != null;
  }

  Future<bool> deletePoints(Set<String> pointIds) async {
    if (pointIds.isEmpty) return false;
    final points = plan.points
        .where((point) => pointIds.contains(point.id))
        .toList(growable: false);
    final updated = await _mutate((repository, planId) async {
      final updated = await repository.deletePointsFromPlan(
        planId: planId,
        pointIds: pointIds,
      );
      unawaited(_reclaimFiles(repository: repository, points: points));
      return updated;
    }, failureMessage: '批量删除失败');
    return updated != null;
  }

  /// Replaces a point's reference image with a stored user upload.
  Future<bool> replaceReference(
    PilgrimagePoint point, {
    required String? thumbnailPath,
    required String? fullImagePath,
  }) async {
    final updated = await _mutate(
      (repository, planId) => repository.updatePointInPlan(
        planId: planId,
        point: point.copyWith(
          referenceImageUrl: null,
          referenceThumbnailPath: thumbnailPath,
          referenceFullImagePath: fullImagePath,
        ),
      ),
      failureMessage: '参考图保存失败',
    );
    return updated != null;
  }

  // ---------------------------------------------------------------------
  // Assignment tools
  // ---------------------------------------------------------------------

  /// 最近分配: one atomic write (every point moves or none does). The
  /// distance is remembered only after the assignment was stored; a failed
  /// settings save is reported in the result, not thrown. Throws
  /// 「最近分配失败」 (after reloading the plan) when the assignment fails.
  Future<NearestAssignResult?> assignNearest(
    Map<String, String?> groupIdsByPointId, {
    required Future<void> Function() saveDistance,
  }) {
    return _run(
      () async {
        await session.mutate(
          (repository, planId) => repository.assignPointsToGroups(
            planId: planId,
            groupIdsByPointId: groupIdsByPointId,
          ),
        );
        var settingsSaved = true;
        try {
          await saveDistance();
        } catch (_) {
          settingsSaved = false;
        }
        return (count: groupIdsByPointId.length, settingsSaved: settingsSaved);
      },
      failureMessage: '最近分配失败',
      reloadOnFailure: true,
    );
  }

  /// 框选分配: moves [pointIds] into [groupId].
  Future<bool> assignBox(Set<String> pointIds, String groupId) =>
      movePoints(pointIds, groupId, failureMessage: '框选分配失败');
}
