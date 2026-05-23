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
    required this.name,
    required this.subtitle,
    required this.position,
    required this.episodeLabel,
    required this.referenceLabel,
  });

  final String id;
  final String name;
  final String subtitle;
  final LatLng position;
  final String episodeLabel;
  final String referenceLabel;
}

class PilgrimagePlan {
  const PilgrimagePlan({
    required this.work,
    required this.name,
    required this.points,
  });

  final PilgrimageWork work;
  final String name;
  final List<PilgrimagePoint> points;
}
