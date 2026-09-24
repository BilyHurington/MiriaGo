import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:miriago/data/local/app_database.dart';
import 'package:miriago/data/local/sqlite_pilgrimage_repository.dart';
import 'package:miriago/data/pilgrimage_repository.dart';
import 'package:miriago/data/sample_pilgrimage_repository.dart';
import 'package:miriago/desktop/desktop_pilgrimage_repository.dart';
import 'package:miriago/plan/pilgrimage_models.dart';

class _MemoryPersistence extends DesktopRepositoryPersistence {
  @override
  Future<void> saveState(String json) async {}
  @override
  Future<void> saveSettings(String json) async {}
  @override
  Future<void> savePlan(String plan, String records, String? activeId) async {}
  @override
  Future<void> setActivePlan(String id) async {}
  @override
  Future<void> deletePlan(String id, String? activeId) async {}
  @override
  Future<void> saveRecord(String json) async {}
  @override
  Future<void> deleteRecord(String id) async {}
}

typedef _Factory = PilgrimageRepository Function();

final _factories = <String, _Factory>{
  'sqlite': () {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    return SqlitePilgrimageRepository(database: database);
  },
  'sample': () => SamplePilgrimageRepository(visitRecords: const []),
  'desktop': () => DesktopPilgrimageRepository(
    snapshot: SamplePilgrimageRepository(visitRecords: const []).snapshot(),
    persistence: _MemoryPersistence(),
  ),
};

const _fullWork = PilgrimageWork(
  id: 'work',
  bangumiId: 42,
  bangumiSubjectType: BangumiSubjectType.music,
  coverImageUrl: 'https://lain.bgm.tv/r/200/pic/cover/work.jpg',
  title: 'Stored title',
  subtitle: 'Stored subtitle',
  city: 'Stored city',
  source: WorkSource.bangumi,
);

/// A stale copy embedded in a point: same id, but missing metadata.
const _staleWork = PilgrimageWork(
  id: 'work',
  title: 'Stale title',
  subtitle: '',
  city: '',
  source: WorkSource.manual,
);

PilgrimagePoint _point(String id, {PilgrimageWork work = _fullWork}) {
  return PilgrimagePoint(
    id: id,
    work: work,
    name: id,
    subtitle: '',
    position: const LatLng(35, 135),
    episodeLabel: 'EP 1',
    referenceLabel: '',
  );
}

PilgrimagePlanGroup _group(String id, int order) => PilgrimagePlanGroup(
  id: id,
  name: id,
  orderIndex: order,
  createdAt: DateTime(2026),
);

PilgrimagePoint _find(PilgrimagePlan plan, String id) =>
    plan.points.singleWhere((point) => point.id == id);

void _expectFullWork(PilgrimageWork work) {
  expect(work.bangumiId, _fullWork.bangumiId);
  expect(work.bangumiSubjectType, _fullWork.bangumiSubjectType);
  expect(work.coverImageUrl, _fullWork.coverImageUrl);
  expect(work.title, _fullWork.title);
  expect(work.subtitle, _fullWork.subtitle);
  expect(work.city, _fullWork.city);
}

