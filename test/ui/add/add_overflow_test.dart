import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/ui/app/router.dart';
import 'package:miriago/ui/app/shell.dart';
import 'package:miriago/ui/features/add/add_menu.dart';

import 'add_test_helpers.dart';

Future<void> scrollThrough(WidgetTester tester) async {
  final scrollables = find.byType(Scrollable);
  if (scrollables.evaluate().isEmpty) return;
  for (var i = 0; i < 6; i++) {
    await tester.drag(scrollables.first, const Offset(0, -400));
    await settle(tester, frames: 4);
  }
}

void main() {
  final sizes = {
    'phoneSmall@2.0': (TestSizes.phoneSmall, 2.0),
    'phoneLandscape@1.0': (TestSizes.phoneLandscape, 1.0),
    'tablet@1.0': (TestSizes.tablet, 1.0),
    'desktop@1.0': (TestSizes.desktop, 1.0),
  };
  final pages = {
    'bangumi search': Routes.bangumiSearch,
    'manual work': Routes.manualWork,
    'link import': Routes.linkImport,
    'new point': Routes.newPoint,
    'anitabi import': Routes.anitabiImport,
  };

  for (final size in sizes.entries) {
    for (final page in pages.entries) {
      testWidgets('${page.key} has no overflow at ${size.key}', (tester) async {
        await pumpAddApp(
          tester,
          location: page.value,
          size: size.value.$1,
          textScale: size.value.$2,
          bangumi: FakeBangumiClient(results: [bangumiResult]),
        );
        expect(tester.takeException(), isNull);
        if (page.value == Routes.bangumiSearch) {
          await tester.enterText(find.byType(EditableText).first, '轻音');
          await tester.testTextInput.receiveAction(TextInputAction.search);
          await settle(tester);
          expect(tester.takeException(), isNull);
        }
        if (page.value != Routes.anitabiImport) await scrollThrough(tester);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('add menu has no overflow at ${size.key}', (tester) async {
      await pumpAddApp(
        tester,
        location: '/plan',
        size: size.value.$1,
        textScale: size.value.$2,
      );
      final context = tester.element(find.byType(AppShell));
      // ignore: unawaited_futures
      showAddMenu(context);
      await settle(tester);
      expect(find.text('搜索 Bangumi'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('point card and organize dialog fit at phoneSmall@2.0', (
    tester,
  ) async {
    await pumpAddApp(
      tester,
      location: Routes.anitabiImport,
      size: TestSizes.phoneSmall,
      textScale: 2,
    );
    expect(find.byKey(const ValueKey('anitabi-point-card-a1')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('anitabi-import-all')));
    await settle(tester);
    await tester.tap(find.text('添加全部'));
    await settle(tester, frames: 20);
    expect(find.text('整理刚导入的点位'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
