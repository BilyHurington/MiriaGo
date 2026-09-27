@TestOn('vm')
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:miriago/data/bounded_image_decoder.dart';
import 'package:miriago/data/user_reference_image_io.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  setUp(() {
    root = Directory.systemTemp.createTempSync('reference-bounded-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => root.path,
        );
  });
  tearDown(() {
    debugOnImageRasterDecode = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
    root.deleteSync(recursive: true);
  });

  test(
    'normal upload preserves original and creates 360 JPEG thumbnail in exclusive directory',
    () async {
      final bytes = img.encodePng(img.Image(width: 720, height: 480));
      final source = File('${root.path}/source.png')..writeAsBytesSync(bytes);
      final first = (await storeUserReferenceImage(
        sourcePath: source.path,
        pointId: '../../point',
      ))!;
      final second = (await storeUserReferenceImage(
        sourcePath: source.path,
        pointId: '../../point',
      ))!;
      expect(first.fullImagePath, isNot(second.fullImagePath));
      expect(File(first.fullImagePath).readAsBytesSync(), bytes);
      expect(source.readAsBytesSync(), bytes);
      final thumb = File(first.thumbnailPath).readAsBytesSync();
      expect(thumb.take(3), [255, 216, 255]);
      final info = await probeBoundedImage(thumb);
      expect([info.width, info.height], [360, 240]);
      await deleteStoredUserReferenceImage(first);
      await deleteStoredUserReferenceImage(first);
      expect(File(first.fullImagePath).existsSync(), false);
      expect(
        Directory(File(first.fullImagePath).parent.path).existsSync(),
        false,
      );
      expect(File(second.fullImagePath).existsSync(), true);
      expect(source.readAsBytesSync(), bytes);
      await second.retain();
      await second.retain();
      expect(File(second.fullImagePath).existsSync(), true);
    },
  );

  test(
    '48MP rejection performs zero raster and leaves no generated files',
    () async {
      final bytes = img.encodePng(img.Image(width: 1, height: 1));
      ByteData.sublistView(bytes)
        ..setUint32(16, 8000)
        ..setUint32(20, 6000);
      final source = File('${root.path}/source.png')..writeAsBytesSync(bytes);
      var raster = 0;
      debugOnImageRasterDecode = () => raster++;
      await expectLater(
        storeUserReferenceImage(sourcePath: source.path, pointId: 'p'),
        throwsA(
          isA<ImageBudgetException>().having(
            (e) => e.kind,
            'kind',
            ImageBudgetFailure.sourcePixels,
          ),
        ),
      );
      expect(raster, 0);
      expect(root.listSync().map((e) => e.path), [source.path]);
      expect(source.readAsBytesSync(), bytes);
    },
  );

  test('compressed byte rejection leaves source untouched', () async {
    final source = File('${root.path}/large.jpg');
    final handle = source.openSync(mode: FileMode.write);
    handle.truncateSync(maxImageEncodedBytes + 1);
    handle.closeSync();
    await expectLater(
      storeUserReferenceImage(sourcePath: source.path, pointId: 'p'),
      throwsA(
        isA<ImageBudgetException>().having(
          (e) => e.kind,
          'kind',
          ImageBudgetFailure.encodedBytes,
        ),
      ),
    );
    expect(source.lengthSync(), maxImageEncodedBytes + 1);
    expect(root.listSync().length, 1);
  });

  test(
    'thumbnail write failure removes only this exclusive batch including full copy',
    () async {
      final bytes = img.encodePng(img.Image(width: 20, height: 10));
      final source = File('${root.path}/source.png')..writeAsBytesSync(bytes);
      final existing = (await storeUserReferenceImage(
        sourcePath: source.path,
        pointId: 'p',
      ))!;
      final parent = Zone.current;
      String? newFull;
      await expectLater(
        IOOverrides.runZoned(
          () => storeUserReferenceImage(sourcePath: source.path, pointId: 'p'),
          createFile: (path) {
            if (path.endsWith('/full.png')) newFull = path;
            if (path.endsWith('/thumb.jpg')) {
              expect(parent.run(() => File(newFull!).existsSync()), true);
              throw const FileSystemException(
                'injected thumbnail write failure',
              );
            }
            return parent.run(() => File(path));
          },
        ),
        throwsA(isA<FileSystemException>()),
      );
      expect(newFull, isNotNull);
      expect(File(newFull!).parent.existsSync(), false);
      expect(File(existing.fullImagePath).readAsBytesSync(), bytes);
      expect(source.readAsBytesSync(), bytes);
    },
  );
}
