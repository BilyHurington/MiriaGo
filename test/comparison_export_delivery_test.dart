import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:miriago/camera_reference/auto_comparison_gallery_backup.dart';
import 'package:miriago/data/bounded_image_decoder.dart';
import 'package:miriago/data/sample_pilgrimage_repository.dart';
import 'package:miriago/plan/pilgrimage_models.dart';
import 'package:miriago/plan_transfer/plan_export_delivery_result.dart';
import 'package:miriago/records/comparison_export_config.dart';
import 'package:miriago/records/comparison_export_encoding.dart';
import 'package:miriago/records/comparison_export_support.dart';
import 'package:miriago/records/comparison_exporter_io.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class _Paths extends PathProviderPlatform {
  _Paths(this.path);
  final String path;
  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

class _StreamClient extends http.BaseClient {
  _StreamClient(this.response);
  final http.StreamedResponse response;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async =>
      response;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late File original;
  late Uint8List source;
  late PathProviderPlatform previous;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('comparison-delivery-');
    previous = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _Paths(directory.path);
    source = img.encodePng(img.Image(width: 24, height: 16));
    original = await File(
      '${directory.path}/original.png',
    ).writeAsBytes(source);
  });
  tearDown(() async {
    PathProviderPlatform.instance = previous;
    await directory.delete(recursive: true);
  });

  for (final encoding in ComparisonImageEncoding.values) {
    test(
      'IO $encoding preserves originals and uses exclusive output directory',
      () async {
        Future<ComparisonExportImageResult> export() => exportComparisonImage(
          referenceImagePath: original.path,
          referenceImageUrl: null,
          capturedPath: original.path,
          config: ComparisonExportConfig(
            imageEncoding: encoding,
            metadataFields: {},
            borderWidthPercent: 0,
          ),
          metadata: {},
          colorGradingSummary: null,
        );
        final first = await export();
        final firstBytes = await File(first.path!).readAsBytes();
        final second = await export();
        expect(first.disposition, ComparisonExportDisposition.localFile);
        expect(first.path, endsWith('.${encoding.extension}'));
        expect(
          File(first.path!).parent.path,
          isNot(File(second.path!).parent.path),
        );
        expect(await File(first.path!).readAsBytes(), firstBytes);
        expect(img.decodeImage(firstBytes), isNotNull);
        expect(await original.readAsBytes(), source);
      },
    );

    test(
      'download $encoding passes real MIME and never invents local path',
      () async {
        final output = EncodedComparisonImage(
          bytes: source,
          width: 24,
          height: 16,
          encoding: encoding,
        );
        final result = await downloadComparisonImage(
          output,
          deliver:
              ({
                required bytes,
                required fileName,
                required mimeType,
                required shareSubject,
                required shareText,
                required extension,
              }) async {
                expect(identical(bytes, source), isTrue);
                expect(fileName, endsWith('.${encoding.extension}'));
                expect(mimeType, encoding.mimeType);
                expect(extension, encoding.extension);
                return const PlanExportDeliveryResult(
                  PlanExportDeliveryAction.saved,
                );
              },
        );
        expect(result.isSuccess, isTrue);
        expect(result.disposition, ComparisonExportDisposition.downloaded);
        expect(result.path, isNull);
      },
    );
  }

  for (final throwsCancel in [false, true]) {
    test(
      'download canceled result/exception $throwsCancel stays non-success',
      () async {
        final result = await downloadComparisonImage(
          EncodedComparisonImage(
            bytes: source,
            width: 24,
            height: 16,
            encoding: ComparisonImageEncoding.png,
          ),
          deliver:
              ({
                required bytes,
                required fileName,
                required mimeType,
                required shareSubject,
                required shareText,
                required extension,
              }) async {
                if (throwsCancel) throw const PlanExportCanceledException();
                return const PlanExportDeliveryResult(
                  PlanExportDeliveryAction.canceled,
                );
              },
        );
        expect(result.disposition, ComparisonExportDisposition.canceled);
        expect(result.isSuccess, isFalse);
        expect(result.path, isNull);
      },
    );
  }

  test('local source byte limit is explicit and creates no output', () async {
    final result = await exportComparisonImage(
      referenceImagePath: original.path,
      referenceImageUrl: null,
      capturedPath: original.path,
      config: const ComparisonExportConfig(),
      metadata: {},
      colorGradingSummary: null,
      maxSourceBytes: 8,
    );
    expect(result.failureReason, ComparisonExportFailureReason.budgetExceeded);
    expect(result.message, contains('${source.length}'));
    expect(result.message, contains('8'));
    expect(
      await Directory('${directory.path}/visit_record_images').exists(),
      isFalse,
    );
    expect(await original.readAsBytes(), source);
  });

  test(
    'remote stream is canceled when actual bytes exceed tiny injected cap',
    () async {
      var chunks = 0;
      var canceled = false;
      final stream = Stream<List<int>>.multi((controller) {
        final timer = Timer.periodic(const Duration(milliseconds: 1), (_) {
          chunks++;
          controller.add([1, 2, 3]);
        });
        controller.onCancel = () {
          canceled = true;
          timer.cancel();
        };
      });
      final client = _StreamClient(http.StreamedResponse(stream, 200));
      addTearDown(client.close);
      await expectLater(
        readRemoteComparisonImage(
          'https://example.org/photo.png',
          maxBytes: 5,
          client: client,
        ),
        throwsA(
          isA<ImageBudgetException>().having(
            (e) => e.kind,
            'kind',
            ImageBudgetFailure.encodedBytes,
          ),
        ),
      );
      expect(chunks, 2);
      expect(canceled, isTrue);
    },
  );

  test(
    'auto backup reloads manually persisted encoding instead of route snapshot',
    () async {
      final repository = SamplePilgrimageRepository();
      final plan = await repository.loadActivePlan();
      final point = plan.points.first;
      final record = await repository.createVisitRecord(
        planId: plan.id,
        pointId: point.id,
        workId: point.work.id,
        photoPath: original.path,
        referenceImagePath: original.path,
        referenceMode: 'test',
      );
      const config = ComparisonExportConfig(
        imageEncoding: ComparisonImageEncoding.jpegHighQuality,
      );
      const staleRouteSettings = AppSettings();
      await repository.saveAppSettings(
        config.applyToSettings(staleRouteSettings),
      );
      final result = await autoSaveComparisonImageToGallery(
        record: record,
        point: point,
        settings: staleRouteSettings,
        loadCurrentSettings: repository.loadAppSettings,
        pointReferenceFullImagePath: null,
        pointReferenceImageUrl: null,
        loadConfig: () async =>
            throw StateError('must not read stale legacy settings'),
        exporter:
            ({
              required referenceImagePath,
              required referenceImageUrl,
              required capturedPath,
              required config,
              required metadata,
              required colorGradingSummary,
            }) async {
              expect(
                config.imageEncoding,
                ComparisonImageEncoding.jpegHighQuality,
              );
              return const ComparisonExportImageResult.failure(
                ComparisonExportFailureReason.budgetExceeded,
                message: '16000001 > 16000000',
              );
            },
        gallerySaver: (_) async =>
            throw StateError('must not save failed output'),
      );
      expect(result.status, AutoComparisonGalleryStatus.renderFailed);
      expect(result.message, '16000001 > 16000000');
      expect(await original.readAsBytes(), source);
    },
  );
}
