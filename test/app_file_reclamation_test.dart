@TestOn('vm')
library;

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/camera_reference/auto_comparison_gallery_backup.dart';
import 'package:miriago/color_grading/graded_photo_reclamation.dart';
import 'package:miriago/data/app_file_reclamation.dart';
import 'package:miriago/data/app_managed_file_paths_io.dart';
import 'package:miriago/data/local/app_database.dart';
import 'package:miriago/data/local/sqlite_pilgrimage_repository.dart';
import 'package:miriago/data/pilgrimage_repository.dart';
import 'package:miriago/data/sample_pilgrimage_repository.dart';
import 'package:miriago/plan/pilgrimage_models.dart';
import 'package:miriago/plan_transfer/plan_import_asset_restore.dart';
import 'package:miriago/plan_transfer/plan_import_package.dart';
import 'package:miriago/plan_transfer/plan_package.dart';
import 'package:miriago/records/comparison_export_config.dart';
import 'package:miriago/records/comparison_export_temp_io.dart';
import 'package:miriago/records/comparison_exporter_io.dart';
import 'package:miriago/records/visit_record_file_ops_io.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temporary;
  late Directory documents;
  late PathProviderPlatform originalProvider;

  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('miriago_reclaim_');
    documents = await Directory(p.join(temporary.path, 'Documents')).create();
    originalProvider = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _Paths(documents.path);
    setAppManagedFileBaseDirectoriesForTesting([documents.path]);
  });
  tearDown(() async {
    PathProviderPlatform.instance = originalProvider;
    setAppManagedFileBaseDirectoriesForTesting(null);
    await Process.run('chmod', ['-R', 'u+w', temporary.path]);
    await temporary.delete(recursive: true);
  });

  Future<File> file(String relative) async {
    final result = File(p.join(documents.path, relative));
    await result.parent.create(recursive: true);
    await result.writeAsBytes([1, 2, 3]);
    return result;
  }

  final basePoint = samplePilgrimagePlan.points.first;

  PilgrimagePoint point(String id, {String? thumbnail, String? full}) =>
      basePoint.copyWith(
        id: id,
        referenceThumbnailPath: thumbnail,
        referenceFullImagePath: full,
      );

  PilgrimagePlan plan(String id, List<PilgrimagePoint> points) =>
      samplePilgrimagePlan.copyWith(
        id: id,
        points: points,
        currentPointId: null,
        completedPointIds: const {},
      );

  PilgrimageVisitRecord record(
    String id,
    String planId, {
    required String photo,
    String? original,
    String? graded,
    String? reference,
  }) => PilgrimageVisitRecord(
    id: id,
    planId: planId,
    pointId: basePoint.id,
    workId: basePoint.work.id,
    photoPath: photo,
    originalPhotoPath: original,
    gradedPhotoPath: graded,
    referenceImagePath: reference,
    referenceMode: 'overlay',
    capturedAt: DateTime(2026),
  );

  group('plan deletion', () {
    test('removes exclusive files and keeps files shared elsewhere', () async {
      final exclusivePhoto = await file('visit_record_images/mine.jpg');
      final exclusiveGraded = await file('graded_photos/graded_mine.jpg');
      final exclusiveUserRef = await file(
        'user_reference_images/point-a-1/full.jpg',
      );
      final exclusiveUserThumb = await file(
        'user_reference_images/point-a-1/thumb.jpg',
      );
      final importedRecordPhoto = await file(
        'imported_plan_assets/import-1/assets/visit_photos/r.jpg',
      );
      final sharedCache = await file('reference_full/shared.jpg');
      final exclusiveCache = await file('reference_thumbnails/mine.jpg');
      final sharedWithRecord = await file(
        'imported_plan_assets/import-2/assets/full_references/f.jpg',
      );
      final sharedPhoto = await file('visit_record_images/duplicated.jpg');
      final external = File(p.join(temporary.path, 'external.jpg'))
        ..writeAsBytesSync([1]);

      final deleted = plan('deleted', [
        point(
          'a',
          thumbnail: exclusiveUserThumb.path,
          full: exclusiveUserRef.path,
        ),
        point('b', thumbnail: exclusiveCache.path, full: sharedCache.path),
        point('c', full: sharedWithRecord.path),
      ]);
      final kept = plan('kept', [point('k', full: sharedCache.path)]);
      final repository = SamplePilgrimageRepository(
        plans: [kept, deleted],
        visitRecords: [
          record(
            'r1',
            'deleted',
            photo: exclusivePhoto.path,
            graded: exclusiveGraded.path,
            original: external.path,
          ),
          record('r2', 'deleted', photo: importedRecordPhoto.path),
          record('r3', 'deleted', photo: sharedPhoto.path),
          // A duplicated plan's record still uses these two files.
          record(
            'r4',
            'kept',
            photo: sharedPhoto.path,
            reference: sharedWithRecord.path,
          ),
        ],
      );

      await deletePlanReclaimingFiles(
        repository: repository,
        planId: 'deleted',
        awaitReclamation: true,
      );

      expect((await repository.loadPlans()).map((plan) => plan.id), ['kept']);
      for (final gone in [
        exclusivePhoto,
        exclusiveGraded,
        exclusiveUserRef,
        exclusiveUserThumb,
        importedRecordPhoto,
        exclusiveCache,
      ]) {
        expect(gone.existsSync(), isFalse, reason: gone.path);
      }
      for (final kept in [sharedCache, sharedWithRecord, sharedPhoto]) {
        expect(kept.existsSync(), isTrue, reason: kept.path);
      }
      expect(external.existsSync(), isTrue);
      // Emptied package / reference folders go, owned roots stay.
      expect(
        Directory(
          p.join(documents.path, 'imported_plan_assets', 'import-1'),
        ).existsSync(),
        isFalse,
      );
      expect(
        Directory(
          p.join(documents.path, 'user_reference_images', 'point-a-1'),
        ).existsSync(),
        isFalse,
      );
      expect(
        Directory(p.join(documents.path, 'imported_plan_assets')).existsSync(),
        isTrue,
      );
      expect(
        Directory(
          p.join(documents.path, 'imported_plan_assets', 'import-2'),
        ).existsSync(),
        isTrue,
      );
    });

    test('a failed plan deletion keeps every file', () async {
      final photo = await file('visit_record_images/mine.jpg');
      final repository = _FailingDeleteRepository(
        plans: [
          plan('kept', const []),
          plan('deleted', [point('a', full: photo.path)]),
        ],
        visitRecords: [record('r', 'deleted', photo: photo.path)],
      );
      await expectLater(
        deletePlanReclaimingFiles(
          repository: repository,
          planId: 'deleted',
          awaitReclamation: true,
        ),
        throwsStateError,
      );
      expect(photo.existsSync(), isTrue);
    });
  });

  test(
    'point deletion reclaims only reference files nothing else uses',
    () async {
      final userRef = await file('user_reference_images/p-1/full.jpg');
      final userThumb = await file('user_reference_images/p-1/thumb.jpg');
      final recordReference = await file('reference_full/record.jpg');
      final otherPointCache = await file('reference_thumbnails/shared.jpg');
      final deletedA = point(
        'a',
        thumbnail: userThumb.path,
        full: userRef.path,
      );
      final deletedB = point(
        'b',
        thumbnail: otherPointCache.path,
        full: recordReference.path,
      );
      final remaining = point('c', thumbnail: otherPointCache.path);
      final repository = SamplePilgrimageRepository(
        plans: [
          plan('plan', [deletedA, deletedB, remaining]),
        ],
        visitRecords: [
          // Records survive point deletion and keep their comparison image.
          record(
            'r',
            'plan',
            photo: '/elsewhere.jpg',
            reference: recordReference.path,
          ),
        ],
      );
      await repository.deletePointsFromPlan(
        planId: 'plan',
        pointIds: {'a', 'b'},
      );
      await reclaimDeletedPointFiles(
        repository: repository,
        points: [deletedA, deletedB],
      );
      expect(userRef.existsSync(), isFalse);
      expect(userThumb.existsSync(), isFalse);
      expect(
        Directory(
          p.join(documents.path, 'user_reference_images', 'p-1'),
        ).existsSync(),
        isFalse,
      );
      expect(recordReference.existsSync(), isTrue);
      expect(otherPointCache.existsSync(), isTrue);
    },
  );

  test(
    'one failed delete does not stop the others and is reported',
    () async {
      final locked = await file('visit_record_images/locked/photo.jpg');
      final graded = await file('graded_photos/graded.jpg');
      final lockedDirectory = locked.parent.path;
      await Process.run('chmod', ['a-w', lockedDirectory]);
      addTearDown(() => Process.run('chmod', ['u+w', lockedDirectory]));
      final repository = SamplePilgrimageRepository(visitRecords: []);

      final result = await reclaimUnreferencedAppFiles(
        repository: repository,
        candidatePaths: [locked.path, graded.path],
        ownedDirectories: AppOwnedDirectory.values.toSet(),
      );
      expect(result.failedFileCount, 1);
      expect(result.deletedFileCount, 1);
      expect(locked.existsSync(), isTrue);
      expect(graded.existsSync(), isFalse);

      final photo = await file('visit_record_images/next.jpg');
      await expectLater(
        deleteUnreferencedVisitRecordPhotos(
          record: record('gone', 'x', photo: locked.path, graded: photo.path),
          repository: repository,
        ),
        throwsA(isA<FileSystemException>()),
      );
      expect(photo.existsSync(), isFalse);
    },
    skip: Platform.isWindows,
  );

  group('color grading', () {
    Future<(SamplePilgrimageRepository, PilgrimageVisitRecord)> graded(
      String gradedPath,
    ) async {
      final repository = SamplePilgrimageRepository(
        plans: [plan('plan', const [])],
        visitRecords: [
          record('r', 'plan', photo: '/outside/photo.jpg', graded: gradedPath),
        ],
      );
      return (repository, (await repository.loadVisitRecords('plan')).single);
    }

    test('regrading reclaims the replaced graded photo', () async {
      final old = await file('graded_photos/graded_r_1.jpg');
      final next = await file('graded_photos/graded_r_2.jpg');
      final (repository, current) = await graded(old.path);
      final updated = await commitGradedPhoto(
        repository: repository,
        newGradedPath: next.path,
        previousGradedPath: current.gradedPhotoPath,
        awaitCleanup: true,
        update: () => repository.updateVisitRecordColorGrading(
          planId: 'plan',
          recordId: 'r',
          originalPhotoPath: current.photoPath,
          gradedPhotoPath: next.path,
          colorGradingMode: 'standard',
          colorGradingParamsJson: '{}',
          colorGradingIntensity: 1,
        ),
      );
      expect(updated?.gradedPhotoPath, next.path);
      expect(old.existsSync(), isFalse);
      expect(next.existsSync(), isTrue);
    });

    test('resetting reclaims the graded photo after the clear', () async {
      final old = await file('graded_photos/graded_r_1.jpg');
      final (repository, current) = await graded(old.path);
      await clearGradedPhoto(
        repository: repository,
        previousGradedPath: current.gradedPhotoPath,
        awaitCleanup: true,
        clear: () => repository.clearVisitRecordColorGrading(
          planId: 'plan',
          recordId: 'r',
        ),
      );
      expect(old.existsSync(), isFalse);
    });

    test('definite failure removes the new photo, keeps the old', () async {
      final old = await file('graded_photos/graded_r_1.jpg');
      final next = await file('graded_photos/graded_r_2.jpg');
      final (repository, current) = await graded(old.path);
      await expectLater(
        commitGradedPhoto(
          repository: repository,
          newGradedPath: next.path,
          previousGradedPath: current.gradedPhotoPath,
          awaitCleanup: true,
          update: () async =>
              throw VisitRecordNotCommittedException(StateError('rolled back')),
        ),
        throwsA(isA<VisitRecordNotCommittedException>()),
      );
      expect(next.existsSync(), isFalse);
      expect(old.existsSync(), isTrue);
    });

    test('uncertain failures keep both photos', () async {
      final old = await file('graded_photos/graded_r_1.jpg');
      final next = await file('graded_photos/graded_r_2.jpg');
      final (repository, current) = await graded(old.path);
      await expectLater(
        commitGradedPhoto(
          repository: repository,
          newGradedPath: next.path,
          previousGradedPath: current.gradedPhotoPath,
          awaitCleanup: true,
          update: () async => throw StateError('connection lost'),
        ),
        throwsStateError,
      );
      await expectLater(
        clearGradedPhoto(
          repository: repository,
          previousGradedPath: current.gradedPhotoPath,
          awaitCleanup: true,
          clear: () async => throw StateError('connection lost'),
        ),
        throwsStateError,
      );
      expect(next.existsSync(), isTrue);
      expect(old.existsSync(), isTrue);
    });

    test(
      'SQLite reports an update of a missing record as not committed',
      () async {
        final database = AppDatabase(NativeDatabase.memory());
        addTearDown(database.close);
        final repository = SqlitePilgrimageRepository(database: database);
        final created = await repository.createPlan(name: 'P', area: '');
        await expectLater(
          repository.updateVisitRecordColorGrading(
            planId: created.id,
            recordId: 'missing',
            originalPhotoPath: '/a.jpg',
            gradedPhotoPath: '/b.jpg',
            colorGradingMode: 'standard',
            colorGradingParamsJson: '{}',
            colorGradingIntensity: 1,
          ),
          throwsA(isA<VisitRecordNotCommittedException>()),
        );
      },
    );
  });

  group('comparison exports', () {
    test('delivered temporary export and its folder are removed', () async {
      final export = await file('visit_record_images/comparison-abc/out.jpg');
      final photo = await file('visit_record_images/photo.jpg');
      await deleteComparisonExportTemp(export.path);
      await deleteComparisonExportTemp(photo.path);
      expect(export.existsSync(), isFalse);
      expect(export.parent.existsSync(), isFalse);
      expect(photo.existsSync(), isTrue);
    });

    test('auto gallery backup removes the render after saving', () async {
      final photo = await file('visit_record_images/photo.jpg');
      late File export;
      final result = await autoSaveComparisonImageToGallery(
        record: record('r', 'plan', photo: photo.path),
        point: basePoint,
        settings: const AppSettings(),
        pointReferenceFullImagePath: photo.path,
        pointReferenceImageUrl: null,
        loadConfig: () async => const ComparisonExportConfig(),
        exporter:
            ({
              required referenceImagePath,
              required referenceImageUrl,
              required capturedPath,
              required config,
              required metadata,
              required colorGradingSummary,
            }) async {
              export = await file('visit_record_images/comparison-x/c.jpg');
              return ComparisonExportImageResult.success(export.path);
            },
        gallerySaver: (path) async {
          expect(File(path).existsSync(), isTrue);
          return true;
        },
      );
      expect(result.isSuccess, isTrue);
      expect(export.existsSync(), isFalse);
      expect(photo.existsSync(), isTrue);
    });

    test('startup sweep removes only stale unreferenced exports', () async {
      final stale = await file('visit_record_images/comparison-old/a.jpg');
      final fresh = await file('visit_record_images/comparison-new/b.jpg');
      final referenced = await file('visit_record_images/comparison-ref/c.jpg');
      final photo = await file('visit_record_images/photo.jpg');
      final old = DateTime.now().subtract(const Duration(days: 3));
      for (final entry in [stale, referenced, photo]) {
        entry.setLastModifiedSync(old);
      }
      final repository = SamplePilgrimageRepository(
        plans: [plan('plan', const [])],
        visitRecords: [record('r', 'plan', photo: referenced.path)],
      );
      await sweepStaleComparisonExports(repository: repository);
      expect(stale.existsSync(), isFalse);
      expect(stale.parent.existsSync(), isFalse);
      expect(fresh.existsSync(), isTrue);
      expect(referenced.existsSync(), isTrue);
      expect(photo.existsSync(), isTrue);
    });
  });

  group('import restore', () {
    const pointAsset = 'assets/full_references/point.png';
    const recordAsset = 'assets/visit_photos/record.png';
    const strayAsset = 'assets/visit_photos/stray.png';
    final package = PlanImportPackage(
      kind: PlanImportPackageKind.miriagoZip,
      package: PlanPackage(plan: samplePilgrimagePlan, visitRecords: const []),
      sourceName: 'test.sjhplan',
      manifest: const {},
      assetCounts: const {},
      assetEntries: {
        pointAsset: [1],
        recordAsset: [2],
        strayAsset: [3],
      },
      pointAssetRefsById: {
        basePoint.id: const PlanImportPointAssetRefs(
          referenceFullReferenceAsset: pointAsset,
        ),
      },
      recordAssetRefsById: const {
        'r': PlanImportRecordAssetRefs(visitPhotoAsset: recordAsset),
      },
      warnings: const [],
      exportedAt: null,
      appVersion: null,
      schemaVersion: 2,
      exportMode: 'plan_with_records',
    );

    Future<Set<String>> restoredFiles() async => {
      await for (final entry in Directory(
        p.join(documents.path, 'imported_plan_assets'),
      ).list(recursive: true))
        if (entry is File) p.basename(entry.path),
    };

    test('without records only point assets are written', () async {
      final restored = await restorePlanImportAssets(
        package,
        includeRecords: false,
      );
      expect(restored.keys, [pointAsset]);
      expect(await restoredFiles(), {'point.png'});
    });

    test('with records unreferenced entries are still skipped', () async {
      final restored = await restorePlanImportAssets(
        package,
        includeRecords: true,
      );
      expect(restored.keys.toSet(), {pointAsset, recordAsset});
      expect(await restoredFiles(), {'point.png', 'record.png'});
    });
  });
}

class _Paths extends PathProviderPlatform {
  _Paths(this.path);
  final String path;
  @override
  Future<String?> getApplicationDocumentsPath() async => path;
  @override
  Future<String?> getApplicationSupportPath() async => path;
}

class _FailingDeleteRepository extends SamplePilgrimageRepository {
  _FailingDeleteRepository({super.plans, super.visitRecords});

  @override
  Future<void> deletePlan(String id) async => throw StateError('delete failed');
}
