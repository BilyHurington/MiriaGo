import 'dart:convert';

import 'package:latlong2/latlong.dart';

import '../data/sample_pilgrimage_repository.dart';
import '../plan/pilgrimage_models.dart';

const desktopRepositoryStateSchemaVersion = 1;

String encodeDesktopRepositoryState(
  SamplePilgrimageRepositorySnapshot snapshot,
) {
  return jsonEncode({
    'schemaVersion': desktopRepositoryStateSchemaVersion,
    'activePlanId': snapshot.activePlanId,
    'settings': _settingsJson(snapshot.settings),
    'plans': snapshot.plans.map(_planJson).toList(),
    'visitRecords': snapshot.visitRecords.map(_visitRecordJson).toList(),
  });
}

String encodeDesktopPlan(PilgrimagePlan plan) {
  return jsonEncode(_planJson(plan));
}

String encodeDesktopVisitRecord(PilgrimageVisitRecord record) {
  return jsonEncode(_visitRecordJson(record));
}

String encodeDesktopVisitRecords(List<PilgrimageVisitRecord> records) {
  return jsonEncode(records.map(_visitRecordJson).toList());
}

String encodeDesktopAppSettings(AppSettings settings) {
  return jsonEncode(_settingsJson(settings));
}

SamplePilgrimageRepositorySnapshot? decodeDesktopRepositoryState(
  String? source,
) {
  if (source == null || source.trim().isEmpty) {
    return null;
  }
  final root = jsonDecode(source);
  if (root is! Map<String, Object?>) {
    throw const FormatException('Desktop state root must be an object.');
  }
  final plans = _listMaps(root['plans']).map(_planFromJson).toList();
  if (plans.isEmpty) {
    return null;
  }
  final activePlanId = root['activePlanId'] as String?;
  return SamplePilgrimageRepositorySnapshot(
    plans: plans,
    visitRecords: _listMaps(
      root['visitRecords'],
    ).map(_visitRecordFromJson).toList(),
    settings: _settingsFromJson(_mapValue(root['settings'])),
    activePlanId: plans.any((plan) => plan.id == activePlanId)
        ? activePlanId!
        : plans.first.id,
  );
}

Map<String, Object?> _settingsJson(AppSettings settings) {
  return {
    'uiScale': settings.uiScale,
    'fontScale': settings.fontScale,
    'themeMode': settings.themeMode.name,
    'cameraCaptureAspectRatio': settings.cameraCaptureAspectRatio.name,
    'cameraFallbackAspectRatio': settings.cameraFallbackAspectRatio.name,
    'cameraMinZoom': settings.cameraMinZoom,
    'cameraMaxZoom': settings.cameraMaxZoom,
    'referenceImageScale': settings.referenceImageScale,
    'nearestAssignDistanceMeters': settings.nearestAssignDistanceMeters,
    'themePalette': settings.themePalette.name,
    'mapTileProvider': settings.mapTileProvider.name,
    'navigationApp': settings.navigationApp.name,
    'customXyzTileUrl': settings.customXyzTileUrl,
    'customMapLibreStyleUrl': settings.customMapLibreStyleUrl,
    'saveVisitPhotoToGallery': settings.saveVisitPhotoToGallery,
    'comparisonShowPilgrimName': settings.comparisonShowPilgrimName,
    'comparisonPilgrimName': settings.comparisonPilgrimName,
    'customThemeColorName': settings.customThemeColorName,
    'customThemeColorValue': settings.customThemeColorValue,
    'customThemeColors': settings.customThemeColors
        .map((color) => color.toJson())
        .toList(growable: false),
    'customCameraAspectRatioWidth': settings.customCameraAspectRatioWidth,
    'customCameraAspectRatioHeight': settings.customCameraAspectRatioHeight,
  };
}

