import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/widgets/app_motion.dart';
import 'package:miriago/widgets/map_thumbnail_marker.dart';
import 'package:miriago/widgets/reference_thumbnail_io.dart';

Widget host(Widget child) => MaterialApp(
  builder: (context, child) => AppMotionScope(child: child!),
  home: Scaffold(body: Center(child: child)),
);

void main() {
  testWidgets('content changes keep one interactive child and preserve focus', (
    tester,
  ) async {
    final focus = FocusNode();
    final controller = TextEditingController(text: 'memo');
    addTearDown(focus.dispose);
    addTearDown(controller.dispose);
    Widget content(int revision) => host(
      AppContentFade(
        revision: revision,
        child: TextField(focusNode: focus, controller: controller),
      ),
    );
    await tester.pumpWidget(content(0));
    focus.requestFocus();
    await tester.pump();
    final element = tester.element(find.byType(TextField));
    for (var i = 1; i < 5; i++) {
      await tester.pumpWidget(content(i));
      await tester.pump(const Duration(milliseconds: 20));
      expect(find.byType(TextField), findsOneWidget);
      expect(tester.element(find.byType(TextField)), same(element));
      expect(focus.hasFocus, isTrue);
      expect(controller.text, 'memo');
    }
    await tester.pumpAndSettle();
  });

  testWidgets(
    'reveal removes interaction and focus as soon as closing starts',
    (tester) async {
      var taps = 0;
      final focus = FocusNode();
      addTearDown(focus.dispose);
      Widget content(bool visible) => host(
        AppReveal(
          visible: visible,
          child: SizedBox(
            height: 80,
            child: TextButton(
              focusNode: focus,
              onPressed: () => taps++,
              child: const Text('action'),
            ),
          ),
        ),
      );
      await tester.pumpWidget(content(true));
      focus.requestFocus();
      await tester.pump();
      final center = tester.getCenter(find.byType(TextButton));
      await tester.pumpWidget(content(false));
      await tester.pump(const Duration(milliseconds: 20));
      await tester.tapAt(center);
      expect(taps, 0);
      expect(focus.hasFocus, isFalse);
      await tester.pumpWidget(content(true));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(TextButton));
      expect(taps, 1);
      await tester.pumpWidget(content(false));
      await tester.pumpAndSettle();
      expect(find.byType(TextButton), findsNothing);
    },
  );

  testWidgets(
    'reduced motion switches off in-flight motion on both platforms',
    (tester) async {
      final dispatcher = tester.binding.platformDispatcher;
      addTearDown(dispatcher.clearAccessibilityFeaturesTestValue);
      var revision = 0;
      Widget content() =>
          host(AppContentFade(revision: revision, child: const Text('status')));
      for (final features in [
        const FakeAccessibilityFeatures(reduceMotion: true),
        const FakeAccessibilityFeatures(disableAnimations: true),
      ]) {
        dispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures();
        await tester.pumpWidget(content());
        revision++;
        await tester.pumpWidget(content());
        final fade = find.descendant(
          of: find.byType(AppContentFade),
          matching: find.byType(FadeTransition),
        );
        expect(tester.widget<FadeTransition>(fade).opacity.value, lessThan(1));
        dispatcher.accessibilityFeaturesTestValue = features;
        await tester.pump();
        expect(tester.widget<FadeTransition>(fade).opacity.value, 1);
        revision++;
        await tester.pumpWidget(content());
        expect(tester.widget<FadeTransition>(fade).opacity.value, 1);
      }
    },
  );

  testWidgets(
    'selected thumbnail grows upwards with stable anchor and image element',
    (tester) async {
      Widget marker(bool selected) => host(
        MapThumbnailMarker(selected: selected, imported: false, onTap: () {}),
      );
      await tester.pumpWidget(marker(false));
      final image = tester.element(find.byType(ReferenceThumbnail));
      final rect = tester.getRect(find.byType(AnimatedContainer));
      await tester.pumpWidget(marker(true));
      await tester.pump(const Duration(milliseconds: 70));
      final middle = tester.getRect(find.byType(AnimatedContainer));
      expect(middle.bottom, closeTo(rect.bottom, 0.01));
      expect(middle.width, greaterThan(rect.width));
      expect(middle.width, lessThan(76));
      expect(middle.center.dx, closeTo(rect.center.dx, 0.01));
      expect(tester.element(find.byType(ReferenceThumbnail)), same(image));
      await tester.pumpAndSettle();
      final selectedRect = tester.getRect(find.byType(AnimatedContainer));
      expect(selectedRect.size, const Size(76, 56));
      expect(selectedRect.bottom, closeTo(rect.bottom, 0.01));
      await tester.pumpWidget(marker(false));
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byType(AnimatedContainer)), rect);
      expect(tester.element(find.byType(ReferenceThumbnail)), same(image));
    },
  );
}
