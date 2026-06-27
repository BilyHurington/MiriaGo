import 'dart:convert';

import 'package:archive/archive.dart';

import '../app_version.dart';
import '../data/anitabi_image_url.dart';
import '../plan/pilgrimage_models.dart';
import '../plan/reference_image_status.dart';
import 'plan_export_asset_stub.dart'
    if (dart.library.io) 'plan_export_asset_io.dart';
import 'plan_package.dart';

enum PlanExportV2Mode { planOnly, planWithRecords }

class PlanExportV2Options {
  const PlanExportV2Options({
    required this.mode,
    required this.includeFullReferenceCache,
  });

  final PlanExportV2Mode mode;
  final bool includeFullReferenceCache;

  bool get includeRecords => mode == PlanExportV2Mode.planWithRecords;

  String get exportMode => switch (mode) {
    PlanExportV2Mode.planOnly => 'plan_only',
    PlanExportV2Mode.planWithRecords => 'plan_with_records',
  };
}

class PlanExportV2Result {
  const PlanExportV2Result({
    required this.bytes,
    required this.fileName,
    required this.warnings,
    required this.warningCounts,
  });

  final List<int> bytes;
  final String fileName;
  final List<String> warnings;
  final Map<String, int> warningCounts;
}

typedef ExportNetworkBytesReader = Future<List<int>?> Function(String url);

const miriagoExportPackageFormat = 'miriago_export_package';
const miriagoExportPackageMimeType = 'application/vnd.miriago.plan+zip';
const miriagoExportSchemaVersion = 2;

enum PlanExportWarningType {
  thumbnailMissing('thumbnailMissing'),
  fullReferenceDownloadFailed('fullReferenceDownloadFailed'),
  fullReferenceMissing('fullReferenceMissing'),
  userReferenceMissing('userReferenceMissing'),
  visitPhotoMissing('visitPhotoMissing'),
  gradedPhotoMissing('gradedPhotoMissing');

  const PlanExportWarningType(this.key);

  final String key;
}