AppSettings _settingsFromJson(Map<String, Object?> json) {
  return AppSettings(
    uiScale: _doubleValue(json['uiScale']) ?? 1,
    fontScale: _doubleValue(json['fontScale']) ?? 1,
    themeMode:
        _enumByName(AppThemeMode.values, json['themeMode']) ??
        AppThemeMode.light,
    cameraCaptureAspectRatio:
        _enumByName(
          CameraPhotoAspectRatio.values,
          json['cameraCaptureAspectRatio'],
        ) ??
        CameraPhotoAspectRatio.auto,
    cameraFallbackAspectRatio:
        _enumByName(
          CameraPhotoAspectRatio.values,
          json['cameraFallbackAspectRatio'],
        ) ??
        CameraPhotoAspectRatio.native,
    cameraMinZoom: _doubleValue(json['cameraMinZoom']) ?? 0.6,
    cameraMaxZoom: _doubleValue(json['cameraMaxZoom']) ?? 5,
    referenceImageScale: _doubleValue(json['referenceImageScale']) ?? 1,
    nearestAssignDistanceMeters:
        _doubleValue(json['nearestAssignDistanceMeters']) ?? 350,
    themePalette:
        _enumByName(AppThemePalette.values, json['themePalette']) ??
        AppThemePalette.classicGreen,
    mapTileProvider:
        _enumByName(MapTileProvider.values, json['mapTileProvider']) ??
        MapTileProvider.openFreeMap,
    navigationApp:
        _enumByName(NavigationApp.values, json['navigationApp']) ??
        NavigationApp.googleMaps,
    customXyzTileUrl: _stringValue(json['customXyzTileUrl'], fallback: ''),
    customMapLibreStyleUrl: _stringValue(
      json['customMapLibreStyleUrl'],
      fallback: '',
    ),
    saveVisitPhotoToGallery:
        _boolValue(json['saveVisitPhotoToGallery']) ?? true,
    comparisonShowPilgrimName:
        _boolValue(json['comparisonShowPilgrimName']) ?? false,
    comparisonPilgrimName: _stringValue(
      json['comparisonPilgrimName'],
      fallback: '',
    ),
    customThemeColorName: _stringValue(
      json['customThemeColorName'],
      fallback: '\u81ea\u5b9a\u4e49',
    ),
    customThemeColorValue:
        _intValue(json['customThemeColorValue']) ?? 0xFF16C6A8,
    customThemeColors: _customThemeColorsValue(json['customThemeColors']),
    customCameraAspectRatioWidth:
        _doubleValue(json['customCameraAspectRatioWidth']) ?? 1,
    customCameraAspectRatioHeight:
        _doubleValue(json['customCameraAspectRatioHeight']) ?? 1,
  );
}

Map<String, Object?> _planJson(PilgrimagePlan plan) {
  return {
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
    'points': plan.points.map(_pointJson).toList(),
  };
}

