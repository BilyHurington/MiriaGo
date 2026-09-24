import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:miriago/data/sample_pilgrimage_repository.dart';
import 'package:miriago/plan/pilgrimage_models.dart';
import 'package:miriago/plan/pilgrimage_plan_controller.dart';
import 'package:miriago/records/records_screen.dart';

const _work = PilgrimageWork(
  id: 'work',
  title: '测试作品',
  subtitle: '',
  city: '',
  source: WorkSource.manual,
);

PilgrimagePoint _point(String id) => PilgrimagePoint(
  id: id,
  work: _work,
  name: '点位 $id',
  subtitle: '',
  position: const LatLng(35, 135),
  episodeLabel: 'EP 1',
  referenceLabel: '手动',
);

PilgrimagePlan _plan(List<PilgrimagePoint> points, {String? currentPointId}) {
  final now = DateTime.utc(2026);
  return PilgrimagePlan(
    id: 'plan',
    name: '测试计划',
    area: '',
    works: const [_work],
    points: points,
    createdAt: now,
    updatedAt: now,
    currentPointId: currentPointId,
  );
}

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

  test('orphan record does not resolve to the first plan point', () async {
    final first = _point('first');
    final doomed = _point('doomed');
    final plan = _plan([first, doomed]);
    final repository = SamplePilgrimageRepository(plans: [plan]);
    final controller = PilgrimagePlanController(
      plan: plan,
      visitRepository: repository,
    );
    addTearDown(controller.dispose);

    await controller.loadVisitRecords();
    final record = await controller.createVisitRecord(
      point: doomed,
      photoPath: 'photo.jpg',
      referenceMode: 'manual',
    );
    await controller.deletePoint(doomed);

    expect(controller.points.map((point) => point.id), [first.id]);
    expect(record, isNotNull);
    expect(controller.pointById(record!.pointId), isNull);
    expect(controller.pointById(first.id)?.id, first.id);
    expect(controller.recordsForPoint(first.id), isEmpty);
  });

  test('stale current point id does not fall back to the first point', () {
    final controller = PilgrimagePlanController(
      plan: _plan([_point('a'), _point('b')], currentPointId: 'missing'),
    );
    addTearDown(controller.dispose);

    expect(controller.currentPoint, isNull);
  });

  test('replacePlan drops a removed selected point and falls back', () {
    final a = _point('a');
    final b = _point('b');
    final original = _plan([a, b]);
    final controller = PilgrimagePlanController(plan: original);
    addTearDown(controller.dispose);

    controller.selectPoint(b);
    expect(controller.selectedPoint?.id, b.id);

    controller.replacePlan(_plan([a]));
    expect(controller.selectedPoint?.id, a.id);

    // The stale selection must have been replaced, not merely masked.
    controller.replacePlan(original);
    expect(controller.selectedPoint?.id, a.id);

    controller.replacePlan(_plan(const []));
    expect(controller.selectedPoint, isNull);
  });

  testWidgets('records screen lists orphan records in the orphan section', (
    tester,
  ) async {
    final first = _point('first');
    final doomed = _point('doomed');
    final plan = _plan([first, doomed]);
    final repository = SamplePilgrimageRepository(plans: [plan]);
    final controller = PilgrimagePlanController(
      plan: plan,
      visitRepository: repository,
    );
    addTearDown(controller.dispose);

    await tester.runAsync(() async {
      await controller.loadVisitRecords();
      await controller.createVisitRecord(
        point: doomed,
        photoPath: 'photo.jpg',
        referenceMode: 'manual',
      );
      await controller.deletePoint(doomed);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: RecordsScreen(
          controller: controller,
          settings: const AppSettings(),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('对应点位已不在当前计划中'), findsOneWidget);
    expect(find.text('还没有放入片区的记录'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
