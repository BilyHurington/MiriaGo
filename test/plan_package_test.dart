import 'package:flutter_test/flutter_test.dart';
import 'package:seichi_junrei_helper/data/sample_pilgrimage_repository.dart';
import 'package:seichi_junrei_helper/plan_transfer/plan_package.dart';

void main() {
  test('encodes and decodes plan package data', () async {
    final repository = SamplePilgrimageRepository();
    final plan = await repository.loadActivePlan();
    final point = plan.points.first;
    final record = await repository.createVisitRecord(
      planId: plan.id,
      pointId: point.id,
      workId: point.work.id,
      photoPath: '/tmp/photo.jpg',
      referenceImagePath: '/tmp/reference.jpg',
      referenceImageUrl: 'https://example.com/reference.jpg',
      referenceMode: '叠影',
    );

    final encoded = PlanPackage(
      plan: plan,
      visitRecords: [record],
    ).toJsonString();
    final decoded = PlanPackage.fromJsonString(encoded);

    expect(decoded.plan.name, plan.name);
    expect(
      decoded.plan.points.map((point) => point.id),
      plan.points.map((p) => p.id),
    );
    expect(
      decoded.plan.works.map((work) => work.id),
      plan.works.map((w) => w.id),
    );
    expect(decoded.visitRecords, hasLength(1));
    expect(decoded.visitRecords.single.referenceMode, '叠影');
  });
}