Future<PlanExportV2Result> buildPlanExportV2Package({
  required PilgrimagePlan plan,
  required List<PilgrimageVisitRecord> visitRecords,
  required PlanExportV2Options options,
  DateTime? exportedAt,
  ExportNetworkBytesReader? networkBytesReader,
}) async {
  final exportTime = exportedAt ?? DateTime.now();
  final archive = Archive();
  final readNetworkBytes = networkBytesReader ?? readExportNetworkBytes;
  final records = options.includeRecords
      ? visitRecords
      : const <PilgrimageVisitRecord>[];
  final warnings = <String>[];
  final warningCounts = <String, int>{};
  final assetCounts = <String, int>{
    'thumbnails': 0,
    'userReferenceImages': 0,
    'fullReferences': 0,
    'visitPhotos': 0,
    'gradedPhotos': 0,
  };
  final pointAssetRefsById = <String, _PointAssetRefs>{};
  final recordAssetRefsById = <String, _RecordAssetRefs>{};

  void addString(String name, String content) {
    archive.addFile(ArchiveFile.string(name, content));
  }

  void addWarning(PlanExportWarningType type, String message) {
    warnings.add(message);
    warningCounts[type.key] = (warningCounts[type.key] ?? 0) + 1;
  }

  void addBytesAsset({
    required List<int> bytes,
    required String targetPath,
    required String countKey,
  }) {
    archive.addFile(ArchiveFile.bytes(targetPath, bytes));
    assetCounts[countKey] = (assetCounts[countKey] ?? 0) + 1;
  }

  Future<String?> addFileAsset({
    required String? sourcePath,
    required String targetPath,
    required String warningLabel,
    required PlanExportWarningType warningType,
    required String countKey,
    String? missingSourceDescription,
  }) async {
    final normalizedPath = sourcePath?.trim();
    if (normalizedPath == null || normalizedPath.isEmpty) {
      final description = missingSourceDescription?.trim();
      if (description != null && description.isNotEmpty) {
        addWarning(
          warningType,
          '$warningLabel missing local cache: $description',
        );
      }
      return null;
    }
    final bytes = await readExportAssetBytes(normalizedPath);
    if (bytes == null) {
      addWarning(warningType, '$warningLabel missing: $normalizedPath');
      return null;
    }
    addBytesAsset(bytes: bytes, targetPath: targetPath, countKey: countKey);
    return targetPath;
  }

  Future<String?> addLocalAsset({
    required String? sourcePath,
    required String targetPath,
    required String warningLabel,
    required PlanExportWarningType warningType,
    required String countKey,
    String? missingSourceDescription,
  }) async {
    final normalizedPath = sourcePath?.trim();
    if (normalizedPath == null || normalizedPath.isEmpty) {
      final description = missingSourceDescription?.trim();
      if (description != null && description.isNotEmpty) {
        addWarning(
          warningType,
          '$warningLabel missing local cache: $description',
        );
      }
      return null;
    }
    final bytes = await readExportAssetBytes(normalizedPath);
    if (bytes == null) {
      addWarning(warningType, '$warningLabel missing: $normalizedPath');
      return null;
    }
    addBytesAsset(bytes: bytes, targetPath: targetPath, countKey: countKey);
    return targetPath;
  }

  Future<String?> addLocalOrNetworkAsset({
    required String? sourcePath,
    required String? sourceUrl,
    required String targetPath,
    required String warningLabel,
    required PlanExportWarningType missingWarningType,
    required PlanExportWarningType downloadFailedWarningType,
    required String countKey,
    String? missingSourceDescription,
  }) async {
    final normalizedPath = sourcePath?.trim();
    if (normalizedPath != null && normalizedPath.isNotEmpty) {
      final localBytes = await readExportAssetBytes(normalizedPath);
      if (localBytes != null) {
        addBytesAsset(
          bytes: localBytes,
          targetPath: targetPath,
          countKey: countKey,
        );
        return targetPath;
      }
    }

    final normalizedUrl = sourceUrl?.trim();
    if (normalizedUrl != null && normalizedUrl.isNotEmpty) {
      final bytes = await readNetworkBytes(normalizedUrl);
      if (bytes == null) {
        addWarning(
          downloadFailedWarningType,
          '$warningLabel download failed: $normalizedUrl',
        );
        return null;
      }
      addBytesAsset(bytes: bytes, targetPath: targetPath, countKey: countKey);
      return targetPath;
    }

    if (normalizedPath != null && normalizedPath.isNotEmpty) {
      addWarning(missingWarningType, '$warningLabel missing: $normalizedPath');
      return null;
    }

    final description = missingSourceDescription?.trim();
    if (description != null && description.isNotEmpty) {
      addWarning(
        missingWarningType,
        '$warningLabel missing local cache: $description',
      );
      return null;
    }

    return null;
  }

  for (final point in plan.points) {
    final isLocalUpload = isLocalUploadedReference(point);
    final pointAssetRefs = _PointAssetRefs();
    pointAssetRefs.referenceThumbnailAsset = await addLocalAsset(
      sourcePath: point.referenceThumbnailPath,
      targetPath: 'assets/thumbnails/${_assetName(point.id, 'thumbnail.jpg')}',
      warningLabel: 'thumbnail',
      warningType: PlanExportWarningType.thumbnailMissing,
      countKey: 'thumbnails',
      missingSourceDescription: _missingThumbnailDescription(point),
    );
    if (isLocalUpload) {
      pointAssetRefs.userReferenceAsset = await addFileAsset(
        sourcePath: point.referenceFullImagePath,
        targetPath:
            'assets/user_references/${_assetName(point.id, 'reference.jpg')}',
        warningLabel: 'user reference',
        warningType: PlanExportWarningType.userReferenceMissing,
        countKey: 'userReferenceImages',
        missingSourceDescription: point.name,
      );
    } else if (options.includeFullReferenceCache &&
        hasRemoteReferenceImage(point)) {
      pointAssetRefs.referenceFullReferenceAsset = await addLocalOrNetworkAsset(
        sourcePath: point.referenceFullImagePath,
        sourceUrl: anitabiFullResolutionImageUrl(point.referenceImageUrl),
        targetPath:
            'assets/full_references/${_assetName(point.id, 'reference.jpg')}',
        warningLabel: 'full reference',
        missingWarningType: PlanExportWarningType.fullReferenceMissing,
        downloadFailedWarningType:
            PlanExportWarningType.fullReferenceDownloadFailed,
        countKey: 'fullReferences',
      );
    }
    if (pointAssetRefs.hasAny) {
      pointAssetRefsById[point.id] = pointAssetRefs;
    }
  }

  if (options.includeRecords) {
    for (final record in records) {
      final recordAssetRefs = _RecordAssetRefs();
      recordAssetRefs.visitPhotoAsset = await addFileAsset(
        sourcePath: record.photoPath,
        targetPath: 'assets/visit_photos/${_assetName(record.id, 'photo.jpg')}',
        warningLabel: 'visit photo',
        warningType: PlanExportWarningType.visitPhotoMissing,
        countKey: 'visitPhotos',
      );
      recordAssetRefs.gradedPhotoAsset = await addFileAsset(
        sourcePath: record.gradedPhotoPath,
        targetPath:
            'assets/graded_photos/${_assetName(record.id, 'graded.jpg')}',
        warningLabel: 'graded photo',
        warningType: PlanExportWarningType.gradedPhotoMissing,
        countKey: 'gradedPhotos',
      );
      if (recordAssetRefs.hasAny) {
        recordAssetRefsById[record.id] = recordAssetRefs;
      }
    }
  }

  addString(
    'manifest.json',
    _prettyJson(
      _manifestJson(
        plan: plan,
        records: records,
        options: options,
        exportedAt: exportTime,
        warnings: warnings,
        warningCounts: warningCounts,
        assetCounts: assetCounts,
      ),
    ),
  );
  addString(
    'plan.json',
    _prettyJson(
      _planJson(
        plan: plan,
        records: records,
        options: options,
        pointAssetRefsById: pointAssetRefsById,
        recordAssetRefsById: recordAssetRefsById,
      ),
    ),
  );
  addString('points.csv', _pointsCsv(plan, visitRecords));
  if (options.includeRecords) {
    addString('records.csv', _recordsCsv(plan, records));
  }

  final bytes = ZipEncoder().encode(archive);

  return PlanExportV2Result(
    bytes: bytes,
    fileName: suggestPlanExportV2FileName(plan: plan, exportedAt: exportTime),
    warnings: List.unmodifiable(warnings),
    warningCounts: Map.unmodifiable(warningCounts),
  );
}

