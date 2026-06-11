import 'dart:convert';

import 'package:latlong2/latlong.dart';

import '../plan/pilgrimage_models.dart';

const seichiPlanFileExtension = 'sjhplan';
const seichiPlanMimeType = 'application/vnd.miriago.plan+json';
const _miriaGoPlanFormat = 'miriago-plan';
const _legacyPlanFormat = 'seichi-junrei-helper-plan';

class PlanPackage {
  const PlanPackage({required this.plan, required this.visitRecords});

  final PilgrimagePlan plan;
  final List<PilgrimageVisitRecord> visitRecords;

  String toJsonString() {
    return const JsonEncoder.withIndent('  ').convert({
      'format': _miriaGoPlanFormat,
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'plan': _planToJson(plan),
      'visitRecords': visitRecords.map(_visitRecordToJson).toList(),
    });
  }

  static PlanPackage fromJsonString(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('Invalid plan package root.');
    }
    if (decoded['format'] != _miriaGoPlanFormat &&
        decoded['format'] != _legacyPlanFormat) {
      throw const FormatException('Unsupported plan package format.');
    }
    if (decoded['version'] != 1) {
      throw const FormatException('Unsupported plan package version.');
    }

    final planJson = decoded['plan'];
    if (planJson is! Map<String, Object?>) {
      throw const FormatException('Missing plan payload.');
    }

    final recordsJson = decoded['visitRecords'];
    final records = recordsJson is List
        ? recordsJson
              .whereType<Map<String, Object?>>()
              .map(_visitRecordFromJson)
              .toList(growable: false)
        : <PilgrimageVisitRecord>[];

    return PlanPackage(plan: _planFromJson(planJson), visitRecords: records);
  }
}

Map<String, Object?> _planToJson(PilgrimagePlan plan) {
  return {
    'id': plan.id,
    'name': plan.name,
    'area': plan.area,
    'createdAt': plan.createdAt.toIso8601String(),
    'updatedAt': plan.updatedAt.toIso8601String(),
    'currentPointId': plan.currentPointId,
    'completedPointIds': plan.completedPointIds.toList()..sort(),
    'works': plan.works.map(_workToJson).toList(),
    'points': plan.points.map(_pointToJson).toList(),
  };
}

PilgrimagePlan _planFromJson(Map<String, Object?> json) {
  final works = _readList(json['works'], _workFromJson);
  final workById = {for (final work in works) work.id: work};
  final points = _readList(
    json['points'],
    (pointJson) => _pointFromJson(pointJson, workById),
  );
  final completedPointIds =
      (json['completedPointIds'] as List?)?.whereType<String>().toSet() ??
      <String>{};

  return PilgrimagePlan(
    id: _stringValue(json['id'], fallback: 'imported-plan'),
    name: _stringValue(json['name'], fallback: '导入的巡礼计划'),
    area: _stringValue(json['area'], fallback: '未设置区域'),
    works: works,
    points: points,
    createdAt: _dateValue(json['createdAt']),
    updatedAt: _dateValue(json['updatedAt']),
    currentPointId: json['currentPointId'] as String?,
    completedPointIds: completedPointIds,
  );
}

Map<String, Object?> _workToJson(PilgrimageWork work) {
  return {
    'id': work.id,
    'bangumiId': work.bangumiId,
    'title': work.title,
    'subtitle': work.subtitle,
    'city': work.city,
    'source': work.source.name,
  };
}

PilgrimageWork _workFromJson(Map<String, Object?> json) {
  return PilgrimageWork(
    id: _stringValue(json['id'], fallback: 'work-${json.hashCode}'),
    bangumiId: json['bangumiId'] is int ? json['bangumiId'] as int : null,
    title: _stringValue(json['title'], fallback: '未知作品'),
    subtitle: _stringValue(json['subtitle'], fallback: ''),
    city: _stringValue(json['city'], fallback: '未设置地区'),
    source: WorkSource.values.firstWhere(
      (source) => source.name == json['source'],
      orElse: () => WorkSource.manual,
    ),
  );
}

Map<String, Object?> _pointToJson(PilgrimagePoint point) {
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
    'referenceImageUrl': point.referenceImageUrl,
    'referenceThumbnailPath': point.referenceThumbnailPath,
    'referenceFullImagePath': point.referenceFullImagePath,
    'sourceUrl': point.sourceUrl,
  };
}

PilgrimagePoint _pointFromJson(
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
    source: PointSource.values.firstWhere(
      (source) => source.name == json['source'],
      orElse: () => PointSource.manual,
    ),
    sourceId: json['sourceId'] as String?,
    referenceImageUrl: json['referenceImageUrl'] as String?,
    referenceThumbnailPath: json['referenceThumbnailPath'] as String?,
    referenceFullImagePath: json['referenceFullImagePath'] as String?,
    sourceUrl: json['sourceUrl'] as String?,
  );
}

Map<String, Object?> _visitRecordToJson(PilgrimageVisitRecord record) {
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
    'referenceMode': record.referenceMode,
    'capturedAt': record.capturedAt.toIso8601String(),
  };
}

PilgrimageVisitRecord _visitRecordFromJson(Map<String, Object?> json) {
  return PilgrimageVisitRecord(
    id: _stringValue(json['id'], fallback: 'record-${json.hashCode}'),
    planId: _stringValue(json['planId'], fallback: ''),
    pointId: _stringValue(json['pointId'], fallback: ''),
    workId: _stringValue(json['workId'], fallback: ''),
    workTitle: json['workTitle'] as String?,
    workSubtitle: json['workSubtitle'] as String?,
    pointName: json['pointName'] as String?,
    pointSubtitle: json['pointSubtitle'] as String?,
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

List<T> _readList<T>(
  Object? source,
  T Function(Map<String, Object?> json) decode,
) {
  if (source is! List) {
    return const [];
  }
  return source.whereType<Map<String, Object?>>().map(decode).toList();
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
  if (value is String) {
    return DateTime.tryParse(value) ?? DateTime.now();
  }
  return DateTime.now();
}
