import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/data/sample_pilgrimage_repository.dart';
import 'package:miriago/plan_transfer/plan_export_v2.dart';
import 'package:miriago/plan_transfer/plan_import_package.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('reads v2 package asset entries and asset references', () async {
    final repository = SamplePilgrimageRepository();
    final plan = await repository.loadActivePlan();
    final records = await repository.loadVisitRecords(plan.id);
    final record = records.firstWhere(
      (record) => record.gradedPhotoPath != null,
    );
    final point = plan.points.first.copyWith(
      referenceThumbnailPath: 'docs/sample_images/铃音-记录详情页面-调色前.jpg',
      referenceFullImagePath: 'docs/sample_images/铃音-记录详情页面-调色后.jpg',
    );
    final package = await buildPlanExportV2Package(
      plan: plan.copyWith(points: [point]),
      visitRecords: [record],
      options: const PlanExportV2Options(
        mode: PlanExportV2Mode.planWithRecords,
        includeFullReferenceCache: true,
      ),
    );

    final importPackage = readPlanImportPackageFromBytes(
      package.bytes,
      sourceName: package.fileName,
    );

    expect(importPackage.kind, PlanImportPackageKind.miriagoZip);
    expect(importPackage.hasRestorableAssets, isTrue);
    expect(
      importPackage.assetEntries,
      contains('assets/thumbnails/${point.id}.jpg'),
    );
    expect(
      importPackage.assetEntries,
      contains('assets/full_references/${point.id}.jpg'),
    );
    expect(
      importPackage.pointAssetRefsById[point.id]?.referenceThumbnailAsset,
      'assets/thumbnails/${point.id}.jpg',
    );
    expect(
      importPackage.recordAssetRefsById[record.id]?.visitPhotoAsset,
      'assets/visit_photos/${record.id}.jpg',
    );
  });

  test('ignores unsafe asset paths from v2 zip packages', () {
    final bytes = _zipPackageBytes(
      assetFiles: {
        'assets/thumbnails/safe.jpg': utf8.encode('safe'),
        'assets/../escape.jpg': utf8.encode('bad'),
        '/assets/absolute.jpg': utf8.encode('bad'),
        r'assets\windows.jpg': utf8.encode('bad'),
      },
    );

    final importPackage = readPlanImportPackageFromBytes(
      bytes,
      sourceName: 'unsafe.sjhplan',
    );

    expect(importPackage.assetEntries.keys, ['assets/thumbnails/safe.jpg']);
  });

  test(
    'legacy v1 json import ignores visit records without bundled photos',
    () {
      final bytes = utf8.encode(
        jsonEncode({
          'format': 'miriago-plan',
          'version': 1,
          'exportedAt': '2026-06-07T00:00:00.000',
          'plan': {
            'id': 'plan-1',
            'name': 'Legacy Plan',
            'area': 'Test Area',
            'createdAt': '2026-06-07T00:00:00.000',
            'updatedAt': '2026-06-07T00:00:00.000',
            'currentPointId': null,
            'completedPointIds': [],
            'works': [],
            'points': [],
          },
          'visitRecords': [
            {
              'id': 'legacy-record',
              'planId': 'plan-1',
              'pointId': 'point-1',
              'workId': 'work-1',
              'photoPath': '/missing/photo.jpg',
              'referenceMode': '叠影',
              'capturedAt': '2026-06-07T00:00:00.000',
            },
          ],
        }),
      );

      final importPackage = readPlanImportPackageFromBytes(
        bytes,
        sourceName: 'legacy.sjhplan',
      );

      expect(importPackage.kind, PlanImportPackageKind.legacyJson);
      expect(importPackage.visitRecordCount, 0);
      expect(importPackage.package.visitRecords, isEmpty);
    },
  );

  test('applies restored asset paths to plan points and records', () {
    final bytes = _zipPackageBytes(
      assetFiles: {
        'assets/thumbnails/point-1.jpg': utf8.encode('thumb'),
        'assets/full_references/point-1.jpg': utf8.encode('full'),
        'assets/visit_photos/record-1.jpg': utf8.encode('photo'),
        'assets/graded_photos/record-1.jpg': utf8.encode('graded'),
      },
    );
    final importPackage = readPlanImportPackageFromBytes(
      bytes,
      sourceName: 'restore.sjhplan',
    );

    final restored = applyRestoredAssetPaths(
      importPackage: importPackage,
      restoredPaths: const {
        'assets/thumbnails/point-1.jpg': '/local/thumb.jpg',
        'assets/full_references/point-1.jpg': '/local/full.jpg',
        'assets/visit_photos/record-1.jpg': '/local/photo.jpg',
        'assets/graded_photos/record-1.jpg': '/local/graded.jpg',
      },
      includeRecords: true,
    );

    expect(
      restored.plan.points.single.referenceThumbnailPath,
      '/local/thumb.jpg',
    );
    expect(
      restored.plan.points.single.referenceFullImagePath,
      '/local/full.jpg',
    );
    expect(restored.visitRecords.single.photoPath, '/local/photo.jpg');
    expect(restored.visitRecords.single.gradedPhotoPath, '/local/graded.jpg');
    expect(restored.warnings, isEmpty);
  });

  test(
    'clears stale graded photo path when declared asset is not restored',
    () {
      final bytes = _zipPackageBytes(
        assetFiles: {
          'assets/thumbnails/point-1.jpg': utf8.encode('thumb'),
          'assets/full_references/point-1.jpg': utf8.encode('full'),
          'assets/visit_photos/record-1.jpg': utf8.encode('photo'),
        },
      );
      final importPackage = readPlanImportPackageFromBytes(
        bytes,
        sourceName: 'missing-graded.sjhplan',
      );

      final restored = applyRestoredAssetPaths(
        importPackage: importPackage,
        restoredPaths: const {
          'assets/thumbnails/point-1.jpg': '/local/thumb.jpg',
          'assets/full_references/point-1.jpg': '/local/full.jpg',
          'assets/visit_photos/record-1.jpg': '/local/photo.jpg',
        },
        includeRecords: true,
      );

      expect(restored.visitRecords.single.photoPath, '/local/photo.jpg');
      expect(restored.visitRecords.single.gradedPhotoPath, isNull);
      expect(
        restored.warnings,
        contains('asset not restored: assets/graded_photos/record-1.jpg'),
      );
    },
  );

  test('restored user reference assets clear stale remote reference url', () {
    final bytes = _zipPackageBytes(
      pointReferenceImageUrl: 'https://image.anitabi.cn/points/old.jpg',
      pointUserReferenceAsset: 'assets/user_references/point-1.jpg',
      pointFullReferenceAsset: null,
      assetFiles: {
        'assets/thumbnails/point-1.jpg': utf8.encode('thumb'),
        'assets/user_references/point-1.jpg': utf8.encode('user full'),
      },
    );
    final importPackage = readPlanImportPackageFromBytes(
      bytes,
      sourceName: 'restore-user-reference.sjhplan',
    );

    final restored = applyRestoredAssetPaths(
      importPackage: importPackage,
      restoredPaths: const {
        'assets/thumbnails/point-1.jpg': '/local/thumb.jpg',
        'assets/user_references/point-1.jpg':
            '/local/user_reference_images/full/point-1.jpg',
      },
      includeRecords: false,
    );

    final point = restored.plan.points.single;
    expect(point.referenceImageUrl, isNull);
    expect(
      point.referenceFullImagePath,
      '/local/user_reference_images/full/point-1.jpg',
    );
    expect(restored.warnings, isEmpty);
  });

  test('clears stale full reference path when asset is not restored', () {
    final bytes = _zipPackageBytes(
      assetFiles: {'assets/thumbnails/point-1.jpg': utf8.encode('thumb')},
    );
    final importPackage = readPlanImportPackageFromBytes(
      bytes,
      sourceName: 'restore.sjhplan',
    );

    final restored = applyRestoredAssetPaths(
      importPackage: importPackage,
      restoredPaths: const {
        'assets/thumbnails/point-1.jpg': '/local/thumb.jpg',
      },
      includeRecords: true,
    );

    expect(
      restored.plan.points.single.referenceThumbnailPath,
      '/local/thumb.jpg',
    );
    expect(restored.plan.points.single.referenceFullImagePath, isNull);
  });
}