String suggestPlanExportV2FileName({
  required PilgrimagePlan plan,
  required DateTime exportedAt,
}) {
  return '${_safeFileName(plan.name, fallback: 'miriago_plan')}_${_timestamp(exportedAt)}.$seichiPlanFileExtension';
}

Map<String, Object?> _manifestJson({
  required PilgrimagePlan plan,
  required List<PilgrimageVisitRecord> records,
  required PlanExportV2Options options,
  required DateTime exportedAt,
  required List<String> warnings,
  required Map<String, int> warningCounts,
  required Map<String, int> assetCounts,
}) {
  return {
    'format': miriagoExportPackageFormat,
    'container': 'zip',
    'schemaVersion': miriagoExportSchemaVersion,
    'appName': 'MiriaGo',
    'appVersion': miriagoAppVersion,
    'exportedAt': exportedAt.toIso8601String(),
    'exportMode': options.exportMode,
    'packageId': 'miriago-export-${_timestamp(exportedAt)}',
    'planId': plan.id,
    'planName': plan.name,
    'includedContent': {
      'plan': true,
      'works': true,
      'groups': true,
      'points': true,
      'pointCompletion': true,
      'thumbnails': true,
      'userReferenceImages': true,
      'fullReferenceCache': options.includeFullReferenceCache,
      'visitRecords': options.includeRecords,
      'visitPhotos': options.includeRecords,
      'gradedPhotos': options.includeRecords,
      'colorGradingParams': options.includeRecords,
    },
    'counts': {
      'works': plan.works.length,
      'groups': plan.groups.length,
      'points': plan.points.length,
      'visitRecords': records.length,
    },
    'assetCounts': assetCounts,
    'warningCounts': warningCounts,
    'warnings': warnings,
  };
}

String? _missingThumbnailDescription(PilgrimagePoint point) {
  final localThumbnailPath = point.referenceThumbnailPath?.trim();
  if (localThumbnailPath != null && localThumbnailPath.isNotEmpty) {
    return localThumbnailPath;
  }
  if (hasRemoteReferenceImage(point)) {
    return anitabiThumbnailImageUrl(point.referenceImageUrl);
  }
  if (isLocalUploadedReference(point)) {
    return point.name;
  }
  return null;
}

