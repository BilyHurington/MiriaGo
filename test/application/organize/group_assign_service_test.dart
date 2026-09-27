import 'package:flutter_map/flutter_map.dart' show LatLngBounds;
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:miriago/application/organize/group_assign_service.dart';
import 'package:miriago/plan/pilgrimage_models.dart';
import 'package:miriago/plan/plan_group_utils.dart';

const _work = PilgrimageWork(
  id: 'work',
  title: '作品',
  subtitle: '',
  city: '',
  source: WorkSource.manual,
);

PilgrimagePoint _point(String id, LatLng position, {String? groupId}) =>
    PilgrimagePoint(
      id: id,
      work: _work,
      name: id,
      subtitle: '',
      position: position,
      episodeLabel: '',
      referenceLabel: '',
      groupId: groupId,
    );

PilgrimagePlanGroup _group(
  String id,
  int order, {
  LatLng? anchor,
  String? anchorPointId,
}) => PilgrimagePlanGroup(
  id: id,
  name: id,
  orderIndex: order,
  anchorName: anchor == null && anchorPointId == null ? null : 'anchor-$id',
  anchorLatitude: anchor?.latitude,
  anchorLongitude: anchor?.longitude,
  anchorPointId: anchorPointId,
  createdAt: DateTime(2026),
);

PilgrimagePlan _plan({
  required List<PilgrimagePlanGroup> groups,
  required List<PilgrimagePoint> points,
}) => PilgrimagePlan(
  id: 'plan',
  name: 'plan',
  area: '',
  memo: '',
  works: const [_work],
  groups: groups,
  points: points,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  completedPointIds: const {},
);

/// Offsets [base] by roughly [meters] northwards.
LatLng _north(LatLng base, double meters) =>
    LatLng(base.latitude + meters / 111195, base.longitude);

void main() {
  const origin = LatLng(34.89, 135.80);
  final east = LatLng(origin.latitude, origin.longitude + 0.05);

  group('formatAssignDistance / clamp', () {
    test('formats metres and kilometres like the old app', () {
      expect(formatAssignDistance(50), '50 m');
      expect(formatAssignDistance(999.4), '999 m');
      expect(formatAssignDistance(1000), '1.0 km');
      expect(formatAssignDistance(2550), '2.5 km');
    });

    test('clamps the stored distance into 50 m – 5 km', () {
      expect(clampNearestAssignDistance(10), 50);
      expect(clampNearestAssignDistance(9000), 5000);
      expect(clampNearestAssignDistance(800), 800);
    });
  });

  group('NearestGroupAssigner', () {
    test('assigns ungrouped points to the nearest key point in range', () {
      final plan = _plan(
        groups: [
          _group('a', 0, anchor: origin),
          _group('b', 1, anchor: east),
          _group('no-anchor', 2),
        ],
        points: [
          _point('near-a', _north(origin, 200)),
          _point('far', _north(origin, 3000)),
          _point('near-b', _north(east, 100)),
          _point('grouped', _north(origin, 10), groupId: 'a'),
          _point('pending', PilgrimagePoint.pendingPosition),
        ],
      );
      final assigner = NearestGroupAssigner(plan);

      expect(assigner.targetGroups.map((g) => g.id), ['a', 'b']);
      expect(assigner.ungroupedPoints.map((p) => p.id), [
        'near-a',
        'far',
        'near-b',
      ]);
      expect(assigner.assignments(500), {
        'a': {'near-a'},
        'b': {'near-b'},
      });
      expect(assigner.assignableCount(500), 2);
      expect(assigner.groupIdsByPointId(5000), {
        'near-a': 'a',
        'far': 'a',
        'near-b': 'b',
      });

      final far = plan.points[1];
      expect(assigner.nearestGroupFor(far)?.id, 'a');
      expect(assigner.nearestDistanceFor(far), closeTo(3000, 15));
      expect(assigner.isAssignable(far, 2980), isFalse);
      expect(assigner.isAssignable(far, 3010), isTrue);
    });

    test('the maximum distance is inclusive', () {
      final point = _point('p', _north(origin, 300));
      final plan = _plan(
        groups: [_group('a', 0, anchor: origin)],
        points: [point],
      );
      final assigner = NearestGroupAssigner(plan);
      final meters = assigner.nearestDistanceFor(point)!;
      expect(assigner.isAssignable(point, meters), isTrue);
      expect(assigner.assignableCount(meters), 1);
    });

    test('ties keep the group that comes first in plan order', () {
      final plan = _plan(
        groups: [
          _group('second', 5, anchor: origin),
          _group('first', 1, anchor: origin),
        ],
        points: [_point('p', _north(origin, 50))],
      );
      final assigner = NearestGroupAssigner(plan);
      expect(assigner.nearestGroupFor(plan.points.single)?.id, 'first');
    });

    test('a linked anchor point wins over the stored coordinates', () {
      final moved = _north(east, 0);
      final plan = _plan(
        groups: [
          // Stored copy says origin, but the linked point is at `east`.
          PilgrimagePlanGroup(
            id: 'linked',
            name: 'linked',
            orderIndex: 0,
            anchorName: 'x',
            anchorLatitude: origin.latitude,
            anchorLongitude: origin.longitude,
            anchorPointId: 'anchor-point',
            createdAt: DateTime(2026),
          ),
        ],
        points: [
          _point('anchor-point', moved, groupId: 'linked'),
          _point('p', _north(east, 100)),
        ],
      );
      final assigner = NearestGroupAssigner(plan);
      expect(assigner.anchorsByGroupId['linked'], moved);
      expect(assigner.assignableCount(200), 1);
    });

    test('without key points nothing is assignable', () {
      final plan = _plan(
        groups: [_group('a', 0)],
        points: [_point('p', origin)],
      );
      final assigner = NearestGroupAssigner(plan);
      expect(assigner.targetGroups, isEmpty);
      expect(assigner.nearestGroupFor(plan.points.single), isNull);
      expect(assigner.nearestDistanceFor(plan.points.single), isNull);
      expect(assigner.assignments(5000), isEmpty);
    });

    test('map centre averages points and key points', () {
      final plan = _plan(
        groups: [_group('a', 0, anchor: const LatLng(10, 20))],
        points: [_point('p', const LatLng(20, 40))],
      );
      expect(NearestGroupAssigner(plan).mapCenter, const LatLng(15, 30));
      expect(assignMapCenter(const [], const []), previewCurrentLocation);
    });
  });

  group('box assignment', () {
    test('selects only ungrouped points with coordinates inside', () {
      final plan = _plan(
        groups: [_group('a', 0)],
        points: [
          _point('inside', const LatLng(1, 1)),
          _point('outside', const LatLng(5, 5)),
          _point('grouped', const LatLng(1, 1), groupId: 'a'),
          _point('pending', PilgrimagePoint.pendingPosition),
        ],
      );
      final bounds = LatLngBounds(const LatLng(0, 0), const LatLng(2, 2));
      expect(boxSelectedPoints(plan, bounds).map((p) => p.id), ['inside']);
      expect(boxSelectedPoints(plan, null), isEmpty);
    });

    test('target group falls back to the first group', () {
      final plan = _plan(
        groups: [_group('b', 2), _group('a', 1)],
        points: const [],
      );
      expect(boxTargetGroup(plan, null)?.id, 'a');
      expect(boxTargetGroup(plan, 'b')?.id, 'b');
      expect(boxTargetGroup(plan, 'gone')?.id, 'a');
      expect(
        boxTargetGroup(_plan(groups: const [], points: const []), null),
        isNull,
      );
    });
  });
}
