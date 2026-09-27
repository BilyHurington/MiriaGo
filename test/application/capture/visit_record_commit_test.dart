import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/application/capture/visit_record_commit.dart';
import 'package:miriago/camera_reference/auto_comparison_gallery_backup.dart';
import 'package:miriago/camera_reference/photo_location.dart';
import 'package:miriago/camera_reference/visit_record_save_assets.dart';
import 'package:miriago/data/pilgrimage_repository.dart';
import 'package:miriago/data/sample_pilgrimage_repository.dart';
import 'package:miriago/map/current_location_resolver.dart';
import 'package:miriago/plan/pilgrimage_models.dart';
import 'package:miriago/plan/pilgrimage_plan_controller.dart';

// Ported from the old visit_record_save_recovery_test.dart and
// visit_record_confirmation_screen_test.dart: the same scenarios run
// directly against the save protocol.

final _location = PhotoLocationData(
  latitude: 35,
  longitude: 139,
  accuracy: 20,
  timestamp: DateTime.utc(2026, 9, 22),
);
final _referenceBytes = Uint8List.fromList([1, 2, 3]);

class _Repository extends SamplePilgrimageRepository {
  _Repository() : super(visitRecords: const []);
  int creates = 0;
  int completes = 0;
  String? failure;
  Completer<void>? completionGate;
  bool completionFails = false;

  @override
  Future<PilgrimageVisitRecord> createVisitRecord({
    required String planId,
    required String pointId,
    required String workId,
    String? workTitle,
    String? workSubtitle,
    String? pointName,
    String? pointSubtitle,
    required String photoPath,
    String? referenceImagePath,
    String? referenceImageUrl,
    required String referenceMode,
    DateTime? capturedAt,
  }) async {
    creates++;
    if (failure == 'rollback') {
      throw const VisitRecordNotCommittedException('injected rollback');
    }
    if (failure == 'unknown') throw StateError('transport response lost');
    final record = await super.createVisitRecord(
      planId: planId,
      pointId: pointId,
      workId: workId,
      workTitle: workTitle,
      workSubtitle: workSubtitle,
      pointName: pointName,
      pointSubtitle: pointSubtitle,
      photoPath: photoPath,
      referenceImagePath: referenceImagePath,
      referenceImageUrl: referenceImageUrl,
      referenceMode: referenceMode,
      capturedAt: capturedAt,
    );
    if (failure == 'committed') throw StateError('response lost after commit');
    return record;
  }

  @override
  Future<void> completePoint({
    required String planId,
    required String pointId,
    required String? nextCurrentPointId,
  }) async {
    completes++;
    await completionGate?.future;
    if (completionFails) throw StateError('completion failed');
    await super.completePoint(
      planId: planId,
      pointId: pointId,
      nextCurrentPointId: nextCurrentPointId,
    );
  }
}

Future<PreparedPhotoLocation> _prepare({
  required String sourcePath,
  required PhotoLocationData location,
  required PhotoLocationWriter writer,
}) async {
  final written = await writer('/owned/working.jpg', location);
  return PreparedPhotoLocation(
    path: written ? '/owned/working.jpg' : sourcePath,
    written: written,
  );
}

class _Fixture {
  _Fixture(this.repository, this.controller, this.commit);
  final _Repository repository;
  final PilgrimagePlanController controller;
  final VisitRecordCommit commit;
}

