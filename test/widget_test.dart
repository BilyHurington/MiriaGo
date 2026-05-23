import 'package:flutter_test/flutter_test.dart';

import 'package:seichi_junrei_helper/main.dart';

void main() {
  testWidgets('shows the pilgrimage plan workflow shell', (tester) async {
    await tester.pumpWidget(const SeichiJunreiHelperApp());
    await tester.pump();

    expect(find.text('计划'), findsWidgets);
    expect(find.text('地图'), findsWidgets);
    expect(find.text('记录'), findsWidgets);
    expect(find.text('吹响吧！上低音号'), findsOneWidget);
    expect(find.text('当前目标 0/3'), findsOneWidget);
    expect(find.text('宇治桥'), findsWidgets);
  });

  testWidgets('opens camera reference from current target', (tester) async {
    await tester.pumpWidget(const SeichiJunreiHelperApp());
    await tester.pump();

    await tester.tap(find.text('拍摄参考'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('宇治桥'), findsWidgets);
    expect(find.text('参考图待接入'), findsOneWidget);
    expect(find.text('Split'), findsOneWidget);
    expect(find.text('Overlay'), findsOneWidget);
  });
}
