import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:miriago/data/sample_pilgrimage_repository.dart';
import 'package:miriago/main.dart';

Future<void> _openCameraSettings(WidgetTester tester) async {
  await tester.pumpWidget(MiriaGoApp(repository: SamplePilgrimageRepository()));
  await tester.pumpAndSettle();

  await tester.tap(find.text('设置').last);
  await tester.pumpAndSettle();
  await tester.tap(find.text('拍摄设置'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('debug camera settings show photo location strategy dropdown', (
    tester,
  ) async {
    await _openCameraSettings(tester);

    await tester.scrollUntilVisible(
      find.text('照片定位信息'),
      280,
      scrollable: find.byType(Scrollable).last,
    );

    expect(find.text('照片定位信息'), findsOneWidget);
    expect(find.text('首次拍摄时询问'), findsOneWidget);
    expect(find.text('询问'), findsOneWidget);

    await tester.tap(find.text('首次拍摄时询问'));
    await tester.pumpAndSettle();

    expect(find.text('不记录定位'), findsOneWidget);
    expect(find.text('使用最近一次定位'), findsOneWidget);
    expect(find.text('确认记录时获取定位'), findsOneWidget);
    expect(find.text('推荐'), findsOneWidget);
  });
}
