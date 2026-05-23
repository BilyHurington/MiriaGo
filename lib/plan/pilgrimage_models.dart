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

const samplePilgrimagePlan = PilgrimagePlan(
  work: PilgrimageWork(
    id: 'hibike-euphonium',
    title: '吹响吧！上低音号',
    subtitle: '響け！ユーフォニアム',
    city: '宇治市',
  ),
  name: '宇治示例巡礼',
  points: [
    PilgrimagePoint(
      id: 'uji-bridge',
      name: '宇治桥',
      subtitle: '宇治川沿岸',
      position: LatLng(34.8917, 135.8077),
      episodeLabel: '示例点位 1',
      referenceLabel: '参考图待接入',
    ),
    PilgrimagePoint(
      id: 'agata-dori',
      name: 'あがた通り',
      subtitle: '县神社方向街道',
      position: LatLng(34.8899, 135.8081),
      episodeLabel: '示例点位 2',
      referenceLabel: '参考图待接入',
    ),
    PilgrimagePoint(
      id: 'uji-station',
      name: 'JR 宇治站',
      subtitle: 'JR 奈良线车站',
      position: LatLng(34.8905, 135.8008),
      episodeLabel: '示例点位 3',
      referenceLabel: '参考图待接入',
    ),
  ],
);
