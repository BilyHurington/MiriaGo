import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/data/sample_pilgrimage_repository.dart';
import 'package:miriago/plan/pilgrimage_models.dart';
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
    final originalWork = plan.works.first;
    final workWithMetadata = PilgrimageWork(
      id: originalWork.id,
      bangumiId: originalWork.bangumiId,
      bangumiSubjectType: BangumiSubjectType.anime,
      coverImageUrl: 'https://lain.bgm.tv/r/200/pic/cover/import.jpg',
      title: originalWork.title,
      subtitle: originalWork.subtitle,
      city: originalWork.city,
      source: originalWork.source,
    );
    final package = await buildPlanExportV2Package(
      plan: plan.copyWith(
        memo: '导出前确认交通预约。',
        works: [workWithMetadata, ...plan.works.skip(1)],
        points: [point],
      ),
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
    expect(importPackage.package.plan.memo, '导出前确认交通预约。');
    expect(
      importPackage.package.plan.works.first.bangumiSubjectType,
      BangumiSubjectType.anime,
    );
    expect(
      importPackage.package.plan.works.first.coverImageUrl,
      workWithMetadata.coverImageUrl,
    );
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
        'assets/thumbnails/safe.jpg': _jpegBytes,
        'assets/../escape.jpg': utf8.encode('bad'),
        '/assets/absolute.jpg': utf8.encode('bad'),
        r'assets\windows.jpg': _jpegBytes,
      },
    );

    final importPackage = readPlanImportPackageFromBytes(
      bytes,
      sourceName: 'unsafe.sjhplan',
    );

    expect(importPackage.assetEntries.keys, [
      'assets/thumbnails/safe.jpg',
      'assets/windows.jpg',
    ]);
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
      expect(importPackage.package.plan.memo, '');
      expect(importPackage.visitRecordCount, 0);
      expect(importPackage.package.visitRecords, isEmpty);
    },
  );

  test('applies restored asset paths to plan points and records', () {
    final bytes = _zipPackageBytes(
      assetFiles: {
        'assets/thumbnails/point-1.jpg': _jpegBytes,
        'assets/full_references/point-1.jpg': _jpegBytes,
        'assets/visit_photos/record-1.jpg': _jpegBytes,
        'assets/graded_photos/record-1.jpg': _jpegBytes,
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
          'assets/thumbnails/point-1.jpg': _jpegBytes,
          'assets/full_references/point-1.jpg': _jpegBytes,
          'assets/visit_photos/record-1.jpg': _jpegBytes,
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
        'assets/thumbnails/point-1.jpg': _jpegBytes,
        'assets/user_references/point-1.jpg': _jpegBytes,
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

  test('canonicalizes Anitabi mirror URLs from imported v2 packages', () {
    final bytes = _zipPackageBytes(
      assetFiles: const {},
      pointReferenceImageUrl: 'https://img-tc.anitabi.cn/points/old.jpg',
    );

    final importPackage = readPlanImportPackageFromBytes(
      bytes,
      sourceName: 'mirror-url.sjhplan',
    );

    expect(
      importPackage.package.plan.points.single.referenceImageUrl,
      'https://image.anitabi.cn/points/old.jpg',
    );
  });

  test('clears stale full reference path when asset is not restored', () {
    final bytes = _zipPackageBytes(
      assetFiles: {'assets/thumbnails/point-1.jpg': _jpegBytes},
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

  test('clears exporter device paths when package has no point assets', () {
    final bytes = _zipPackageBytes(
      assetFiles: const {},
      pointReferenceImageUrl: 'https://image.anitabi.cn/points/remote.jpg',
      pointThumbnailAsset: null,
      pointFullReferenceAsset: null,
      pointSource: 'anitabi',
    );
    final importPackage = readPlanImportPackageFromBytes(
      bytes,
      sourceName: 'remote-without-assets.sjhplan',
    );

    final restored = applyRestoredAssetPaths(
      importPackage: importPackage,
      restoredPaths: const {},
      includeRecords: false,
    );

    final point = restored.plan.points.single;
    expect(point.referenceThumbnailPath, isNull);
    expect(point.referenceFullImagePath, isNull);
    expect(
      point.referenceImageUrl,
      'https://image.anitabi.cn/points/remote.jpg',
    );
  });

  test('warns when an unbundled local reference cannot be restored', () {
    final bytes = _zipPackageBytes(
      assetFiles: const {},
      pointThumbnailAsset: null,
      pointFullReferenceAsset: null,
    );
    final importPackage = readPlanImportPackageFromBytes(
      bytes,
      sourceName: 'local-without-assets.sjhplan',
    );

    final restored = applyRestoredAssetPaths(
      importPackage: importPackage,
      restoredPaths: const {},
      includeRecords: false,
    );

    final point = restored.plan.points.single;
    expect(point.referenceThumbnailPath, isNull);
    expect(point.referenceFullImagePath, isNull);
    expect(restored.warnings, contains('local reference not bundled: point-1'));
  });

  test('ignores image package assets that contain html bytes', () {
    final bytes = _zipPackageBytes(
      assetFiles: {
        'assets/thumbnails/point-1.jpg': _htmlBytes,
        'assets/full_references/point-1.jpg': _htmlBytes,
        'assets/visit_photos/record-1.jpg': _jpegBytes,
      },
    );

    final importPackage = readPlanImportPackageFromBytes(
      bytes,
      sourceName: 'bad-assets.sjhplan',
    );

    expect(importPackage.assetEntries.keys, [
      'assets/visit_photos/record-1.jpg',
    ]);

    final restored = applyRestoredAssetPaths(
      importPackage: importPackage,
      restoredPaths: const {
        'assets/visit_photos/record-1.jpg': '/local/photo.jpg',
      },
      includeRecords: true,
    );

    final point = restored.plan.points.single;
    expect(point.referenceThumbnailPath, isNull);
    expect(point.referenceFullImagePath, isNull);
    expect(
      restored.warnings,
      contains('asset not restored: assets/thumbnails/point-1.jpg'),
    );
    expect(
      restored.warnings,
      contains('asset not restored: assets/full_references/point-1.jpg'),
    );
  });

  test('normalizes windows-style restored asset paths', () {
    final bytes = _zipPackageBytes(
      assetFiles: {
        r'assets\thumbnails\point-1.jpg': _jpegBytes,
        r'assets\full_references\point-1.jpg': _jpegBytes,
      },
    );

    final importPackage = readPlanImportPackageFromBytes(
      bytes,
      sourceName: 'windows-paths.sjhplan',
    );

    expect(
      importPackage.assetEntries.keys,
      containsAll([
        'assets/thumbnails/point-1.jpg',
        'assets/full_references/point-1.jpg',
      ]),
    );

    final restored = applyRestoredAssetPaths(
      importPackage: importPackage,
      restoredPaths: const {
        'assets/thumbnails/point-1.jpg':
            r'assets\imported_plan_assets\pkg\assets\thumbnails\point-1.jpg',
        'assets/full_references/point-1.jpg':
            r'assets\imported_plan_assets\pkg\assets\full_references\point-1.jpg',
      },
      includeRecords: false,
    );

    expect(
      restored.plan.points.single.referenceThumbnailPath,
      'assets/imported_plan_assets/pkg/assets/thumbnails/point-1.jpg',
    );
    expect(
      restored.plan.points.single.referenceFullImagePath,
      'assets/imported_plan_assets/pkg/assets/full_references/point-1.jpg',
    );
  });
}

List<int> _zipPackageBytes({
  required Map<String, List<int>> assetFiles,
  String? pointReferenceImageUrl,
  String? pointThumbnailAsset = 'assets/thumbnails/point-1.jpg',
  String? pointFullReferenceAsset = 'assets/full_references/point-1.jpg',
  String? pointUserReferenceAsset,
  String pointSource = 'manual',
}) {
  final archive = Archive()
    ..addFile(ArchiveFile.string('manifest.json', _manifestJson()))
    ..addFile(
      ArchiveFile.string(
        'plan.json',
        _planJson(
          pointReferenceImageUrl: pointReferenceImageUrl,
          pointThumbnailAsset: pointThumbnailAsset,
          pointFullReferenceAsset: pointFullReferenceAsset,
          pointUserReferenceAsset: pointUserReferenceAsset,
          pointSource: pointSource,
        ),
      ),
    );
  for (final entry in assetFiles.entries) {
    archive.addFile(ArchiveFile.bytes(entry.key, entry.value));
  }
  return ZipEncoder().encode(archive);
}

const _jpegBytes = <int>[0xFF, 0xD8, 0xFF, 0xD9];
final _htmlBytes = utf8.encode(
  '<!DOCTYPE html><html><body>MiriaGo</body></html>',
);

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
  String? pointThumbnailAsset = 'assets/thumbnails/point-1.jpg',
  String? pointFullReferenceAsset = 'assets/full_references/point-1.jpg',
  String? pointUserReferenceAsset,
  String pointSource = 'manual',
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
          'source': pointSource,
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
          'referenceThumbnailAsset': pointThumbnailAsset,
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
