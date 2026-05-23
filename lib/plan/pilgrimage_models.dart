import 'package:latlong2/latlong.dart';

enum VisitStatus { pending, current, completed }

enum WorkSource { bangumi, manual }

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
  });

  final String id;
  final PilgrimageWork work;
  final String name;
  final String subtitle;
  final LatLng position;
  final String episodeLabel;
  final String referenceLabel;
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
  });

  final String id;
  final String name;
  final String area;
  final List<PilgrimageWork> works;
  final List<PilgrimagePoint> points;
  final DateTime createdAt;
  final DateTime updatedAt;

  PilgrimagePlan copyWith({
    String? id,
    String? name,
    String? area,
    List<PilgrimageWork>? works,
    List<PilgrimagePoint>? points,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PilgrimagePlan(
      id: id ?? this.id,
      name: name ?? this.name,
      area: area ?? this.area,
      works: works ?? this.works,
      points: points ?? this.points,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
