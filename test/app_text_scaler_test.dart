import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/app_theme.dart';

void main() {
  test('app preference multiplies the system text size', () {
    const system = TextScaler.linear(1.3);
    expect(appTextScaler(1, base: system).scale(10), closeTo(13, 0.001));
    // 1.2 eases to 1.116.
    expect(appTextScaler(1.2, base: system).scale(10), closeTo(14.508, 0.001));
    expect(appTextScaler(0.8, base: system).scale(10), lessThan(13));
  });

  test('app growth stops at twice the font size but honours the system', () {
    expect(
      appTextScaler(1.4, base: const TextScaler.linear(1.9)).scale(10),
      closeTo(20, 0.001),
    );
    expect(
      appTextScaler(1.4, base: const TextScaler.linear(2.5)).scale(10),
      closeTo(25, 0.001),
    );
  });

  testWidgets('nested scaled subtrees start from the system size', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    late TextScaler outer;
    late TextScaler inner;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            outer = appTextScalerFor(context, 1.2);
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: outer),
              child: Builder(
                builder: (context) {
                  inner = appTextScalerFor(context, 1.2);
                  return const SizedBox();
                },
              ),
            );
          },
        ),
      ),
    );
    expect(outer.scale(10), closeTo(16.74, 0.01));
    expect(inner.scale(10), closeTo(outer.scale(10), 0.0001));
  });
}
