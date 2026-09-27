import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/ui/components/components.dart';

import '../../helpers/pump_app.dart';

void main() {
  testWidgets('works list shows badges and the import shortcut', (
    tester,
  ) async {
    await pumpMiriaApp(tester, location: '/plan/works', size: TestSizes.phone);
    expect(find.text('共 1 部作品，27 个点位'), findsOneWidget);
    expect(find.text('吹响吧！上低音号'), findsOneWidget);
    expect(find.text('響け！ユーフォニアム'), findsOneWidget);
    expect(find.text('Bangumi'), findsOneWidget);
    expect(find.text('27 个点位'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('work-import-hibike-euphonium')),
      findsOneWidget,
    );
  });

  testWidgets('deleting a work confirms and removes its points', (
    tester,
  ) async {
    final repository = await pumpMiriaApp(
      tester,
      location: '/plan/works',
      size: TestSizes.phone,
    );
    await tester.tap(find.byKey(const ValueKey('work-more-hibike-euphonium')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除作品'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining(
        '将删除「吹响吧！上低音号」，并同时移除 27 个相关点位和对应记录。',
        findRichText: true,
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect((await repository.loadActivePlan()).works, hasLength(1));

    await tester.tap(find.byKey(const ValueKey('work-more-hibike-euphonium')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除作品'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    final plan = await repository.loadActivePlan();
    expect(plan.works, isEmpty);
    expect(plan.points, isEmpty);
    expect(find.byKey(const ValueKey('works-empty')), findsOneWidget);
    expect(find.text('还没有作品'), findsOneWidget);
  });

  testWidgets('works render as a grid on desktop', (tester) async {
    await pumpMiriaApp(
      tester,
      location: '/plan/works',
      size: TestSizes.desktop,
    );
    expect(find.byType(AdaptiveGrid), findsOneWidget);
    expect(find.text('吹响吧！上低音号'), findsOneWidget);
    // No back button beside the secondary navigation.
    expect(find.byType(BackButton), findsNothing);
  });
}
