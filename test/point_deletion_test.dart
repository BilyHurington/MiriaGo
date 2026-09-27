import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:miriago/app_theme.dart';
import 'package:miriago/data/local/app_database.dart';
import 'package:miriago/data/local/sqlite_pilgrimage_repository.dart';
import 'package:miriago/data/sample_pilgrimage_repository.dart';
import 'package:miriago/desktop/desktop_repository_state.dart';
import 'package:miriago/plan/pilgrimage_models.dart';
import 'package:miriago/plan/pilgrimage_plan_controller.dart';
import 'package:miriago/point_detail/point_detail_sheet.dart';
import 'package:miriago/widgets/confirm_action_dialog.dart';

const _work = PilgrimageWork(
  id: 'delete-work',
  title: 'Deletion work',
  subtitle: 'Work snapshot',
  city: '',
  source: WorkSource.manual,
);

const _point = PilgrimagePoint(
  id: 'delete-point',
  work: _work,
  name: 'Deletion point',
  subtitle: 'Point snapshot',
  position: LatLng(35, 135),
  episodeLabel: 'EP 1',
  referenceLabel: 'Manual',
);

final _deleteButton = find.byKey(const ValueKey('point-detail-delete'));

Future<NavigatorState> _openSheet(
  WidgetTester tester,
  Future<void> Function(PilgrimagePoint) onDelete,
) async {
  final navigatorKey = GlobalKey<NavigatorState>();
  await tester.pumpWidget(
    MaterialApp(
      navigatorKey: navigatorKey,
      theme: AppTheme.light(),
      home: const Scaffold(body: Text('Home')),
    ),
  );
  final navigator = navigatorKey.currentState!;
  unawaited(
    navigator.push<void>(
      MaterialPageRoute<void>(
        builder: (context) => Scaffold(
          body: FilledButton(
            onPressed: () => PointDetailSheet.show(
              context,
              point: _point,
              status: VisitStatus.pending,
              onReplaceReference: (_, _) async {},
              onDelete: onDelete,
            ),
            child: const Text('Open point'),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Open point'));
  await tester.pumpAndSettle();
  return navigator;
}

Future<void> _confirmDeletion(WidgetTester tester) async {
  await tester.tap(_deleteButton);
  await tester.pumpAndSettle();
  await tester.tap(
    find
        .descendant(
          of: find.byType(ConfirmActionDialog),
          matching: find.byType(FilledButton),
        )
        .last,
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('cancel keeps the point and explains that history is retained', (
    tester,
  ) async {
    var calls = 0;
    await _openSheet(tester, (_) async => calls++);
    await tester.tap(_deleteButton);
    await tester.pumpAndSettle();

    final dialog = tester.widget<ConfirmActionDialog>(
      find.byType(ConfirmActionDialog),
    );
    expect(dialog.message, contains('已有巡礼记录及照片将保留'));
    expect(dialog.destructive, isTrue);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(calls, 0);
    expect(find.byType(PointDetailSheet), findsOneWidget);
    expect(tester.widget<IconButton>(_deleteButton).onPressed, isNotNull);
  });

  testWidgets('guards stale callbacks before confirmation and while deleting', (
    tester,
  ) async {
    final pending = Completer<void>();
    var calls = 0;
    PilgrimagePoint? deletedPoint;
    await _openSheet(tester, (point) {
      deletedPoint = point;
      calls++;
      return pending.future;
    });
    final staleOnPressed = tester.widget<IconButton>(_deleteButton).onPressed!;
    staleOnPressed();
    staleOnPressed();
    await tester.pumpAndSettle();
    expect(find.byType(ConfirmActionDialog), findsOneWidget);
    expect(calls, 0);
    await tester.tap(
      find
          .descendant(
            of: find.byType(ConfirmActionDialog),
            matching: find.byType(FilledButton),
          )
          .last,
    );
    await tester.pumpAndSettle();

    expect(find.byType(ConfirmActionDialog), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
    expect(calls, 1);
    expect(deletedPoint?.id, _point.id);
    expect(tester.widget<IconButton>(_deleteButton).onPressed, isNull);
    expect(find.byTooltip('正在删除点位'), findsOneWidget);
    staleOnPressed();
    await tester.tap(_deleteButton);
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.byType(ConfirmActionDialog), findsNothing);

    pending.complete();
    await tester.pumpAndSettle();
    expect(find.byType(PointDetailSheet), findsNothing);
    expect(find.text('Open point'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failure keeps the sheet open and allows a successful retry', (
    tester,
  ) async {
    final pending = Completer<void>();
    var calls = 0;
    await _openSheet(tester, (_) {
      calls++;
      return calls == 1 ? pending.future : Future<void>.value();
    });
    await _confirmDeletion(tester);
    pending.completeError(StateError('delete failed'));
    await tester.pumpAndSettle();

    expect(find.byType(PointDetailSheet), findsOneWidget);
    expect(find.text('删除点位失败，请稍后重试'), findsOneWidget);
    expect(tester.widget<IconButton>(_deleteButton).onPressed, isNotNull);
    await _confirmDeletion(tester);
    expect(calls, 2);
    expect(find.byType(PointDetailSheet), findsNothing);
    expect(find.text('Open point'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final fail in [false, true]) {
    for (final finishDismissal in [false, true]) {
      testWidgets(
        'completion after dismissal: fail=$fail, disposed=$finishDismissal',
        (tester) async {
          final pending = Completer<void>();
          final navigator = await _openSheet(tester, (_) => pending.future);
          await _confirmDeletion(tester);
          final element = tester.element(find.byType(PointDetailSheet));
          final route = ModalRoute.of(element)!;
          navigator.pop();
          if (finishDismissal) {
            await tester.pumpAndSettle();
            expect(element.mounted, isFalse);
          } else {
            // Reproduce the mounted-but-already-popped exit animation window.
            expect(element.mounted, isTrue);
          }
          expect(route.isCurrent, isFalse);
          if (fail) {
            pending.completeError(StateError('late failure'));
          } else {
            pending.complete();
          }
          await tester.pumpAndSettle();

          expect(find.text('Open point'), findsOneWidget);
          expect(navigator.canPop(), isTrue);
          expect(find.byType(PointDetailSheet), findsNothing);
          expect(find.byType(SnackBar), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('completion does not pop a newer route above the sheet', (
    tester,
  ) async {
    final pending = Completer<void>();
    final navigator = await _openSheet(tester, (_) => pending.future);
    await _confirmDeletion(tester);
    unawaited(
      navigator.push<void>(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('New page')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    pending.complete();
    await tester.pumpAndSettle();
    expect(find.text('New page'), findsOneWidget);

    navigator.pop();
    await tester.pumpAndSettle();
    expect(find.byType(PointDetailSheet), findsNothing);
    expect(find.text('Open point'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('confirmation cannot delete after its sheet has been removed', (
    tester,
  ) async {
    var calls = 0;
    final navigator = await _openSheet(tester, (_) async => calls++);
    final route = ModalRoute.of(tester.element(find.byType(PointDetailSheet)))!;
    await tester.tap(_deleteButton);
    await tester.pumpAndSettle();
    navigator.removeRoute(route);
    await tester.pumpAndSettle();
    await tester.tap(
      find
          .descendant(
            of: find.byType(ConfirmActionDialog),
            matching: find.byType(FilledButton),
          )
          .last,
    );
    await tester.pumpAndSettle();

    expect(calls, 0);
    expect(find.text('Open point'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test(
    'delayed SQLite deletion preserves a newer current target and status',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final repository = _DelayedDeleteSqliteRepository(database);
      final emptyPlan = await repository.createPlan(
        name: 'Delayed deletion',
        area: '',
      );
      final target = _point.copyWith(id: 'point-b', name: 'New target');
      final fallback = _point.copyWith(id: 'point-c', name: 'Old fallback');
      await repository.addPointsToPlan(
        planId: emptyPlan.id,
        points: [_point, target, fallback],
      );
      await repository.completePoint(
        planId: emptyPlan.id,
        pointId: target.id,
        nextCurrentPointId: _point.id,
      );
      final plan = (await repository.loadPlans()).singleWhere(
        (plan) => plan.id == emptyPlan.id,
      );
      final controller = PilgrimagePlanController(
        plan: plan,
        visitRepository: repository,
      );
      addTearDown(controller.dispose);
      await controller.loadVisitRecords();
      final deletion = controller.deletePoint(_point);
      try {
        final snapshot = await repository.deleteSnapshotReady.future;
        expect(snapshot.currentPointId, fallback.id);
        expect(snapshot.completedPointIds, contains(target.id));

        controller.setCurrentPoint(target);
        await repository.latestSetCurrent;
        expect(controller.currentPoint?.id, target.id);
        expect(controller.completedPointIds, isNot(contains(target.id)));
      } finally {
        repository.finishDelete.complete();
        await deletion;
      }

      expect(controller.points.map((point) => point.id), [
        target.id,
        fallback.id,
      ]);
      expect(controller.currentPoint?.id, target.id);
      expect(controller.selectedPoint?.id, target.id);
      expect(controller.statusFor(target), VisitStatus.current);
      expect(controller.completedPointIds, isEmpty);
      expect(controller.plan.currentPointId, target.id);
      expect(controller.plan.completedPointIds, isEmpty);
      final persisted = (await repository.loadPlans()).singleWhere(
        (plan) => plan.id == emptyPlan.id,
      );
      expect(persisted.currentPointId, controller.plan.currentPointId);
      expect(persisted.completedPointIds, controller.completedPointIds);
    },
  );

  group('interleaved deletion', () {
    final target = _point.copyWith(id: 'point-b', name: 'Target B');
    final other = _point.copyWith(id: 'point-c', name: 'Target C');
    late _InterleavedDeleteRepository repository;
    late PilgrimagePlanController controller;
    final pendingDeletions = <Future<void>>[];

    setUp(() async {
      final now = DateTime.utc(2026, 9, 6);
      final plan = PilgrimagePlan(
        id: 'interleaved-plan',
        name: 'Interleaved deletion',
        area: '',
        works: const [_work],
        points: [_point, target, other],
        currentPointId: target.id,
        memo: 'Original memo',
        createdAt: now,
        updatedAt: now,
      );
      repository = _InterleavedDeleteRepository(plan);
      controller = PilgrimagePlanController(
        plan: plan,
        visitRepository: repository,
      );
      await controller.loadVisitRecords();
    });

    tearDown(() async {
      for (final request in repository.requests.values) {
        if (!request.capture.isCompleted) request.capture.complete();
        if (!request.release.isCompleted) request.release.complete();
      }
      await Future.wait(pendingDeletions);
      pendingDeletions.clear();
      controller.dispose();
    });

    Future<void> startDeletion(PilgrimagePoint point) {
      final deletion = controller.deletePoint(point);
      pendingDeletions.add(deletion);
      return deletion;
    }

    Future<void> expectPersistedStateMatches() async {
      final persisted = await repository.loadActivePlan();
      expect(
        controller.points.map((point) => point.id),
        persisted.points.map((point) => point.id),
      );
      expect(controller.plan.currentPointId, persisted.currentPointId);
      expect(controller.completedPointIds, persisted.completedPointIds);
      expect(controller.plan.completedPointIds, persisted.completedPointIds);
      expect(controller.plan.memo, persisted.memo);
    }

    test('target B to C to B survives an intermediate C snapshot', () async {
      final deletion = startDeletion(_point);
      controller.setCurrentPoint(other);
      final request = repository.requests[_point.id]!;
      request.capture.complete();
      final snapshot = await request.snapshotReady.future;
      expect(snapshot.currentPointId, other.id);

      controller.setCurrentPoint(target);
      request.release.complete();
      await deletion;
      expect(controller.currentPoint?.id, target.id);
      expect(controller.selectedPoint?.id, target.id);
      expect(controller.statusFor(target), VisitStatus.current);
      await expectPersistedStateMatches();
    });

    test(
      'complete then reopen survives an intermediate completed snapshot',
      () async {
        final deletion = startDeletion(_point);
        controller.completePoint(target);
        final request = repository.requests[_point.id]!;
        request.capture.complete();
        final snapshot = await request.snapshotReady.future;
        expect(snapshot.completedPointIds, contains(target.id));

        controller.reopenPoint(target);
        request.release.complete();
        await deletion;
        expect(controller.completedPointIds, isEmpty);
        expect(controller.currentPoint?.id, target.id);
        expect(controller.statusFor(target), VisitStatus.current);
        await expectPersistedStateMatches();
      },
    );

    test(
      'late deletion A cannot restore deleted B or select it as fallback',
      () async {
        controller.setCurrentPoint(_point);
        final deletionA = startDeletion(_point);
        final requestA = repository.requests[_point.id]!;
        requestA.capture.complete();
        final snapshotA = await requestA.snapshotReady.future;
        expect(snapshotA.currentPointId, target.id);
        expect(snapshotA.points.map((point) => point.id), contains(target.id));

        final deletionB = startDeletion(target);
        final requestB = repository.requests[target.id]!;
        requestB.capture.complete();
        await requestB.snapshotReady.future;
        requestB.release.complete();
        await deletionB;
        expect(
          controller.points.map((point) => point.id),
          isNot(contains(target.id)),
        );

        requestA.release.complete();
        await deletionA;
        expect(controller.points.map((point) => point.id), [other.id]);
        expect(controller.currentPoint?.id, other.id);
        expect(controller.selectedPoint?.id, other.id);
        await expectPersistedStateMatches();
      },
    );

    test('late deletion cannot overwrite a saved memo', () async {
      final deletion = startDeletion(_point);
      final request = repository.requests[_point.id]!;
      request.capture.complete();
      final snapshot = await request.snapshotReady.future;
      expect(snapshot.memo, 'Original memo');

      await controller.updatePlanMemo('Saved during deletion');
      final savedAt = controller.plan.updatedAt;
      request.release.complete();
      await deletion;
      expect(controller.plan.memo, 'Saved during deletion');
      expect(controller.plan.updatedAt, savedAt);
      expect(controller.points.map((point) => point.id), [target.id, other.id]);
      await expectPersistedStateMatches();
    });
  });

  test(
    'desktop JSON roundtrip retains deleted point history after controller reload',
    () async {
      final capturedAt = DateTime.utc(2026, 9, 6, 12);
      final plan = PilgrimagePlan(
        id: 'desktop-deletion-plan',
        name: 'Desktop deletion',
        area: '',
        works: const [_work],
        points: const [_point],
        completedPointIds: {_point.id},
        createdAt: capturedAt,
        updatedAt: capturedAt,
      );
      final repository = SamplePilgrimageRepository(
        plans: [plan],
        visitRecords: const [],
      );
      final controller = PilgrimagePlanController(
        plan: plan,
        visitRepository: repository,
      );
      late String encoded;
      late PilgrimageVisitRecord record;
      try {
        await controller.loadVisitRecords();
        record = (await controller.createVisitRecord(
          point: _point,
          photoPath: '/desktop/photos/visit.jpg',
          referenceImagePath: '/desktop/references/point.jpg',
          referenceImageUrl: 'https://example.com/reference.jpg',
          referenceMode: 'manual',
          capturedAt: capturedAt,
        ))!;
        await controller.deletePoint(_point);
        expect(controller.points, isEmpty);
        expect(controller.completedPointIds, isEmpty);
        expect(controller.visitRecords, [record]);
        expect(controller.recordsForPoint(_point.id), [record]);
        encoded = encodeDesktopRepositoryState(repository.snapshot());
      } finally {
        controller.dispose();
      }

      final decoded = decodeDesktopRepositoryState(encoded);
      expect(decoded, isNotNull);
      final restoredRepository = SamplePilgrimageRepository(
        plans: decoded!.plans,
        visitRecords: decoded.visitRecords,
        settings: decoded.settings,
        activePlanId: decoded.activePlanId,
      );
      final restoredController = PilgrimagePlanController(
        plan: await restoredRepository.loadActivePlan(),
        visitRepository: restoredRepository,
      );
      try {
        await restoredController.loadVisitRecords();
        expect(restoredController.plan.id, plan.id);
        expect(restoredController.points, isEmpty);
        expect(restoredController.currentPoint, isNull);
        expect(restoredController.selectedPoint, isNull);
        expect(restoredController.completedPointIds, isEmpty);
        expect(restoredController.visitRecords, hasLength(1));
        final restored = restoredController.recordsForPoint(_point.id).single;
        expect(restored.id, record.id);
        expect(restored.planId, plan.id);
        expect(restored.pointName, _point.name);
        expect(restored.workTitle, _work.title);
        expect(restored.photoPath, record.photoPath);
        expect(restored.referenceImagePath, record.referenceImagePath);
        expect(restored.capturedAt.toUtc(), capturedAt);
        expect(
          encodeDesktopVisitRecord(restored),
          encodeDesktopVisitRecord(record),
        );
      } finally {
        restoredController.dispose();
      }
    },
  );

  test(
    'SQLite desktop controller retains history across database reopen',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'point_deletion_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/plan.sqlite');
      final photo = File('${directory.path}/photo.jpg');
      final reference = File('${directory.path}/reference.jpg');
      await photo.writeAsBytes([1, 2, 3]);
      await reference.writeAsBytes([4, 5, 6]);
      final capturedAt = DateTime.utc(2026, 9, 6, 12);
      late String planId;
      late PilgrimageVisitRecord record;
      final database = AppDatabase(NativeDatabase(file));
      try {
        final repository = SqlitePilgrimageRepository(database: database);
        final emptyPlan = await repository.createPlan(
          name: 'Deletion',
          area: '',
        );
        planId = emptyPlan.id;
        await repository.addPointsToPlan(planId: planId, points: [_point]);
        await repository.completePoint(
          planId: planId,
          pointId: _point.id,
          nextCurrentPointId: null,
        );
        final plan = (await repository.loadPlans()).singleWhere(
          (plan) => plan.id == planId,
        );
        final controller = PilgrimagePlanController(
          plan: plan,
          visitRepository: repository,
        );
        try {
          await controller.loadVisitRecords();
          record = (await controller.createVisitRecord(
            point: _point,
            photoPath: photo.path,
            referenceImagePath: reference.path,
            referenceImageUrl: 'https://example.com/reference.jpg',
            referenceMode: 'manual',
            capturedAt: capturedAt,
          ))!;
          expect(controller.completedPointIds, contains(_point.id));
          await controller.deletePoint(_point);

          expect(controller.points, isEmpty);
          expect(controller.currentPoint, isNull);
          expect(controller.selectedPoint, isNull);
          expect(controller.completedPointIds, isEmpty);
          expect(controller.visitRecords, [record]);
          expect(controller.recordsForPoint(_point.id), [record]);
          await controller.loadVisitRecords();
          expect(controller.visitRecords.single.id, record.id);
          expect(controller.recordsForPoint(_point.id).single.id, record.id);
          expect(
            (await repository.loadVisitRecords(planId)).single.id,
            record.id,
          );
        } finally {
          controller.dispose();
        }
      } finally {
        await database.close();
      }

      final reopenedDatabase = AppDatabase(NativeDatabase(file));
      try {
        final repository = SqlitePilgrimageRepository(
          database: reopenedDatabase,
        );
        final plan = (await repository.loadPlans()).singleWhere(
          (plan) => plan.id == planId,
        );
        final controller = PilgrimagePlanController(
          plan: plan,
          visitRepository: repository,
        );
        try {
          await controller.loadVisitRecords();
          expect(controller.points, isEmpty);
          expect(controller.completedPointIds, isEmpty);
          expect(controller.visitRecords, hasLength(1));
          final restored = controller.recordsForPoint(_point.id).single;
          expect(restored.id, record.id);
          expect(restored.planId, planId);
          expect(restored.pointId, _point.id);
          expect(restored.workId, _work.id);
          expect(restored.pointName, _point.name);
          expect(restored.pointSubtitle, _point.subtitle);
          expect(restored.workTitle, _work.title);
          expect(restored.workSubtitle, _work.subtitle);
          expect(restored.photoPath, photo.path);
          expect(restored.referenceImagePath, reference.path);
          expect(restored.referenceImageUrl, record.referenceImageUrl);
          expect(restored.referenceMode, 'manual');
          expect(restored.capturedAt.toUtc(), capturedAt);
          expect(await photo.readAsBytes(), [1, 2, 3]);
          expect(await reference.readAsBytes(), [4, 5, 6]);
        } finally {
          controller.dispose();
        }
      } finally {
        await reopenedDatabase.close();
      }
    },
  );
}

class _DeleteRequest {
  final capture = Completer<void>();
  final snapshotReady = Completer<PilgrimagePlan>();
  final release = Completer<void>();
}

class _InterleavedDeleteRepository extends SamplePilgrimageRepository {
  _InterleavedDeleteRepository(PilgrimagePlan plan)
    : super(plans: [plan], visitRecords: const []);

  final requests = <String, _DeleteRequest>{};

  @override
  Future<PilgrimagePlan> deletePointFromPlan({
    required String planId,
    required String pointId,
  }) async {
    final request = _DeleteRequest();
    requests[pointId] = request;
    await request.capture.future;
    final snapshot = await super.deletePointFromPlan(
      planId: planId,
      pointId: pointId,
    );
    request.snapshotReady.complete(snapshot);
    await request.release.future;
    return snapshot;
  }
}

class _DelayedDeleteSqliteRepository extends SqlitePilgrimageRepository {
  _DelayedDeleteSqliteRepository(AppDatabase database)
    : super(database: database);

  final deleteSnapshotReady = Completer<PilgrimagePlan>();
  final finishDelete = Completer<void>();
  Future<void>? latestSetCurrent;

  @override
  Future<void> setCurrentPoint({
    required String planId,
    required String pointId,
  }) {
    return latestSetCurrent = super.setCurrentPoint(
      planId: planId,
      pointId: pointId,
    );
  }

  @override
  Future<PilgrimagePlan> deletePointFromPlan({
    required String planId,
    required String pointId,
  }) async {
    final snapshot = await super.deletePointFromPlan(
      planId: planId,
      pointId: pointId,
    );
    deleteSnapshotReady.complete(snapshot);
    await finishDelete.future;
    return snapshot;
  }
}