Map<String, Object?> _planJson({
  required PilgrimagePlan plan,
  required List<PilgrimageVisitRecord> records,
  required PlanExportV2Options options,
  required Map<String, _PointAssetRefs> pointAssetRefsById,
  required Map<String, _RecordAssetRefs> recordAssetRefsById,
}) {
  return {
    'schemaVersion': miriagoExportSchemaVersion,
    'exportMode': options.exportMode,
    'plan': {
      'id': plan.id,
      'name': plan.name,
      'area': plan.area,
      'createdAt': plan.createdAt.toIso8601String(),
      'updatedAt': plan.updatedAt.toIso8601String(),
      'currentPointId': plan.currentPointId,
      'currentGroupId': plan.currentGroupId,
      'completedPointIds': plan.completedPointIds.toList()..sort(),
      'works': plan.works.map(_workJson).toList(),
      'groups': plan.groups.map(_groupJson).toList(),
      'points': plan.points
          .map((point) => _pointJson(point, pointAssetRefsById[point.id]))
          .toList(),
    },
    if (options.includeRecords)
      'visitRecords': records
          .map(
            (record) =>
                _visitRecordJson(record, recordAssetRefsById[record.id]),
          )
          .toList(),
  };
}

Map<String, Object?> _workJson(PilgrimageWork work) {
  return {
    'id': work.id,
    'bangumiId': work.bangumiId,
    'bangumiSubjectType': work.bangumiSubjectType?.name,
    'title': work.title,
    'subtitle': work.subtitle,
    'city': work.city,
    'source': work.source.name,
  };
}

Map<String, Object?> _groupJson(PilgrimagePlanGroup group) {
  return {
    'id': group.id,
    'name': group.name,
    'orderIndex': group.orderIndex,
    'orderMode': group.orderMode.name,
    'anchorName': group.anchorName,
    'anchorLatitude': group.anchorLatitude,
    'anchorLongitude': group.anchorLongitude,
    'anchorPointId': group.anchorPointId,
    'note': group.note,
    'createdAt': group.createdAt.toIso8601String(),
  };
}

Map<String, Object?> _pointJson(
  PilgrimagePoint point,
  _PointAssetRefs? assetRefs,
) {
  return {
    'id': point.id,
    'workId': point.work.id,
    'name': point.name,
    'subtitle': point.subtitle,
    'latitude': point.position.latitude,
    'longitude': point.position.longitude,
    'episodeLabel': point.episodeLabel,
    'referenceLabel': point.referenceLabel,
    'source': point.source.name,
    'sourceId': point.sourceId,
    'referenceImageUrl': isLocalUploadedReference(point)
        ? null
        : point.referenceImageUrl,
    'referenceThumbnailPath': point.referenceThumbnailPath,
    'referenceFullImagePath': point.referenceFullImagePath,
    'referenceThumbnailAsset': assetRefs?.referenceThumbnailAsset,
    'referenceFullReferenceAsset': assetRefs?.referenceFullReferenceAsset,
    'userReferenceAsset': assetRefs?.userReferenceAsset,
    'sourceUrl': point.sourceUrl,
    'note': point.note,
    'groupId': point.groupId,
    'groupOrderIndex': point.groupOrderIndex,
  };
}

Map<String, Object?> _visitRecordJson(
  PilgrimageVisitRecord record,
  _RecordAssetRefs? assetRefs,
) {
  return {
    'id': record.id,
    'planId': record.planId,
    'pointId': record.pointId,
    'workId': record.workId,
    'workTitle': record.workTitle,
    'workSubtitle': record.workSubtitle,
    'pointName': record.pointName,
    'pointSubtitle': record.pointSubtitle,
    'photoPath': record.photoPath,
    'originalPhotoPath': record.originalPhotoPath,
    'gradedPhotoPath': record.gradedPhotoPath,
    'colorGradingMode': record.colorGradingMode,
    'colorGradingParamsJson': record.colorGradingParamsJson,
    'colorGradingIntensity': record.colorGradingIntensity,
    'referenceImagePath': record.referenceImagePath,
    'referenceImageUrl': record.referenceImageUrl,
    'visitPhotoAsset': assetRefs?.visitPhotoAsset,
    'gradedPhotoAsset': assetRefs?.gradedPhotoAsset,
    'referenceMode': record.referenceMode,
    'capturedAt': record.capturedAt.toIso8601String(),
  };
}

