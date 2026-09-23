import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/data/sample_pilgrimage_repository.dart';
import 'package:miriago/desktop/desktop_pilgrimage_repository.dart';
import 'package:miriago/desktop/desktop_repository_state.dart';
import 'package:miriago/plan/pilgrimage_models.dart';

void main() {
  late _Storage storage;
  late DesktopPilgrimageRepository repository;

  setUp(() {
    storage = _Storage();
    repository = DesktopPilgrimageRepository(
      snapshot: SamplePilgrimageRepository(visitRecords: []).snapshot(),
      persistence: storage,
    );
  });

  String state() => encodeDesktopRepositoryState(repository.snapshot());

  test('failed plan persistence leaves committed state unchanged', () async {
    final before = state();
    storage.fail = true;
    await expectLater(
      repository.createPlan(name: 'Not saved', area: 'Area'),
      throwsStateError,
    );
    expect(state(), before);
    storage.fail = false;
    await repository.createPlan(name: 'Saved', area: 'Area');
    expect(
      (await repository.loadPlans()).map((p) => p.name),
      isNot(contains('Not saved')),
    );
    expect((await repository.loadActivePlan()).name, 'Saved');
  });

  test('rename persists once without virtual re-entry', () async {
    final plan = await repository.loadActivePlan();
    await repository.renamePlan(planId: plan.id, name: 'Renamed');
    expect(storage.calls, ['plan']);
    expect((await repository.loadActivePlan()).name, 'Renamed');
  });

  test('editing a point persists its updated information', () async {
    final plan = await repository.loadActivePlan();
    final point = plan.points.first.copyWith(name: 'Edited point');
    await repository.updatePointInPlan(planId: plan.id, point: point);
    expect(storage.calls, ['plan']);
    final saved = jsonDecode(storage.lastPlan!) as Map<String, dynamic>;
    expect((saved['points'] as List).first['name'], 'Edited point');
    final before = state();
    storage.fail = true;
    await expectLater(
      repository.updatePointInPlan(
        planId: plan.id,
        point: point.copyWith(name: 'Failed'),
      ),
      throwsStateError,
    );
    expect(state(), before);
  });

  test(
    'failed settings writes are not visible and do not poison the queue',
    () async {
      final before = await repository.loadAppSettings();
      storage.fail = true;
      await expectLater(
        repository.saveAppSettings(before.copyWith(fontScale: 1.2)),
        throwsStateError,
      );
      expect(await repository.loadAppSettings(), same(before));
      storage.fail = false;
      await repository.saveAppSettings(before.copyWith(fontScale: 1.1));
      expect((await repository.loadAppSettings()).fontScale, 1.1);
    },
  );

  test(
    'pending mutation is invisible and following writes use the committed result',
    () async {
      final plan = await repository.loadActivePlan();
      final gate = storage.gate = Completer<void>();
      final first = repository.renamePlan(planId: plan.id, name: 'First');
      await storage.started.future;
      final second = repository.updatePlanMemo(planId: plan.id, memo: 'Second');
      expect((await repository.loadActivePlan()).name, plan.name);
      expect(storage.calls, ['plan']);
      gate.complete();
      await first;
      await second;
      final result = await repository.loadActivePlan();
      expect(result.name, 'First');
      expect(result.memo, 'Second');
      expect(storage.calls, ['plan', 'plan']);
    },
  );

  test(
    'queued mutation does not inherit changes from a rejected write',
    () async {
      final plan = await repository.loadActivePlan();
      final gate = storage.gate = Completer<void>();
      final first = repository.renamePlan(planId: plan.id, name: 'Rejected');
      final rejected = expectLater(first, throwsStateError);
      await storage.started.future;
      final second = repository.updatePlanMemo(planId: plan.id, memo: 'Kept');
      gate.completeError(StateError('disk full'));
      await rejected;
      await second;
      final result = await repository.loadActivePlan();
      expect(result.name, plan.name);
      expect(result.memo, 'Kept');
    },
  );

  test(
    'active plan, order and deletion remain unchanged when writes fail',
    () async {
      final first = await repository.loadActivePlan();
      final second = await repository.createPlan(name: 'Second', area: 'Area');
      final before = state();
      storage.fail = true;
      await expectLater(repository.setActivePlan(first.id), throwsStateError);
      expect(state(), before);
      await expectLater(
        repository.reorderPlans(orderedPlanIds: [second.id, first.id]),
        throwsStateError,
      );
      expect(state(), before);
      await expectLater(repository.deletePlan(second.id), throwsStateError);
      expect(state(), before);
      await expectLater(
        repository.completePoint(
          planId: first.id,
          pointId: first.points.first.id,
          nextCurrentPointId: null,
        ),
        throwsStateError,
      );
      expect(state(), before);
    },
  );

  test('record creation and deletion publish only after persistence', () async {
    final plan = await repository.loadActivePlan();
    final point = plan.points.first;
    Future<PilgrimageVisitRecord> create() => repository.createVisitRecord(
      planId: plan.id,
      pointId: point.id,
      workId: point.work.id,
      photoPath: 'photo.jpg',
      referenceMode: 'overlay',
    );
    storage.fail = true;
    await expectLater(create(), throwsStateError);
    expect(await repository.loadVisitRecords(plan.id), isEmpty);
    storage.fail = false;
    final record = await create();
    expect(await repository.loadVisitRecords(plan.id), hasLength(1));
    storage.fail = true;
    await expectLater(
      repository.deleteVisitRecord(planId: plan.id, recordId: record.id),
      throwsStateError,
    );
    expect((await repository.loadVisitRecords(plan.id)).single.id, record.id);
  });

  test('failed import does not publish the plan or its records', () async {
    final plan = await repository.loadActivePlan();
    final before = state();
    storage.fail = true;
    await expectLater(
      repository.importPlanPackage(plan: plan, visitRecords: []),
      throwsStateError,
    );
    expect(state(), before);
  });
}

class _Storage extends DesktopRepositoryPersistence {
  bool fail = false;
  Completer<void>? gate;
  final started = Completer<void>();
  final calls = <String>[];
  String? lastPlan;

  Future<void> _save(String kind) async {
    calls.add(kind);
    if (!started.isCompleted) started.complete();
    final pending = gate;
    gate = null;
    if (pending != null) await pending.future;
    if (fail) throw StateError('disk full');
  }

  @override
  Future<void> saveState(String json) => _save('state');
  @override
  Future<void> saveSettings(String json) => _save('settings');
  @override
  Future<void> savePlan(String plan, String records, String? activeId) async {
    await _save('plan');
    lastPlan = plan;
  }

  @override
  Future<void> setActivePlan(String id) => _save('active');
  @override
  Future<void> deletePlan(String id, String? activeId) => _save('delete-plan');
  @override
  Future<void> saveRecord(String json) => _save('record');
  @override
  Future<void> deleteRecord(String id) => _save('delete-record');
}
