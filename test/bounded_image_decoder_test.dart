import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:miriago/data/bounded_image_decoder.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  var rasters = 0;
  setUp(() {
    rasters = 0;
    debugOnImageRasterDecode = () => rasters++;
  });
  tearDown(() {
    debugOnImageRasterDecode = null;
  });

  test('small PNG decodes within target', () async {
    final bytes = Uint8List.fromList(
      img.encodePng(img.Image(width: 80, height: 40)),
    );
    final image = await decodeBoundedImage(
      bytes,
      target: const ImageDecodeTarget(maxEdge: 40, maxPixels: 800),
    );
    expect([image.width, image.height], [40, 20]);
    expect(rasters, 1);
    image.dispose();
  });

  test(
    'grading target is independently capped at 12MP without shrinking source allowance',
    () {
      final size = ImageDecodeTarget.grading.dimensions(
        const BoundedImageInfo(4032, 3024),
      );
      expect(size.width * size.height, lessThanOrEqualTo(12000000));
      expect(size.width / size.height, closeTo(4 / 3, .002));
      final thin = const ImageDecodeTarget(
        maxEdge: 16000,
        maxPixels: 1,
      ).dimensions(const BoundedImageInfo(1, 16000));
      expect(thin.width * thin.height, 1);
    },
  );

  test(
    'ordinary 12MP source remains usable with bounded retained target',
    () async {
      final recorder = ui.PictureRecorder();
      ui.Canvas(
        recorder,
      ).drawColor(const ui.Color(0xff558833), ui.BlendMode.src);
      final picture = recorder.endRecording();
      final original = await picture.toImage(4032, 3024);
      picture.dispose();
      final data = (await original.toByteData(format: ui.ImageByteFormat.png))!;
      original.dispose();
      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      final info = await probeBoundedImage(bytes);
      expect([info.width, info.height], [4032, 3024]);
      expect(rasters, 0);
      final image = await decodeBoundedImage(
        bytes,
        target: ImageDecodeTarget.preview,
      );
      expect(image.width * image.height, lessThanOrEqualTo(4000000));
      expect(image.width / image.height, closeTo(4 / 3, .002));
      expect(rasters, 1);
      image.dispose();
    },
  );

  test(
    '48MP header rejects before any raster even with invalid payload',
    () async {
      final bytes = Uint8List.fromList(
        img.encodePng(img.Image(width: 1, height: 1)),
      );
      ByteData.sublistView(bytes)
        ..setUint32(16, 8000)
        ..setUint32(20, 6000);
      await expectLater(
        decodeBoundedImage(bytes, target: ImageDecodeTarget.preview),
        throwsA(
          isA<ImageBudgetException>().having(
            (e) => e.kind,
            'kind',
            ImageBudgetFailure.sourcePixels,
          ),
        ),
      );
      expect(rasters, 0);
    },
  );

  test(
    'duplicate PNG dimensions and chunk overflow reject before raster',
    () async {
      final bytes = Uint8List.fromList(
        img.encodePng(img.Image(width: 2, height: 2)),
      );
      final duplicate = Uint8List.fromList([
        ...bytes.sublist(0, 33),
        ...bytes.sublist(8),
      ]);
      await expectLater(
        decodeBoundedImage(duplicate, target: ImageDecodeTarget.panel),
        throwsA(isA<ImageBudgetException>()),
      );
      ByteData.sublistView(bytes).setUint32(33, 0xffffffff);
      await expectLater(
        probeBoundedImage(bytes),
        throwsA(isA<ImageBudgetException>()),
      );
      expect(rasters, 0);
    },
  );

  test('duplicate JPEG SOF rejects before raster', () async {
    final bytes = orientedJpeg(1);
    var offset = 2;
    while (bytes[offset + 1] != 0xc0) {
      offset += 2 + ByteData.sublistView(bytes).getUint16(offset + 2);
    }
    final end = offset + 2 + ByteData.sublistView(bytes).getUint16(offset + 2);
    final duplicate = Uint8List.fromList([
      ...bytes.sublist(0, end),
      ...bytes.sublist(offset),
    ]);
    await expectLater(
      decodeBoundedImage(duplicate, target: ImageDecodeTarget.panel),
      throwsA(isA<ImageBudgetException>()),
    );
    expect(rasters, 0);
  });

  test('inconsistent WebP extended canvas rejects before raster', () async {
    final bytes = Uint8List(48);
    bytes.setRange(0, 4, 'RIFF'.codeUnits);
    bytes.setRange(8, 12, 'WEBP'.codeUnits);
    bytes.setRange(12, 16, 'VP8X'.codeUnits);
    bytes.setRange(30, 34, 'VP8L'.codeUnits);
    final data = ByteData.sublistView(bytes);
    data
      ..setUint32(4, 40, Endian.little)
      ..setUint32(16, 10, Endian.little)
      ..setUint32(34, 5, Endian.little);
    bytes[24] = 9;
    bytes[27] = 9;
    bytes[38] = 0x2f;
    // Canvas 10x10 versus lossless payload 1x1.
    await expectLater(
      decodeBoundedImage(bytes, target: ImageDecodeTarget.panel),
      throwsA(isA<ImageBudgetException>()),
    );
    expect(rasters, 0);
  });

  for (var orientation = 1; orientation <= 8; orientation++) {
    test(
      'EXIF orientation $orientation keeps display aspect and corner colors',
      () async {
        final bytes = orientedJpeg(orientation);
        final expected = orientation >= 5 ? [24, 40] : [40, 24];
        final image = await decodeBoundedImage(
          bytes,
          target: const ImageDecodeTarget(maxEdge: 40, maxPixels: 960),
        );
        expect([image.width, image.height], expected);
        final data = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        final rgba = data.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        );
        final colors = <int>[];
        for (final p in [
          [3, 3],
          [image.width - 4, 3],
          [3, image.height - 4],
          [image.width - 4, image.height - 4],
        ]) {
          final offset = (p[1] * image.width + p[0]) * 4;
          final r = rgba[offset], g = rgba[offset + 1], b = rgba[offset + 2];
          colors.add(
            r > 180 && g > 180
                ? 3
                : r > g && r > b
                ? 0
                : g > r && g > b
                ? 1
                : 2,
          );
        }
        expect(
          colors,
          const [
            [0, 1, 2, 3],
            [1, 0, 3, 2],
            [3, 2, 1, 0],
            [2, 3, 0, 1],
            [0, 2, 1, 3],
            [2, 0, 3, 1],
            [3, 1, 2, 0],
            [1, 3, 0, 2],
          ][orientation - 1],
        );
        image.dispose();
      },
    );
  }

  test(
    'animated GIF emits first frame only and refuses ignored downscale',
    () async {
      final first = img.Image(width: 20, height: 12);
      img.fill(first, color: img.ColorRgb8(255, 0, 0));
      final second = img.Image(width: 20, height: 12);
      img.fill(second, color: img.ColorRgb8(0, 255, 0));
      first.addFrame(second);
      final bytes = Uint8List.fromList(img.encodeGif(first));
      final image = await decodeBoundedImage(
        bytes,
        target: ImageDecodeTarget.panel,
      );
      final data = (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!;
      expect(data.getUint8(0), greaterThan(200));
      expect(data.getUint8(1), lessThan(20));
      image.dispose();
      expect(rasters, 1);
      await expectLater(
        decodeBoundedImage(
          bytes,
          target: const ImageDecodeTarget(maxEdge: 10, maxPixels: 100),
        ),
        throwsA(
          isA<ImageBudgetException>().having(
            (e) => e.kind,
            'kind',
            ImageBudgetFailure.targetPixels,
          ),
        ),
      );
      expect(rasters, 1);
    },
  );

  test('stream checks declared and actual bytes and cancels overrun', () async {
    Stream<List<int>> stream() async* {
      yield [1, 2];
      yield [3, 4];
    }

    await expectLater(
      readImageStreamBounded(stream(), maxBytes: 3, declaredLength: 4),
      throwsA(isA<ImageBudgetException>()),
    );
    await expectLater(
      readImageStreamBounded(stream(), maxBytes: 3),
      throwsA(isA<ImageBudgetException>()),
    );
    expect(await readImageStreamBounded(Stream.value([1, 2, 3]), maxBytes: 3), [
      1,
      2,
      3,
    ]);
  });
}

Uint8List orientedJpeg(int orientation) {
  final image = img.Image(width: 80, height: 48);
  for (final pixel in image) {
    final right = pixel.x >= 40, bottom = pixel.y >= 24;
    pixel.setRgb(
      bottom ? (right ? 255 : 0) : (right ? 0 : 255),
      right ? 255 : 0,
      bottom && !right ? 255 : 0,
    );
  }
  image.exif.imageIfd.orientation = orientation;
  return Uint8List.fromList(img.encodeJpg(image, quality: 100));
}
