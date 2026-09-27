import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

Future<void> _load(WidgetTester tester) async {
  // Photo bytes come from the asset bundle and are decoded by the engine;
  // let that real I/O finish between frames.
  for (var round = 0; round < 2; round++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }
}

void main() {
  for (final size in [TestSizes.phone, TestSizes.desktop]) {
    testWidgets('grading page renders at $size', (tester) async {
      await pumpMiriaApp(
        tester,
        location: '/records/sample-record-agata-02/grading',
        size: size,
      );
      await _load(tester);
      expect(find.text('自动调色'), findsWidgets);
      expect(find.byTooltip('重置'), findsOneWidget);
      expect(find.byKey(const ValueKey('grading-controls')), findsOneWidget);
      expect(find.text('匹配模式'), findsOneWidget);
      expect(find.text('自然'), findsOneWidget);
      expect(find.text('标准'), findsOneWidget);
      expect(find.text('强匹配'), findsOneWidget);
      // Saved parameters of the sample record are restored.
      expect(find.text('已恢复上次调色参数'), findsOneWidget);
      expect(find.text('按住显示原图'), findsOneWidget);
      expect(find.text('原图'), findsNothing);
      expect(find.text('调色后'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('parameter sheet lists the 17 parameters', (tester) async {
    await pumpMiriaApp(
      tester,
      location: '/records/sample-record-agata-02/grading',
      size: TestSizes.desktop,
    );
    await _load(tester);
    await tester.ensureVisible(
      find.byKey(const ValueKey('grading-parameters')),
    );
    await tester.tap(find.byKey(const ValueKey('grading-parameters')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('亮度'), findsOneWidget);
    expect(find.text('范围 -0.25 ~ 0.25'), findsOneWidget);
    await tester.ensureVisible(find.text('蓝高光曲线'));
    expect(find.text('蓝高光曲线'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reset asks for confirmation', (tester) async {
    await pumpMiriaApp(
      tester,
      location: '/records/sample-record-agata-02/grading',
    );
    await _load(tester);
    await tester.tap(find.byTooltip('重置'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('重置调色'), findsOneWidget);
    expect(find.text('将清除当前调色，恢复为原图。'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  });

  testWidgets('grading has no overflow on a small phone at 2.0 text', (
    tester,
  ) async {
    await pumpMiriaApp(
      tester,
      location: '/records/sample-record-agata-02/grading',
      size: TestSizes.phoneSmall,
      textScale: 2.0,
    );
    await _load(tester);
    expect(tester.takeException(), isNull);
  });
}
