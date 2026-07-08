import 'package:latlong2/latlong.dart';

const Object _unset = Object();

enum VisitStatus { pending, current, completed }

enum WorkSource { bangumi, manual }

enum PointSource { manual, anitabi }

enum PlanGroupOrderMode { unordered, manual }

enum BangumiSubjectType {
  book(1, '书籍'),
  anime(2, '动画'),
  music(3, '音乐'),
  game(4, '游戏'),
  real(6, '三次元');

  const BangumiSubjectType(this.code, this.label);

  final int code;
  final String label;

  static BangumiSubjectType? fromCode(int? code) {
    for (final type in BangumiSubjectType.values) {
      if (type.code == code) {
        return type;
      }
    }
    return null;
  }
}

enum CameraPhotoAspectRatio {
  auto,
  native,
  landscape16x9,
  cinema21x9,
  standard4x3,
  photo3x2,
  portrait9x16,
  portrait9x21,
  portrait3x4,
  portrait2x3,
  square1x1,
  custom,
}

class CustomThemeColor {
  const CustomThemeColor({required this.name, required this.value});

  final String name;
  final int value;

  Map<String, Object?> toJson() => {'name': name, 'value': value};

  static CustomThemeColor? fromJson(Object? value) {
    if (value is! Map) {
      return null;
    }
    final name = value['name'];
    final colorValue = value['value'];
    if (name is! String || colorValue is! num) {
      return null;
    }
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      return null;
    }
    return CustomThemeColor(name: trimmedName, value: colorValue.toInt());
  }
}

enum AppThemePalette {
  classicGreen,
  deepBlue,
  cherryPink,
  twilightPurple,
  miriaYellow,
  graphite,
  aurora;

  String get label {
    return switch (this) {
      AppThemePalette.classicGreen => '\u7ecf\u5178\u7eff',
      AppThemePalette.deepBlue => '\u6df1\u9083\u84dd',
      AppThemePalette.cherryPink => '\u6a31\u82b1\u7c89',
      AppThemePalette.twilightPurple => '\u66ae\u5149\u7d2b',
      AppThemePalette.miriaYellow => '\u7435\u73c0\u6a59',
      AppThemePalette.graphite => '\u77f3\u58a8\u9ed1',
      AppThemePalette.aurora => '\u81ea\u5b9a\u4e49',
    };
  }
}

enum AppThemeMode { light, dark, system }

extension CameraPhotoAspectRatioLabel on CameraPhotoAspectRatio {
  String get label {
    return switch (this) {
      CameraPhotoAspectRatio.auto => '自动',
      CameraPhotoAspectRatio.native => '原生比例',
      CameraPhotoAspectRatio.landscape16x9 => '16:9',
      CameraPhotoAspectRatio.cinema21x9 => '21:9',
      CameraPhotoAspectRatio.standard4x3 => '4:3',
      CameraPhotoAspectRatio.photo3x2 => '3:2',
      CameraPhotoAspectRatio.portrait9x16 => '9:16',
      CameraPhotoAspectRatio.portrait9x21 => '9:21',
      CameraPhotoAspectRatio.portrait3x4 => '3:4',
      CameraPhotoAspectRatio.portrait2x3 => '2:3',
      CameraPhotoAspectRatio.square1x1 => '1:1',
      CameraPhotoAspectRatio.custom => '\u81ea\u5b9a\u4e49',
    };
  }
}

enum MapTileProvider {
  openFreeMap,
  openStreetMap,
  customXyz,
  customMapLibreStyle,
}

enum OpenFreeMapStyle { liberty, bright, positron, dark, fiord }

enum AnitabiImageSource { auto, official, mirror }

enum NavigationApp {
  googleMaps,
  amap,
  appleMaps,
  baiduMaps;

  String get label {
    return switch (this) {
      NavigationApp.googleMaps => 'Google Maps',
      NavigationApp.amap => '\u9ad8\u5fb7\u5730\u56fe',
      NavigationApp.appleMaps => 'Apple Maps',
      NavigationApp.baiduMaps => '\u767e\u5ea6\u5730\u56fe',
    };
  }
}

