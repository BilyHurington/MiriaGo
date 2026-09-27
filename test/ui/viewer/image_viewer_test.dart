import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/ui/features/settings/settings_page.dart';
import 'package:miriago/ui/features/viewer/image_viewer.dart';
import 'package:miriago/ui/features/viewer/viewer_source.dart';

import '../../helpers/pump_app.dart';

final _png = Uint8List.fromList(const [
  0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0x00, 0x00, 0x00, 0x0d, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1f, 0x15, 0xc4, 0x89, 0x00, 0x00, 0x00,
  0x0a, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9c, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0d, 0x0a, 0x2d, 0xb4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4e, 0x44, 0xae, 0x42, 0x60, 0x82,
]);

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

Future<void> _open(
  WidgetTester tester,
  List<ViewerImage> images, {
  int initialIndex = 0,
}) async {
  final context = tester.element(find.byType(SettingsPage).first);
  unawaited(
    openImageViewer(context, images: images, initialIndex: initialIndex),
  );
  await _settle(tester);
}

void main() {
  tearDown(() => debugViewerRemoteImageResolver = null);

  testWidgets('opens full screen, pages between images and closes', (
    tester,
  ) async {
    final remote = Completer<Uint8List?>();
    debugViewerRemoteImageResolver = (url, source) => remote.future;
    await pumpMiriaApp(tester, location: '/settings');
    await _open(tester, [
      ViewerImage(bytes: _png, label: '参考图'),
      const ViewerImage(
        url: 'https://image.anitabi.cn/points/1/id.jpg',
        label: '巡礼图',
      ),
    ]);
    expect(find.byType(ImageViewerPage), findsOneWidget);
    expect(find.text('参考图 · 1 / 2'), findsOneWidget);
    expect(find.byTooltip('保存或分享原件'), findsOneWidget);

    await tester.tap(find.byTooltip('下一张'));
    await _settle(tester);
    expect(find.text('巡礼图 · 2 / 2'), findsOneWidget);
    expect(find.text('图片加载中'), findsOneWidget);
    expect(find.text('图片暂不可用'), findsNothing);

    remote.complete(null);
    await _settle(tester);
    expect(find.text('图片暂不可用'), findsOneWidget);

    await tester.tap(find.byTooltip('关闭'));
    await _settle(tester);
    expect(find.byType(ImageViewerPage), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('starts at the requested page and Esc closes', (tester) async {
    await pumpMiriaApp(tester, location: '/settings', size: TestSizes.desktop);
    await _open(tester, [
      const ViewerImage(label: '参考图'),
      const ViewerImage(label: '巡礼图'),
    ], initialIndex: 1);
    expect(find.text('巡礼图 · 2 / 2'), findsOneWidget);
    expect(find.text('暂无图片'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await _settle(tester);
    expect(find.text('参考图 · 1 / 2'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await _settle(tester);
    expect(find.byType(ImageViewerPage), findsNothing);
  });

  testWidgets('swipe down dismisses on touch', (tester) async {
    await pumpMiriaApp(tester, location: '/settings');
    await _open(tester, [const ViewerImage(label: '参考图')]);
    await tester.fling(find.byType(PageView), const Offset(0, 400), 1500);
    await _settle(tester);
    expect(find.byType(ImageViewerPage), findsNothing);
  });

  testWidgets('native menu offers share and save to gallery', (tester) async {
    await pumpMiriaApp(tester, location: '/settings');
    await _open(tester, [ViewerImage(bytes: _png, label: '参考图')]);
    await tester.tap(find.byTooltip('保存或分享原件'));
    await _settle(tester);
    expect(find.text('分享'), findsOneWidget);
    expect(find.text('保存到相册'), findsOneWidget);
    expect(find.text('保存图片'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('long press opens the same menu', (tester) async {
    await pumpMiriaApp(tester, location: '/settings');
    await _open(tester, [const ViewerImage(label: '参考图')]);
    await tester.longPress(find.byType(InteractiveViewer));
    await _settle(tester);
    expect(find.text('保存或分享原件'), findsWidgets);
    expect(find.text('分享'), findsOneWidget);
  });

  testWidgets('no overflow on a small phone at text scale 2', (tester) async {
    await pumpMiriaApp(
      tester,
      location: '/settings',
      size: TestSizes.phoneSmall,
      textScale: 2,
    );
    await _open(tester, [
      const ViewerImage(label: '参考图'),
      const ViewerImage(label: '巡礼图'),
    ]);
    expect(find.byType(ImageViewerPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('image type sniffing', () {
    test('extensions come from bytes, then the path', () {
      expect(preferredImageExtension(_png), 'png');
      expect(
        preferredImageExtension(Uint8List.fromList([0xFF, 0xD8, 0xFF, 0x00])),
        'jpg',
      );
      expect(
        preferredImageExtension(Uint8List.fromList('GIF89a'.codeUnits)),
        'gif',
      );
      expect(
        preferredImageExtension(
          Uint8List.fromList([0, 0, 0, 0, ...'ftypheic'.codeUnits]),
        ),
        'heic',
      );
      expect(
        preferredImageExtension(null, fallbackPath: '/a/b/photo.webp'),
        'webp',
      );
      expect(extensionFromUrl('https://x.org/a.jpeg?plan=h160'), 'jpg');
      expect(mimeTypeForImageExtension('png'), 'image/png');
      expect(mimeTypeForImageExtension('jpg'), 'image/jpeg');
    });

    test('data URLs decode only base64 payloads', () {
      expect(bytesFromDataUrl('data:image/png;base64,AAE='), [0, 1]);
      expect(bytesFromDataUrl('data:image/png,abc'), isNull);
      expect(bytesFromDataUrl(null), isNull);
    });
  });
}
