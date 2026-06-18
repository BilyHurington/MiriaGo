import 'dart:convert';

import '../data/anitabi_image_url.dart';
import '../data/local_asset_size_stub.dart'
    if (dart.library.io) '../data/local_asset_size_io.dart';
import '../plan/pilgrimage_models.dart';
import 'plan_export_v2.dart';

const _estimatedThumbnailBytes = 48 * 1024;

class PlanExportSizeEstimate {
  const PlanExportSizeEstimate({
    required this.knownBytes,
    required this.missingFullReferenceCount,
    required this.missingThumbnailCount,
    required this.hasUnknownLocalAssets,
  });

  final int knownBytes;
  final int missingFullReferenceCount;
  final int missingThumbnailCount;
  final bool hasUnknownLocalAssets;

  String get label {
    final size = _formatBytes(knownBytes);
    if (missingFullReferenceCount > 0) {
      return '预计数据包大小：至少约 $size，另有 $missingFullReferenceCount 张完整参考图需下载';
    }
    if (hasUnknownLocalAssets) {
      return '预计数据包大小：约 $size，部分本地照片或资源当前不可读取，实际包体可能略有变化';
    }
    if (missingThumbnailCount > 0) {
      return '预计数据包大小：约 $size，另有 $missingThumbnailCount 张缩略图需下载';
    }
    return '预计数据包大小：约 $size';
  }
}

Future<PlanExportSizeEstimate> estimatePlanExportV2Size({
  required PilgrimagePlan plan,
  required List<PilgrimageVisitRecord> visitRecords,
  required PlanExportV2Options options,
}) async {
  var knownBytes = 0;
  var missingFullReferenceCount = 0;
  var missingThumbnailCount = 0;
  var hasUnknownLocalAssets = false;

  knownBytes += _utf8Length(_roughJsonForPlan(plan, options));
  if (options.includeRecords) {
    knownBytes += _utf8Length(_roughJsonForRecords(visitRecords));
  }
  knownBytes += _roughCsvSize(
    plan,
    visitRecords,
    includeRecords: options.includeRecords,
  );
  knownBytes += 4096;

  Future<void> addLocalAsset(String? path) async {
    final size = await localAssetSize(path);
    if (size == null) {
      if (path != null && path.isNotEmpty) {
        hasUnknownLocalAssets = true;
      }
      return;
    }
    knownBytes += size;
  }

  for (final point in plan.points) {
    final thumbnailSize = await localAssetSize(point.referenceThumbnailPath);
    if (thumbnailSize == null) {
      if (point.referenceImageUrl != null) {
        missingThumbnailCount += 1;
        knownBytes += _estimatedThumbnailBytes;
      } else if (point.referenceThumbnailPath != null) {
        hasUnknownLocalAssets = true;
      }
    } else {
      knownBytes += thumbnailSize;
    }

    if (_isUserReference(point)) {
      await addLocalAsset(point.referenceFullImagePath);
    } else if (options.includeFullReferenceCache) {
      final fullSize = await localAssetSize(point.referenceFullImagePath);
      if (fullSize == null) {
        final fullUrl = anitabiFullResolutionImageUrl(point.referenceImageUrl);
        if (fullUrl != null && fullUrl.isNotEmpty) {
          missingFullReferenceCount += 1;
        } else if (point.referenceFullImagePath != null) {
          hasUnknownLocalAssets = true;
        }
      } else {
        knownBytes += fullSize;
      }
    }
  }

  if (options.includeRecords) {
    for (final record in visitRecords) {
      await addLocalAsset(record.photoPath);
      await addLocalAsset(record.gradedPhotoPath);
    }
  }

  return PlanExportSizeEstimate(
    knownBytes: knownBytes,
    missingFullReferenceCount: missingFullReferenceCount,
    missingThumbnailCount: missingThumbnailCount,
    hasUnknownLocalAssets: hasUnknownLocalAssets,
  );
}

String _roughJsonForPlan(PilgrimagePlan plan, PlanExportV2Options options) {
  return jsonEncode({
    'plan': {
      'id': plan.id,
      'name': plan.name,
      'area': plan.area,
      'works': plan.works.length,
      'points': plan.points.length,
      'groups': plan.groups.length,
      'completedPointIds': plan.completedPointIds.length,
    },
    'mode': options.exportMode,
  });
}

String _roughJsonForRecords(List<PilgrimageVisitRecord> records) {
  return jsonEncode({
    'records': records
        .map(
          (record) => {
            'id': record.id,
            'pointId': record.pointId,
            'photoPath': record.photoPath,
            'capturedAt': record.capturedAt.toIso8601String(),
          },
        )
        .toList(growable: false),
  });
}

int _roughCsvSize(
  PilgrimagePlan plan,
  List<PilgrimageVisitRecord> records, {
  required bool includeRecords,
}) {
  final pointText = plan.points
      .map((point) => '${point.work.title},${point.name},${point.subtitle}')
      .join('\n');
  final recordText = includeRecords
      ? records.map((record) => '${record.id},${record.photoPath}').join('\n')
      : '';
  return _utf8Length('$pointText\n$recordText');
}

bool _isUserReference(PilgrimagePoint point) {
  return point.source == PointSource.manual ||
      (point.referenceFullImagePath != null && point.referenceImageUrl == null);
}

String _formatBytes(int bytes) {
  if (bytes < 1024) {
    return '$bytes B';
  }
  final kib = bytes / 1024;
  if (kib < 1024) {
    return '${kib.toStringAsFixed(kib < 10 ? 1 : 0)} KB';
  }
  final mib = kib / 1024;
  if (mib < 1024) {
    return '${mib.toStringAsFixed(mib < 10 ? 1 : 0)} MB';
  }
  final gib = mib / 1024;
  return '${gib.toStringAsFixed(gib < 10 ? 1 : 0)} GB';
}

int _utf8Length(String value) => utf8.encode(value).length;
