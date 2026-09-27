import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/ui/components/components.dart';
import 'package:miriago/ui/dev/component_gallery.dart';

void main() {
  for (final (size, scale) in const [
    (Size(320, 16000), 2.0),
    (Size(390, 12000), 1.0),
    (Size(1440, 9000), 1.0),
  ]) {
    testWidgets('gallery renders without overflow at $size ×$scale', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildMiriaTheme(MiriaColors.light),
          home: const ComponentGalleryPage(),
        ),
      );
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(tester.takeException(), isNull);
      expect(find.text('组件画廊'), findsOneWidget);

      // Dark theme toggle.
      await tester.tap(find.byTooltip('深色'));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(tester.takeException(), isNull);
    });
  }
}