Future<_Fixture> _fixture({
  _Repository? repository,
  PhotoLocationStrategy strategy = PhotoLocationStrategy.disabled,
  PhotoLocationData? pending,
  Future<PhotoLocationData> Function()? resolve,
  PhotoLocationWriter? writer,
  PhotoLocationPreparer prepare = _prepare,
  Uint8List? referenceBytes,
  ReferenceImagePreparer? prepareReference,
  Future<void> Function()? discardSource,
  bool gallery = false,
  bool comparison = false,
  Future<bool> Function(String)? gallerySaver,
  Future<AutoComparisonGalleryResult> Function(PilgrimageVisitRecord)?
  comparisonSaver,
  bool noRepository = false,
  bool start = true,
}) async {
  final repo = repository ?? _Repository();
  final plan = await repo.loadActivePlan();
  final controller = PilgrimagePlanController(
    plan: plan,
    visitRepository: noRepository ? null : repo,
  );
  await controller.loadVisitRecords();
  addTearDown(controller.dispose);
  final commit = VisitRecordCommit(
    point: plan.points.first,
    controller: controller,
    photoPath: '/draft/capture.jpg',
    referenceMode: '叠影',
    photoLocationStrategy: strategy,
    pendingPhotoLocation: pending,
    resolvePhotoLocation: resolve,
    writePhotoLocation: writer,
    prepareLocation: prepare,
    referenceBytes: referenceBytes,
    prepareReference:
        prepareReference ??
        (_) async => const PreparedRecordImage(path: '/owned/ref.jpg'),
    discardSourcePhoto: discardSource,
    saveVisitPhotoToGallery: gallery,
    autoSaveComparisonToGallery: comparison,
    savePhotoToGallery: gallerySaver ?? (_) async => false,
    backupComparison:
        comparisonSaver ??
        (_) async => const AutoComparisonGalleryResult(
          AutoComparisonGalleryStatus.renderFailed,
        ),
    referencePathCanDisplay: (_) => false,
  );
  if (start) commit.start();
  return _Fixture(repo, controller, commit);
}

Future<void> _flush() => Future<void>.delayed(Duration.zero);

