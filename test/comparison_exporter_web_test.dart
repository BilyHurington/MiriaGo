@TestOn('browser')
library;

import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:miriago/data/bounded_image_decoder.dart';
import 'package:miriago/records/comparison_export_config.dart';
import 'package:miriago/records/comparison_exporter_web.dart';
import 'package:web/web.dart' as web;

@JS('window')
external JSObject get _window;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final source = img.encodePng(img.Image(width: 24, height: 16));
  const sourcePath = 'assets/visit_record_images/source.png';
  late JSAny? previous;
  setUp(() {
    previous = _window.getProperty<JSAny?>('__TAURI__'.toJS);
  });
  tearDown(() => _window.setProperty('__TAURI__'.toJS, previous));

  for (final encoding in ComparisonImageEncoding.values) {
    test(
      'Tauri $encoding bounds reads and writes correctly named encoded asset',
      () async {
        final reads = <Map>[];
        final writes = <Map>[];
        final core = JSObject();
        core.setProperty(
          'invoke'.toJS,
          ((JSString command, JSObject args) {
            final request = (args.dartify() as Map)['request'] as Map;
            if (command.toDart == 'read_asset') {
              reads.add(request);
              return Future<JSAny?>.value(
                {
                  'dataBase64': base64Encode(source),
                  'mimeType': 'image/png',
                }.jsify(),
              ).toJS;
            }
            expect(command.toDart, 'write_asset');
            writes.add(request);
            return Future<JSAny?>.value(
              {'dataBase64': '', 'mimeType': encoding.mimeType}.jsify(),
            ).toJS;
          }).toJS,
        );
        _window.setProperty(
          '__TAURI__'.toJS,
          JSObject()..setProperty('core'.toJS, core),
        );
        final result = await exportComparisonImage(
          referenceImagePath: sourcePath,
          referenceImageUrl: null,
          capturedPath: sourcePath,
          config: ComparisonExportConfig(
            imageEncoding: encoding,
            borderWidthPercent: 0,
            metadataFields: {},
          ),
          metadata: {},
          colorGradingSummary: null,
        );
        expect(result.disposition, ComparisonExportDisposition.localFile);
        expect(reads, hasLength(2));
        for (final request in reads) {
          expect(request['path'], sourcePath);
          expect(request['maxBytes'], maxImageEncodedBytes);
        }
        expect(writes, hasLength(1));
        expect(result.path, writes.single['path']);
        expect(result.path, endsWith('.${encoding.extension}'));
        final bytes = base64Decode(writes.single['dataBase64'] as String);
        expect(
          bytes.take(2),
          encoding == ComparisonImageEncoding.png ? [137, 80] : [255, 216],
        );
        final decoded = img.decodeImage(bytes)!;
        expect(decoded.width, 24);
        expect(decoded.height, 32);
      },
    );
  }

  test(
    'ordinary Web exports blob sources through browser download without filepath',
    () async {
      _window.setProperty('__TAURI__'.toJS, null);
      final blob = web.Blob(
        [source.toJS].toJS,
        web.BlobPropertyBag(type: 'image/png'),
      );
      final url = web.URL.createObjectURL(blob);
      addTearDown(() => web.URL.revokeObjectURL(url));
      final result = await exportComparisonImage(
        referenceImagePath: url,
        referenceImageUrl: null,
        capturedPath: url,
        config: const ComparisonExportConfig(
          borderWidthPercent: 0,
          metadataFields: {},
        ),
        metadata: {},
        colorGradingSummary: null,
      );
      expect(result.disposition, ComparisonExportDisposition.downloaded);
      expect(result.path, isNull);
    },
  );

  test(
    'Tauri bounded read failure remains budget error and never writes',
    () async {
      final core = JSObject();
      core.setProperty(
        'invoke'.toJS,
        ((JSString command, JSObject args) {
          expect(command.toDart, 'read_asset');
          return JSPromise<JSAny?>(
            (JSFunction resolve, JSFunction reject) {
              reject.callAsFunction(
                null,
                'ASSET_BYTE_LIMIT: 33554433 > 33554432'.toJS,
              );
            }.toJS,
          );
        }).toJS,
      );
      _window.setProperty(
        '__TAURI__'.toJS,
        JSObject()..setProperty('core'.toJS, core),
      );
      final result = await exportComparisonImage(
        referenceImagePath: sourcePath,
        referenceImageUrl: null,
        capturedPath: sourcePath,
        config: const ComparisonExportConfig(),
        metadata: {},
        colorGradingSummary: null,
      );
      expect(
        result.failureReason,
        ComparisonExportFailureReason.budgetExceeded,
      );
      expect(result.message, contains('33554432'));
      expect(result.path, isNull);
    },
  );
}
