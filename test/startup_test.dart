import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/data/sample_pilgrimage_repository.dart';
import 'package:miriago/main.dart';

void main() {
  testWidgets('shows a recoverable error when repository startup fails', (
    tester,
  ) async {
    var attempts = 0;
    await tester.pumpWidget(
      MiriaGoBootstrap(
        repositoryLoader: () async {
          attempts += 1;
          if (attempts == 1) {
            throw StateError('database unavailable');
          }
          return SamplePilgrimageRepository();
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('MiriaGo 启动失败'), findsOneWidget);
    expect(find.textContaining('用户数据没有被删除'), findsOneWidget);

    final retry = tester.widget<FilledButton>(
      find.byKey(const ValueKey('desktop-startup-retry')),
    );
    retry.onPressed!();
    await tester.pumpAndSettle();

    expect(attempts, 2);
    expect(find.text('MiriaGo 启动失败'), findsNothing);
    expect(find.byType(MiriaGoApp), findsOneWidget);
  });
}
