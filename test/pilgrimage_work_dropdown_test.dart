import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/plan/pilgrimage_models.dart';
import 'package:miriago/plan/pilgrimage_work_dropdown.dart';

void main() {
  const works = [
    PilgrimageWork(
      id: 'work-1',
      title: 'Sound! Euphonium',
      subtitle: '',
      city: '',
      source: WorkSource.bangumi,
      bangumiSubjectType: BangumiSubjectType.anime,
    ),
    PilgrimageWork(
      id: 'work-2',
      title: 'BanG Dream!',
      subtitle: '',
      city: '',
      source: WorkSource.bangumi,
      bangumiSubjectType: BangumiSubjectType.anime,
    ),
  ];

  Future<void> pumpDropdown(
    WidgetTester tester, {
    List<PilgrimageWork> options = works,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              child: PilgrimageWorkDropdown(
                works: options,
                value: options.first,
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(DropdownButtonFormField<PilgrimageWork>));
    await tester.pumpAndSettle();
  }

  Future<TestGesture> hoverTitle(WidgetTester tester, Finder title) async {
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(title));
    await tester.pump();
    return mouse;
  }

  testWidgets('unselected menu item content slides right while hovered', (
    tester,
  ) async {
    await pumpDropdown(tester);

    final title = find.text('BanG Dream!');
    final startX = tester.getTopLeft(title).dx;
    final mouse = await hoverTitle(tester, title);

    await tester.pump(const Duration(milliseconds: 80));
    final middleX = tester.getTopLeft(title).dx;
    expect(middleX, greaterThan(startX));
    expect(middleX, lessThan(startX + 12));

    await tester.pumpAndSettle();
    expect(tester.getTopLeft(title).dx, closeTo(startX + 12, 0.01));

    await mouse.moveTo(Offset.zero);
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(title).dx, closeTo(startX, 0.01));
  });

  testWidgets('selected menu item stays still while hovered', (tester) async {
    await pumpDropdown(tester);

    final title = find.text('Sound! Euphonium').last;
    final startX = tester.getTopLeft(title).dx;
    final mouse = await hoverTitle(tester, title);

    await tester.pumpAndSettle();
    expect(tester.getTopLeft(title).dx, closeTo(startX, 0.01));

    await mouse.moveTo(Offset.zero);
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(title).dx, closeTo(startX, 0.01));
  });

  testWidgets('long menu keeps selected content clear of the scrollbar', (
    tester,
  ) async {
    final manyWorks = List.generate(
      12,
      (index) => PilgrimageWork(
        id: 'work-$index',
        title: 'Work $index',
        subtitle: '',
        city: '',
        source: WorkSource.bangumi,
        bangumiSubjectType: BangumiSubjectType.anime,
      ),
    );

    await pumpDropdown(tester, options: manyWorks);

    expect(find.byType(Scrollbar), findsOneWidget);
    final scrollbarRect = tester.getRect(find.byType(Scrollbar));
    final selectedIconRect = tester.getRect(find.byIcon(Icons.check_circle));
    expect(selectedIconRect.right, lessThanOrEqualTo(scrollbarRect.right - 10));

    final backgrounds = find.byType(AnimatedContainer);
    expect(backgrounds, findsWidgets);
    for (final element in backgrounds.evaluate()) {
      final backgroundRect = tester.getRect(
        find.byElementPredicate((candidate) => identical(candidate, element)),
      );
      expect(backgroundRect.right, lessThanOrEqualTo(scrollbarRect.right - 6));
    }
  });
}
