@TestOn('browser')
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:miriago/data/bounded_image_decoder.dart';
import 'package:miriago/data/reference_asset_paths.dart';
import 'package:miriago/data/user_reference_image_stub.dart';
import 'package:miriago/plan/pending_reference_lifecycle.dart';
import 'package:miriago/widgets/bounded_image.dart';
import 'package:web/web.dart' as web;

@JS('window')
external JSObject get _window;
@JS('Function')
external JSFunction _function(JSString first, JSString second, JSString body);

class _Bridge {
  final files = <String, String>{
    'assets/user_reference_images/existing.jpg': 'b2xk',
  };
  final pending = <String, List<String>>{};
  int restores = 0, cleanups = 0, finalizes = 0;
  bool partialFailure = false, missingPath = false, finalizeFailure = false;
  Future<JSAny?> invoke(JSString command, JSObject arguments) async {
    final request = (arguments.dartify()! as Map)['request'] as Map;
    switch (command.toDart) {
      case 'restore_import_assets':
        final id = ++restores;
        if (pending.length >= 128) {
          throw StateError('too many unfinished asset restorations');
        }
        final assets = Map<String, String>.from(request['assetsBase64'] as Map);
        final paths = <String, String>{};
        for (final entry in assets.entries) {
          final path = 'assets/imported_plan_assets/import-$id/${entry.key}';
          paths[entry.key] = path;
          files[path] = entry.value;
          if (partialFailure) {
            // Contract of the real Rust restore, also covered by Rust fault tests.
            for (final written in paths.values) {
              files.remove(written);
            }
            throw StateError('injected restore write failure');
          }
        }
        pending['token-$id'] = paths.values.toList();
        if (missingPath) {
          paths.removeWhere((key, value) => key.endsWith('/thumb.jpg'));
        }
        return {'restoredPaths': paths, 'restoreToken': 'token-$id'}.jsify();
      case 'cleanup_import_assets':
        expect(request.keys, ['restoreToken']);
        cleanups++;
        for (final path in pending.remove(request['restoreToken'])!) {
          files.remove(path);
        }
        return null;
      case 'finalize_import_assets':
        finalizes++;
        if (finalizeFailure) throw StateError('injected finalize failure');
        expect(pending.remove(request['restoreToken']), isNotNull);
        return null;
      case 'read_asset':
        return {
          'dataBase64': files[request['path']],
          'mimeType': 'image/jpeg',
        }.jsify();
      default:
        throw StateError('unexpected command: ${command.toDart}');
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Bridge bridge;
  late JSAny? previous;
  late JSObject xhrPrototype;
  late JSAny? previousOpen;
  final urls = <String>[];
  setUp(() {
    bridge = _Bridge();
    previous = _window.getProperty<JSAny?>('__TAURI__'.toJS);
    final core = JSObject()
      ..setProperty(
        'invoke'.toJS,
        ((JSString cmd, JSObject args) => bridge.invoke(cmd, args).toJS).toJS,
      );
    _window.setProperty(
      '__TAURI__'.toJS,
      JSObject()..setProperty('core'.toJS, core),
    );
    xhrPrototype = _window
        .getProperty<JSObject>('XMLHttpRequest'.toJS)
        .getProperty<JSObject>('prototype'.toJS);
    previousOpen = xhrPrototype.getProperty<JSAny?>('open'.toJS);
  });
  tearDown(() {
    debugOnImageRasterDecode = null;
    _window.setProperty('__TAURI__'.toJS, previous);
    xhrPrototype.setProperty('open'.toJS, previousOpen);
    for (final url in urls) {
      web.URL.revokeObjectURL(url);
    }
    urls.clear();
  });

  String source(Uint8List bytes, String name) {
    final url = web.URL.createObjectURL(web.Blob([bytes.toJS].toJS));
    urls.add(url);
    // Give XFile a deliberately misleading filename while serving a real Blob.
    // No external request is made; restore the native method after each test.
    final factory = _function(
      'original'.toJS,
      'target'.toJS,
      'return function(method, requested, async) { return original.call(this, method, target, async); };'
          .toJS,
    );
    xhrPrototype.setProperty(
      'open'.toJS,
      factory.callAsFunction(null, previousOpen, url.toJS),
    );
    return 'https://upload.invalid/$name';
  }

  for (final png in [true, false]) {
    test(
      'actual signature wins over misleading source filename png=$png; discard owns only batch',
      () async {
        final image = img.Image(width: 720, height: 480);
        final bytes = Uint8List.fromList(
          png ? img.encodePng(image) : img.encodeJpg(image),
        );
        final path = source(bytes, png ? 'source.jpg' : 'source.png');
        final stored = (await storeUserReferenceImage(
          sourcePath: path,
          pointId: '../p',
        ))!;
        expect(stored.fullImagePath, endsWith(png ? '.png' : '.jpg'));
        expect(isRuntimeManagedAssetPath(stored.fullImagePath), true);
        expect(isSafeRelativeAssetPath(stored.fullImagePath), true);
        expect(stored.fullImagePath, contains('/user_reference_images/'));
        expect(await readBoundedImageSource(stored.fullImagePath), bytes);
        final thumb = await readBoundedImageSource(stored.thumbnailPath);
        expect(thumb.take(3), [255, 216, 255]);
        final info = await probeBoundedImage(thumb);
        expect([info.width, info.height], [360, 240]);
        await deleteStoredUserReferenceImage(stored);
        await deleteStoredUserReferenceImage(stored);
        expect(bridge.cleanups, 1);
        expect(bridge.pending, isEmpty);
        expect(bridge.files.keys, [
          'assets/user_reference_images/existing.jpg',
        ]);
      },
    );
  }

  test(
    '48MP rejects before raster or restore; source bytes remain readable',
    () async {
      final bytes = img.encodePng(img.Image(width: 1, height: 1));
      ByteData.sublistView(bytes)
        ..setUint32(16, 8000)
        ..setUint32(20, 6000);
      final path = source(bytes, 'large.png');
      var rasters = 0;
      debugOnImageRasterDecode = () => rasters++;
      await expectLater(
        storeUserReferenceImage(sourcePath: path, pointId: 'p'),
        throwsA(isA<ImageBudgetException>()),
      );
      expect(rasters, 0);
      expect(bridge.restores, 0);
      expect(bridge.files.length, 1);
      expect(urls, hasLength(1));
    },
  );

  test(
    'partial write uses one atomic restore, not independently committed asset writes',
    () async {
      bridge.partialFailure = true;
      final path = source(
        img.encodePng(img.Image(width: 2, height: 2)),
        'source.png',
      );
      await expectLater(
        storeUserReferenceImage(sourcePath: path, pointId: 'p'),
        throwsA(anything),
      );
      expect(bridge.restores, 1);
      expect(bridge.files.length, 1);
      expect(bridge.pending, isEmpty);
    },
  );

  test(
    'incomplete restore response cleans only the returned ownership token',
    () async {
      bridge.missingPath = true;
      final path = source(
        img.encodePng(img.Image(width: 2, height: 2)),
        'source.png',
      );
      await expectLater(
        storeUserReferenceImage(sourcePath: path, pointId: 'p'),
        throwsStateError,
      );
      expect(bridge.cleanups, 1);
      expect(bridge.files.length, 1);
      expect(bridge.pending, isEmpty);
    },
  );

  for (final succeeded in [true, false]) {
    test(
      'outcome $succeeded retains and finalizes more than 128 uploads without accumulating tokens',
      () async {
        final path = source(
          img.encodePng(img.Image(width: 2, height: 2)),
          'source.png',
        );
        for (var i = 0; i < 130; i++) {
          final stored = (await storeUserReferenceImage(
            sourcePath: path,
            pointId: 'p',
          ))!;
          final lifecycle = PendingReferenceLifecycle<StoredUserReferenceImage>(
            delete: deleteStoredUserReferenceImage,
            onRetain: (image) => image.retain(),
          );
          await lifecycle.select(() async => stored);
          lifecycle.beginSave();
          lifecycle.beginPersistence();
          lifecycle.finishPersistence(succeeded: succeeded);
          lifecycle.endSave();
          lifecycle.dispose();
          await stored.retain();
          await deleteStoredUserReferenceImage(stored);
          expect(bridge.pending, isEmpty);
          expect(bridge.files.containsKey(stored.fullImagePath), true);
        }
        expect(bridge.finalizes, 130);
        expect(bridge.cleanups, 0);
      },
    );
  }

  test(
    'failed finalization never makes possibly committed files disposable',
    () async {
      final path = source(
        img.encodePng(img.Image(width: 2, height: 2)),
        'source.png',
      );
      final stored = (await storeUserReferenceImage(
        sourcePath: path,
        pointId: 'p',
      ))!;
      bridge.finalizeFailure = true;
      await expectLater(stored.retain(), throwsA(anything));
      await deleteStoredUserReferenceImage(stored);
      expect(bridge.files.containsKey(stored.fullImagePath), true);
      expect(bridge.cleanups, 0);
      bridge.finalizeFailure = false;
      await stored.retain();
      await stored.retain();
      expect(bridge.pending, isEmpty);
    },
  );
}
