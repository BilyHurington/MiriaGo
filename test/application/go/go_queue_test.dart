import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:miriago/application/go/go_queue.dart';
import 'package:miriago/plan/pilgrimage_models.dart';

const _work = PilgrimageWork(
  id: 'work',
  title: '作品',
  subtitle: 'サブタイトル',
  city: '宇治',
  source: WorkSource.manual,
);

PilgrimagePoint _point(
  String id, {
  LatLng? position,
  String? groupId,
  int? order,
  String episode = 'EP 1',
}) => PilgrimagePoint(
  id: id,
  work: _work,
  name: id,
  subtitle: '',
  position: position ?? PilgrimagePoint.pendingPosition,
  episodeLabel: episode,
  referenceLabel: 'ref',
  source: PointSource.manual,
  groupId: groupId,
  groupOrderIndex: order,
);

PilgrimagePlanGroup _group(String id, int order) => PilgrimagePlanGroup(
  id: id,
  name: id,
  orderIndex: order,
  createdAt: DateTime(2026),
);

void main() {
  group('GoSort', () {
    test('labels match the old sort control', () {
      expect(const GoSort().label, '默认计划 · 正序');
      expect(const GoSort(descending: true).directionLabel, '反序');
      const distance = GoSort(mode: PointSortMode.distance);
      expect(distance.modeLabel, '按距离');
      expect(distance.directionLabel, '近到远');
      expect(distance.copyWith(descending: true).directionLabel, '远到近');
      expect(GoSort.menuLabel(PointSortMode.plan), '默认计划顺序');
      expect(GoSort.menuLabel(PointSortMode.distance), '按距离当前位置');
    });
  });

  group('goQueuePoints', () {
    final near = _point(
      'near',
      position: const LatLng(34.89, 135.80),
      order: 2,
    );
    final far = _point('far', position: const LatLng(35.5, 136.5), order: 0);
    final pending = _point('pending', order: 1);
    final bucket = PlanGroupBucket(
      id: 'g',
      name: 'g',
      points: [far, pending, near],
      completedCount: 0,
    );

    test('plan order keeps points without coordinates last', () {
      expect(goQueuePoints(bucket).map((p) => p.id), [
        'far',
        'near',
        'pending',
      ]);
      expect(
        goQueuePoints(
          bucket,
          sort: const GoSort(descending: true),
        ).map((p) => p.id),
        ['near', 'far', 'pending'],
      );
    });

    test('distance order uses the location, reversed on demand', () {
      const here = LatLng(34.89, 135.80);
      expect(
        goQueuePoints(
          bucket,
          sort: const GoSort(mode: PointSortMode.distance),
          location: here,
        ).map((p) => p.id),
        ['near', 'far', 'pending'],
      );
      expect(
        goQueuePoints(
          bucket,
          sort: const GoSort(mode: PointSortMode.distance, descending: true),
          location: here,
        ).map((p) => p.id),
        ['far', 'near', 'pending'],
      );
    });

    test('distance order falls back to the preview location', () {
      expect(
        goQueuePoints(
          bucket,
          sort: const GoSort(mode: PointSortMode.distance),
        ).first.id,
        'near',
      );
    });
  });

  group('groups', () {
    final plan = PilgrimagePlan(
      id: 'p',
      name: 'p',
      area: '',
      memo: '',
      works: const [_work],
      groups: [_group('b', 1), _group('a', 0)],
      points: [
        _point('a1', groupId: 'a', position: const LatLng(1, 1)),
        _point('b1', groupId: 'b', position: const LatLng(2, 2)),
        _point('lost', groupId: 'missing', position: const LatLng(3, 3)),
        _point('none'),
      ],
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      completedPointIds: const {},
    );
    final buckets = planGroupBuckets(plan, const {});

    test('buckets are in plan order with the synthetic ungrouped last', () {
      expect(buckets.map((b) => b.id), ['a', 'b', kGoUngroupedBucketId]);
    });

    test('goGroupIndex restores the current group or falls back', () {
      expect(goGroupIndex(buckets, 'b'), 1);
      expect(goGroupIndex(buckets, kGoUngroupedBucketId), 2);
      expect(goGroupIndex(buckets, 'deleted'), 0);
      expect(goGroupIndex(buckets, null), 0);
      expect(goGroupIndex(const [], null), -1);
    });

    test('previous / next do not wrap', () {
      expect(adjacentGroupIndex(0, -1, 3), isNull);
      expect(adjacentGroupIndex(0, 1, 3), 1);
      expect(adjacentGroupIndex(2, 1, 3), isNull);
      expect(adjacentGroupIndex(2, -1, 3), 1);
    });

    test('points of unknown groups belong to the ungrouped bucket', () {
      final byId = {for (final p in plan.points) p.id: p};
      expect(goBucketIdForPoint(byId['a1']!, buckets), 'a');
      expect(goBucketIdForPoint(byId['lost']!, buckets), kGoUngroupedBucketId);
      expect(goBucketIdForPoint(byId['none']!, buckets), kGoUngroupedBucketId);
    });
  });

  group('map', () {
    final a = _point('a', position: const LatLng(1, 1));
    final b = _point('b', position: const LatLng(2, 2));
    final pending = _point('pending');

    test('initial centre: selected → current → visible → group → Kyoto', () {
      expect(
        goInitialMapCenter(selected: a, current: b, visiblePoints: [b]),
        a.position,
      );
      expect(
        goInitialMapCenter(selected: pending, current: b, visiblePoints: [a]),
        b.position,
      );
      expect(
        goInitialMapCenter(current: pending, visiblePoints: [pending, a]),
        a.position,
      );
      final group = PlanGroupBucket(
        id: 'g',
        name: 'g',
        points: [b],
        completedCount: 0,
      );
      expect(goInitialMapCenter(group: group), b.position);
      expect(goInitialMapCenter(), kGoFallbackCenter);
    });

    test('visible points skip missing coordinates and hidden completed', () {
      VisitStatus status(PilgrimagePoint p) =>
          p.id == 'a' ? VisitStatus.completed : VisitStatus.pending;
      expect(
        goVisibleMapPoints(
          [a, b, pending],
          statusOf: status,
          hideCompleted: false,
        ).map((p) => p.id),
        ['a', 'b'],
      );
      expect(
        goVisibleMapPoints(
          [a, b, pending],
          statusOf: status,
          hideCompleted: true,
        ).map((p) => p.id),
        ['b'],
      );
    });

    test('设为当前目标 needs coordinates and a pending point', () {
      expect(goCanOfferSetCurrent(a, VisitStatus.pending), isTrue);
      expect(goCanOfferSetCurrent(a, VisitStatus.current), isFalse);
      expect(goCanOfferSetCurrent(a, VisitStatus.completed), isFalse);
      expect(goCanOfferSetCurrent(pending, VisitStatus.pending), isFalse);
    });

    test('overlapping points follow plan order', () {
      final bucket = PlanGroupBucket(
        id: 'g',
        name: 'g',
        points: [a, b],
        completedCount: 0,
      );
      expect(goOrderedOverlap([b, a], [bucket]).map((p) => p.id), ['a', 'b']);
    });
  });

  test('keyboard index moves without wrapping', () {
    expect(goKeyboardIndex(-1, 1, 3), 0);
    expect(goKeyboardIndex(-1, -1, 3), 2);
    expect(goKeyboardIndex(2, 1, 3), 2);
    expect(goKeyboardIndex(0, -1, 3), 0);
    expect(goKeyboardIndex(1, 1, 3), 2);
    expect(goKeyboardIndex(0, 1, 0), isNull);
  });

  test('point meta is 作品 · 集数', () {
    expect(
      goPointMeta(_point('x', episode: 'EP 2 / 13:29')),
      '作品 · EP 2 / 13:29',
    );
    expect(goPointMeta(_point('x', episode: ' ')), '作品');
  });
}
