import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/widgets/input_dialog.dart';
import 'package:miriago/widgets/keyboard_dismiss_on_tap.dart';

void main() {
  testWidgets('switches directly between input fields', (tester) async {
    final firstFocus = FocusNode();
    final secondFocus = FocusNode();
    addTearDown(firstFocus.dispose);
    addTearDown(secondFocus.dispose);

    await tester.pumpWidget(
      _testApp(
        Column(
          children: [
            TextField(
              key: const ValueKey('first-field'),
              focusNode: firstFocus,
              onTapOutside: dismissKeyboardOnTapOutside,
            ),
            TextField(
              key: const ValueKey('second-field'),
              focusNode: secondFocus,
              onTapOutside: dismissKeyboardOnTapOutside,
            ),
          ],
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('first-field')));
    await tester.pump();
    expect(firstFocus.hasFocus, isTrue);

    await tester.tap(find.byKey(const ValueKey('second-field')));
    await tester.pump();
    expect(firstFocus.hasFocus, isFalse);
    expect(secondFocus.hasFocus, isTrue);
  });

  testWidgets('keeps controls interactive while dismissing outside focus', (
    tester,
  ) async {
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);
    var buttonTaps = 0;
    var customControlTaps = 0;

    await tester.pumpWidget(
      _testApp(
        Column(
          children: [
            TextField(
              key: const ValueKey('focus-field'),
              focusNode: focusNode,
              onTapOutside: dismissKeyboardOnTapOutside,
            ),
            FilledButton(
              key: const ValueKey('action-button'),
              onPressed: () => buttonTaps += 1,
              child: const Text('操作'),
            ),
            Material(
              child: InkWell(
                key: const ValueKey('custom-control'),
                onTap: () => customControlTaps += 1,
                child: const SizedBox(width: 100, height: 44),
              ),
            ),
            const Expanded(
              child: ColoredBox(
                key: ValueKey('blank-area'),
                color: Colors.transparent,
              ),
            ),
          ],
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('focus-field')));
    await tester.pump();
    expect(focusNode.hasFocus, isTrue);

    await tester.tap(find.byKey(const ValueKey('action-button')));
    await tester.pump();
    expect(buttonTaps, 1);
    expect(focusNode.hasFocus, isFalse);

    await tester.tap(find.byKey(const ValueKey('focus-field')));
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('custom-control')));
    await tester.pump();
    expect(customControlTaps, 1);
    expect(focusNode.hasFocus, isFalse);

    await tester.tap(find.byKey(const ValueKey('focus-field')));
    await tester.pump();

    await tester.tapAt(
      tester.getCenter(find.byKey(const ValueKey('blank-area'))),
    );
    await tester.pump();
    expect(focusNode.hasFocus, isFalse);
  });

  testWidgets('outside drag still scrolls after dismissing input', (
    tester,
  ) async {
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      _testApp(
        ListView(
          key: const ValueKey('scroll-view'),
          children: [
            TextField(
              key: const ValueKey('scroll-field'),
              focusNode: focusNode,
              onTapOutside: dismissKeyboardOnTapOutside,
            ),
            const SizedBox(height: 1200),
          ],
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('scroll-field')));
    await tester.pump();
    await tester.drag(
      find.byKey(const ValueKey('scroll-view')),
      const Offset(0, -240),
    );
    await tester.pumpAndSettle();

    expect(focusNode.hasFocus, isFalse);
    expect(
      tester.state<ScrollableState>(find.byType(Scrollable)).position.pixels,
      greaterThan(0),
    );
  });

  testWidgets('dismisses input focus inside a dialog', (tester) async {
    final fieldFocus = FocusNode();
    addTearDown(fieldFocus.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (context) => AppInputDialog(
                  title: '输入信息',
                  content: TextField(
                    key: const ValueKey('dialog-field'),
                    focusNode: fieldFocus,
                    onTapOutside: dismissKeyboardOnTapOutside,
                  ),
                  confirmLabel: '确认',
                  onConfirm: () {},
                ),
              ),
              child: const Text('打开'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('dialog-field')));
    await tester.pump();
    expect(fieldFocus.hasFocus, isTrue);

    await tester.tap(find.text('输入信息'));
    await tester.pump();
    expect(fieldFocus.hasFocus, isFalse);
  });
}

Widget _testApp(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}
