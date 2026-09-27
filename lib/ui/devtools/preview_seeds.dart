import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import '../../data/pilgrimage_repository.dart';
import '../../data/sample_pilgrimage_repository.dart';
import '../../plan/pilgrimage_models.dart';

/// Dev-only data seeds for the plain web preview (`?seed=…`).
///
/// They only use the public repository API on an in-memory
/// [SamplePilgrimageRepository]; nothing is persisted.
abstract final class PreviewSeeds {
  static const empty = 'empty';
  static const stress = 'stress';
  static const manyPlans = 'many-plans';

  static Future<PilgrimageRepository> build(String? seed) async {
    final repository = SamplePilgrimageRepository();
    switch (seed) {
      case empty:
        final plan = await repository.createPlan(
          name: '新巡礼计划 2',
          area: '未设置区域',
        );
        await repository.setActivePlan(plan.id);
      case manyPlans:
        const areas = ['宇治市', '镰仓市', '秩父市', '沼津市', '京都市', '东京都', '飞騨市'];
        for (var i = 0; i < 19; i++) {
          await repository.createPlan(
            name: '巡礼计划 ${i + 2}',
            area: areas[i % areas.length],
          );
        }
      case stress:
        await _seedStress(repository);
    }
    return repository;
  }

  static Future<void> _seedStress(SamplePilgrimageRepository repository) async {
    final base = await repository.loadActivePlan();
    final plan = await repository.createPlan(name: '压力测试计划', area: '京都府');
    await repository.setActivePlan(plan.id);
    final works = base.works.isEmpty
        ? const <PilgrimageWork>[]
        : [base.works.first];
    for (final work in works) {
      await repository.addWorkToPlan(planId: plan.id, work: work);
    }
    final work = works.isEmpty ? base.points.first.work : works.first;
    final random = math.Random(42);
    const groupCount = 40;
    for (var g = 0; g < groupCount; g++) {
      await repository.createPlanGroup(
        planId: plan.id,
        group: PilgrimagePlanGroup(
          id: 'stress-group-$g',
          name: '片区 ${g + 1}',
          orderIndex: g,
          orderMode: g.isEven
              ? PlanGroupOrderMode.unordered
              : PlanGroupOrderMode.manual,
          anchorName: '关键点 ${g + 1}',
          anchorLatitude: 34.85 + (g ~/ 8) * 0.02,
          anchorLongitude: 135.72 + (g % 8) * 0.02,
          createdAt: DateTime(2026, 6, 1),
        ),
      );
    }
    final references = base.points
        .map((point) => point.referenceImageUrl)
        .whereType<String>()
        .toList();
    final points = <PilgrimagePoint>[];
    for (var i = 0; i < 600; i++) {
      final g = i % (groupCount + 1);
      final grouped = g < groupCount;
      final lat = 34.85 + (g ~/ 8) * 0.02 + (random.nextDouble() - 0.5) * 0.012;
      final lng = 135.72 + (g % 8) * 0.02 + (random.nextDouble() - 0.5) * 0.012;
      points.add(
        PilgrimagePoint(
          id: 'stress-point-$i',
          work: work,
          name: '压力点位 ${i + 1}',
          subtitle: '場所 ${i + 1}',
          position: LatLng(lat, lng),
          episodeLabel: 'EP ${1 + i % 13} / ${i % 24}:${(i * 7) % 60}',
          referenceLabel: 'Anitabi',
          source: PointSource.anitabi,
          sourceId: 'stress$i',
          referenceImageUrl: references.isEmpty
              ? null
              : references[i % references.length],
          groupId: grouped ? 'stress-group-$g' : null,
        ),
      );
    }
    await repository.addPointsToPlan(planId: plan.id, points: points);
    await repository.completePoints(
      planId: plan.id,
      pointIds: {for (var i = 0; i < 600; i += 3) 'stress-point-$i'},
    );
    for (var i = 0; i < 300; i++) {
      final point = points[i * 2];
      await repository.createVisitRecord(
        planId: plan.id,
        pointId: point.id,
        workId: work.id,
        workTitle: work.title,
        workSubtitle: work.subtitle,
        pointName: point.name,
        pointSubtitle: point.subtitle,
        photoPath:
            'docs/sample_images/sample_visit_records/${_samplePhotos[i % _samplePhotos.length]}',
        referenceImageUrl: point.referenceImageUrl,
        referenceMode: i.isEven ? '叠影' : '上下',
        capturedAt: DateTime(2026, 6, 1).add(Duration(minutes: i * 17)),
      );
    }
  }

  static const _samplePhotos = [
    'sample-record-agata-01.jpg',
    'sample-record-byodoin-01.jpg',
    'sample-record-daikichi-view-01.jpg',
    'sample-record-jr-uji-01.jpg',
    'sample-record-kohata-01.jpg',
    'sample-record-obaku-01.jpg',
    'sample-record-rokuchizo-01.jpg',
    'sample-record-uji-bridge-01.jpg',
    'sample-record-uji-walk-01.jpg',
  ];
}
