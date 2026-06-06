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
}

enum AppThemePalette {
  miriaYellow,
  classicGreen;

  String get label {
    return switch (this) {
      AppThemePalette.miriaYellow => '鲜黄色',
      AppThemePalette.classicGreen => '经典绿色',
    };
  }
}

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
    };
  }
}

class AppSettings {
  const AppSettings({
    this.uiScale = 1,
    this.cameraCaptureAspectRatio = CameraPhotoAspectRatio.auto,
    this.cameraFallbackAspectRatio = CameraPhotoAspectRatio.native,
    this.cameraMinZoom = 0.6,
    this.cameraMaxZoom = 5,
    this.referenceImageScale = 1,
    this.nearestAssignDistanceMeters = 350,
    this.themePalette = AppThemePalette.classicGreen,
  });

  final double uiScale;
  final CameraPhotoAspectRatio cameraCaptureAspectRatio;
  final CameraPhotoAspectRatio cameraFallbackAspectRatio;
  final double cameraMinZoom;
  final double cameraMaxZoom;
  final double referenceImageScale;
  final double nearestAssignDistanceMeters;
  final AppThemePalette themePalette;

  AppSettings copyWith({
    double? uiScale,
    CameraPhotoAspectRatio? cameraCaptureAspectRatio,
    CameraPhotoAspectRatio? cameraFallbackAspectRatio,
    double? cameraMinZoom,
    double? cameraMaxZoom,
    double? referenceImageScale,
    double? nearestAssignDistanceMeters,
    AppThemePalette? themePalette,
  }) {
    return AppSettings(
      uiScale: uiScale ?? this.uiScale,
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
    );
  }
}

class PilgrimageVisitRecord {
  const PilgrimageVisitRecord({
    required this.id,
    required this.planId,
    required this.pointId,
    required this.workId,
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

  bool get hasColorGrading =>
      gradedPhotoPath != null && colorGradingParamsJson != null;

  PilgrimageVisitRecord copyWith({
    String? photoPath,
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
  final String? groupId;
  final int? groupOrderIndex;

  String get displayEpisodeLabel => formatEpisodeLabelForDisplay(episodeLabel);

  PilgrimagePoint copyWith({
    Object? referenceThumbnailPath = _unset,
    Object? referenceFullImagePath = _unset,
    Object? groupId = _unset,
    Object? groupOrderIndex = _unset,
  }) {
    return PilgrimagePoint(
      id: id,
      work: work,
      name: name,
      subtitle: subtitle,
      position: position,
      episodeLabel: episodeLabel,
      referenceLabel: referenceLabel,
      source: source,
      sourceId: sourceId,
      referenceImageUrl: referenceImageUrl,
      referenceThumbnailPath: referenceThumbnailPath == _unset
          ? this.referenceThumbnailPath
          : referenceThumbnailPath as String?,
      referenceFullImagePath: referenceFullImagePath == _unset
          ? this.referenceFullImagePath
          : referenceFullImagePath as String?,
      sourceUrl: sourceUrl,
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
