import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/plan/pilgrimage_models.dart';
import 'package:miriago/widgets/image_viewer_screen.dart';

void main() {
  testWidgets('remote preview keeps loading placeholder until bytes resolve', (
    tester,
  ) async {
    final completer = Completer<Uint8List?>();

    await tester.pumpWidget(
      MaterialApp(
        home: ImageViewerScreen(
          imageUrl: 'https://image.anitabi.cn/points/1/id.jpg',
          remoteImageResolver: (url, imageSource) => completer.future,
        ),
      ),
    );

    expect(find.text('图片加载中'), findsOneWidget);
    expect(find.text('图片暂不可用'), findsNothing);

    completer.complete(Uint8List.fromList(_transparentPngBytes));
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsOneWidget);
    expect(find.text('图片加载中'), findsNothing);
    expect(find.text('图片暂不可用'), findsNothing);
  });

  testWidgets('remote preview shows unavailable only after resolver fails', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ImageViewerScreen(
          imageUrl: 'https://image.anitabi.cn/points/1/id.jpg',
          imageSource: AnitabiImageSource.auto,
          remoteImageResolver: (url, imageSource) async => null,
        ),
      ),
    );

    expect(find.text('图片加载中'), findsOneWidget);
    expect(find.text('图片暂不可用'), findsNothing);

    await tester.pumpAndSettle();

    expect(find.text('图片加载中'), findsNothing);
    expect(find.text('图片暂不可用'), findsOneWidget);
  });
}

const _transparentPngBytes = <int>[
  0x89,
  0x50,
  0x4e,
  0x47,
  0x0d,
  0x0a,
  0x1a,
  0x0a,
  0x00,
  0x00,
  0x00,
  0x0d,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1f,
  0x15,
  0xc4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0a,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9c,
  0x63,
  0x00,
  0x01,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0x0d,
  0x0a,
  0x2d,
  0xb4,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4e,
  0x44,
  0xae,
  0x42,
  0x60,
  0x82,
];
