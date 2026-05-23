import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:seichi_junrei_helper/camera_reference/camera_reference_screen.dart';

void main() {
  testWidgets('shows the camera reference tool shell', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: CameraReferenceScreen()));

    expect(find.text('Reference Camera'), findsOneWidget);
    expect(find.text('Reference'), findsOneWidget);
    expect(find.text('Split'), findsOneWidget);
    expect(find.text('Overlay'), findsOneWidget);
  });
}
