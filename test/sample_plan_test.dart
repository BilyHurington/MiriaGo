import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:miriago/data/sample_pilgrimage_repository.dart';
import 'package:miriago/plan/pilgrimage_models.dart';
import 'package:miriago/records/visit_record_photo_io.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
      expect(record.workTitle, isNotEmpty);
      expect(record.pointName, isNotEmpty);
      expect(record.photoPath, isNotEmpty);
      expect(record.photoPath, startsWith('docs/sample_images/'));
      expect(record.referenceMode, isNotEmpty);
      await rootBundle.load(record.photoPath);
      if (record.gradedPhotoPath != null) {
        expect(record.gradedPhotoPath, startsWith('docs/sample_images/'));
        await rootBundle.load(record.gradedPhotoPath!);
      }
    }
  });

  test('sample repository preserves manual order inside a group', () async {
    final repository = SamplePilgrimageRepository();
    final plan = await repository.loadActivePlan();
    final group = plan.groups.firstWhere(
      (group) =>
          group.orderMode == PlanGroupOrderMode.manual &&
          plan.points.where((point) => point.groupId == group.id).length >= 2,
    );
    final originalIds =
        plan.points
            .where((point) => point.groupId == group.id)
            .toList(growable: false)
          ..sort(
            (a, b) =>
                (a.groupOrderIndex ?? 999).compareTo(b.groupOrderIndex ?? 999),
          );
    final reorderedIds = originalIds
        .map((point) => point.id)
        .toList()
        .reversed
        .toList(growable: false);

    await repository.reorderGroupPoints(
      planId: plan.id,
      groupId: group.id,
      pointIds: reorderedIds,
    );

    final updatedPlan = await repository.loadActivePlan();
    final updatedIds =
        updatedPlan.points
            .where((point) => point.groupId == group.id)
            .toList(growable: false)
          ..sort(
            (a, b) =>
                (a.groupOrderIndex ?? 999).compareTo(b.groupOrderIndex ?? 999),
          );

    expect(updatedIds.map((point) => point.id), reorderedIds);
  });

  testWidgets('sample record photos render bundled assets on IO platforms', (
    tester,
  ) async {
    final repository = SamplePilgrimageRepository();
    final plan = await repository.loadActivePlan();
    final records = await repository.loadVisitRecords(plan.id);
    final record = records.first;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: VisitRecordPhoto(path: record.photoPath)),
      ),
    );

    expect(find.byType(Image), findsOneWidget);
  });
}