void main() {
  test('save returns saved with the base message', () async {
    final f = await _fixture();
    final outcome = await f.commit.save(completePoint: false);
    expect(outcome!.isError, isFalse);
    expect(outcome.result, VisitRecordConfirmationResult.saved);
    expect(outcome.message, '记录已保存');
    expect(f.repository.creates, 1);
    expect(f.controller.visitRecords.single.referenceMode, '叠影');
    f.commit.dispose();
  });

  test(
    'complete-and-wait reports completed and names the next point',
    () async {
      final f = await _fixture();
      final point = f.controller.plan.points.first;
      f.controller.setCurrentPoint(point);
      final outcome = await f.commit.save(completePoint: true);
      expect(outcome!.result, VisitRecordConfirmationResult.completed);
      expect(f.controller.completedPointIds, contains(point.id));
      final next = f.controller.currentPoint;
      expect(next, isNotNull);
      expect(outcome.message, '已保存并标记完成，下一个：${next!.name}');
      f.commit.dispose();
    },
  );

  test('missing repository reports storage unavailable', () async {
    final f = await _fixture(noRepository: true);
    final outcome = await f.commit.save(completePoint: false);
    expect(outcome!.isError, isTrue);
    expect(outcome.message, '记录存储不可用，请返回后重试。');
    f.commit.dispose();
  });

  for (final afterResolution in [false, true]) {
    test(
      'skip ${afterResolution ? 'ready' : 'pending'} location never writes',
      () async {
        final resolver = Completer<PhotoLocationData>();
        var writes = 0;
        final f = await _fixture(
          strategy: PhotoLocationStrategy.waitOnConfirmation,
          resolve: () => resolver.future,
          writer: (_, _) async {
            writes++;
            return true;
          },
        );
        expect(f.commit.locating, isTrue);
        expect(f.commit.locationStatus, '正在获取拍摄位置...');
        expect(f.commit.canSave, isFalse);
        if (afterResolution) {
          resolver.complete(_location);
          await _flush();
          expect(f.commit.locationStatus, '已获取拍摄位置，保存时写入照片。');
        }
        expect(f.commit.canSkipLocation, isTrue);
        f.commit.skipLocation();
        if (!afterResolution) resolver.complete(_location);
        await _flush();
        expect(f.commit.locationStatus, '已跳过定位，本次不添加位置，保留照片原有信息。');
        expect(f.commit.canSkipLocation, isFalse);
        final outcome = await f.commit.save(completePoint: false);
        expect(writes, 0);
        expect(f.repository.creates, 1);
        expect(outcome!.result, VisitRecordConfirmationResult.saved);
        f.commit.dispose();
      },
    );
  }

  test(
    'recent fix is staged unchanged; write blocks skip and double save',
    () async {
      final gate = Completer<bool>();
      var writes = 0;
      PhotoLocationData? writtenLocation;
      final f = await _fixture(
        strategy: PhotoLocationStrategy.useRecentLocation,
        pending: _location,
        resolve: () async => throw StateError('must not refresh'),
        writer: (path, location) {
          writes++;
          writtenLocation = location;
          return gate.future;
        },
      );
      expect(f.commit.locationStatus, '已获取拍摄位置，保存时写入照片。');
      final first = f.commit.save(completePoint: false);
      final second = f.commit.save(completePoint: false);
      f.commit.skipLocation();
      await _flush();
      expect(writes, 1);
      expect(writtenLocation, same(_location));
      expect(f.commit.savingStage, '正在写入照片定位，请稍候...');
      expect(f.commit.canSkipLocation, isFalse);
      expect(f.commit.canSave, isFalse);
      expect(f.commit.blocksPop, isTrue);
      expect(await second, isNull);
      gate.complete(true);
      final outcome = await first;
      expect(outcome!.result, VisitRecordConfirmationResult.saved);
      expect(f.repository.creates, 1);
      expect(f.controller.visitRecords.single.photoPath, '/owned/working.jpg');
      expect(f.commit.blocksPop, isFalse);
      f.commit.dispose();
    },
  );

  test('disabled strategy ignores a pending location', () async {
    var writes = 0;
    final f = await _fixture(
      pending: _location,
      writer: (_, _) async {
        writes++;
        return true;
      },
    );
    expect(f.commit.locationStatus, isNull);
    await f.commit.save(completePoint: false);
    expect(writes, 0);
    expect(f.controller.visitRecords.single.photoPath, '/draft/capture.jpg');
    f.commit.dispose();
  });

  test(
    'location failures show the old texts and keep save available',
    () async {
      final f = await _fixture(
        strategy: PhotoLocationStrategy.waitOnConfirmation,
        resolve: () async => throw StateError('permission denied'),
        writer: (_, _) async => true,
      );
      await _flush();
      expect(f.commit.locationStatus, '定位获取失败，本次不添加位置，保留照片原有信息。');
      expect(f.commit.canSave, isTrue);
      final denied = await _fixture(
        strategy: PhotoLocationStrategy.waitOnConfirmation,
        resolve: () async => throw const CurrentLocationException(
          CurrentLocationFailure.permissionDenied,
        ),
        writer: (_, _) async => true,
      );
      await _flush();
      expect(denied.commit.locationStatus, '需要定位权限来显示当前位置。');
      await f.commit.save(completePoint: false);
      expect(f.repository.creates, 1);
      f.commit.dispose();
      denied.commit.dispose();
    },
  );

  test(
    'recent strategy resolves once after capture without a staged fix',
    () async {
      var resolves = 0;
      final f = await _fixture(
        strategy: PhotoLocationStrategy.useRecentLocation,
        resolve: () async {
          resolves++;
          return _location;
        },
      );
      await _flush();
      expect(resolves, 1);
      expect(f.commit.pendingLocation, same(_location));
      final staged = await _fixture(
        strategy: PhotoLocationStrategy.useRecentLocation,
        pending: _location,
        resolve: () async {
          resolves++;
          return _location;
        },
      );
      await _flush();
      expect(resolves, 1);
      f.commit.dispose();
      staged.commit.dispose();
    },
  );

  test('a write that fails keeps the original photo and says so', () async {
    final f = await _fixture(
      strategy: PhotoLocationStrategy.useRecentLocation,
      pending: _location,
      writer: (_, _) async => false,
    );
    final outcome = await f.commit.save(completePoint: false);
    expect(outcome!.message, '记录已保存；定位写入失败，保留照片原有信息');
    expect(f.controller.visitRecords.single.photoPath, '/draft/capture.jpg');
    f.commit.dispose();
  });

  test('preparation failure unlocks retry without any record', () async {
    var attempts = 0;
    final f = await _fixture(
      strategy: PhotoLocationStrategy.useRecentLocation,
      pending: _location,
      writer: (_, _) async => true,
      prepare:
          ({required sourcePath, required location, required writer}) async {
            if (++attempts == 1) throw StateError('copy failed');
            return const PreparedPhotoLocation(
              path: '/owned/retry.jpg',
              written: true,
            );
          },
    );
    final failed = await f.commit.save(completePoint: false);
    expect(failed!.isError, isTrue);
    expect(failed.message, '保存记录失败，请重试。');
    expect(f.repository.creates, 0);
    final retried = await f.commit.save(completePoint: false);
    expect(retried!.result, VisitRecordConfirmationResult.saved);
    expect(f.repository.creates, 1);
    f.commit.dispose();
  });

  test(
    'proven rollback cleans drafts and permits one successful retry',
    () async {
      final repo = _Repository()..failure = 'rollback';
      var cleanPhotos = 0;
      var cleanRefs = 0;
      var cleanSources = 0;
      final f = await _fixture(
        repository: repo,
        strategy: PhotoLocationStrategy.useRecentLocation,
        pending: _location,
        writer: (_, _) async => true,
        referenceBytes: _referenceBytes,
        prepareReference: (_) async => PreparedRecordImage(
          path: '/owned/ref.jpg',
          discard: () async => cleanRefs++,
        ),
        prepare:
            ({required sourcePath, required location, required writer}) async =>
                PreparedPhotoLocation(
                  path: '/owned/location.jpg',
                  written: true,
                  discard: () async => cleanPhotos++,
                ),
        discardSource: () async => cleanSources++,
      );
      final failed = await f.commit.save(completePoint: false);
      expect(failed!.message, '保存记录失败，请重试。');
      expect(cleanPhotos, 1);
      expect(cleanRefs, 1);
      expect(cleanSources, 0);
      expect(f.controller.visitRecords, isEmpty);
      repo.failure = null;
      await f.commit.save(completePoint: false);
      expect(repo.creates, 2);
      expect(f.controller.visitRecords, hasLength(1));
      f.commit.dispose();
      await _flush();
      expect(cleanPhotos, 1);
      expect(cleanRefs, 1);
      expect(cleanSources, 1);
    },
  );

  test(
    'uncertain failure locks recreation and preserves drafts on leave',
    () async {
      var discarded = 0;
      final f = await _fixture(
        repository: _Repository()..failure = 'unknown',
        strategy: PhotoLocationStrategy.useRecentLocation,
        pending: _location,
        writer: (_, _) async => true,
        prepare:
            ({required sourcePath, required location, required writer}) async =>
                PreparedPhotoLocation(
                  path: '/owned/uncertain.jpg',
                  written: true,
                  discard: () async => discarded++,
                ),
        referenceBytes: _referenceBytes,
        prepareReference: (_) async => PreparedRecordImage(
          path: '/owned/ref.jpg',
          discard: () async => discarded++,
        ),
        discardSource: () async => discarded++,
      );
      final outcome = await f.commit.save(completePoint: false);
      expect(outcome!.message, '保存结果未确认，请返回记录页检查，勿重复保存。');
      expect(f.commit.recordCommitUncertain, isTrue);
      expect(await f.commit.save(completePoint: false), isNull);
      expect(f.repository.creates, 1);
      expect(f.commit.canSave, isFalse);
      expect(f.commit.canSkipLocation, isFalse);
      expect(f.commit.canCancel, isTrue);
      f.commit.dispose();
      await _flush();
      expect(discarded, 0);
    },
  );

  test(
    'reference preparation failure permits retry without duplicates',
    () async {
      var attempts = 0;
      final f = await _fixture(
        referenceBytes: _referenceBytes,
        prepareReference: (_) async {
          if (++attempts == 1) throw StateError('reference storage failed');
          return const PreparedRecordImage(path: '/owned/ref.jpg');
        },
      );
      await f.commit.save(completePoint: false);
      expect(f.repository.creates, 0);
      await f.commit.save(completePoint: false);
      expect(f.repository.creates, 1);
      expect(
        f.controller.visitRecords.single.referenceImagePath,
        '/owned/ref.jpg',
      );
      f.commit.dispose();
    },
  );

  test(
    'rollback then skip discards the GPS draft and retries the source',
    () async {
      final repo = _Repository()..failure = 'rollback';
      var prepares = 0;
      var discarded = 0;
      var sourceDiscarded = 0;
      final f = await _fixture(
        repository: repo,
        strategy: PhotoLocationStrategy.useRecentLocation,
        pending: _location,
        writer: (_, _) async => true,
        prepare:
            ({required sourcePath, required location, required writer}) async {
              prepares++;
              return PreparedPhotoLocation(
                path: '/owned/gps.jpg',
                written: true,
                discard: () async => discarded++,
              );
            },
        discardSource: () async => sourceDiscarded++,
      );
      await f.commit.save(completePoint: false);
      expect(discarded, 1);
      f.commit.skipLocation();
      repo.failure = null;
      final outcome = await f.commit.save(completePoint: false);
      expect(prepares, 1);
      expect(discarded, 1);
      expect(sourceDiscarded, 0);
      expect(f.controller.visitRecords.single.photoPath, '/draft/capture.jpg');
      expect(outcome!.result, VisitRecordConfirmationResult.saved);
      f.commit.dispose();
    },
  );

  test('a committed record is recovered after a lost response', () async {
    final f = await _fixture(repository: _Repository()..failure = 'committed');
    final outcome = await f.commit.save(completePoint: false);
    expect(f.repository.creates, 1);
    expect(f.controller.visitRecords, hasLength(1));
    expect(outcome!.result, VisitRecordConfirmationResult.saved);
    expect(f.commit.recordCommitUncertain, isFalse);
    f.commit.dispose();
  });

  for (final fails in [false, true]) {
    test('completion is awaited; failure=$fails does not duplicate', () async {
      final gate = Completer<void>();
      var galleryCalls = 0;
      var comparisonCalls = 0;
      final f = await _fixture(
        repository: _Repository()
          ..completionGate = gate
          ..completionFails = fails,
        gallery: true,
        comparison: true,
        gallerySaver: (_) async {
          galleryCalls++;
          throw StateError('gallery failed');
        },
        comparisonSaver: (_) async {
          comparisonCalls++;
          throw StateError('render failed');
        },
      );
      final point = f.controller.plan.points.first;
      final saving = f.commit.save(completePoint: true);
      await _flush();
      await _flush();
      expect(f.repository.creates, 1);
      expect(galleryCalls, 1);
      expect(comparisonCalls, 1);
      expect(f.commit.savingStage, '更新点位状态中...');
      expect(f.controller.completedPointIds.contains(point.id), isFalse);
      gate.complete();
      final outcome = await saving;
      expect(f.repository.creates, 1);
      expect(f.controller.completedPointIds.contains(point.id), !fails);
      expect(
        outcome!.result,
        fails
            ? VisitRecordConfirmationResult.saved
            : VisitRecordConfirmationResult.completed,
      );
      expect(
        outcome.message,
        fails
            ? '记录已保存；相册备份失败，对比图生成失败；标记完成失败，请在计划中重试'
            : startsWith('已保存并标记完成；相册备份失败，对比图生成失败'),
      );
      f.commit.dispose();
    });
  }

  test('gallery and comparison backups are reported in the message', () async {
    final f = await _fixture(
      gallery: true,
      comparison: true,
      gallerySaver: (_) async => true,
      comparisonSaver: (_) async =>
          const AutoComparisonGalleryResult(AutoComparisonGalleryStatus.saved),
    );
    final outcome = await f.commit.save(completePoint: false);
    expect(outcome!.message, '记录已保存，并备份到相册，对比图已保存到相册');
    f.commit.dispose();
  });

  test('comparison backup messages match the old texts', () {
    String message(AutoComparisonGalleryStatus status, {String? detail}) =>
        comparisonBackupMessage(
          AutoComparisonGalleryResult(status, message: detail),
        );
    expect(comparisonBackupMessage(null), '');
    expect(
      message(AutoComparisonGalleryStatus.referenceUnavailable),
      '，参考图不可用，未生成对比图',
    );
    expect(
      message(AutoComparisonGalleryStatus.capturedPhotoUnavailable),
      '，巡礼图不可用，未生成对比图',
    );
    expect(message(AutoComparisonGalleryStatus.galleryFailed), '，对比图保存到相册失败');
    expect(message(AutoComparisonGalleryStatus.renderFailed), '，对比图生成失败');
    expect(
      message(AutoComparisonGalleryStatus.renderFailed, detail: '自定义'),
      '，自定义',
    );
    expect(
      visitRecordSaveSuccessMessage(
        completePoint: false,
        nextPointName: 'X',
        attemptedGalleryBackup: false,
        galleryBackupSucceeded: false,
        comparisonBackupResult: null,
      ),
      '记录已保存',
    );
  });

  test('dispose during reference write cleans new drafts and source', () async {
    final gate = Completer<PreparedRecordImage>();
    var writes = 0;
    var discarded = 0;
    final f = await _fixture(
      strategy: PhotoLocationStrategy.useRecentLocation,
      pending: _location,
      referenceBytes: _referenceBytes,
      prepareReference: (_) => gate.future,
      writer: (_, _) async {
        writes++;
        return true;
      },
      discardSource: () async => discarded++,
    );
    final saving = f.commit.save(completePoint: false);
    await _flush();
    f.commit.dispose();
    gate.complete(
      PreparedRecordImage(
        path: '/owned/ref.jpg',
        discard: () async => discarded++,
      ),
    );
    expect(await saving, isNull);
    await _flush();
    expect(f.repository.creates, 0);
    expect(writes, 0);
    expect(discarded, 2);
  });

  test('dispose during location write cleans the copy afterwards', () async {
    final gate = Completer<PreparedPhotoLocation>();
    var discarded = 0;
    final f = await _fixture(
      strategy: PhotoLocationStrategy.useRecentLocation,
      pending: _location,
      writer: (_, _) async => true,
      prepare: ({required sourcePath, required location, required writer}) =>
          gate.future,
      discardSource: () async => discarded++,
    );
    final saving = f.commit.save(completePoint: false);
    await _flush();
    f.commit.dispose();
    expect(discarded, 0);
    gate.complete(
      PreparedPhotoLocation(
        path: '/owned/location.jpg',
        written: true,
        discard: () async => discarded++,
      ),
    );
    expect(await saving, isNull);
    await _flush();
    expect(f.repository.creates, 0);
    expect(discarded, 2);
  });

  test('cancel discards the owned source without writing', () async {
    var discarded = 0;
    var writes = 0;
    final f = await _fixture(
      strategy: PhotoLocationStrategy.useRecentLocation,
      pending: _location,
      writer: (_, _) async {
        writes++;
        return true;
      },
      discardSource: () async => discarded++,
    );
    f.commit.dispose();
    await _flush();
    expect(writes, 0);
    expect(discarded, 1);
  });

  test(
    'the source is only discarded after the preview read finished',
    () async {
      final read = Completer<void>();
      var discarded = 0;
      final f = await _fixture(discardSource: () async => discarded++);
      f.commit.attachPreviewRead(() => read.future);
      f.commit.dispose();
      await _flush();
      expect(discarded, 0);
      read.complete();
      await _flush();
      await _flush();
      expect(discarded, 1);
    },
  );

  test('a saved record keeps its own photo as the source', () async {
    var discarded = 0;
    final f = await _fixture(discardSource: () async => discarded++);
    await f.commit.save(completePoint: false);
    f.commit.dispose();
    await _flush();
    // The record points at the source photo itself.
    expect(discarded, 0);
  });
}
