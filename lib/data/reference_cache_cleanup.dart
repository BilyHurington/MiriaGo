import '../plan/pilgrimage_models.dart';
import 'pilgrimage_repository.dart';
import 'reference_asset_paths.dart';
import 'reference_cache_file_stub.dart'
    if (dart.library.io) 'reference_cache_file_io.dart'
    as backend;

bool get isReferenceCacheCleanupSupported =>
    backend.isReferenceCacheCleanupSupported;

bool isDownloadedReferenceCachePath(String? path) {
  if (path == null || path.trim().isEmpty) return false;
  final normalized = normalizeAssetPathSeparators(path).toLowerCase();
  if (normalized.contains('/imported_plan_assets/') ||
      normalized.contains('/user_reference_images/') ||
      normalized.contains('/user_references/')) {
    return false;
  }
  return normalized.startsWith('assets/reference_full/') ||
      normalized.startsWith('assets/reference_thumbnails/') ||
      normalized.contains('/reference_full/') ||
      normalized.contains('/reference_thumbnails/');
}

bool isDownloadedFullReferenceCachePath(String? path) {
  if (!isDownloadedReferenceCachePath(path)) return false;
  final normalized = normalizeAssetPathSeparators(path!).toLowerCase();
  return normalized.startsWith('assets/reference_full/') ||
      normalized.contains('/reference_full/');
}

class ReferenceCacheScan {
  const ReferenceCacheScan({
    required this.fileCount,
    required this.byteCount,
    required this.paths,
  });
  final int fileCount;
  final int byteCount;
  final Set<String> paths;
}

class ReferenceCacheCleanupResult {
  const ReferenceCacheCleanupResult({
    required this.deletedFileCount,
    required this.reclaimedBytes,
    required this.failedFileCount,
  });
  final int deletedFileCount;
  final int reclaimedBytes;
  final int failedFileCount;
}

/// Cache files the selected plans must not delete: files referenced by points
/// of any other plan, and by any visit record (records can keep a cached
/// reference as their comparison image). Downloaded caches are shared between
/// plans because files are named by image URL.
Future<Set<String>> referenceCachePathsInUseElsewhere({
  required PilgrimageRepository repository,
  required Iterable<String> planIds,
}) async => (await loadReferenceCacheUsage(repository)).retainedFor(planIds);

/// Which plans and visit records use each downloaded cache file. Loaded once,
/// it answers [referenceCachePathsInUseElsewhere] for any selection without
/// reading every plan and record again.
class ReferenceCacheUsage {
  const ReferenceCacheUsage._(this._planIdsByPath, this._recordPaths);

  final Map<String, Set<String>> _planIdsByPath;
  final Set<String> _recordPaths;

  /// Files the plans [planIds] must keep: used by another plan's points or by
  /// any visit record.
  Set<String> retainedFor(Iterable<String> planIds) {
    final selected = planIds.toSet();
    return {
      ..._recordPaths,
      for (final entry in _planIdsByPath.entries)
        if (entry.value.any((id) => !selected.contains(id))) entry.key,
    };
  }
}

Future<ReferenceCacheUsage> loadReferenceCacheUsage(
  PilgrimageRepository repository,
) async {
  final planIdsByPath = <String, Set<String>>{};
  final recordPaths = <String>{};
  String? identity(String? path) => isDownloadedReferenceCachePath(path)
      ? backend.referenceCacheIdentity(path!)
      : null;

  for (final plan in await repository.loadPlans()) {
    for (final point in plan.points) {
      for (final path in [
        point.referenceFullImagePath,
        point.referenceThumbnailPath,
      ]) {
        final id = identity(path);
        if (id != null) (planIdsByPath[id] ??= {}).add(plan.id);
      }
    }
    for (final record in await repository.loadVisitRecords(plan.id)) {
      final id = identity(record.referenceImagePath);
      if (id != null) recordPaths.add(id);
    }
  }
  return ReferenceCacheUsage._(planIdsByPath, recordPaths);
}

/// [sizeCache] keeps file size reads between scans of the same page, so
/// changing a selection does not read every file again (one launcher call per
/// file on the desktop); a read still in progress is shared too.
Future<ReferenceCacheScan> scanDownloadedReferenceCaches(
  Iterable<PilgrimagePlan> plans, {
  Set<String> retainedPaths = const {},
  Map<String, Future<int>>? sizeCache,
}) async {
  final paths = _deletableCachePaths(plans, retainedPaths);
  var bytes = 0;
  var files = 0;
  for (final path in paths) {
    files++;
    try {
      final size = await (sizeCache == null
          ? backend.referenceCacheFileSize(path)
          : sizeCache[path] ??= backend.referenceCacheFileSize(path));
      if (size > 0) {
        bytes += size;
      }
    } on Object {
      // Unreadable stale paths are still cleared from point metadata later.
    }
  }
  return ReferenceCacheScan(fileCount: files, byteCount: bytes, paths: paths);
}

/// Deletes the downloaded full-reference caches of [plans] and clears those
/// paths from their points. Files still used by another plan or by a visit
/// record are kept on disk; the selected plans stop referencing them either
/// way.
Future<ReferenceCacheCleanupResult> cleanupDownloadedReferenceCaches({
  required PilgrimageRepository repository,
  required Iterable<PilgrimagePlan> plans,
  void Function(int completed, int total)? onProgress,
}) async {
  final planList = plans.toList(growable: false);
  final retained = await referenceCachePathsInUseElsewhere(
    repository: repository,
    planIds: planList.map((plan) => plan.id),
  );
  final paths = _deletableCachePaths(planList, retained);
  var deleted = 0;
  var reclaimed = 0;
  var failed = 0;
  var completed = 0;
  for (final path in paths) {
    try {
      final bytes = await backend.deleteReferenceCacheFile(path);
      if (bytes > 0) {
        deleted++;
        reclaimed += bytes;
      }
    } on Object {
      failed++;
    }
    completed++;
    onProgress?.call(completed, paths.length);
  }

  for (final plan in planList) {
    final updates = <String, PointImageCacheUpdate>{};
    for (final point in plan.points) {
      final thumbnail = point.referenceThumbnailPath;
      final full =
          isDownloadedFullReferenceCachePath(point.referenceFullImagePath)
          ? null
          : point.referenceFullImagePath;
      if (thumbnail != point.referenceThumbnailPath ||
          full != point.referenceFullImagePath) {
        updates[point.id] = PointImageCacheUpdate(
          referenceThumbnailPath: thumbnail,
          referenceFullImagePath: full,
        );
      }
    }
    if (updates.isNotEmpty) {
      await repository.updatePointImageCaches(
        planId: plan.id,
        updatesByPointId: updates,
      );
    }
  }
  return ReferenceCacheCleanupResult(
    deletedFileCount: deleted,
    reclaimedBytes: reclaimed,
    failedFileCount: failed,
  );
}

Set<String> _deletableCachePaths(
  Iterable<PilgrimagePlan> plans,
  Set<String> retainedPaths,
) => {
  for (final plan in plans)
    for (final point in plan.points)
      if (isDownloadedFullReferenceCachePath(point.referenceFullImagePath) &&
          !retainedPaths.contains(
            backend.referenceCacheIdentity(point.referenceFullImagePath!),
          ))
        point.referenceFullImagePath!,
};
