@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:miriago/camera_reference/gallery_capture_time_io.dart';
import 'package:miriago/camera_reference/photo_location_save_io.dart';
import 'package:miriago/color_grading/color_adjustment.dart';
import 'package:miriago/color_grading/color_grading_params.dart';
import 'package:miriago/data/bounded_image_decoder.dart';
import 'package:miriago/data/bounded_image_file_io.dart';
import 'package:miriago/records/visit_record_photo_io.dart';
import 'package:miriago/widgets/bounded_image.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  setUp(() {
    root = Directory.systemTemp.createTempSync('miriago-bounded-');
  });
  tearDown(() {
    debugOnImageRasterDecode = null;
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    root.deleteSync(recursive: true);
  });

  test('file cap rejects and preserves original', () async {
    final file = await File(
      '${root.path}/original.jpg',
    ).writeAsBytes([1, 2, 3, 4]);
    await expectLater(
      readBoundedImageFile(file.path, maxBytes: 3),
      throwsA(isA<ImageBudgetException>()),
    );
    expect(await file.readAsBytes(), [1, 2, 3, 4]);
  });

  for (final date in [
    '2026:02:31 12:00:00',
    '2026:13:01 12:00:00',
    '2026:01:01 25:00:00',
    '2026:01:01 12:61:00',
  ]) {
    test('EXIF invalid date $date falls back without raster', () async {
      final image = img.Image(width: 2, height: 2);
      image.exif.exifIfd['DateTimeOriginal'] = date;
      final file = await File(
        '${root.path}/date.jpg',
      ).writeAsBytes(img.encodeJpg(image));
      var rasters = 0;
      debugOnImageRasterDecode = () => rasters++;
      expect(await readGalleryCaptureTime(file.path), isNull);
      expect(rasters, 0);
    });
  }

  test('valid EXIF date survives damaged JPEG raster', () async {
    final image = img.Image(width: 2, height: 2);
    image.exif.exifIfd['DateTimeOriginal'] = '2024:02:29 12:34:56';
    final encoded = img.encodeJpg(image);
    var offset = 2;
    while (encoded[offset + 1] != 0xda) {
      offset += 2 + ((encoded[offset + 2] << 8) | encoded[offset + 3]);
    }
    final file = await File(
      '${root.path}/date.jpg',
    ).writeAsBytes(encoded.sublist(0, offset));
    expect(
      await readGalleryCaptureTime(file.path),
      DateTime(2024, 2, 29, 12, 34, 56),
    );
  });

  test(
    'grading operates on bounded RGBA and keeps source bytes unchanged',
    () async {
      final input = Uint8List.fromList(
        img.encodeJpg(img.Image(width: 80, height: 40)),
      );
      final original = Uint8List.fromList(input);
      final result = await renderGradedJpeg(
        imageBytes: input,
        params: const ColorGradingParams(),
      );
      final info = await probeBoundedImage(result);
      expect([info.width, info.height], [80, 40]);
      expect(input, original);
    },
  );

  test('grading and matching reject 48MP before raster', () async {
    final small = Uint8List.fromList(
      img.encodePng(img.Image(width: 2, height: 2)),
    );
    final large = Uint8List.fromList(small);
    ByteData.sublistView(large)
      ..setUint32(16, 8000)
      ..setUint32(20, 6000);
    var rasters = 0;
    debugOnImageRasterDecode = () => rasters++;
    await expectLater(
      renderGradedJpeg(imageBytes: large, params: const ColorGradingParams()),
      throwsA(isA<ImageBudgetException>()),
    );
    await expectLater(
      autoMatchColorTone(
        capturedBytes: small,
        referenceBytes: large,
        mode: ColorMatchMode.standard,
      ),
      throwsA(isA<ImageBudgetException>()),
    );
    expect(rasters, 0);
  });

  testWidgets('confirmation lease and panel share one decode across disposal', (
    tester,
  ) async {
    final bytes = img.encodePng(img.Image(width: 40, height: 20));
    final file = File('${root.path}/pending.png');
    file.writeAsBytesSync(bytes);
    var rasters = 0;
    debugOnImageRasterDecode = () => rasters++;
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    final context = tester.element(find.byType(SizedBox).first);
    late Future<void> lease;
    await tester.runAsync(() async {
      lease = retainPhotoPreviewUntilRead(file.path, context);
      await lease;
    });
    await tester.pumpWidget(
      MaterialApp(
        home: VisitRecordPhoto(
          path: file.path,
          target: ImageDecodeTarget.panel,
        ),
      ),
    );
    await tester.pump();
    expect(rasters, 1);
    expect(
      tester.widget<Image>(find.byType(Image)).image,
      BoundedImageProvider(path: file.path),
    );
    await tester.pumpWidget(const SizedBox());
    file.deleteSync();
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  final heicPath = Platform.environment['HEIC_TEST_FIXTURE'];
  test(
    'Apple HEIC metadata then bounded native decode',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        final bytes = await File(heicPath!).readAsBytes();
        var rasters = 0;
        debugOnImageRasterDecode = () => rasters++;
        final info = await probeBoundedImage(bytes);
        expect([info.width, info.height], [300, 400]);
        expect(rasters, 0);
        final image = await decodeBoundedImage(
          bytes,
          target: ImageDecodeTarget.list,
        );
        expect([image.width, image.height], [300, 400]);
        expect(rasters, 1);
        image.dispose();
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
    skip: heicPath == null || !Platform.isMacOS,
  );
}
