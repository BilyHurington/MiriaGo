import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/camera_reference/auto_comparison_gallery_backup.dart';
import 'package:miriago/data/sample_pilgrimage_repository.dart';
import 'package:miriago/plan/pilgrimage_models.dart';
import 'package:miriago/records/comparison_export_config.dart';
import 'package:miriago/records/comparison_export_renderer.dart';
import 'package:miriago/records/comparison_exporter_stub.dart'
    if (dart.library.io) 'package:miriago/records/comparison_exporter_io.dart';

Future<Uint8List> _png() async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawColor(const ui.Color(0xFFFFFFFF), ui.BlendMode.src);
  final picture = recorder.endRecording();
  final image = await picture.toImage(64, 64);
  try {
    return (await image.toByteData(
      format: ui.ImageByteFormat.png,
    ))!.buffer.asUint8List();
  } finally {
    image.dispose();
    picture.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const renderer = ComparisonExportRenderer();
  const config = ComparisonExportConfig(
    borderWidthPercent: 0,
    metadataFields: {},
  );
  Future<Uint8List?> render(Uint8List capture, {Uint8List? reference}) =>
      renderer
          .render(
            capturedBytes: capture,
            referenceBytes: reference,
            config: config,
            metadata: const {},
            colorGradingSummary: null,
          )
          .timeout(const Duration(seconds: 3));

  for (final reference in [false, true]) {
    for (final empty in [false, true]) {
      test(
        '${reference ? 'reference' : 'capture'} ${empty ? 'empty' : 'malformed'} bytes finish and next render succeeds',
        () async {
          final good = await _png();
          final bad = empty ? Uint8List(0) : Uint8List.fromList([1, 2, 3, 4]);
          expect(
            await render(
              reference ? good : bad,
              reference: reference ? bad : good,
            ),
            isNull,
          );
          expect(await render(good, reference: good), isNotEmpty);
        },
      );
    }
  }

  test(
    'decoded images are released after successful and failed renders',
    () async {
      final created = <ui.Image>[];
      final disposed = <ui.Image>{};
      final oldCreate = ui.Image.onCreate;
      final oldDispose = ui.Image.onDispose;
      final good = await _png();
      ui.Image.onCreate = created.add;
      ui.Image.onDispose = disposed.add;
      addTearDown(() {
        ui.Image.onCreate = oldCreate;
        ui.Image.onDispose = oldDispose;
      });
      expect(await render(Uint8List(0), reference: good), isNull);
      expect(await render(good, reference: good), isNotEmpty);
      expect(created, isNotEmpty);
      expect(created.every(disposed.contains), isTrue);
    },
  );

  for (final failure in ['settings', 'config', 'export', 'gallery', 'none']) {
    test('auto backup $failure has a bounded post-commit result', () async {
      final directory = await Directory.systemTemp.createTemp(
        'backup-recovery-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = await File('${directory.path}/photo.jpg').writeAsBytes([1]);
      final repository = SamplePilgrimageRepository(visitRecords: const []);
      final plan = await repository.loadActivePlan();
      final point = plan.points.first;
      final record = await repository.createVisitRecord(
        planId: plan.id,
        pointId: point.id,
        workId: point.work.id,
        photoPath: file.path,
        referenceImagePath: file.path,
        referenceMode: 'test',
      );
      var galleryCalls = 0;
      final result = await autoSaveComparisonImageToGallery(
        record: record,
        point: point,
        settings: const AppSettings(comparisonExportConfigMigrated: false),
        loadCurrentSettings: () async {
          if (failure == 'settings') throw StateError('settings failure');
          return const AppSettings(comparisonExportConfigMigrated: false);
        },
        pointReferenceFullImagePath: null,
        pointReferenceImageUrl: null,
        loadConfig: () async {
          if (failure == 'config') throw StateError('config failure');
          return config;
        },
        exporter:
            ({
              required referenceImagePath,
              required referenceImageUrl,
              required capturedPath,
              required config,
              required metadata,
              required colorGradingSummary,
            }) async {
              if (failure == 'export') throw StateError('export failure');
              return ComparisonExportImageResult.success(file.path);
            },
        gallerySaver: (_) async {
          galleryCalls++;
          if (failure == 'gallery') throw StateError('gallery failure');
          return true;
        },
      );
      expect(result.status, switch (failure) {
        'gallery' => AutoComparisonGalleryStatus.galleryFailed,
        'none' => AutoComparisonGalleryStatus.saved,
        _ => AutoComparisonGalleryStatus.renderFailed,
      });
      expect(galleryCalls, failure == 'gallery' || failure == 'none' ? 1 : 0);
      expect(await repository.loadVisitRecords(plan.id), hasLength(1));
      expect(await file.readAsBytes(), [1]);
    });
  }
}