class AppSettings {
  const AppSettings({
    this.uiScale = 1,
    this.fontScale = 1,
    this.themeMode = AppThemeMode.light,
    this.cameraCaptureAspectRatio = CameraPhotoAspectRatio.auto,
    this.cameraFallbackAspectRatio = CameraPhotoAspectRatio.native,
    this.cameraMinZoom = 0.6,
    this.cameraMaxZoom = 5,
    this.referenceImageScale = 1,
    this.nearestAssignDistanceMeters = 350,
    this.themePalette = AppThemePalette.classicGreen,
    this.mapTileProvider = MapTileProvider.openFreeMap,
    this.openFreeMapStyle = OpenFreeMapStyle.liberty,
    this.anitabiImageSource = AnitabiImageSource.auto,
    this.navigationApp = NavigationApp.googleMaps,
    this.customXyzTileUrl = '',
    this.customMapLibreStyleUrl = '',
    this.saveVisitPhotoToGallery = true,
    this.autoSaveComparisonToGallery = false,
    this.comparisonShowPilgrimName = false,
    this.comparisonPilgrimName = '',
    this.customThemeColorName = '\u81ea\u5b9a\u4e49',
    this.customThemeColorValue = 0xFF16C6A8,
    this.customThemeColors = const [],
    this.customCameraAspectRatioWidth = 1,
    this.customCameraAspectRatioHeight = 1,
    this.mapThumbnailVisibleThreshold = 40,
    this.mapThumbnailConcurrentLoads = 10,
  });

  final double uiScale;
  final double fontScale;
  final AppThemeMode themeMode;
  final CameraPhotoAspectRatio cameraCaptureAspectRatio;
  final CameraPhotoAspectRatio cameraFallbackAspectRatio;
  final double cameraMinZoom;
  final double cameraMaxZoom;
  final double referenceImageScale;
  final double nearestAssignDistanceMeters;
  final AppThemePalette themePalette;
  final MapTileProvider mapTileProvider;
  final OpenFreeMapStyle openFreeMapStyle;
  final AnitabiImageSource anitabiImageSource;
  final NavigationApp navigationApp;
  final String customXyzTileUrl;
  final String customMapLibreStyleUrl;
  final bool saveVisitPhotoToGallery;
  final bool autoSaveComparisonToGallery;
  final bool comparisonShowPilgrimName;
  final String comparisonPilgrimName;
  final String customThemeColorName;
  final int customThemeColorValue;
  final List<CustomThemeColor> customThemeColors;
  final double customCameraAspectRatioWidth;
  final double customCameraAspectRatioHeight;
  final int mapThumbnailVisibleThreshold;
  final int mapThumbnailConcurrentLoads;

