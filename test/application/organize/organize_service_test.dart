import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:miriago/application/organize/organize_service.dart';
import 'package:miriago/application/plan_session.dart';
import 'package:miriago/data/pilgrimage_repository.dart';
import 'package:miriago/data/sample_pilgrimage_repository.dart';
import 'package:miriago/plan/pilgrimage_models.dart';

const _stationGroup = 'sample-group-uji-station';
const _daikichiGroup = 'sample-group-daikichiyama';
const _ungroupedPoint = 'anitabi-115908-sample-unassigned-02';

class _FailingRepository extends SamplePilgrimageRepository {
  final Set<String> failing = {};
  Completer<void>? gate;

  Future<void> _maybeFail(String name) async {
    final pending = gate;
    if (pending != null) await pending.future;
    if (failing.contains(name)) throw StateError('$name failed');
  }

  @override
  Future<PilgrimagePlan> reorderGroups({
    required String planId,
    required List<String> orderedGroupIds,
  }) async {
    await _maybeFail('reorderGroups');
    return super.reorderGroups(
      planId: planId,
      orderedGroupIds: orderedGroupIds,
    );
  }

  @override
  Future<PilgrimagePlan> movePointsToGroup({
    required String planId,
    required Set<String> pointIds,
    required String? groupId,
  }) async {
    await _maybeFail('movePointsToGroup');
    return super.movePointsToGroup(
      planId: planId,
      pointIds: pointIds,
      groupId: groupId,
    );
  }

  @override
  Future<PilgrimagePlan> assignPointsToGroups({
    required String planId,
    required Map<String, String?> groupIdsByPointId,
  }) async {
    await _maybeFail('assignPointsToGroups');
    return super.assignPointsToGroups(
      planId: planId,
      groupIdsByPointId: groupIdsByPointId,
    );
  }

  @override
  Future<PilgrimagePlan> createPlanGroup({
    required String planId,
    required PilgrimagePlanGroup group,
  }) async {
    await _maybeFail('createPlanGroup');
    return super.createPlanGroup(planId: planId, group: group);
  }

  @override
  Future<void> completePoints({
    required String planId,
    required Set<String> pointIds,
  }) async {
    await _maybeFail('completePoints');
    return super.completePoints(planId: planId, pointIds: pointIds);
  }
}

