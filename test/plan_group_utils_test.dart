import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:miriago/plan/pilgrimage_models.dart';
import 'package:miriago/plan/pilgrimage_plan_controller.dart';
import 'package:miriago/plan/plan_group_utils.dart';

void main() {
  test('sorts groups by plan order without mutating the source list', () {
    final createdAt = DateTime.utc(2026);
    final lateGroup = PilgrimagePlanGroup(
      id: 'late',
      name: '后访问',
      orderIndex: 2,
      createdAt: createdAt,
    );
    final earlyGroup = PilgrimagePlanGroup(
      id: 'early',
      name: '先访问',
      orderIndex: 0,
      createdAt: createdAt,
    );
    final middleGroup = PilgrimagePlanGroup(
      id: 'middle',
      name: '中间',
      orderIndex: 1,
      createdAt: createdAt,
    );
    final groups = [lateGroup, earlyGroup, middleGroup];

    final sortedGroups = sortGroupsByPlanOrder(groups);

    expect(sortedGroups.map((group) => group.id), ['early', 'middle', 'late']);
    expect(groups.map((group) => group.id), ['late', 'early', 'middle']);
  });

  test('ungrouped points keep their plan insertion order', () {
    final fixture = _buildGroupedPlanFixture();
    final routePoints = [
      fixture.groupAFirst.copyWith(
        id: 'route-first',
        name: 'Z 路线第一站',
        groupId: null,
        groupOrderIndex: null,
      ),
      fixture.groupASecond.copyWith(
        id: 'route-second',
        name: 'A 路线第二站',
        groupId: null,
        groupOrderIndex: null,
      ),
      fixture.groupBFirst.copyWith(
        id: 'route-third',
        name: 'M 路线第三站',
        groupId: null,
        groupOrderIndex: null,
      ),
    ];
    final plan = fixture.plan.copyWith(points: routePoints);

    final ungrouped = planGroupBuckets(plan, const {}).last;

    expect(ungrouped.points.map((point) => point.id), [
      'route-first',
      'route-second',
      'route-third',
    ]);
  });

  test('duplicate group order indexes keep their source order', () {
    final fixture = _buildGroupedPlanFixture();
    final points = [
      fixture.groupAFirst.copyWith(id: 'same-order-first', name: 'Z'),
      fixture.groupAFirst.copyWith(id: 'same-order-second', name: 'A'),
    ];

    final sorted = sortPointsByPlanOrder(points);

    expect(sorted.map((point) => point.id), [
      'same-order-first',
      'same-order-second',
    ]);
  });

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

  test('pending-coordinate points stay out of map and target calculations', () {
    final fixture = _buildGroupedPlanFixture();
    final pendingPoint = fixture.groupASecond.copyWith(
      id: 'pending-coordinate',
      position: PilgrimagePoint.pendingPosition,
      groupOrderIndex: 2,
    );
    final group = PlanGroupBucket(
      id: fixture.plan.groups.first.id,
      name: fixture.plan.groups.first.name,
      group: fixture.plan.groups.first,
      points: [fixture.groupAFirst, pendingPoint],
      completedCount: 0,
    );

    expect(groupMapCenter(group), fixture.groupAFirst.position);
    expect(
      nextPendingPointAfterCompletion(
        points: [fixture.groupAFirst, pendingPoint, fixture.groupBFirst],
        completedPoint: fixture.groupAFirst,
        completedPointIds: {fixture.groupAFirst.id},
      )?.id,
      fixture.groupBFirst.id,
    );
    expect(
      displayPointsForGroup(
        group,
        sortMode: PointSortMode.distance,
        descending: true,
      ).last.id,
      pendingPoint.id,
    );
  });

  test('rounded group hull uses a smooth meter-based radius', () {
    const center = LatLng(35.681236, 139.767125);
    const point = PilgrimagePoint(
      id: 'area-center',
      work: PilgrimageWork(
        id: 'area-work',
        title: '片区测试',
        subtitle: '',
        city: '东京',
        source: WorkSource.manual,
      ),
      name: '中心点',
      subtitle: '',
      position: center,
      episodeLabel: '',
      referenceLabel: '',
    );

    final hull = roundedGroupHull(const [point], radiusMeters: 160);
    final distances = hull
        .map((position) => const Distance()(center, position))
        .toList(growable: false);

    expect(hull.length, greaterThanOrEqualTo(40));
    expect(
      distances.reduce((a, b) => a + b) / distances.length,
      closeTo(160, 2),
    );
  });

  test('larger group radius expands the generated hull', () {
    const center = LatLng(34.693725, 135.502254);
    const point = PilgrimagePoint(
      id: 'radius-point',
      work: PilgrimageWork(
        id: 'radius-work',
        title: '半径测试',
        subtitle: '',
        city: '大阪',
        source: WorkSource.manual,
      ),
      name: '测试点位',
      subtitle: '',
      position: center,
      episodeLabel: '',
      referenceLabel: '',
    );
    final smallHull = roundedGroupHull(const [point], radiusMeters: 80);
    final largeHull = roundedGroupHull(const [point], radiusMeters: 240);
    final distance = const Distance();
    final smallAverage =
        smallHull
            .map((position) => distance(center, position))
            .reduce((a, b) => a + b) /
        smallHull.length;
    final largeAverage =
        largeHull
            .map((position) => distance(center, position))
            .reduce((a, b) => a + b) /
        largeHull.length;

    expect(smallAverage, closeTo(80, 2));
    expect(largeAverage, closeTo(240, 3));
    expect(largeAverage, greaterThan(smallAverage * 2.9));
  });

  test('in-app navigation tour chains all coordinate points in a zone', () {
    final fixture = _buildGroupedPlanFixture();
    final tour = inAppNavigationTourFor(
      point: fixture.groupAFirst,
      buckets: planGroupBuckets(fixture.plan, const {}),
    );

    expect(tour.groupName, '片区 A');
    expect(tour.stops.map((point) => point.id), ['a-1', 'a-2']);
    expect(tour.startIndex, 0);
    expect(tour.remainingStops.map((point) => point.id), ['a-1', 'a-2']);
  });

  test('in-app navigation tour starts from the selected point in a zone', () {
    final fixture = _buildGroupedPlanFixture();
    final tour = inAppNavigationTourFor(
      point: fixture.groupASecond,
      buckets: planGroupBuckets(fixture.plan, const {}),
    );

    expect(tour.groupName, '片区 A');
    expect(tour.startIndex, 1);
    expect(tour.stops.map((point) => point.id), ['a-1', 'a-2']);
    expect(tour.remainingStops.map((point) => point.id), ['a-2']);
  });

  test('in-app navigation tour stays on a single ungrouped point', () {
    final fixture = _buildGroupedPlanFixture();
    final ungrouped = fixture.groupAFirst.copyWith(
      id: 'ungrouped-1',
      groupId: null,
      groupOrderIndex: null,
    );
    final plan = fixture.plan.copyWith(
      points: [...fixture.plan.points, ungrouped],
    );
    final tour = inAppNavigationTourFor(
      point: ungrouped,
      buckets: planGroupBuckets(plan, const {}),
    );

    expect(tour.groupName, isNull);
    expect(tour.stops.map((point) => point.id), ['ungrouped-1']);
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
