import 'package:latlong2/latlong.dart';

import '../plan/pilgrimage_models.dart';
import 'pilgrimage_repository.dart';

class SamplePilgrimageRepository implements PilgrimageRepository {
  const SamplePilgrimageRepository();

  @override
  Future<PilgrimagePlan> loadActivePlan() async {
    return samplePilgrimagePlan;
  }
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
