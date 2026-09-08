import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:miriago/data/sample_pilgrimage_repository.dart';
import 'package:miriago/plan/pilgrimage_models.dart';
import 'package:miriago/plan/pilgrimage_plan_controller.dart';

void main() {
  test('deletePoint clears point state but preserves visit history', () async {
    const work = PilgrimageWork(
      id: 'work',
      title: '测试作品',
      subtitle: '',
      city: '',
      source: WorkSource.manual,
    );
    const point = PilgrimagePoint(
      id: 'point',
      work: work,
      name: '测试点位',
      subtitle: '',
      position: LatLng(35, 135),
      episodeLabel: 'EP 1',
      referenceLabel: '手动',
    );
    final now = DateTime.utc(2026);
    final plan = PilgrimagePlan(
      id: 'plan',
      name: '测试计划',
      area: '',
      works: const [work],
      points: const [point],
      createdAt: now,
      updatedAt: now,
      currentPointId: point.id,
      completedPointIds: {point.id},
    );
    final repository = SamplePilgrimageRepository(plans: [plan]);
    final controller = PilgrimagePlanController(
      plan: plan,
      visitRepository: repository,
    );
    addTearDown(controller.dispose);

    await controller.loadVisitRecords();
    final record = await controller.createVisitRecord(
      point: point,
      photoPath: 'photo.jpg',
      referenceMode: 'manual',
    );
    controller.selectPoint(point);
    expect(controller.recordsForPoint(point.id), hasLength(1));
    expect(controller.selectedPoint?.id, point.id);

    await controller.deletePoint(point);

    expect(controller.pointById(point.id), isNull);
    expect(controller.currentPoint, isNull);
    expect(controller.selectedPoint, isNull);
    expect(controller.completedPointIds, isEmpty);
    expect(controller.recordsForPoint(point.id), [record]);
    expect(controller.visitRecords, [record]);
    expect(await repository.loadVisitRecords(plan.id), [record]);

    await controller.loadVisitRecords();
    expect(controller.recordsForPoint(point.id), [record]);
    expect(controller.visitRecords, [record]);
  });
}
