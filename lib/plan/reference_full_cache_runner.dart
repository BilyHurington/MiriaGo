import '../data/reference_cache_file_stub.dart'
    if (dart.library.io) '../data/reference_cache_file_io.dart';
import '../data/reference_image_cache_stub.dart'
    if (dart.library.io) '../data/reference_image_cache_io.dart'
    as reference_image_cache;
import '../data/pilgrimage_repository.dart';
import '../utils/limited_concurrency.dart';
import 'pilgrimage_models.dart';
import 'reference_image_status.dart';

class ReferenceFullCacheProgress {
  const ReferenceFullCacheProgress({
    required this.total,
    this.processed = 0,
    this.succeeded = 0,
    this.failed = 0,
    this.done = false,
  });

  final int total;
  final int processed;
  final int succeeded;
  final int failed;
  final bool done;

  String get label {
    if (total == 0) {
      return '当前计划没有需要缓存的参考图';
    }
    if (done) {
      return failed == 0
          ? '已缓存 $succeeded/$total 张完整参考图'
          : '已缓存 $succeeded/$total 张完整参考图，失败 $failed 张';
    }
    return '正在缓存完整参考图 $processed/$total，成功 $succeeded';
  }
}

List<PilgrimagePoint> pointsNeedingFullReferenceCache(
  Iterable<PilgrimagePoint> points,
) {
  return points
      .where(
        (point) =>
            hasRemoteReferenceImage(point) &&
            !referenceFullCacheFileIsCurrent(
              path: point.referenceFullImagePath,
              imageUrl: point.referenceImageUrl,
            ),
      )
      .toList(growable: false);
}

Future<PilgrimagePlan> cacheFullReferenceImages({
  required PilgrimagePlan plan,
  required PilgrimageRepository repository,
  required ValueChangedPlan onPlanUpdated,
  required ValueChangedProgress onProgress,
  AnitabiImageSource imageSource = AnitabiImageSource.auto,
  int maxConcurrent = 4,
}) async {
  final points = pointsNeedingFullReferenceCache(plan.points);
  if (points.isEmpty) {
    onProgress(const ReferenceFullCacheProgress(total: 0, done: true));
    return plan;
  }

  var currentPlan = plan;
  var succeeded = 0;
  var failed = 0;
  var processed = 0;
  onProgress(ReferenceFullCacheProgress(total: points.length));

  final updates = <String, PointImageCacheUpdate>{};
  await runLimitedConcurrent<PilgrimagePoint, _FullReferenceCacheResult>(
    items: points,
    maxConcurrent: maxConcurrent.clamp(1, 4),
    task: (point, _) async {
      try {
        final path = await reference_image_cache.cacheReferenceFullImage(
          point,
          imageSource: imageSource,
        );
        if (path == null || path.isEmpty) {
          return _FullReferenceCacheResult.failed(point.id);
        }
        return _FullReferenceCacheResult.succeeded(
          pointId: point.id,
          referenceFullImagePath: path,
        );
      } catch (_) {
        return _FullReferenceCacheResult.failed(point.id);
      }
    },
    onResult: (result) {
      processed += 1;
      if (result.referenceFullImagePath == null) {
        failed += 1;
      } else {
        succeeded += 1;
        final point = points.firstWhere((point) => point.id == result.pointId);
        updates[result.pointId] = PointImageCacheUpdate(
          referenceThumbnailPath: point.referenceThumbnailPath,
          referenceFullImagePath: result.referenceFullImagePath,
        );
      }
      onProgress(
        ReferenceFullCacheProgress(
          total: points.length,
          processed: processed,
          succeeded: succeeded,
          failed: failed,
        ),
      );
    },
  );

  if (updates.isNotEmpty) {
    currentPlan = await repository.updatePointImageCaches(
      planId: currentPlan.id,
      updatesByPointId: updates,
    );
    onPlanUpdated(currentPlan);
  }

  onProgress(
    ReferenceFullCacheProgress(
      total: points.length,
      processed: processed,
      succeeded: succeeded,
      failed: failed,
      done: true,
    ),
  );
  return currentPlan;
}

typedef ValueChangedPlan = void Function(PilgrimagePlan plan);
typedef ValueChangedProgress =
    void Function(ReferenceFullCacheProgress progress);

class _FullReferenceCacheResult {
  const _FullReferenceCacheResult._({
    required this.pointId,
    required this.referenceFullImagePath,
  });

  factory _FullReferenceCacheResult.succeeded({
    required String pointId,
    required String referenceFullImagePath,
  }) {
    return _FullReferenceCacheResult._(
      pointId: pointId,
      referenceFullImagePath: referenceFullImagePath,
    );
  }

  factory _FullReferenceCacheResult.failed(String pointId) {
    return _FullReferenceCacheResult._(
      pointId: pointId,
      referenceFullImagePath: null,
    );
  }

  final String pointId;
  final String? referenceFullImagePath;
}
