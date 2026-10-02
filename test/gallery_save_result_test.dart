import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/records/gallery_saver_io.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const gallery = MethodChannel('seichi/gallery_saver');
  const permissions = MethodChannel('flutter.baseflow.com/permissions/methods');

  tearDown(() {
    messenger.setMockMethodCallHandler(gallery, null);
    messenger.setMockMethodCallHandler(permissions, null);
  });

  Future<GallerySaveResult> saveWith(Object? Function() answer) {
    messenger.setMockMethodCallHandler(gallery, (_) async => answer());
    return saveImageToGalleryWithResult('/tmp/photo.jpg');
  }

  test('native permission errors map to permissionDenied', () async {
    expect(await saveWith(() => 'content://1'), GallerySaveResult.saved);
    for (final code in ['PHOTO_PERMISSION_DENIED', 'PERMISSION_DENIED']) {
      expect(
        await saveWith(() => throw PlatformException(code: code)),
        GallerySaveResult.permissionDenied,
      );
    }
    expect(
      await saveWith(() => throw PlatformException(code: 'SAVE_FAILED')),
      GallerySaveResult.failed,
    );
    expect(await saveWith(() => null), GallerySaveResult.failed);
    expect(await saveImageToGallery('/tmp/photo.jpg'), isFalse);
  });

  testWidgets('a refused permission offers the system settings', (
    tester,
  ) async {
    var settingsOpened = 0;
    messenger.setMockMethodCallHandler(permissions, (call) async {
      if (call.method == 'openAppSettings') settingsOpened += 1;
      return true;
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showGallerySaveResult(
                ScaffoldMessenger.of(context),
                GallerySaveResult.permissionDenied,
              ),
              child: const Text('save'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('save'));
    await tester.pumpAndSettle();
    expect(find.text('需要相册权限'), findsOneWidget);

    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();
    expect(settingsOpened, 1);
  });
}
