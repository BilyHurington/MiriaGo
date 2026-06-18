import '../data/reference_cache_file_stub.dart'
    if (dart.library.io) '../data/reference_cache_file_io.dart';
import '../data/reference_image_cache_stub.dart'
    if (dart.library.io) '../data/reference_image_cache_io.dart'
    as reference_image_cache;
import '../data/pilgrimage_repository.dart';
import 'pilgrimage_models.dart';

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
            point.referenceImageUrl != null &&
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

  for (final point in points) {
    try {
      final path = await reference_image_cache.cacheReferenceFullImage(point);
      if (path == null) {
        failed += 1;
      } else {
        currentPlan = await repository.updatePointImageCache(
          planId: currentPlan.id,
          pointId: point.id,
          referenceThumbnailPath: point.referenceThumbnailPath,
          referenceFullImagePath: path,
        );
        onPlanUpdated(currentPlan);
        succeeded += 1;
      }
    } catch (_) {
      failed += 1;
    }
    processed += 1;
    onProgress(
      ReferenceFullCacheProgress(
        total: points.length,
        processed: processed,
        succeeded: succeeded,
        failed: failed,
      ),
    );
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
