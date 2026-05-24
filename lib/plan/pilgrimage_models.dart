import 'package:latlong2/latlong.dart';

const Object _unset = Object();

enum VisitStatus { pending, current, completed }

enum WorkSource { bangumi, manual }

enum PointSource { manual, anitabi }

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
  final String? sourceUrl;
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