PilgrimagePlan _planFromJson(Map<String, Object?> json) {
  final works = _listMaps(json['works']).map(_workFromJson).toList();
  final workById = {for (final work in works) work.id: work};
  return PilgrimagePlan(
    id: _stringValue(json['id'], fallback: 'desktop-plan'),
    name: _stringValue(json['name'], fallback: '桌面端计划'),
    area: _stringValue(json['area'], fallback: ''),
    works: works,
    groups: _listMaps(json['groups']).map(_groupFromJson).toList(),
    points: _listMaps(
      json['points'],
    ).map((point) => _pointFromJson(point, workById)).toList(),
    createdAt: _dateValue(json['createdAt']) ?? DateTime.now(),
    updatedAt: _dateValue(json['updatedAt']) ?? DateTime.now(),
    currentPointId: json['currentPointId'] as String?,
    currentGroupId: json['currentGroupId'] as String?,
    completedPointIds: _stringSet(json['completedPointIds']),
  );
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

PilgrimageWork _workFromJson(Map<String, Object?> json) {
  return PilgrimageWork(
    id: _stringValue(json['id'], fallback: 'desktop-work'),
    bangumiId: (json['bangumiId'] as num?)?.toInt(),
    bangumiSubjectType: _enumByName(
      BangumiSubjectType.values,
      json['bangumiSubjectType'],
    ),
    title: _stringValue(json['title'], fallback: '作品'),
    subtitle: _stringValue(json['subtitle'], fallback: ''),
    city: _stringValue(json['city'], fallback: ''),
    source: _enumByName(WorkSource.values, json['source']) ?? WorkSource.manual,
  );
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

PilgrimagePlanGroup _groupFromJson(Map<String, Object?> json) {
  return PilgrimagePlanGroup(
    id: _stringValue(json['id'], fallback: 'desktop-group'),
    name: _stringValue(json['name'], fallback: '分组'),
    orderIndex: (json['orderIndex'] as num?)?.toInt() ?? 0,
    orderMode:
        _enumByName(PlanGroupOrderMode.values, json['orderMode']) ??
        PlanGroupOrderMode.unordered,
    anchorName: json['anchorName'] as String?,
    anchorLatitude: _doubleValue(json['anchorLatitude']),
    anchorLongitude: _doubleValue(json['anchorLongitude']),
    anchorPointId: json['anchorPointId'] as String?,
    note: json['note'] as String?,
    createdAt: _dateValue(json['createdAt']) ?? DateTime.now(),
  );
}

Map<String, Object?> _pointJson(PilgrimagePoint point) {
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
    'note': point.note,
    'groupId': point.groupId,
    'groupOrderIndex': point.groupOrderIndex,
  };
}

PilgrimagePoint _pointFromJson(
  Map<String, Object?> json,
  Map<String, PilgrimageWork> workById,
) {
  final workId = json['workId'] as String?;
  final fallbackWork =
      workById.values.firstOrNull ??
      const PilgrimageWork(
        id: 'desktop-work',
        title: '作品',
        subtitle: '',
        city: '',
        source: WorkSource.manual,
      );
  return PilgrimagePoint(
    id: _stringValue(json['id'], fallback: 'desktop-point'),
    work: workById[workId] ?? fallbackWork,
    name: _stringValue(json['name'], fallback: '点位'),
    subtitle: _stringValue(json['subtitle'], fallback: ''),
    position: LatLng(
      _doubleValue(json['latitude']) ?? 0,
      _doubleValue(json['longitude']) ?? 0,
    ),
    episodeLabel: _stringValue(json['episodeLabel'], fallback: ''),
    referenceLabel: _stringValue(json['referenceLabel'], fallback: ''),
    source:
        _enumByName(PointSource.values, json['source']) ?? PointSource.manual,
    sourceId: json['sourceId'] as String?,
    referenceImageUrl: json['referenceImageUrl'] as String?,
    referenceThumbnailPath: json['referenceThumbnailPath'] as String?,
    referenceFullImagePath: json['referenceFullImagePath'] as String?,
    sourceUrl: json['sourceUrl'] as String?,
    note: json['note'] as String?,
    groupId: json['groupId'] as String?,
    groupOrderIndex: (json['groupOrderIndex'] as num?)?.toInt(),
  );
}

Map<String, Object?> _visitRecordJson(PilgrimageVisitRecord record) {
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
    id: _stringValue(json['id'], fallback: 'desktop-record'),
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
    colorGradingIntensity: _doubleValue(json['colorGradingIntensity']),
    referenceImagePath: json['referenceImagePath'] as String?,
    referenceImageUrl: json['referenceImageUrl'] as String?,
    referenceMode: _stringValue(json['referenceMode'], fallback: 'none'),
    capturedAt: _dateValue(json['capturedAt']) ?? DateTime.now(),
  );
}

T? _enumByName<T extends Enum>(List<T> values, Object? name) {
  if (name is! String) {
    return null;
  }
  for (final value in values) {
    if (value.name == name) {
      return value;
    }
  }
  return null;
}

Map<String, Object?> _mapValue(Object? value) {
  if (value is Map) {
    return value.map((key, value) => MapEntry(key.toString(), value));
  }
  return const {};
}

List<Map<String, Object?>> _listMaps(Object? value) {
  if (value is! List) {
    return const [];
  }
  return value.map(_mapValue).toList(growable: false);
}

Set<String> _stringSet(Object? value) {
  if (value is! List) {
    return const {};
  }
  return value.whereType<String>().toSet();
}

List<CustomThemeColor> _customThemeColorsValue(Object? value) {
  if (value is! List) {
    return const [];
  }
  return value
      .map(CustomThemeColor.fromJson)
      .whereType<CustomThemeColor>()
      .toList(growable: false);
}

String _stringValue(Object? value, {required String fallback}) {
  return value is String ? value : fallback;
}

double? _doubleValue(Object? value) {
  return switch (value) {
    num number => number.toDouble(),
    String text => double.tryParse(text),
    _ => null,
  };
}

int? _intValue(Object? value) {
  return switch (value) {
    num number => number.toInt(),
    String text => int.tryParse(text),
    _ => null,
  };
}

bool? _boolValue(Object? value) {
  return switch (value) {
    bool boolean => boolean,
    String text when text == 'true' => true,
    String text when text == 'false' => false,
    _ => null,
  };
}

DateTime? _dateValue(Object? value) {
  return value is String ? DateTime.tryParse(value) : null;
}
