import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/data/sample_pilgrimage_repository.dart';
import 'package:miriago/plan/pilgrimage_models.dart';

void main() {
  test('sample plan behaves like a complete pilgrimage plan', () async {
    final repository = SamplePilgrimageRepository();
    final plan = await repository.loadActivePlan();
    final records = await repository.loadVisitRecords(plan.id);

    expect(plan, same(samplePilgrimagePlan));
    expect(plan.name, isNotEmpty);
    expect(plan.area, isNotEmpty);
    expect(plan.works, isNotEmpty);
    expect(plan.groups, isNotEmpty);
    expect(plan.points, isNotEmpty);
    expect(records, isNotEmpty);

    final workIds = plan.works.map((work) => work.id).toSet();
    final groupIds = plan.groups.map((group) => group.id).toSet();
    final pointIds = plan.points.map((point) => point.id).toSet();

    expect(pointIds, hasLength(plan.points.length));
    expect(groupIds, hasLength(plan.groups.length));
    expect(plan.currentPointId, isIn(pointIds));
    expect(plan.currentGroupId, isIn(groupIds));
    expect(plan.completedPointIds, isEmpty);

    for (final point in plan.points) {
      expect(point.id, isNotEmpty);
      expect(point.name, isNotEmpty);
      expect(point.work.id, isIn(workIds));
      expect(point.position.latitude, inInclusiveRange(-90, 90));
      expect(point.position.longitude, inInclusiveRange(-180, 180));
      if (point.source == PointSource.anitabi) {
        expect(point.sourceId, isNotNull);
      }
      if (point.groupId != null) {
        expect(point.groupId, isIn(groupIds));
        expect(point.groupOrderIndex, isNotNull);
      }
    }

    for (final group in plan.groups) {
      expect(group.id, isNotEmpty);
      expect(group.name, isNotEmpty);
      expect(group.anchorPointId, isIn(pointIds));
      if (group.anchorLatitude != null) {
        expect(group.anchorLatitude, inInclusiveRange(-90, 90));
      }
      if (group.anchorLongitude != null) {
        expect(group.anchorLongitude, inInclusiveRange(-180, 180));
      }
    }

    for (final groupId in groupIds) {
      final indexes = plan.points
          .where((point) => point.groupId == groupId)
          .map((point) => point.groupOrderIndex)
          .nonNulls
          .toList(growable: false);
      expect(indexes.toSet(), hasLength(indexes.length));
    }

    final recordIds = records.map((record) => record.id).toSet();
    expect(recordIds, hasLength(records.length));
    for (final record in records) {
      expect(record.planId, plan.id);
      expect(record.pointId, isIn(pointIds));
      expect(record.workId, isIn(workIds));
      expect(record.photoPath, isNotEmpty);
      expect(record.referenceMode, isNotEmpty);
    }
  });
}
