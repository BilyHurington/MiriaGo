import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:miriago/data/bounded_image_decoder.dart';
import 'package:miriago/plan/pilgrimage_models.dart';
import 'package:miriago/records/comparison_export_budget.dart';
import 'package:miriago/records/comparison_export_config.dart';
import 'package:miriago/records/comparison_export_renderer.dart';

Uint8List source(int width, int height, int red, int blue) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(red, 0, blue));
  return img.encodePng(image);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const simple = ComparisonExportConfig(
    borderWidthPercent: 0,
    metadataFields: {},
  );

  test(
    'old and unknown config encoding defaults to 85 without changing size',
    () {
      for (final value in [null, 'future-codec']) {
        final config = ComparisonExportConfig.fromJson({
          'outputWidth': 'w3840',
          'borderWidthPercent': 2.0,
          'imageEncoding': value,
        });
        expect(config.imageEncoding, ComparisonImageEncoding.jpegRecommended);
        expect(config.imageEncoding.jpegQuality, 85);
        expect(config.outputWidth, ComparisonOutputWidth.w3840);
        expect(config.borderWidthPercent, 2);
      }
    },
  );

  for (final encoding in ComparisonImageEncoding.values) {
    test(
      '$encoding round trips settings and does not change size selection',
      () {
        final config = simple.copyWith(
          imageEncoding: encoding,
          outputWidth: ComparisonOutputWidth.w1920,
        );
        final saved = config.applyToSettings(const AppSettings());
        final restored = ComparisonExportConfig.fromSettings(saved);
        expect(restored.imageEncoding, encoding);
        expect(restored.outputWidth, ComparisonOutputWidth.w1920);
        expect(restored.copyWith(showLabels: true).imageEncoding, encoding);
        expect(
          restored
              .copyWith(imageEncoding: ComparisonImageEncoding.png)
              .outputWidth,
          ComparisonOutputWidth.w1920,
        );
      },
    );

    test(
      '$encoding produces matching bytes MIME extension and dimensions',
      () async {
        final input = source(100, 60, 230, 0);
        final original = Uint8List.fromList(input);
        final output = await const ComparisonExportRenderer().renderEncoded(
          referenceBytes: input,
          capturedBytes: input,
          config: simple.copyWith(imageEncoding: encoding),
          metadata: {},
          colorGradingSummary: null,
        );
        expect(input, original);
        expect(output.width, 100);
        expect(output.height, 120);
        expect(
          output.extension,
          encoding == ComparisonImageEncoding.png ? 'png' : 'jpg',
        );
        expect(
          output.mimeType,
          encoding == ComparisonImageEncoding.png ? 'image/png' : 'image/jpeg',
        );
        expect(
          output.bytes.take(2),
          encoding == ComparisonImageEncoding.png ? [137, 80] : [255, 216],
        );
        final decoded = img.decodeImage(output.bytes)!;
        expect(decoded.width, output.width);
        expect(decoded.height, output.height);
        expect(decoded.getPixel(50, 110).r, closeTo(230, 3));
      },
    );
  }

  test(
    'whole layout fits area and edge budgets without mutating config',
    () async {
      const config = ComparisonExportConfig(
        borderWidthPercent: 2,
        showLabels: true,
        showPilgrimName: true,
        pilgrimName: 'test',
        imageEncoding: ComparisonImageEncoding.png,
      );
      final before = config.toJson();
      final inputs = source(200, 100, 255, 0);
      final full = await const ComparisonExportRenderer().renderEncoded(
        referenceBytes: inputs,
        capturedBytes: inputs,
        config: config,
        metadata: {ComparisonMetadataField.pointName: 'test'},
        colorGradingSummary: null,
      );
      const budget = ComparisonRenderBudget(maxPixels: 16000, maxEdge: 180);
      final limited = await const ComparisonExportRenderer(budget: budget)
          .renderEncoded(
            referenceBytes: inputs,
            capturedBytes: inputs,
            config: config,
            metadata: {ComparisonMetadataField.pointName: 'test'},
            colorGradingSummary: null,
          );
      final expected = budget.fit(
        full.width.toDouble(),
        full.height.toDouble(),
      );
      expect(limited.width * limited.height, lessThanOrEqualTo(16000));
      expect(limited.width, lessThanOrEqualTo(180));
      expect(limited.height, lessThanOrEqualTo(180));
      expect(limited.width, closeTo(expected.width, 1));
      expect(limited.height, closeTo(expected.height, 1));
      expect(
        limited.width / limited.height,
        closeTo(full.width / full.height, 0.015),
      );
      expect(config.toJson(), before);
    },
  );

  test(
    'multi-megabyte metadata is bounded for layout without changing originals',
    () async {
      final huge = 'x' * (4 * 1024 * 1024);
      final metadata = {
        for (final field in ComparisonMetadataField.values) field: huge,
      };
      final config = ComparisonExportConfig(
        outputWidth: ComparisonOutputWidth.w1080,
        imageEncoding: ComparisonImageEncoding.png,
        showPilgrimName: true,
        pilgrimName: huge,
        showColorGradingParams: true,
        metadataFields: ComparisonMetadataField.values.toSet(),
      );
      final before = config.toJson();
      final input = source(160, 90, 255, 0);
      const renderer = ComparisonExportRenderer(
        budget: ComparisonRenderBudget(maxPixels: 100000, maxEdge: 512),
      );
      final output = await renderer.renderEncoded(
        referenceBytes: input,
        capturedBytes: input,
        config: config,
        metadata: metadata,
        colorGradingSummary: huge,
      );
      final boundedField = '${'x' * 512}...';
      final bounded = await renderer.renderEncoded(
        referenceBytes: input,
        capturedBytes: input,
        config: config.copyWith(pilgrimName: boundedField),
        metadata: {for (final field in metadata.keys) field: boundedField},
        colorGradingSummary: '${'x' * 1024}...',
      );
      expect(output.bytes, isNotEmpty);
      expect(output.width * output.height, lessThanOrEqualTo(100000));
      expect(output.width, lessThanOrEqualTo(512));
      expect(output.height, lessThanOrEqualTo(512));
      expect(output.bytes, bounded.bytes);
      expect(config.toJson(), before);
      expect(config.pilgrimName, huge);
      expect(metadata.values.every((text) => identical(text, huge)), isTrue);
      expect(huge.length, 4 * 1024 * 1024);
    },
  );

  test(
    'both source headers and full layout checked before any raster decode',
    () async {
      final good = source(20, 20, 255, 0);
      final oversized = Uint8List.fromList(good);
      ByteData.sublistView(oversized).setUint32(16, 16000001);
      var decodes = 0;
      final previous = debugOnImageRasterDecode;
      debugOnImageRasterDecode = () => decodes++;
      addTearDown(() => debugOnImageRasterDecode = previous);
      await expectLater(
        const ComparisonExportRenderer().renderEncoded(
          referenceBytes: good,
          capturedBytes: oversized,
          config: simple,
          metadata: {},
          colorGradingSummary: null,
        ),
        throwsA(
          isA<ImageBudgetException>().having(
            (e) => e.kind,
            'kind',
            ImageBudgetFailure.sourcePixels,
          ),
        ),
      );
      expect(decodes, 0);
      await expectLater(
        const ComparisonExportRenderer(
          budget: ComparisonRenderBudget(maxPixels: 1, maxEdge: 1),
        ).renderEncoded(
          referenceBytes: good,
          capturedBytes: good,
          config: simple,
          metadata: {},
          colorGradingSummary: null,
        ),
        throwsA(isA<ComparisonOutputLimitException>()),
      );
      expect(decodes, 0);
    },
  );

  test(
    'source load and encoding queue serializes and releases after failure',
    () async {
      final held = Completer<ComparisonRenderInputs>();
      final events = <int>[];
      const renderer = ComparisonExportRenderer();
      final first = renderer.renderLoaded(
        loadSources: () {
          events.add(1);
          return held.future;
        },
        config: simple,
        metadata: {},
        colorGradingSummary: null,
      );
      final failed = expectLater(first, throwsStateError);
      final good = source(20, 20, 255, 0);
      final second = renderer.renderLoaded(
        loadSources: () async {
          events.add(2);
          return ComparisonRenderInputs(
            referenceBytes: null,
            capturedBytes: good,
          );
        },
        config: simple,
        metadata: {},
        colorGradingSummary: null,
      );
      await Future<void>.delayed(Duration.zero);
      expect(events, [1]);
      held.completeError(StateError('read failed'));
      await failed;
      expect((await second).bytes, isNotEmpty);
      expect(events, [1, 2]);
    },
  );

  test(
    'continuous mixed encodings dispose every raster and release the queue',
    () async {
      final input = source(40, 30, 240, 0);
      final created = <ui.Image>[];
      final disposed = <ui.Image>{};
      final previousCreate = ui.Image.onCreate;
      final previousDispose = ui.Image.onDispose;
      ui.Image.onCreate = created.add;
      ui.Image.onDispose = disposed.add;
      addTearDown(() {
        ui.Image.onCreate = previousCreate;
        ui.Image.onDispose = previousDispose;
      });
      for (var iteration = 0; iteration < 2; iteration++) {
        for (final encoding in ComparisonImageEncoding.values) {
          final result = await const ComparisonExportRenderer().renderEncoded(
            referenceBytes: input,
            capturedBytes: input,
            config: simple.copyWith(imageEncoding: encoding),
            metadata: {},
            colorGradingSummary: null,
          );
          expect(result.bytes, isNotEmpty);
          expect(created.every(disposed.contains), isTrue);
        }
      }
      expect(created, isNotEmpty);
      expect(created.every(disposed.contains), isTrue);
    },
  );
}