  AppSettings copyWith({
    double? uiScale,
    double? fontScale,
    AppThemeMode? themeMode,
    CameraPhotoAspectRatio? cameraCaptureAspectRatio,
    CameraPhotoAspectRatio? cameraFallbackAspectRatio,
    double? cameraMinZoom,
    double? cameraMaxZoom,
    double? referenceImageScale,
    double? nearestAssignDistanceMeters,
    AppThemePalette? themePalette,
    MapTileProvider? mapTileProvider,
    OpenFreeMapStyle? openFreeMapStyle,
    AnitabiImageSource? anitabiImageSource,
    NavigationApp? navigationApp,
    String? customXyzTileUrl,
    String? customMapLibreStyleUrl,
    bool? saveVisitPhotoToGallery,
    bool? autoSaveComparisonToGallery,
    bool? comparisonShowPilgrimName,
    String? comparisonPilgrimName,
    String? customThemeColorName,
    int? customThemeColorValue,
    List<CustomThemeColor>? customThemeColors,
    double? customCameraAspectRatioWidth,
    double? customCameraAspectRatioHeight,
    int? mapThumbnailVisibleThreshold,
    int? mapThumbnailConcurrentLoads,
  }) {
    return AppSettings(
      uiScale: uiScale ?? this.uiScale,
      fontScale: fontScale ?? this.fontScale,
      themeMode: themeMode ?? this.themeMode,
      cameraCaptureAspectRatio:
          cameraCaptureAspectRatio ?? this.cameraCaptureAspectRatio,
      cameraFallbackAspectRatio:
          cameraFallbackAspectRatio ?? this.cameraFallbackAspectRatio,
      cameraMinZoom: cameraMinZoom ?? this.cameraMinZoom,
      cameraMaxZoom: cameraMaxZoom ?? this.cameraMaxZoom,
      referenceImageScale: referenceImageScale ?? this.referenceImageScale,
      nearestAssignDistanceMeters:
          nearestAssignDistanceMeters ?? this.nearestAssignDistanceMeters,
      themePalette: themePalette ?? this.themePalette,
      mapTileProvider: mapTileProvider ?? this.mapTileProvider,
      openFreeMapStyle: openFreeMapStyle ?? this.openFreeMapStyle,
      anitabiImageSource: anitabiImageSource ?? this.anitabiImageSource,
      navigationApp: navigationApp ?? this.navigationApp,
      customXyzTileUrl: customXyzTileUrl ?? this.customXyzTileUrl,
      customMapLibreStyleUrl:
          customMapLibreStyleUrl ?? this.customMapLibreStyleUrl,
      saveVisitPhotoToGallery:
          saveVisitPhotoToGallery ?? this.saveVisitPhotoToGallery,
      autoSaveComparisonToGallery:
          autoSaveComparisonToGallery ?? this.autoSaveComparisonToGallery,
      comparisonShowPilgrimName:
          comparisonShowPilgrimName ?? this.comparisonShowPilgrimName,
      comparisonPilgrimName:
          comparisonPilgrimName ?? this.comparisonPilgrimName,
      customThemeColorName: customThemeColorName ?? this.customThemeColorName,
      customThemeColorValue:
          customThemeColorValue ?? this.customThemeColorValue,
      customThemeColors: customThemeColors ?? this.customThemeColors,
      customCameraAspectRatioWidth:
          customCameraAspectRatioWidth ?? this.customCameraAspectRatioWidth,
      customCameraAspectRatioHeight:
          customCameraAspectRatioHeight ?? this.customCameraAspectRatioHeight,
      mapThumbnailVisibleThreshold:
          mapThumbnailVisibleThreshold ?? this.mapThumbnailVisibleThreshold,
      mapThumbnailConcurrentLoads:
          mapThumbnailConcurrentLoads ?? this.mapThumbnailConcurrentLoads,
    );
  }
}

class PilgrimageVisitRecord {
  const PilgrimageVisitRecord({
    required this.id,
    required this.planId,
    required this.pointId,
    required this.workId,
    this.workTitle,
    this.workSubtitle,
    this.pointName,
    this.pointSubtitle,
    required this.photoPath,
    this.originalPhotoPath,
    this.gradedPhotoPath,
    this.colorGradingMode,
    this.colorGradingParamsJson,
    this.colorGradingIntensity,
    this.referenceImagePath,
    this.referenceImageUrl,
    required this.referenceMode,
    required this.capturedAt,
  });

  final String id;
  final String planId;
  final String pointId;
  final String workId;
  final String? workTitle;
  final String? workSubtitle;
  final String? pointName;
  final String? pointSubtitle;
  final String photoPath;
  final String? originalPhotoPath;
  final String? gradedPhotoPath;
  final String? colorGradingMode;
  final String? colorGradingParamsJson;
  final double? colorGradingIntensity;
  final String? referenceImagePath;
  final String? referenceImageUrl;
  final String referenceMode;
  final DateTime capturedAt;

  String get sourcePhotoPath => originalPhotoPath ?? photoPath;

  String get displayPhotoPath => gradedPhotoPath ?? photoPath;

  String get displayWorkTitleSnapshot => _displaySnapshot(workTitle, workId);

  String get displayWorkSubtitleSnapshot => _displaySnapshot(workSubtitle, '');

  String get displayPointNameSnapshot => _displaySnapshot(pointName, pointId);

  String get displayPointSubtitleSnapshot =>
      _displaySnapshot(pointSubtitle, '');

  bool get hasColorGrading =>
      gradedPhotoPath != null && colorGradingParamsJson != null;

