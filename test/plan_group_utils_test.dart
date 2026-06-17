import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:miriago/plan/pilgrimage_models.dart';
import 'package:miriago/plan/pilgrimage_plan_controller.dart';
import 'package:miriago/plan/plan_group_utils.dart';

void main() {
  test('next pending point stays in the same group first', () {
    final fixture = _buildGroupedPlanFixture();
    final nextPoint = nextPendingPointAfterCompletion(
      points: fixture.plan.points,
      completedPoint: fixture.groupAFirst,
      completedPointIds: {fixture.groupAFirst.id},
    );

    expect(nextPoint?.id, fixture.groupASecond.id);
  });

  test('next pending point falls back to the next available group', () {
    final fixture = _buildGroupedPlanFixture();
    final nextPoint = nextPendingPointAfterCompletion(
      points: fixture.plan.points,
      completedPoint: fixture.groupASecond,
      completedPointIds: {fixture.groupAFirst.id, fixture.groupASecond.id},
    );

    expect(nextPoint?.id, fixture.groupBFirst.id);
  });

  test('controller completion advances within the current group', () {
    final fixture = _buildGroupedPlanFixture();
    final controller = PilgrimagePlanController(plan: fixture.plan);

    controller.completePoint(fixture.groupAFirst);

    expect(controller.currentPoint?.id, fixture.groupASecond.id);
    expect(controller.selectedPoint?.id, fixture.groupASecond.id);
  });
}

_GroupedPlanFixture _buildGroupedPlanFixture() {
  final createdAt = DateTime.utc(2026);
  const work = PilgrimageWork(
    id: 'work',
    title: '作品',
    subtitle: '动画',
    city: '宇治市',
    source: WorkSource.manual,
  );
  final groupA = PilgrimagePlanGroup(
    id: 'group-a',
    name: '片区 A',
    orderIndex: 0,
    createdAt: createdAt,
  );
  final groupB = PilgrimagePlanGroup(
    id: 'group-b',
    name: '片区 B',
    orderIndex: 1,
    createdAt: createdAt,
  );
  const groupAFirst = PilgrimagePoint(
    id: 'a-1',
    work: work,
    name: 'A1',
    subtitle: '',
    position: LatLng(34.89, 135.8),
    episodeLabel: '',
    referenceLabel: '',
    groupId: 'group-a',
    groupOrderIndex: 0,
  );
  const groupBFirst = PilgrimagePoint(
    id: 'b-1',
    work: work,
    name: 'B1',
    subtitle: '',
    position: LatLng(34.9, 135.81),
    episodeLabel: '',
    referenceLabel: '',
    groupId: 'group-b',
    groupOrderIndex: 0,
  );
  const groupASecond = PilgrimagePoint(
    id: 'a-2',
    work: work,
    name: 'A2',
    subtitle: '',
    position: LatLng(34.91, 135.82),
    episodeLabel: '',
    referenceLabel: '',
    groupId: 'group-a',
    groupOrderIndex: 1,
  );
  final plan = PilgrimagePlan(
    id: 'plan',
    name: '测试计划',
    area: '宇治市',
    works: const [work],
    groups: [groupA, groupB],
    points: const [groupAFirst, groupBFirst, groupASecond],
    createdAt: createdAt,
    updatedAt: createdAt,
    currentPointId: groupAFirst.id,
  );
  return _GroupedPlanFixture(
    plan: plan,
    groupAFirst: groupAFirst,
    groupASecond: groupASecond,
    groupBFirst: groupBFirst,
  );
}

class _GroupedPlanFixture {
  const _GroupedPlanFixture({
    required this.plan,
    required this.groupAFirst,
    required this.groupASecond,
    required this.groupBFirst,
  });

  final PilgrimagePlan plan;
  final PilgrimagePoint groupAFirst;
  final PilgrimagePoint groupASecond;
  final PilgrimagePoint groupBFirst;
}