List<int> _zipPackageBytes({
  required Map<String, List<int>> assetFiles,
  String? pointReferenceImageUrl,
  String? pointFullReferenceAsset = 'assets/full_references/point-1.jpg',
  String? pointUserReferenceAsset,
}) {
  final archive = Archive()
    ..addFile(ArchiveFile.string('manifest.json', _manifestJson()))
    ..addFile(
      ArchiveFile.string(
        'plan.json',
        _planJson(
          pointReferenceImageUrl: pointReferenceImageUrl,
          pointFullReferenceAsset: pointFullReferenceAsset,
          pointUserReferenceAsset: pointUserReferenceAsset,
        ),
      ),
    );
  for (final entry in assetFiles.entries) {
    archive.addFile(ArchiveFile.bytes(entry.key, entry.value));
  }
  return ZipEncoder().encode(archive);
}

String _manifestJson() {
  return jsonEncode({
    'format': miriagoExportPackageFormat,
    'container': 'zip',
    'schemaVersion': miriagoExportSchemaVersion,
    'appName': 'MiriaGo',
    'appVersion': '1.1.0+4',
    'exportedAt': '2026-06-07T00:00:00.000',
    'exportMode': 'plan_with_records',
    'packageId': 'test-package',
    'planId': 'plan-1',
    'planName': 'Test Plan',
    'assetCounts': {
      'thumbnails': 1,
      'userReferenceImages': 0,
      'fullReferences': 1,
      'visitPhotos': 1,
      'gradedPhotos': 1,
    },
    'warnings': [],
  });
}

