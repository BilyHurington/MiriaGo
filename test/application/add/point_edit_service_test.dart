import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:miriago/application/add/add_dependencies.dart';
import 'package:miriago/application/add/point_edit_service.dart';
import 'package:miriago/application/plan_session.dart';
import 'package:miriago/plan/pilgrimage_models.dart';

import 'fakes.dart';

void main() {
  group('validateCoordinateField', () {
    String? lat(String v, String other, {bool pending = false}) =>
        validateCoordinateField(
          v,
          other: other,
          latitude: true,
          pending: pending,
        );
    String? lng(String v, String other, {bool pending = false}) =>
        validateCoordinateField(
          v,
          other: other,
          latitude: false,
          pending: pending,
        );

    test('pending skips validation', () {
      expect(lat('', '', pending: true), isNull);
      expect(lng('abc', '', pending: true), isNull);
    });

    test('empty pair without pending asks for both', () {
      expect(lat('', ''), '请填写纬度');
      expect(lng('', ''), '请填写经度');
    });

    test('half-filled pair asks for the other half', () {
      expect(lat('', '135.1'), '请同时填写纬度');
      expect(lng('', '35.1'), '请同时填写经度');
    });

    test('malformed values', () {
      expect(lat('abc', '135'), '纬度格式不正确');
      expect(lat('91', '135'), '纬度格式不正确');
      expect(lng('181', '35'), '经度格式不正确');
      expect(lat('３５．０', '135'), isNull);
    });

    test('the reserved pending position is not a valid coordinate', () {
      expect(lat('-90', '0'), '请输入有效坐标');
      expect(lng('0', '-90'), isNull);
    });
  });

  test('planCenterFor averages positioned points, else (35, 135)', () {
    final plan = PilgrimagePlan(
      id: 'p',
      name: 'p',
      area: 'a',
      works: const [],
      points: const [],
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    expect(planCenterFor(plan), const LatLng(35, 135));
  });

  test('clipboard coordinates produce the old toasts', () async {
    final filled = await readClipboardCoordinate(
      reader: () async => const LatLng(35, 135),
    );
    expect(filled.position, const LatLng(35, 135));
    expect(filled.notice.title, '已填入坐标。');
    final empty = await readClipboardCoordinate(reader: () async => null);
    expect(empty.notice.title, '剪贴板中没有有效坐标。');
    final broken = await readClipboardCoordinate(
      reader: () async => throw StateError('no clipboard'),
    );
    expect(broken.notice.title, '无法读取剪贴板。');
  });

  group('PointEditSession', () {
    late ScriptedRepository repository;
    late PlanSession session;
    late FakeImageStore images;
    final clock = DateTime.fromMicrosecondsSinceEpoch(1234);

    setUp(() async {
      repository = ScriptedRepository();
      session = PlanSession(repository: repository);
      await session.load();
      images = FakeImageStore();
    });

    tearDown(() => session.dispose());

    PointEditSession create({PilgrimagePoint? editing}) {
      final edit = PointEditSession(
        session: session,
        editingPoint: editing,
        imageStore: images.store,
        clock: () => clock,
      );
      addTearDown(() {
        if (!edit.isDisposed) edit.dispose();
      });
      return edit;
    }

    test('new point uses manual defaults and pending position', () async {
      final edit = create();
      expect(edit.initialWork()?.bangumiId, sampleBangumiId);
      final result = await edit.save(
        PointFormValues(
          work: edit.initialWork(),
          name: ' 新点位 ',
          coordinatesPending: true,
        ),
      );
      expect(result.status, PointSaveStatus.saved);
      final point = session.plan.points.firstWhere(
        (p) => p.id == 'manual-1234',
      );
      expect(point.name, '新点位');
      expect(point.referenceLabel, '手动录入');
      expect(point.source, PointSource.manual);
      expect(point.hasCoordinate, isFalse);
      expect(point.note, isNull);
      expect(edit.isBusy, isTrue, reason: 'saved forms stay locked');
    });

    test('paired coordinates and optional fields are stored', () async {
      final edit = create();
      await edit.save(
        PointFormValues(
          work: edit.initialWork(),
          name: '宇治橋',
          latitude: '34.89',
          longitude: '135.80',
          coordinatesPending: false,
          subtitle: '宇治橋西詰',
          episodeLabel: 'EP 1',
          referenceLabel: 'Bilibili@x',
          note: ' 早上人少 ',
        ),
      );
      final point = session.plan.points.firstWhere(
        (p) => p.id == 'manual-1234',
      );
      expect(point.position, const LatLng(34.89, 135.80));
      expect(point.subtitle, '宇治橋西詰');
      expect(point.episodeLabel, 'EP 1');
      expect(point.referenceLabel, 'Bilibili@x');
      expect(point.note, '早上人少');
    });

    test('without a work a manual work is created inline', () async {
      final edit = create();
      await edit.save(
        const PointFormValues(
          newWorkTitle: '轻音少女',
          name: '丰乡小学',
          coordinatesPending: true,
        ),
      );
      final point = session.plan.points.firstWhere(
        (p) => p.id == 'manual-1234',
      );
      expect(point.work.id, 'manual-work-1234');
      expect(point.work.subtitle, '暂无作品原名');
      expect(point.work.city, session.plan.area);
      expect(session.plan.works.any((w) => w.id == 'manual-work-1234'), isTrue);
    });

    test('editing updates the point and keeps its identity', () async {
      final original = session.plan.points.first;
      final edit = create(editing: original);
      expect(edit.isEditing, isTrue);
      final result = await edit.save(
        PointFormValues(
          work: edit.initialWork(),
          name: '改名',
          latitude: '35',
          longitude: '135.5',
          coordinatesPending: false,
          referenceLabel: original.referenceLabel,
        ),
      );
      expect(result.status, PointSaveStatus.saved);
      final updated = session.plan.points.firstWhere(
        (p) => p.id == original.id,
      );
      expect(updated.name, '改名');
      expect(updated.position, const LatLng(35, 135.5));
      expect(updated.source, original.source);
      expect(session.plan.points.length, 27);
    });

    test('failed new save before persistence can be retried', () async {
      repository.failAdd = true;
      final edit = create();
      final values = PointFormValues(
        work: edit.initialWork(),
        name: 'A',
        coordinatesPending: true,
      );
      final result = await edit.save(values);
      // The write itself threw: the result is uncertain for a new point.
      expect(result.status, PointSaveStatus.uncertain);
      expect(result.notice?.title, '保存结果未确认，请返回并刷新计划，检查点位是否已添加。');
      expect(edit.isSaveLocked, isTrue);
      repository.failAdd = false;
      final again = await edit.save(values);
      expect(again.status, PointSaveStatus.ignored);
      expect(repository.addPointCalls, 1);
    });

    test('failed edit is retryable and says 点位保存失败', () async {
      repository.failUpdate = true;
      final edit = create(editing: session.plan.points.first);
      final values = PointFormValues(
        work: edit.initialWork(),
        name: 'B',
        coordinatesPending: true,
      );
      final result = await edit.save(values);
      expect(result.status, PointSaveStatus.failed);
      expect(result.notice?.kind, AddNoticeKind.error);
      expect(result.notice?.title, '点位保存失败，请稍后重试。');
      expect(edit.isSaveLocked, isFalse);
      repository.failUpdate = false;
      expect((await edit.save(values)).status, PointSaveStatus.saved);
    });

    test('picked image is used on save and never deleted', () async {
      final edit = create();
      expect(await edit.pickReferenceImage(), isNull);
      final pending = edit.pendingImage!;
      expect(pending.thumbnailBytes, isNotEmpty);
      await edit.save(
        PointFormValues(
          work: edit.initialWork(),
          name: 'C',
          coordinatesPending: true,
        ),
      );
      final point = session.plan.points.firstWhere(
        (p) => p.id == 'manual-1234',
      );
      expect(point.referenceThumbnailPath, pending.stored.thumbnailPath);
      expect(point.referenceFullImagePath, pending.stored.fullImagePath);
      edit.dispose();
      await pumpEventQueue();
      expect(images.deleted, isEmpty);
    });

    test('re-picking and removing delete only unsaved images', () async {
      final edit = create();
      await edit.pickReferenceImage();
      final first = edit.pendingImage!.stored;
      await edit.pickReferenceImage();
      await pumpEventQueue();
      expect(images.deleted, [first]);
      final second = edit.pendingImage!.stored;
      edit.removeReferenceImage();
      await pumpEventQueue();
      expect(edit.pendingImage, isNull);
      expect(images.deleted, [first, second]);
    });

    test('cancelling deletes the unsaved image', () async {
      final edit = create();
      await edit.pickReferenceImage();
      final stored = edit.pendingImage!.stored;
      edit.dispose();
      await pumpEventQueue();
      expect(images.deleted, [stored]);
    });

    test('read failure reports 参考图读取失败 and cleans up', () async {
      images.failRead = true;
      final edit = create();
      final notice = await edit.pickReferenceImage();
      expect(notice?.title, '参考图读取失败，请重新选择。');
      expect(edit.pendingImage, isNull);
      expect(images.deleted, images.stored);
    });

    test('dispose during image storage cleans the late result', () async {
      images.storeGate = Completer<void>();
      final edit = create();
      final pick = edit.pickReferenceImage();
      await pumpEventQueue();
      edit.dispose();
      images.storeGate!.complete();
      await pick;
      await pumpEventQueue();
      expect(images.stored, hasLength(1));
      expect(images.deleted, images.stored);
    });

    test('edit keeps existing images unless a new one is picked', () async {
      final original = session.plan.points.first.copyWith(
        referenceThumbnailPath: '/old/thumb.jpg',
        referenceFullImagePath: '/old/full.jpg',
      );
      final edit = create(editing: original);
      final kept = edit.buildPoint(
        PointFormValues(
          work: original.work,
          name: original.name,
          coordinatesPending: true,
        ),
      );
      expect(kept.referenceThumbnailPath, '/old/thumb.jpg');
      expect(kept.referenceImageUrl, original.referenceImageUrl);
      await edit.pickReferenceImage();
      final replaced = edit.buildPoint(
        PointFormValues(
          work: original.work,
          name: original.name,
          coordinatesPending: true,
        ),
      );
      expect(replaced.referenceThumbnailPath, startsWith('/store/'));
      expect(replaced.referenceImageUrl, isNull);
    });
  });
}
