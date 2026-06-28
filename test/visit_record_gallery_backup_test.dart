import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:miriago/camera_reference/auto_comparison_gallery_backup.dart';
import 'package:miriago/camera_reference/visit_record_confirmation_screen.dart';
import 'package:miriago/plan/pilgrimage_models.dart';
import 'package:miriago/records/comparison_export_config.dart';
import 'package:miriago/records/comparison_exporter_stub.dart'
    if (dart.library.io) 'package:miriago/records/comparison_exporter_io.dart';

void main() {
  late Directory tempDirectory;
  late File photoFile;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'miriago_auto_comparison_',
    );
    photoFile = File('${tempDirectory.path}/photo.jpg')
      ..writeAsBytesSync(<int>[1, 2, 3], flush: true);
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    if (tempDirectory.existsSync()) {
      tempDirectory.deleteSync(recursive: true);
    }
  });

  test('auto gallery backup only runs on supported mobile platforms', () {
    expect(const AppSettings().saveVisitPhotoToGallery, isTrue);

    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(shouldAutoSaveVisitPhotoToGallery(const AppSettings()), isTrue);

    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    expect(shouldAutoSaveVisitPhotoToGallery(const AppSettings()), isFalse);

    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(
      shouldAutoSaveVisitPhotoToGallery(
        const AppSettings(saveVisitPhotoToGallery: false),
      ),
      isFalse,
    );
  });

  test('auto comparison gallery backup is disabled by default', () {
    expect(const AppSettings().autoSaveComparisonToGallery, isFalse);

    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(shouldAutoSaveComparisonToGallery(const AppSettings()), isFalse);

    expect(
      shouldAutoSaveComparisonToGallery(
        const AppSettings(autoSaveComparisonToGallery: true),
      ),
      isTrue,
    );

    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    expect(
      shouldAutoSaveComparisonToGallery(
        const AppSettings(autoSaveComparisonToGallery: true),
      ),
      isFalse,
    );
  });

  test('auto comparison saves exported image to gallery', () async {
    var galleryPath = '';

    final result = await autoSaveComparisonImageToGallery(
      record: _record(
        photoPath: photoFile.path,
        referenceImageUrl: 'https://example.com/ref.jpg',
      ),
      point: _point,
      settings: const AppSettings(
        autoSaveComparisonToGallery: true,
        comparisonShowPilgrimName: true,
        comparisonPilgrimName: '巡礼者',
      ),
      pointReferenceFullImagePath: null,
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
            expect(referenceImagePath, isNull);
            expect(referenceImageUrl, 'https://example.com/ref.jpg');
            expect(capturedPath, photoFile.path);
            expect(config.showPilgrimName, isTrue);
            expect(config.pilgrimName, '巡礼者');
            expect(metadata[ComparisonMetadataField.workTitle], '测试作品');
            expect(
              metadata[ComparisonMetadataField.episodeLabel],
              'EP 1 / 2:08',
            );
            return const ComparisonExportImageResult.success(
              '/tmp/comparison.png',
            );
          },
      gallerySaver: (path) async {
        galleryPath = path;
        return true;
      },
    );

    expect(result.status, AutoComparisonGalleryStatus.saved);
    expect(galleryPath, '/tmp/comparison.png');
  });

  test(
    'auto comparison reports reference unavailable without gallery save',
    () async {
      var savedToGallery = false;

      final result = await autoSaveComparisonImageToGallery(
        record: _record(photoPath: photoFile.path),
        point: _point,
        settings: const AppSettings(autoSaveComparisonToGallery: true),
        pointReferenceFullImagePath: null,
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
              return const ComparisonExportImageResult.failure(
                ComparisonExportFailureReason.referenceUnavailable,
              );
            },
        gallerySaver: (_) async {
          savedToGallery = true;
          return true;
        },
      );

      expect(result.status, AutoComparisonGalleryStatus.referenceUnavailable);
      expect(savedToGallery, isFalse);
    },
  );
}

const _work = PilgrimageWork(
  id: 'work-1',
  title: '测试作品',
  subtitle: '',
  city: '测试市',
  source: WorkSource.manual,
);

const _point = PilgrimagePoint(
  id: 'point-1',
  work: _work,
  name: '测试点位',
  subtitle: '测试地点',
  position: LatLng(35.0, 135.0),
  episodeLabel: 'EP 1 / 2:08',
  referenceLabel: '参考图',
);

PilgrimageVisitRecord _record({
  required String photoPath,
  String? referenceImageUrl,
}) {
  return PilgrimageVisitRecord(
    id: 'record-1',
    planId: 'plan-1',
    pointId: _point.id,
    workId: _work.id,
    workTitle: _work.title,
    pointName: _point.name,
    photoPath: photoPath,
    referenceImageUrl: referenceImageUrl,
    referenceMode: '上下',
    capturedAt: DateTime(2026, 6, 27, 12, 34),
  );
}