  PilgrimageVisitRecord copyWith({
    String? photoPath,
    Object? workTitle = _unset,
    Object? workSubtitle = _unset,
    Object? pointName = _unset,
    Object? pointSubtitle = _unset,
    Object? originalPhotoPath = _unset,
    Object? gradedPhotoPath = _unset,
    Object? colorGradingMode = _unset,
    Object? colorGradingParamsJson = _unset,
    Object? colorGradingIntensity = _unset,
    Object? referenceImagePath = _unset,
  }) {
    return PilgrimageVisitRecord(
      id: id,
      planId: planId,
      pointId: pointId,
      workId: workId,
      workTitle: workTitle == _unset ? this.workTitle : workTitle as String?,
      workSubtitle: workSubtitle == _unset
          ? this.workSubtitle
          : workSubtitle as String?,
      pointName: pointName == _unset ? this.pointName : pointName as String?,
      pointSubtitle: pointSubtitle == _unset
          ? this.pointSubtitle
          : pointSubtitle as String?,
      photoPath: photoPath ?? this.photoPath,
      originalPhotoPath: originalPhotoPath == _unset
          ? this.originalPhotoPath
          : originalPhotoPath as String?,
      gradedPhotoPath: gradedPhotoPath == _unset
          ? this.gradedPhotoPath
          : gradedPhotoPath as String?,
      colorGradingMode: colorGradingMode == _unset
          ? this.colorGradingMode
          : colorGradingMode as String?,
      colorGradingParamsJson: colorGradingParamsJson == _unset
          ? this.colorGradingParamsJson
          : colorGradingParamsJson as String?,
      colorGradingIntensity: colorGradingIntensity == _unset
          ? this.colorGradingIntensity
          : colorGradingIntensity as double?,
      referenceImagePath: referenceImagePath == _unset
          ? this.referenceImagePath
          : referenceImagePath as String?,
      referenceImageUrl: referenceImageUrl,
      referenceMode: referenceMode,
      capturedAt: capturedAt,
    );
  }
}

String _displaySnapshot(String? value, String fallback) {
  final text = value?.trim();
  return text == null || text.isEmpty ? fallback : text;
}

class PilgrimageWork {
  const PilgrimageWork({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.city,
    required this.source,
    this.bangumiId,
    this.bangumiSubjectType,
  });

  final String id;
  final int? bangumiId;
  final BangumiSubjectType? bangumiSubjectType;
  final String title;
  final String subtitle;
  final String city;
  final WorkSource source;

  BangumiSubjectType? get displayBangumiSubjectType {
    if (bangumiSubjectType != null) {
      return bangumiSubjectType;
    }

    final cityType = city.split('/').first.trim();
    for (final type in BangumiSubjectType.values) {
      if (type.label == cityType) {
        return type;
      }
    }
    return null;
  }
}

class PilgrimagePoint {
  const PilgrimagePoint({
    required this.id,
    required this.work,
    required this.name,
    required this.subtitle,
    required this.position,
    required this.episodeLabel,
    required this.referenceLabel,
    this.source = PointSource.manual,
    this.sourceId,
    this.referenceImageUrl,
    this.referenceThumbnailPath,
    this.referenceFullImagePath,
    this.sourceUrl,
    this.note,
    this.groupId,
    this.groupOrderIndex,
  });

  final String id;
  final PilgrimageWork work;
  final String name;
  final String subtitle;
  final LatLng position;
  final String episodeLabel;
  final String referenceLabel;
  final PointSource source;
  final String? sourceId;
  final String? referenceImageUrl;
  final String? referenceThumbnailPath;
  final String? referenceFullImagePath;
  final String? sourceUrl;
  final String? note;
  final String? groupId;
  final int? groupOrderIndex;

  String get displayEpisodeLabel => formatEpisodeLabelForDisplay(episodeLabel);