class _PointAssetRefs {
  String? referenceThumbnailAsset;
  String? referenceFullReferenceAsset;
  String? userReferenceAsset;

  bool get hasAny =>
      referenceThumbnailAsset != null ||
      referenceFullReferenceAsset != null ||
      userReferenceAsset != null;
}

class _RecordAssetRefs {
  String? visitPhotoAsset;
  String? gradedPhotoAsset;

  bool get hasAny => visitPhotoAsset != null || gradedPhotoAsset != null;
}

String _pointsCsv(
  PilgrimagePlan plan,
  List<PilgrimageVisitRecord> visitRecords,
) {
  final recordCounts = <String, int>{};
  for (final record in visitRecords) {
    recordCounts[record.pointId] = (recordCounts[record.pointId] ?? 0) + 1;
  }
  final lines = <List<Object?>>[
    [
      '作品',
      '片区',
      '点位名',
      '副标题',
      '纬度',
      '经度',
      '集数/场景',
      '来源',
      '来源ID',
      '参考图URL',
      '已完成',
      '记录数',
    ],
    for (final point in plan.points)
      [
        point.work.title,
        _groupName(plan, point.groupId),
        point.name,
        point.subtitle,
        point.position.latitude,
        point.position.longitude,
        point.displayEpisodeLabel,
        point.source.name,
        point.sourceId,
        isLocalUploadedReference(point) ? null : point.referenceImageUrl,
        plan.completedPointIds.contains(point.id) ? '是' : '否',
        recordCounts[point.id] ?? 0,
      ],
  ];
  return _csv(lines);
}

String _recordsCsv(PilgrimagePlan plan, List<PilgrimageVisitRecord> records) {
  final pointById = {for (final point in plan.points) point.id: point};
  final lines = <List<Object?>>[
    ['作品', '片区', '点位名', '记录ID', '拍摄时间', '参考模式', '是否调色', '照片文件名', '调色照片文件名'],
    for (final record in records)
      [
        pointById[record.pointId]?.work.title ??
            record.displayWorkTitleSnapshot,
        _groupName(plan, pointById[record.pointId]?.groupId),
        pointById[record.pointId]?.name ?? record.displayPointNameSnapshot,
        record.id,
        record.capturedAt.toIso8601String(),
        record.referenceMode,
        record.hasColorGrading ? '是' : '否',
        _fileName(record.photoPath),
        record.gradedPhotoPath == null
            ? ''
            : _fileName(record.gradedPhotoPath!),
      ],
  ];
  return _csv(lines);
}

String _groupName(PilgrimagePlan plan, String? groupId) {
  if (groupId == null) {
    return '未分组';
  }
  return plan.groups.where((group) => group.id == groupId).firstOrNull?.name ??
      '未知片区';
}

String _prettyJson(Object? value) {
  return const JsonEncoder.withIndent('  ').convert(value);
}

String _csv(List<List<Object?>> rows) {
  return rows.map((row) => row.map(_csvCell).join(',')).join('\n');
}

String _csvCell(Object? value) {
  final text = (value ?? '').toString();
  if (!text.contains(',') &&
      !text.contains('"') &&
      !text.contains('\n') &&
      !text.contains('\r')) {
    return text;
  }
  return '"${text.replaceAll('"', '""')}"';
}

String _fileName(String path) {
  return path.split(RegExp(r'[\\/]')).last;
}

String _assetName(String id, String fallback) {
  final safeId = _safeFileName(id, fallback: 'asset');
  final extension = fallback.contains('.') ? fallback.split('.').last : 'bin';
  return '$safeId.$extension';
}

String _safeFileName(String value, {required String fallback}) {
  final safe = value
      .replaceAll(RegExp(r'[\\/:*?"<>|\s]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
  return safe.isEmpty ? fallback : safe;
}

String _timestamp(DateTime value) {
  String twoDigits(int number) => number.toString().padLeft(2, '0');
  return '${value.year}${twoDigits(value.month)}${twoDigits(value.day)}_'
      '${twoDigits(value.hour)}${twoDigits(value.minute)}${twoDigits(value.second)}';
}
