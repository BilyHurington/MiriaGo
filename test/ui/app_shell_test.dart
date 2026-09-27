import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';

void main() {
  testWidgets('compact shell shows a bottom navigation bar', (tester) async {
    await pumpMiriaApp(tester, size: TestSizes.phone);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('巡礼'), findsWidgets);
  });

  testWidgets('medium shell shows a navigation rail', (tester) async {
    await pumpMiriaApp(tester, size: TestSizes.tablet);
    expect(find.byType(NavigationRail), findsOneWidget);
  });

  testWidgets('large shell shows the sidebar', (tester) async {
    await pumpMiriaApp(tester, size: TestSizes.desktop);
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('MiriaGo'), findsOneWidget);
  });

  testWidgets('phone landscape uses the rail', (tester) async {
    await pumpMiriaApp(tester, size: TestSizes.phoneLandscape);
    expect(find.byType(NavigationRail), findsOneWidget);
  });
}