  PilgrimagePoint copyWith({
    String? id,
    PilgrimageWork? work,
    String? name,
    String? subtitle,
    LatLng? position,
    String? episodeLabel,
    String? referenceLabel,
    PointSource? source,
    Object? sourceId = _unset,
    Object? referenceImageUrl = _unset,
    Object? referenceThumbnailPath = _unset,
    Object? referenceFullImagePath = _unset,
    Object? sourceUrl = _unset,
    Object? note = _unset,
    Object? groupId = _unset,
    Object? groupOrderIndex = _unset,
  }) {
    return PilgrimagePoint(
      id: id ?? this.id,
      work: work ?? this.work,
      name: name ?? this.name,
      subtitle: subtitle ?? this.subtitle,
      position: position ?? this.position,
      episodeLabel: episodeLabel ?? this.episodeLabel,
      referenceLabel: referenceLabel ?? this.referenceLabel,
      source: source ?? this.source,
      sourceId: sourceId == _unset ? this.sourceId : sourceId as String?,
      referenceImageUrl: referenceImageUrl == _unset
          ? this.referenceImageUrl
          : referenceImageUrl as String?,
      referenceThumbnailPath: referenceThumbnailPath == _unset
          ? this.referenceThumbnailPath
          : referenceThumbnailPath as String?,
      referenceFullImagePath: referenceFullImagePath == _unset
          ? this.referenceFullImagePath
          : referenceFullImagePath as String?,
      sourceUrl: sourceUrl == _unset ? this.sourceUrl : sourceUrl as String?,
      note: note == _unset ? this.note : note as String?,
      groupId: groupId == _unset ? this.groupId : groupId as String?,
      groupOrderIndex: groupOrderIndex == _unset
          ? this.groupOrderIndex
          : groupOrderIndex as int?,
    );
  }
}

class PilgrimagePlanGroup {
  const PilgrimagePlanGroup({
    required this.id,
    required this.name,
    required this.orderIndex,
    this.orderMode = PlanGroupOrderMode.unordered,
    this.anchorName,
    this.anchorLatitude,
    this.anchorLongitude,
    this.anchorPointId,
    this.note,
    required this.createdAt,
  });

  final String id;
  final String name;
  final int orderIndex;
  final PlanGroupOrderMode orderMode;
  final String? anchorName;
  final double? anchorLatitude;
  final double? anchorLongitude;
  final String? anchorPointId;
  final String? note;
  final DateTime createdAt;
}

String formatEpisodeLabelForDisplay(String label) {
  return label.replaceAllMapped(RegExp(r'\b(\d+)s\b'), (match) {
    final seconds = int.tryParse(match.group(1)!);
    return formatSceneSeconds(seconds) ?? match.group(0)!;
  });
}

String? formatSceneSeconds(Object? second) {
  final seconds = switch (second) {
    int value => value,
    num value => value.round(),
    String value => int.tryParse(value),
    _ => null,
  };
  if (seconds == null || seconds < 0) {
    return null;
  }

  String twoDigits(int value) => value.toString().padLeft(2, '0');
  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  final remainingSeconds = seconds % 60;
  if (hours > 0) {
    return '$hours:${twoDigits(minutes)}:${twoDigits(remainingSeconds)}';
  }
  return '$minutes:${twoDigits(remainingSeconds)}';
}

class PilgrimagePlan {
  const PilgrimagePlan({
    required this.id,
    required this.name,
    required this.area,
    this.memo = '',
    required this.works,
    this.groups = const [],
    required this.points,
    required this.createdAt,
    required this.updatedAt,
    this.currentPointId,
    this.currentGroupId,
    this.completedPointIds = const <String>{},
  });

  final String id;
  final String name;
  final String area;
  final String memo;
  final List<PilgrimageWork> works;
  final List<PilgrimagePlanGroup> groups;
  final List<PilgrimagePoint> points;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? currentPointId;
  final String? currentGroupId;
  final Set<String> completedPointIds;

  PilgrimagePlan copyWith({
    String? id,
    String? name,
    String? area,
    String? memo,
    List<PilgrimageWork>? works,
    List<PilgrimagePlanGroup>? groups,
    List<PilgrimagePoint>? points,
    DateTime? createdAt,
    DateTime? updatedAt,
    Object? currentPointId = _unset,
    Object? currentGroupId = _unset,
    Set<String>? completedPointIds,
  }) {
    return PilgrimagePlan(
      id: id ?? this.id,
      name: name ?? this.name,
      area: area ?? this.area,
      memo: memo ?? this.memo,
      works: works ?? this.works,
      groups: groups ?? this.groups,
      points: points ?? this.points,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      currentPointId: currentPointId == _unset
          ? this.currentPointId
          : currentPointId as String?,
      currentGroupId: currentGroupId == _unset
          ? this.currentGroupId
          : currentGroupId as String?,
      completedPointIds: completedPointIds ?? this.completedPointIds,
    );
  }
}
