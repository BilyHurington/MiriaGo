import 'dart:convert';

import '../data/local_asset_size_stub.dart'
    if (dart.library.io) '../data/local_asset_size_io.dart';
import '../plan/pilgrimage_models.dart';
import '../plan/reference_image_status.dart';
import 'plan_export_v2.dart';

class PlanExportSizeEstimate {
  const PlanExportSizeEstimate({
    required this.knownBytes,
    required this.missingFullReferenceCount,
    required this.missingThumbnailCount,
    required this.missingUserReferenceCount,
    required this.missingVisitPhotoCount,
    required this.missingGradedPhotoCount,
    required this.hasUnknownLocalAssets,
  });

  final int knownBytes;
  final int missingFullReferenceCount;
  final int missingThumbnailCount;
  final int missingUserReferenceCount;
  final int missingVisitPhotoCount;
  final int missingGradedPhotoCount;
  final bool hasUnknownLocalAssets;

  bool get hasMissingCriticalAssets =>
      missingUserReferenceCount > 0 ||
      missingVisitPhotoCount > 0 ||
      missingGradedPhotoCount > 0;

  List<String> get detailMessages {
    final messages = <String>[];
    if (missingThumbnailCount > 0) {
      messages.add('$missingThumbnailCount 张缩略图未缓存，不会进入数据包');
    }
    if (missingFullReferenceCount > 0) {
      messages.add('$missingFullReferenceCount 张完整参考图将在导出时下载');
    }
    if (missingUserReferenceCount > 0) {
      messages.add('$missingUserReferenceCount 张本地上传参考图文件缺失，导出后无法恢复');
    }
    if (missingVisitPhotoCount > 0) {
      messages.add('$missingVisitPhotoCount 张巡礼照片文件缺失');
    }
    if (missingGradedPhotoCount > 0) {
      messages.add('$missingGradedPhotoCount 张调色照片文件缺失');
    }
    if (hasUnknownLocalAssets) {
      messages.add('部分本地资源无法读取，实际包体可能变化');
    }
    return messages;
  }

  String get label {
    final size = _formatBytes(knownBytes);
    final details = detailMessages;
    if (details.isNotEmpty) {
      return '预计数据包大小：至少约 $size，${details.join('；')}';
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
  var missingUserReferenceCount = 0;
  var missingVisitPhotoCount = 0;
  var missingGradedPhotoCount = 0;
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

  Future<bool> addLocalAsset(String? path, {bool markUnknown = true}) async {
    final size = await localAssetSize(path);
    if (size == null) {
      if (markUnknown && path != null && path.isNotEmpty) {
        hasUnknownLocalAssets = true;
      }
      return false;
    }
    knownBytes += size;
    return true;
  }

  for (final point in plan.points) {
    final isLocalUpload = isLocalUploadedReference(point);
    final thumbnailSize = await localAssetSize(point.referenceThumbnailPath);
    if (thumbnailSize == null) {
      if (isLocalUpload ||
          hasRemoteReferenceImage(point) ||
          _hasPath(point.referenceThumbnailPath)) {
        missingThumbnailCount += 1;
      }
    } else {
      knownBytes += thumbnailSize;
    }

    if (isLocalUpload) {
      final hasFullReference = await addLocalAsset(
        point.referenceFullImagePath,
        markUnknown: false,
      );
      if (!hasFullReference) {
        missingUserReferenceCount += 1;
      }
    } else if (options.includeFullReferenceCache) {
      final fullSize = await localAssetSize(point.referenceFullImagePath);
      if (fullSize == null) {
        if (hasRemoteReferenceImage(point)) {
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
      if (!await addLocalAsset(record.photoPath, markUnknown: false)) {
        missingVisitPhotoCount += 1;
      }
      if (_hasPath(record.gradedPhotoPath) &&
          !await addLocalAsset(record.gradedPhotoPath, markUnknown: false)) {
        missingGradedPhotoCount += 1;
      }
    }
  }

  return PlanExportSizeEstimate(
    knownBytes: knownBytes,
    missingFullReferenceCount: missingFullReferenceCount,
    missingThumbnailCount: missingThumbnailCount,
    missingUserReferenceCount: missingUserReferenceCount,
    missingVisitPhotoCount: missingVisitPhotoCount,
    missingGradedPhotoCount: missingGradedPhotoCount,
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

bool _hasPath(String? path) => path != null && path.trim().isNotEmpty;