void main() {
  late _FailingRepository repository;
  late PlanSession session;
  late OrganizeService service;
  late List<List<String>> reclaimed;

  setUp(() async {
    repository = _FailingRepository();
    session = PlanSession(repository: repository);
    await session.load();
    reclaimed = [];
    service = OrganizeService(
      session: session,
      reclaimFiles:
          ({
            required PilgrimageRepository repository,
            required Iterable<PilgrimagePoint> points,
          }) async {
            reclaimed.add([for (final point in points) point.id]);
          },
    );
  });

  tearDown(() {
    service.dispose();
    session.dispose();
  });

  PilgrimagePlanGroup groupById(String id) =>
      session.plan.groups.firstWhere((group) => group.id == id);

  PilgrimagePoint point(String id) =>
      session.plan.points.firstWhere((point) => point.id == id);

  group('groups', () {
    test('creates a group at the end with a new id', () async {
      final maxOrder = session.plan.groups
          .map((group) => group.orderIndex)
          .reduce((a, b) => a > b ? a : b);
      final created = await service.createGroup('  新片区  ');
      expect(created, isNotNull);
      expect(created!.name, '新片区');
      expect(created.id, startsWith('group-'));
      expect(created.orderIndex, maxOrder + 1);
      expect(
        session.plan.groups.map((group) => group.id),
        contains(created.id),
      );
      expect(nextGroupOrderIndex(const []), 0);
    });

    test('create failure throws 「片区创建失败」', () async {
      repository.failing.add('createPlanGroup');
      await expectLater(
        service.createGroup('x'),
        throwsA(
          isA<OrganizeFailure>().having((f) => f.message, 'message', '片区创建失败'),
        ),
      );
      expect(service.isSaving, isFalse);
    });

    test('renames, ignoring blank and unchanged names', () async {
      final target = groupById(_stationGroup);
      expect(await service.renameGroup(target, '   '), isFalse);
      expect(await service.renameGroup(target, target.name), isFalse);
      expect(await service.renameGroup(target, '车站'), isTrue);
      expect(groupById(_stationGroup).name, '车站');
    });

    test('sets the order mode', () async {
      final target = groupById(_stationGroup);
      expect(target.orderMode, PlanGroupOrderMode.unordered);
      await service.setOrderMode(target, PlanGroupOrderMode.manual);
      expect(groupById(_stationGroup).orderMode, PlanGroupOrderMode.manual);
    });

    test('sets a manual anchor and clears it (Δ6)', () async {
      await service.setAnchor(
        groupById(_stationGroup),
        name: '手动关键点',
        position: const LatLng(34.9, 135.8),
        pointId: null,
      );
      var stored = groupById(_stationGroup);
      expect(stored.anchorName, '手动关键点');
      expect(stored.anchorLatitude, 34.9);
      expect(stored.anchorPointId, isNull);

      await service.setAnchor(
        stored,
        name: null,
        position: null,
        pointId: null,
      );
      stored = (await repository.loadActivePlan()).groups.firstWhere(
        (group) => group.id == _stationGroup,
      );
      expect(stored.anchorName, isNull);
      expect(stored.anchorLatitude, isNull);
      expect(stored.anchorLongitude, isNull);
      expect(stored.anchorPointId, isNull);
    });

    test('deleting a group moves its points to 未分配', () async {
      final ids = session.plan.points
          .where((point) => point.groupId == _daikichiGroup)
          .map((point) => point.id)
          .toList();
      expect(ids, isNotEmpty);
      await service.deleteGroup(groupById(_daikichiGroup));
      expect(session.plan.groups.any((g) => g.id == _daikichiGroup), isFalse);
      for (final id in ids) {
        expect(point(id).groupId, isNull);
      }
    });

    test('reorders groups atomically', () async {
      final ids = [
        for (final group
            in session.plan.groups.toList()
              ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex)))
          group.id,
      ];
      final reversed = ids.reversed.toList();
      expect(await service.reorderGroups(reversed), isTrue);
      final sorted = session.plan.groups.toList()
        ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
      expect(sorted.map((group) => group.id), reversed);
    });

    test('reorder failure reloads and throws 「片区顺序保存失败」', () async {
      repository.failing.add('reorderGroups');
      final revision = session.revision;
      await expectLater(
        service.reorderGroups(
          session.plan.groups
              .map((group) => group.id)
              .toList()
              .reversed
              .toList(),
        ),
        throwsA(
          isA<OrganizeFailure>().having(
            (f) => f.message,
            'message',
            '片区顺序保存失败',
          ),
        ),
      );
      expect(session.revision, greaterThan(revision), reason: 'reloaded');
    });
  });

  group('points', () {
    test('moves points and reports 「移动片区失败」', () async {
      expect(
        await service.movePoints({_ungroupedPoint}, _stationGroup),
        isTrue,
      );
      expect(point(_ungroupedPoint).groupId, _stationGroup);

      repository.failing.add('movePointsToGroup');
      await expectLater(
        service.movePoints({_ungroupedPoint}, null),
        throwsA(
          isA<OrganizeFailure>().having((f) => f.message, 'message', '移动片区失败'),
        ),
      );
    });

    test('box assignment uses 「框选分配失败」', () async {
      repository.failing.add('movePointsToGroup');
      await expectLater(
        service.assignBox({_ungroupedPoint}, _stationGroup),
        throwsA(
          isA<OrganizeFailure>().having((f) => f.message, 'message', '框选分配失败'),
        ),
      );
    });

    test('batch complete and reopen refresh the runtime state', () async {
      final ids = {_ungroupedPoint, 'anitabi-115908-7gs3o1mm'};
      expect(await service.completePoints(ids), isTrue);
      for (final id in ids) {
        expect(session.controller.statusFor(point(id)), VisitStatus.completed);
      }
      expect(await service.reopenPoints(ids), isTrue);
      for (final id in ids) {
        expect(
          session.controller.statusFor(point(id)),
          isNot(VisitStatus.completed),
        );
      }
    });

    test('batch complete failure throws 「批量完成失败」', () async {
      repository.failing.add('completePoints');
      await expectLater(
        service.completePoints({_ungroupedPoint}),
        throwsA(
          isA<OrganizeFailure>().having((f) => f.message, 'message', '批量完成失败'),
        ),
      );
    });

    test(
      'completing the current target moves it to the next pending',
      () async {
        final current = session.controller.currentPoint!;
        await service.complete(current);
        expect(
          session.controller.statusFor(point(current.id)),
          VisitStatus.completed,
        );
        expect(session.plan.currentPointId, isNot(current.id));
      },
    );

    test('deleting points reclaims their files after the delete', () async {
      final ids = {_ungroupedPoint, 'anitabi-115908-7gs3o1mm'};
      expect(await service.deletePoints(ids), isTrue);
      expect(session.plan.points.any((p) => ids.contains(p.id)), isFalse);
      await Future<void>.delayed(Duration.zero);
      expect(reclaimed.single.toSet(), ids);
    });

    test('a second write while saving is ignored', () async {
      repository.gate = Completer<void>();
      final first = service.movePoints({_ungroupedPoint}, _stationGroup);
      expect(service.isSaving, isTrue);
      expect(await service.movePoints({_ungroupedPoint}, null), isFalse);
      repository.gate!.complete();
      expect(await first, isTrue);
      expect(service.isSaving, isFalse);
    });
  });

  group('nearest assignment', () {
    test('assigns atomically and saves the distance afterwards', () async {
      var saved = false;
      final result = await service.assignNearest({
        _ungroupedPoint: _stationGroup,
      }, saveDistance: () async => saved = true);
      expect(result?.count, 1);
      expect(result?.settingsSaved, isTrue);
      expect(saved, isTrue);
      expect(point(_ungroupedPoint).groupId, _stationGroup);
    });

    test('a failed distance save is reported, not thrown', () async {
      final result = await service.assignNearest({
        _ungroupedPoint: _stationGroup,
      }, saveDistance: () async => throw StateError('disk full'));
      expect(result?.settingsSaved, isFalse);
    });

    test('assignment failure throws 「最近分配失败」 and keeps the distance', () async {
      repository.failing.add('assignPointsToGroups');
      var saved = false;
      await expectLater(
        service.assignNearest({
          _ungroupedPoint: _stationGroup,
        }, saveDistance: () async => saved = true),
        throwsA(
          isA<OrganizeFailure>().having((f) => f.message, 'message', '最近分配失败'),
        ),
      );
      expect(saved, isFalse);
      expect(point(_ungroupedPoint).groupId, isNull);
    });
  });
}
