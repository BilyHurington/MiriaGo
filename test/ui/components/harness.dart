import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/ui/components/components.dart';

/// Pumps [child] inside a themed app at [size] with [textScale].
Future<void> pumpComponent(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(390, 844),
  double textScale = 1,
  bool dark = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildMiriaTheme(dark ? MiriaColors.dark : MiriaColors.light),
      home: Scaffold(body: child),
    ),
  );
  await tester.pump();
}
