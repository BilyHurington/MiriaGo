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

Future<ReferenceCacheScan> scanDownloadedReferenceCaches(
  Iterable<PilgrimagePlan> plans,
) async {
  final paths = _cachePaths(plans);
  var bytes = 0;
  var files = 0;
  for (final path in paths) {
    files++;
    try {
      final size = await backend.referenceCacheFileSize(path);
      if (size > 0) {
        bytes += size;
      }
    } on Object {
      // Unreadable stale paths are still cleared from point metadata later.
    }
  }
  return ReferenceCacheScan(fileCount: files, byteCount: bytes, paths: paths);
}

Future<ReferenceCacheCleanupResult> cleanupDownloadedReferenceCaches({
  required PilgrimageRepository repository,
  required Iterable<PilgrimagePlan> plans,
  void Function(int completed, int total)? onProgress,
}) async {
  final planList = plans.toList(growable: false);
  final paths = _cachePaths(planList);
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

Set<String> _cachePaths(Iterable<PilgrimagePlan> plans) => {
  for (final plan in plans)
    for (final point in plan.points)
      if (isDownloadedFullReferenceCachePath(point.referenceFullImagePath))
        point.referenceFullImagePath!,
};
