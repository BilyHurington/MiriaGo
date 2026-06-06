import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:latlong2/latlong.dart';

import '../plan/pilgrimage_models.dart';
import 'plan_export_v2.dart';
import 'plan_package.dart';

enum PlanImportPackageKind { legacyJson, miriagoZip }

class PlanImportPackage {
  const PlanImportPackage({
    required this.kind,
    required this.package,
    required this.sourceName,
    required this.manifest,
    required this.assetCounts,
    required this.warnings,
    required this.exportedAt,
    required this.appVersion,
    required this.schemaVersion,
    required this.exportMode,
  });

  final PlanImportPackageKind kind;
  final PlanPackage package;
  final String sourceName;
  final Map<String, Object?> manifest;
  final Map<String, int> assetCounts;
  final List<String> warnings;
  final DateTime? exportedAt;
  final String? appVersion;
  final int? schemaVersion;
  final String? exportMode;

  bool get isLegacyJson => kind == PlanImportPackageKind.legacyJson;

  bool get hasVisitRecords => package.visitRecords.isNotEmpty;

  bool get hasAssets => assetCounts.values.any((count) => count > 0);

  int get totalAssetCount =>
      assetCounts.values.fold(0, (total, count) => total + count);

  int get workCount => package.plan.works.length;

  int get groupCount => package.plan.groups.length;

  int get pointCount => package.plan.points.length;

  int get visitRecordCount => package.visitRecords.length;

  String get versionLabel => switch (kind) {
    PlanImportPackageKind.legacyJson => 'v1.0 JSON',
    PlanImportPackageKind.miriagoZip => 'v2 数据包',
  };
}

PlanImportPackage readPlanImportPackageFromBytes(
  List<int> bytes, {
  required String sourceName,
}) {
  if (_looksLikeZip(bytes)) {
    return _readV2ZipPackage(bytes, sourceName: sourceName);
  }
  final package = PlanPackage.fromJsonString(utf8.decode(bytes));
  return PlanImportPackage(
    kind: PlanImportPackageKind.legacyJson,
    package: package,
    sourceName: sourceName,
    manifest: const {},
    assetCounts: const {},
    warnings: const [],
    exportedAt: null,
    appVersion: null,
    schemaVersion: 1,
    exportMode: 'legacy_json',
  );
}

bool _looksLikeZip(List<int> bytes) {
  return bytes.length >= 4 &&
      bytes[0] == 0x50 &&
      bytes[1] == 0x4B &&
      bytes[2] == 0x03 &&
      bytes[3] == 0x04;
}

PlanImportPackage _readV2ZipPackage(
  List<int> bytes, {
  required String sourceName,
}) {
  final archive = ZipDecoder().decodeBytes(bytes);
  final manifest = _readArchiveJson(archive, 'manifest.json');
  if (manifest['format'] != miriagoExportPackageFormat) {
    throw const FormatException('Unsupported MiriaGo package format.');
  }
  final planRoot = _readArchiveJson(archive, 'plan.json');
  final plan = _planFromV2Json(_mapValue(planRoot['plan']));
  final records = _readList(planRoot['visitRecords'], _visitRecordFromV2Json);

  return PlanImportPackage(
    kind: PlanImportPackageKind.miriagoZip,
    package: PlanPackage(plan: plan, visitRecords: records),
    sourceName: sourceName,
    manifest: manifest,
    assetCounts: _intMap(manifest['assetCounts']),
    warnings:
        (manifest['warnings'] as List?)?.whereType<String>().toList() ??
        const [],
    exportedAt: _nullableDateValue(manifest['exportedAt']),
    appVersion: manifest['appVersion'] as String?,
    schemaVersion: (manifest['schemaVersion'] as num?)?.toInt(),
    exportMode: manifest['exportMode'] as String?,
  );
}

Map<String, Object?> _readArchiveJson(Archive archive, String name) {
  final file = archive.findFile(name);
  if (file == null) {
    throw FormatException('Missing $name.');
  }
  final content = file.content;
  final source = utf8.decode(content);
  final decoded = jsonDecode(source);
  return _mapValue(decoded);
}

PilgrimagePlan _planFromV2Json(Map<String, Object?> json) {
  final works = _readList(json['works'], _workFromV2Json);
  final workById = {for (final work in works) work.id: work};
  final groups = _readList(json['groups'], _groupFromV2Json);
  final points = _readList(
    json['points'],
    (pointJson) => _pointFromV2Json(pointJson, workById),
  );

  return PilgrimagePlan(
    id: _stringValue(json['id'], fallback: 'imported-plan'),
    name: _stringValue(json['name'], fallback: '导入的巡礼计划'),
    area: _stringValue(json['area'], fallback: '未设置区域'),
    works: works,
    groups: groups,
    points: points,
    createdAt: _dateValue(json['createdAt']),
    updatedAt: _dateValue(json['updatedAt']),
    currentPointId: json['currentPointId'] as String?,
    currentGroupId: json['currentGroupId'] as String?,
    completedPointIds:
        (json['completedPointIds'] as List?)?.whereType<String>().toSet() ??
        <String>{},
  );
}

