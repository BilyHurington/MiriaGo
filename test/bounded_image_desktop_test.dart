@TestOn('browser')
library;

import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:miriago/data/bounded_image_decoder.dart';
import 'package:miriago/desktop/tauri_bridge.dart';
import 'package:miriago/widgets/bounded_image.dart';

@JS('window')
external JSObject get _window;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late JSAny? previous;
  setUp(() {
    previous = _window.getProperty<JSAny?>('__TAURI__'.toJS);
  });
  tearDown(() => _window.setProperty('__TAURI__'.toJS, previous));

  void bridge(Future<JSAny?> Function(JSString, JSObject) invoke) {
    final core = JSObject()
      ..setProperty(
        'invoke'.toJS,
        ((JSString command, JSObject args) => invoke(command, args).toJS).toJS,
      );
    _window.setProperty(
      '__TAURI__'.toJS,
      JSObject()..setProperty('core'.toJS, core),
    );
  }

  test('bounded Tauri read sends raw-byte cap and decodes source', () async {
    final bytes = img.encodePng(img.Image(width: 24, height: 16));
    final requests = <Object?>[];
    bridge((command, args) async {
      expect(command.toDart, 'read_asset');
      requests.add(args.dartify());
      return {
        'dataBase64': base64Encode(bytes),
        'mimeType': 'image/png',
      }.jsify();
    });
    const path = 'assets/visit_record_images/bounded-test.png';
    final source = await readBoundedImageSource(path);
    expect(requests, [
      {
        'request': {'path': path, 'maxBytes': maxImageEncodedBytes},
      },
    ]);
    expect(source, bytes);
    final image = await decodeBoundedImage(
      source,
      target: ImageDecodeTarget.panel,
    );
    expect([image.width, image.height], [24, 16]);
    image.dispose();
    await readDesktopAsset(path: path);
    expect(requests.last, {
      'request': {'path': path},
    });
  });

  test(
    'Tauri over-budget rejection remains typed and retry is possible',
    () async {
      var calls = 0;
      final core = JSObject()
        ..setProperty(
          'invoke'.toJS,
          ((JSString command, JSObject args) {
            return JSPromise<JSAny?>(
              ((JSFunction resolve, JSFunction reject) {
                if (calls++ == 0) {
                  reject.callAsFunction(
                    null,
                    'ASSET_BYTE_LIMIT: 5 bytes exceeds 4'.toJS,
                  );
                } else {
                  resolve.callAsFunction(
                    null,
                    {'dataBase64': 'AQIDBA==', 'mimeType': 'image/png'}.jsify(),
                  );
                }
              }).toJS,
            );
          }).toJS,
        );
      _window.setProperty(
        '__TAURI__'.toJS,
        JSObject()..setProperty('core'.toJS, core),
      );
      await expectLater(
        readDesktopAsset(
          path: 'assets/visit_record_images/test.png',
          maxBytes: 4,
        ),
        throwsA(
          isA<ImageBudgetException>().having(
            (e) => e.kind,
            'kind',
            ImageBudgetFailure.encodedBytes,
          ),
        ),
      );
      expect(
        (await readDesktopAsset(
          path: 'assets/visit_record_images/test.png',
          maxBytes: 4,
        )).dataBase64,
        'AQIDBA==',
      );
      expect(calls, 2);
    },
  );

  test('HEIC on Web reports unsupported rather than corrupt', () async {
    final bytes = base64Decode('AAAAGGZ0eXBoZWljAAAAAG1pZjFoZWlj');
    await expectLater(
      probeBoundedImage(bytes),
      throwsA(
        isA<ImageBudgetException>().having(
          (e) => e.kind,
          'kind',
          ImageBudgetFailure.unsupported,
        ),
      ),
    );
  });
}
