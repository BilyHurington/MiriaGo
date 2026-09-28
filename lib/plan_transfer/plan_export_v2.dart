import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../app_version.dart';
import '../data/anitabi_image_url.dart';
import '../data/image_bytes.dart';
import '../plan/pilgrimage_models.dart';
import '../plan/reference_image_status.dart';
import 'plan_export_asset_stub.dart'
    if (dart.library.io) 'plan_export_asset_io.dart';
import 'plan_export_zip_source.dart';
import 'plan_package.dart';
import 'plan_transfer_background.dart';

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
  PlanTransferCancellation? cancellation,
}) async {
  final spool = PlanExportAssetSpool();
  try {
    return await _buildPlanExportV2Package(
      plan: plan,
      visitRecords: visitRecords,
      options: options,
      exportedAt: exportedAt,
      networkBytesReader: networkBytesReader,
      cancellation: cancellation,
      spool: spool,
    );
  } finally {
    // The worker has read every spooled file once encoding finished or was
    // cancelled.
    await spool.dispose();
  }
}

Future<PlanExportV2Result> _buildPlanExportV2Package({
  required PilgrimagePlan plan,
  required List<PilgrimageVisitRecord> visitRecords,
  required PlanExportV2Options options,
  required DateTime? exportedAt,
  required ExportNetworkBytesReader? networkBytesReader,
  required PlanTransferCancellation? cancellation,
  required PlanExportAssetSpool spool,
}) async {
  final exportTime = exportedAt ?? DateTime.now();
  // Only file paths and small generated files live here on native platforms,
  // so keeping the list alive while the worker zips costs no photo memory.
  final entries = <_PlanExportZipEntry>[];
  final assetNames = _PlanExportAssetNames();
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
    entries.add(
      _PlanExportZipEntry(
        name,
        PlanExportZipSource.bytes(utf8.encode(content)),
      ),
    );
  }

  void addWarning(PlanExportWarningType type, String message) {
    warnings.add(message);
    warningCounts[type.key] = (warningCounts[type.key] ?? 0) + 1;
  }

  Future<void> addSourceAsset({
    required PlanExportZipSource source,
    required String targetPath,
    required String countKey,
  }) async {
    final bytes = source.bytes;
    // On native, in-memory images are spooled to disk so that no image bytes
    // are copied into the ZIP worker isolate.
    final held = bytes == null ? source : await spool.hold(bytes);
    entries.add(_PlanExportZipEntry(targetPath, held));
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
    final source = await readExportAssetSource(normalizedPath);
    if (source == null) {
      addWarning(warningType, '$warningLabel missing: $normalizedPath');
      return null;
    }
    await addSourceAsset(
      source: source,
      targetPath: targetPath,
      countKey: countKey,
    );
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
    final source = await readExportAssetSource(normalizedPath);
    if (source == null) {
      addWarning(warningType, '$warningLabel missing: $normalizedPath');
      return null;
    }
    await addSourceAsset(
      source: source,
      targetPath: targetPath,
      countKey: countKey,
    );
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
      final localSource = await readExportAssetSource(normalizedPath);
      if (localSource != null) {
        await addSourceAsset(
          source: localSource,
          targetPath: targetPath,
          countKey: countKey,
        );
        return targetPath;
      }
    }

    final normalizedUrl = sourceUrl?.trim();
    if (normalizedUrl != null && normalizedUrl.isNotEmpty) {
      final bytes = await readNetworkBytes(normalizedUrl);
      if (bytes == null || !isSupportedImageBytes(bytes)) {
        addWarning(
          downloadFailedWarningType,
          '$warningLabel download failed: $normalizedUrl',
        );
        return null;
      }
      await addSourceAsset(
        source: PlanExportZipSource.bytes(_asUint8List(bytes)),
        targetPath: targetPath,
        countKey: countKey,
      );
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
      targetPath: assetNames.path('thumbnails', point.id, 'thumbnail.jpg'),
      warningLabel: 'thumbnail',
      warningType: PlanExportWarningType.thumbnailMissing,
      countKey: 'thumbnails',
      missingSourceDescription: _missingThumbnailDescription(point),
    );
    if (isLocalUpload) {
      pointAssetRefs.userReferenceAsset = await addFileAsset(
        sourcePath: point.referenceFullImagePath,
        targetPath: assetNames.path(
          'user_references',
          point.id,
          'reference.jpg',
        ),
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
        targetPath: assetNames.path(
          'full_references',
          point.id,
          'reference.jpg',
        ),
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
        targetPath: assetNames.path('visit_photos', record.id, 'photo.jpg'),
        warningLabel: 'visit photo',
        warningType: PlanExportWarningType.visitPhotoMissing,
        countKey: 'visitPhotos',
      );
      recordAssetRefs.gradedPhotoAsset = await addFileAsset(
        sourcePath: record.gradedPhotoPath,
        targetPath: assetNames.path('graded_photos', record.id, 'graded.jpg'),
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

  final bytes = await _encodePlanExportZip(entries, cancellation);

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
      'memo': plan.memo,
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
    'coverImageUrl': work.coverImageUrl,
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

class _PlanExportZipEntry {
  const _PlanExportZipEntry(this.name, this.source);

  final String name;
  final PlanExportZipSource source;
}

Uint8List _asUint8List(List<int> bytes) =>
    bytes is Uint8List ? bytes : Uint8List.fromList(bytes);

// Deflating hundreds of MiB of photos must not block the UI isolate. On
// native the entries only name files, so the spawn message stays small and
// the worker reads each photo from disk while it zips.
Future<List<int>> _encodePlanExportZip(
  List<_PlanExportZipEntry> entries,
  PlanTransferCancellation? cancellation,
) {
  return runPlanTransferTask(
    () => _encodeZipEntries(entries),
    cancellation: cancellation,
  );
}

List<int> _encodeZipEntries(List<_PlanExportZipEntry> entries) {
  // Size the output once: growing by doubling would briefly hold the ZIP two
  // or three times over. Deflate barely shrinks photos and can grow
  // incompressible data slightly, hence the per-entry slack.
  var capacity = 64 * 1024;
  for (final entry in entries) {
    final size =
        entry.source.bytes?.length ??
        exportZipSourceFileLength(entry.source.filePath!);
    capacity += size + (size >> 10) + 256 + 2 * utf8.encode(entry.name).length;
  }
  final output = OutputMemoryStream(size: capacity);
  final encoder = ZipEncoder()..startEncode(output);
  for (final entry in entries) {
    // Read one file at a time; its bytes are released after it is written.
    final bytes =
        entry.source.bytes ?? readExportZipSourceFile(entry.source.filePath!);
    encoder.add(ArchiveFile.bytes(entry.name, bytes));
  }
  encoder.endEncode(comment: null);
  return output.getBytes();
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
        point.hasCoordinate ? point.position.latitude : null,
        point.hasCoordinate ? point.position.longitude : null,
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

// The BOM lets Excel detect UTF-8 so CJK titles are not garbled.
String _csv(List<List<Object?>> rows) {
  return '\uFEFF${rows.map((row) => row.map(_csvCell).join(',')).join('\n')}';
}

String _csvCell(Object? value) {
  // Numbers (latitude/longitude, counts) are written raw; only text can carry
  // a spreadsheet formula, so neutralize it with a leading apostrophe.
  final text = value is String
      ? _neutralizeSpreadsheetFormula(value)
      : (value ?? '').toString();
  if (!text.contains(',') &&
      !text.contains('"') &&
      !text.contains('\n') &&
      !text.contains('\r')) {
    return text;
  }
  return '"${text.replaceAll('"', '""')}"';
}

String _neutralizeSpreadsheetFormula(String value) {
  if (value.isEmpty) {
    return value;
  }
  return const {'=', '+', '-', '@', '\t', '\r'}.contains(value[0])
      ? "'$value"
      : value;
}

String _fileName(String path) {
  return path.split(RegExp(r'[\\/]')).last;
}

const _maxAssetStemLength = 80;

/// Allocates archive asset paths. Ids are sanitized for file systems, so
/// distinct ids like `a b`/`a_b` or `A`/`a` could otherwise map to the same
/// entry, which the importer rejects (names are unique case-insensitively).
/// A lossy sanitization appends a stable hash of the raw id, and any
/// remaining case-insensitive clash is disambiguated.
class _PlanExportAssetNames {
  final _used = <String>{};

  String path(String directory, String id, String fallback) {
    final extension = fallback.contains('.') ? fallback.split('.').last : 'bin';
    final stem = planExportAssetStem(id);
    var candidate = 'assets/$directory/$stem.$extension';
    if (!_used.add(candidate.toLowerCase())) {
      final hashed = '${stem}_${_idHash(id)}';
      candidate = 'assets/$directory/$hashed.$extension';
      for (var index = 2; !_used.add(candidate.toLowerCase()); index++) {
        candidate = 'assets/$directory/${hashed}_$index.$extension';
      }
    }
    return candidate;
  }
}

/// File-name stem used for an asset of [id]. Ids that are already safe keep
/// their name; anything altered by sanitization or truncation gets a hash of
/// the raw id so different ids stay distinct.
String planExportAssetStem(String id) {
  final safeId = _safeFileName(id, fallback: 'asset');
  if (safeId == id && safeId.length <= _maxAssetStemLength) {
    return safeId;
  }
  final truncated = safeId.length > _maxAssetStemLength
      ? safeId.substring(0, _maxAssetStemLength)
      : safeId;
  return '${truncated}_${_idHash(id)}';
}

String _idHash(String id) =>
    getCrc32(utf8.encode(id)).toRadixString(16).padLeft(8, '0');

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
