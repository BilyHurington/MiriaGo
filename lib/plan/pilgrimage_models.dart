import 'package:latlong2/latlong.dart';

const Object _unset = Object();

enum VisitStatus { pending, current, completed }

enum WorkSource { bangumi, manual }

enum PointSource { manual, anitabi }

enum CameraPhotoAspectRatio {
  auto,
  landscape16x9,
  cinema21x9,
  standard4x3,
  photo3x2,
  square1x1,
}

extension CameraPhotoAspectRatioLabel on CameraPhotoAspectRatio {
  String get label {
    return switch (this) {
      CameraPhotoAspectRatio.auto => '自动',
      CameraPhotoAspectRatio.landscape16x9 => '16:9',
      CameraPhotoAspectRatio.cinema21x9 => '21:9',
      CameraPhotoAspectRatio.standard4x3 => '4:3',
      CameraPhotoAspectRatio.photo3x2 => '3:2',
      CameraPhotoAspectRatio.square1x1 => '1:1',
    };
  }
}

class AppSettings {
  const AppSettings({
    this.uiScale = 1,
    this.cameraAspectRatio = CameraPhotoAspectRatio.auto,
    this.cameraMinZoom = 0.6,
    this.cameraMaxZoom = 5,
  });

  final double uiScale;
  final CameraPhotoAspectRatio cameraAspectRatio;
  final double cameraMinZoom;
  final double cameraMaxZoom;

  AppSettings copyWith({
    double? uiScale,
    CameraPhotoAspectRatio? cameraAspectRatio,
    double? cameraMinZoom,
    double? cameraMaxZoom,
  }) {
    return AppSettings(
      uiScale: uiScale ?? this.uiScale,
      cameraAspectRatio: cameraAspectRatio ?? this.cameraAspectRatio,
      cameraMinZoom: cameraMinZoom ?? this.cameraMinZoom,
      cameraMaxZoom: cameraMaxZoom ?? this.cameraMaxZoom,
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
  final String? referenceImagePath;
  final String? referenceImageUrl;
  final String referenceMode;
  final DateTime capturedAt;
}

class PilgrimageWork {
  const PilgrimageWork({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.city,
    required this.source,
    this.bangumiId,
  });

  final String id;
  final int? bangumiId;
  final String title;
  final String subtitle;
  final String city;
  final WorkSource source;
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

  PilgrimagePoint copyWith({
    String? referenceThumbnailPath,
    String? referenceFullImagePath,
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
      referenceThumbnailPath:
          referenceThumbnailPath ?? this.referenceThumbnailPath,
      referenceFullImagePath:
          referenceFullImagePath ?? this.referenceFullImagePath,
      sourceUrl: sourceUrl,
    );
  }
}

class PilgrimagePlan {
  const PilgrimagePlan({
    required this.id,
    required this.name,
    required this.area,
    required this.works,
    required this.points,
    required this.createdAt,
    required this.updatedAt,
    this.currentPointId,
    this.completedPointIds = const <String>{},
  });

  final String id;
  final String name;
  final String area;
  final List<PilgrimageWork> works;
  final List<PilgrimagePoint> points;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? currentPointId;
  final Set<String> completedPointIds;

  PilgrimagePlan copyWith({
    String? id,
    String? name,
    String? area,
    List<PilgrimageWork>? works,
    List<PilgrimagePoint>? points,
    DateTime? createdAt,
    DateTime? updatedAt,
    Object? currentPointId = _unset,
    Set<String>? completedPointIds,
  }) {
    return PilgrimagePlan(
      id: id ?? this.id,
      name: name ?? this.name,
      area: area ?? this.area,
      works: works ?? this.works,
      points: points ?? this.points,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      currentPointId: currentPointId == _unset
          ? this.currentPointId
          : currentPointId as String?,
      completedPointIds: completedPointIds ?? this.completedPointIds,
    );
  }
}