void main() {
  for (final entry in _factories.entries) {
    final name = entry.key;
    final create = entry.value;

    group('$name repository', () {
      test('stale embedded work copies never clobber the shared work', () async {
        final repository = create();
        var plan = await repository.createPlan(name: 'Works', area: 'Area');
        await repository.addWorkToPlan(planId: plan.id, work: _fullWork);
        await repository.addPointsToPlan(
          planId: plan.id,
          points: [_point('p1', work: _staleWork)],
        );
        plan = await repository.updatePointInPlan(
          planId: plan.id,
          point: _point('p1', work: _staleWork).copyWith(name: 'Edited'),
        );

        _expectFullWork(plan.works.single);
        _expectFullWork(_find(plan, 'p1').work);
        expect(_find(plan, 'p1').name, 'Edited');
        final reloaded = (await repository.loadPlans()).singleWhere(
          (candidate) => candidate.id == plan.id,
        );
        _expectFullWork(reloaded.works.single);
      });

      test('a later richer work copy fills only missing fields', () async {
        final repository = create();
        var plan = await repository.createPlan(name: 'Works', area: 'Area');
        await repository.addPointsToPlan(
          planId: plan.id,
          points: [_point('p1', work: _staleWork)],
        );
        plan = await repository.addWorkToPlan(
          planId: plan.id,
          work: _fullWork,
        );

        final work = plan.works.single;
        expect(work.title, _staleWork.title);
        expect(work.subtitle, _fullWork.subtitle);
        expect(work.city, _fullWork.city);
        expect(work.coverImageUrl, _fullWork.coverImageUrl);
        expect(work.bangumiSubjectType, _fullWork.bangumiSubjectType);
        expect(work.bangumiId, _fullWork.bangumiId);
      });

      test('updating a point keeps its group membership', () async {
        final repository = create();
        var plan = await repository.createPlan(name: 'Groups', area: 'Area');
        await repository.createPlanGroup(
          planId: plan.id,
          group: _group('g', 0),
        );
        await repository.addPointsToPlan(
          planId: plan.id,
          points: [_point('p0'), _point('p1')],
        );
        await repository.movePointsToGroup(
          planId: plan.id,
          pointIds: {'p0', 'p1'},
          groupId: 'g',
        );
        plan = await repository.updatePointInPlan(
          planId: plan.id,
          point: _point('p1').copyWith(name: 'Renamed'),
        );

        final point = _find(plan, 'p1');
        expect(point.name, 'Renamed');
        expect(point.groupId, 'g');
        expect(point.groupOrderIndex, 1);
      });

      test('moving a key point refreshes the stored group anchor', () async {
        final repository = create();
        var plan = await repository.createPlan(name: 'Anchor', area: 'Area');
        await repository.addPointsToPlan(
          planId: plan.id,
          points: [_point('anchor')],
        );
        await repository.createPlanGroup(
          planId: plan.id,
          group: PilgrimagePlanGroup(
            id: 'g',
            name: 'g',
            orderIndex: 0,
            anchorName: 'anchor',
            anchorLatitude: 35,
            anchorLongitude: 135,
            anchorPointId: 'anchor',
            createdAt: DateTime(2026),
          ),
        );
        plan = await repository.updatePointInPlan(
          planId: plan.id,
          point: _point(
            'anchor',
          ).copyWith(position: const LatLng(34.5, 135.5)),
        );

        final group = plan.groups.single;
        expect(group.anchorPointId, 'anchor');
        expect(group.anchorLatitude, 34.5);
        expect(group.anchorLongitude, 135.5);
      });

      test('visit records are newest first with a stable id tie-break', () async {
        final repository = create();
        final plan = await repository.addPointsToPlan(
          planId: (await repository.createPlan(name: 'Records', area: 'A')).id,
          points: [_point('p')],
        );
        Future<PilgrimageVisitRecord> record(DateTime capturedAt) =>
            repository.createVisitRecord(
              planId: plan.id,
              pointId: 'p',
              workId: 'work',
              photoPath: 'photo.jpg',
              referenceMode: 'overlay',
              capturedAt: capturedAt,
            );
        final oldest = await record(DateTime(2026, 1, 1, 9));
        final newest = await record(DateTime(2026, 1, 1, 11));
        final tiedFirst = await record(DateTime(2026, 1, 1, 10));
        final tiedSecond = await record(DateTime(2026, 1, 1, 10));
        expect(tiedSecond.id.compareTo(tiedFirst.id), greaterThan(0));

        final records = await repository.loadVisitRecords(plan.id);
        expect(records.map((record) => record.id), [
          newest.id,
          tiedSecond.id,
          tiedFirst.id,
          oldest.id,
        ]);
      });

      test('bulk completion and deletion continue in group order', () async {
        final repository = create();
        var plan = await repository.createPlan(name: 'Walk', area: 'Area');
        for (final (id, order) in [('a', 0), ('b', 1), ('c', 2)]) {
          await repository.createPlanGroup(
            planId: plan.id,
            group: _group(id, order),
          );
        }
        // Insertion order differs from group order on purpose.
        await repository.addPointsToPlan(
          planId: plan.id,
          points: [_point('c0'), _point('a0'), _point('b0'), _point('b1')],
        );
        for (final (pointId, groupId) in [
          ('a0', 'a'),
          ('b0', 'b'),
          ('b1', 'b'),
          ('c0', 'c'),
        ]) {
          await repository.movePointsToGroup(
            planId: plan.id,
            pointIds: {pointId},
            groupId: groupId,
          );
        }
        await repository.setCurrentPoint(planId: plan.id, pointId: 'a0');
        await repository.completePoints(planId: plan.id, pointIds: {'b0'});
        await repository.completePoints(planId: plan.id, pointIds: {'a0'});
        plan = (await repository.loadPlans()).singleWhere(
          (candidate) => candidate.id == plan.id,
        );
        expect(plan.currentPointId, 'b1');

        plan = await repository.deletePointsFromPlan(
          planId: plan.id,
          pointIds: {'b1'},
        );
        expect(plan.currentPointId, 'c0');
      });

      test('group reorder and batch assignment are applied together', () async {
        final repository = create();
        var plan = await repository.createPlan(name: 'Batch', area: 'Area');
        for (final (id, order) in [('a', 0), ('b', 1)]) {
          await repository.createPlanGroup(
            planId: plan.id,
            group: _group(id, order),
          );
        }
        await repository.addPointsToPlan(
          planId: plan.id,
          points: [_point('p0'), _point('p1'), _point('p2')],
        );
        plan = await repository.assignPointsToGroups(
          planId: plan.id,
          groupIdsByPointId: {'p0': 'b', 'p1': 'a', 'p2': 'b'},
        );
        expect(_find(plan, 'p0').groupId, 'b');
        expect(_find(plan, 'p0').groupOrderIndex, 0);
        expect(_find(plan, 'p2').groupOrderIndex, 1);
        expect(_find(plan, 'p1').groupId, 'a');

        plan = await repository.reorderGroups(
          planId: plan.id,
          orderedGroupIds: ['b', 'a'],
        );
        final orders = {
          for (final group in plan.groups) group.id: group.orderIndex,
        };
        expect(orders, {'b': 0, 'a': 1});

        await expectLater(
          repository.reorderGroups(planId: plan.id, orderedGroupIds: ['a']),
          throwsArgumentError,
        );
        await expectLater(
          repository.assignPointsToGroups(
            planId: plan.id,
            groupIdsByPointId: {'p0': null, 'p1': 'missing'},
          ),
          throwsArgumentError,
        );
        plan = (await repository.loadPlans()).singleWhere(
          (candidate) => candidate.id == plan.id,
        );
        expect(_find(plan, 'p0').groupId, 'b');
      });
    });
  }
}
