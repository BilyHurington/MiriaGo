import 'package:latlong2/latlong.dart';

enum VisitStatus { pending, current, completed }

class PilgrimageWork {
  const PilgrimageWork({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.city,
  });

  final String id;
  final String title;
  final String subtitle;
  final String city;
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
    required this.points,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String area;
  final List<PilgrimagePoint> points;
  final DateTime createdAt;
  final DateTime updatedAt;

  PilgrimagePlan copyWith({
    String? id,
    String? name,
    String? area,
    List<PilgrimagePoint>? points,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PilgrimagePlan(
      id: id ?? this.id,
      name: name ?? this.name,
      area: area ?? this.area,
      points: points ?? this.points,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
