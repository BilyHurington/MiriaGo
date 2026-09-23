import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:miriago/camera_reference/photo_location_save_stub.dart'
    if (dart.library.io) 'package:miriago/camera_reference/photo_location_save_io.dart';
import 'package:miriago/data/bounded_image_decoder.dart';
import 'package:miriago/widgets/bounded_image.dart';

void main() {
  tearDown(() {
    debugOnImageRasterDecode = null;
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  });

  testWidgets(
    'pending asset read survives unmount and lease shares panel key',
    (tester) async {
      const path = 'docs/sample_images/bounded-delayed.png';
      late Completer<ByteData> data;
      late Completer<void> started;
      await tester.runAsync(() async {
        data = Completer<ByteData>();
        started = Completer<void>();
      });
      var reads = 0, rasters = 0;
      debugOnImageRasterDecode = () => rasters++;
      tester.binding.defaultBinaryMessenger.setMockMessageHandler(
        'flutter/assets',
        (message) async {
          if (const StringCodec().decodeMessage(message) != path) return null;
          reads++;
          if (!started.isCompleted) started.complete();
          return data.future;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMessageHandler(
          'flutter/assets',
          null,
        ),
      );
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      final context = tester.element(find.byType(SizedBox).first);
      late Future<void> lease;
      var settled = false;
      await tester.runAsync(() async {
        lease = retainPhotoPreviewUntilRead(path, context).then((_) {
          settled = true;
        });
        await started.future;
      });
      await tester.pumpWidget(
        const MaterialApp(home: BoundedImage(path: path)),
      );
      expect(find.text('图片加载中'), findsOneWidget);
      expect(settled, false);
      expect(reads, 1);
      expect(
        BoundedImageProvider(path: path),
        BoundedImageProvider(path: path, target: ImageDecodeTarget.panel),
      );
      expect(
        BoundedImageProvider(path: path),
        isNot(BoundedImageProvider(path: path, target: ImageDecodeTarget.list)),
      );
      await tester.pumpWidget(const SizedBox());
      expect(settled, false);
      await tester.runAsync(() async {
        final bytes = img.encodePng(img.Image(width: 20, height: 10));
        data.complete(ByteData.sublistView(bytes));
        await lease;
      });
      await tester.pump();
      expect(settled, true);
      expect(reads, 1);
      expect(rasters, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'small thumbnail budget error stays compact without text overflow',
    (tester) async {
      final bytes = img.encodePng(img.Image(width: 1, height: 1));
      ByteData.sublistView(bytes)
        ..setUint32(16, 8000)
        ..setUint32(20, 6000);
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: 40,
              height: 40,
              child: BoundedImage(bytes: bytes, target: ImageDecodeTarget.list),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(Tooltip), findsOneWidget);
      expect(find.textContaining('16000000'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