PilgrimageWork _workFromV2Json(Map<String, Object?> json) {
  return PilgrimageWork(
    id: _stringValue(json['id'], fallback: 'work-${json.hashCode}'),
    bangumiId: (json['bangumiId'] as num?)?.toInt(),
    bangumiSubjectType: _enumValue(
      BangumiSubjectType.values,
      json['bangumiSubjectType'],
    ),
    title: _stringValue(json['title'], fallback: '未知作品'),
    subtitle: _stringValue(json['subtitle'], fallback: ''),
    city: _stringValue(json['city'], fallback: '未设置地区'),
    source: _enumValue(WorkSource.values, json['source']) ?? WorkSource.manual,
  );
}

PilgrimagePlanGroup _groupFromV2Json(Map<String, Object?> json) {
  return PilgrimagePlanGroup(
    id: _stringValue(json['id'], fallback: 'group-${json.hashCode}'),
    name: _stringValue(json['name'], fallback: '未命名片区'),
    orderIndex: (json['orderIndex'] as num?)?.toInt() ?? 0,
    orderMode:
        _enumValue(PlanGroupOrderMode.values, json['orderMode']) ??
        PlanGroupOrderMode.unordered,
    anchorName: json['anchorName'] as String?,
    anchorLatitude: (json['anchorLatitude'] as num?)?.toDouble(),
    anchorLongitude: (json['anchorLongitude'] as num?)?.toDouble(),
    anchorPointId: json['anchorPointId'] as String?,
    note: json['note'] as String?,
    createdAt: _dateValue(json['createdAt']),
  );
}

PilgrimagePoint _pointFromV2Json(
  Map<String, Object?> json,
  Map<String, PilgrimageWork> works,
) {
  final workId = _stringValue(json['workId'], fallback: 'manual-work');
  final work =
      works[workId] ??
      PilgrimageWork(
        id: workId,
        title: '未知作品',
        subtitle: '',
        city: '未设置地区',
        source: WorkSource.manual,
      );

  return PilgrimagePoint(
    id: _stringValue(json['id'], fallback: 'point-${json.hashCode}'),
    work: work,
    name: _stringValue(json['name'], fallback: '未命名点位'),
    subtitle: _stringValue(json['subtitle'], fallback: ''),
    position: LatLng(
      _doubleValue(json['latitude']),
      _doubleValue(json['longitude']),
    ),
    episodeLabel: _stringValue(json['episodeLabel'], fallback: ''),
    referenceLabel: _stringValue(json['referenceLabel'], fallback: ''),
    source:
        _enumValue(PointSource.values, json['source']) ?? PointSource.manual,
    sourceId: json['sourceId'] as String?,
    referenceImageUrl: json['referenceImageUrl'] as String?,
    referenceThumbnailPath: json['referenceThumbnailPath'] as String?,
    referenceFullImagePath: json['referenceFullImagePath'] as String?,
    sourceUrl: json['sourceUrl'] as String?,
    groupId: json['groupId'] as String?,
    groupOrderIndex: (json['groupOrderIndex'] as num?)?.toInt(),
  );
}

PilgrimageVisitRecord _visitRecordFromV2Json(Map<String, Object?> json) {
  return PilgrimageVisitRecord(
    id: _stringValue(json['id'], fallback: 'record-${json.hashCode}'),
    planId: _stringValue(json['planId'], fallback: ''),
    pointId: _stringValue(json['pointId'], fallback: ''),
    workId: _stringValue(json['workId'], fallback: ''),
    photoPath: _stringValue(json['photoPath'], fallback: ''),
    originalPhotoPath: json['originalPhotoPath'] as String?,
    gradedPhotoPath: json['gradedPhotoPath'] as String?,
    colorGradingMode: json['colorGradingMode'] as String?,
    colorGradingParamsJson: json['colorGradingParamsJson'] as String?,
    colorGradingIntensity: (json['colorGradingIntensity'] as num?)?.toDouble(),
    referenceImagePath: json['referenceImagePath'] as String?,
    referenceImageUrl: json['referenceImageUrl'] as String?,
    referenceMode: _stringValue(json['referenceMode'], fallback: '未知'),
    capturedAt: _dateValue(json['capturedAt']),
  );
}

Map<String, int> _intMap(Object? source) {
  if (source is! Map) {
    return const {};
  }
  return {
    for (final entry in source.entries)
      if (entry.key is String && entry.value is num)
        entry.key as String: (entry.value as num).toInt(),
  };
}

Map<String, Object?> _mapValue(Object? source) {
  if (source is Map<String, Object?>) {
    return source;
  }
  if (source is Map) {
    return source.map((key, value) => MapEntry(key.toString(), value));
  }
  throw const FormatException('Invalid object payload.');
}

List<T> _readList<T>(
  Object? source,
  T Function(Map<String, Object?> json) decode,
) {
  if (source is! List) {
    return const [];
  }
  return source.map(_mapValue).map(decode).toList();
}

T? _enumValue<T extends Enum>(List<T> values, Object? source) {
  if (source is! String) {
    return null;
  }
  for (final value in values) {
    if (value.name == source) {
      return value;
    }
  }
  return null;
}

String _stringValue(Object? value, {required String fallback}) {
  return value is String && value.isNotEmpty ? value : fallback;
}

double _doubleValue(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  return 0;
}

DateTime _dateValue(Object? value) {
  return _nullableDateValue(value) ?? DateTime.now();
}

DateTime? _nullableDateValue(Object? value) {
  if (value is String) {
    return DateTime.tryParse(value);
  }
  return null;
}