String _planJson({
  String? pointReferenceImageUrl,
  String? pointFullReferenceAsset = 'assets/full_references/point-1.jpg',
  String? pointUserReferenceAsset,
}) {
  return jsonEncode({
    'schemaVersion': miriagoExportSchemaVersion,
    'exportMode': 'plan_with_records',
    'plan': {
      'id': 'plan-1',
      'name': 'Test Plan',
      'area': 'Test Area',
      'createdAt': '2026-06-07T00:00:00.000',
      'updatedAt': '2026-06-07T00:00:00.000',
      'currentPointId': 'point-1',
      'currentGroupId': null,
      'completedPointIds': ['point-1'],
      'works': [
        {
          'id': 'work-1',
          'bangumiId': null,
          'bangumiSubjectType': null,
          'title': 'Work',
          'subtitle': '',
          'city': 'City',
          'source': 'manual',
        },
      ],
      'groups': [],
      'points': [
        {
          'id': 'point-1',
          'workId': 'work-1',
          'name': 'Point',
          'subtitle': '',
          'latitude': 35.0,
          'longitude': 135.0,
          'episodeLabel': '',
          'referenceLabel': '',
          'source': 'manual',
          'sourceId': null,
          'referenceImageUrl': pointReferenceImageUrl,
          'referenceThumbnailPath': '/old/thumb.jpg',
          'referenceFullImagePath': '/old/full.jpg',
          'referenceThumbnailAsset': 'assets/thumbnails/point-1.jpg',
          'referenceFullReferenceAsset': pointFullReferenceAsset,
          'userReferenceAsset': pointUserReferenceAsset,
          'sourceUrl': null,
          'groupId': null,
          'groupOrderIndex': null,
        },
      ],
    },
    'visitRecords': [
      {
        'id': 'record-1',
        'planId': 'plan-1',
        'pointId': 'point-1',
        'workId': 'work-1',
        'workTitle': 'Work',
        'workSubtitle': '',
        'pointName': 'Point',
        'pointSubtitle': '',
        'photoPath': '/old/photo.jpg',
        'originalPhotoPath': null,
        'gradedPhotoPath': '/old/graded.jpg',
        'colorGradingMode': null,
        'colorGradingParamsJson': null,
        'colorGradingIntensity': null,
        'referenceImagePath': null,
        'referenceImageUrl': null,
        'visitPhotoAsset': 'assets/visit_photos/record-1.jpg',
        'gradedPhotoAsset': 'assets/graded_photos/record-1.jpg',
        'referenceMode': '叠影',
        'capturedAt': '2026-06-07T00:00:00.000',
      },
    ],
  });
}
