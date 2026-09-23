@TestOn('browser')
library;

import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:miriago/desktop/desktop_asset_image.dart';

@JS('window')
external JSObject get _window;

void main() {
  testWidgets(
    'Tauri thumbnail data URL preserves bytes and decodes for pending preview',
    (tester) async {
      final previous = _window.getProperty<JSAny?>('__TAURI__'.toJS);
      addTearDown(() => _window.setProperty('__TAURI__'.toJS, previous));
      final bytes = img.encodeJpg(img.Image(width: 3, height: 2));
      const path = 'assets/user_reference_images/thumb/preview-contract.jpg';
      final requests = <Object?>[];
      final core = JSObject();
      core.setProperty(
        'invoke'.toJS,
        ((JSString command, JSObject arguments) {
          expect(command.toDart, 'read_asset');
          requests.add(arguments.dartify());
          return Future<JSAny?>.value(
            {
              'dataBase64': base64Encode(bytes),
              'mimeType': 'image/jpeg',
            }.jsify(),
          ).toJS;
        }).toJS,
      );
      final tauri = JSObject()..setProperty('core'.toJS, core);
      _window.setProperty('__TAURI__'.toJS, tauri);

      expect(isDesktopAssetPath(path), isTrue);
      final dataUrl = await tester.runAsync(
        () => loadDesktopAssetDataUrl(path),
      );
      expect(dataUrl, startsWith('data:image/jpeg;base64,'));
      final thumbnailBytes = base64Decode(
        dataUrl!.substring(dataUrl.indexOf(',') + 1),
      );
      expect(thumbnailBytes, bytes);
      expect(requests, [
        {
          'request': {'path': path},
        },
      ]);
      Object? decodeError;
      await tester.pumpWidget(
        MaterialApp(
          home: Image.memory(
            thumbnailBytes,
            errorBuilder: (_, error, _) {
              decodeError = error;
              return const SizedBox();
            },
          ),
        ),
      );
      for (var i = 0; i < 50; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
        if (tester.widget<RawImage>(find.byType(RawImage)).image != null) break;
      }
      final decoded = tester.widget<RawImage>(find.byType(RawImage)).image;
      expect(decodeError, isNull);
      expect(decoded?.width, 3);
      expect(decoded?.height, 2);
      expect(tester.takeException(), isNull);
    },
  );
}
