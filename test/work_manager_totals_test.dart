import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/app_theme.dart';
import 'package:miriago/data/sample_pilgrimage_repository.dart';
import 'package:miriago/plan/pilgrimage_models.dart';
import 'package:miriago/plan/work_manager_screen.dart';

void main() {
  Future<String> badge(
    WidgetTester tester,
    Future<Map<int, int>> Function() load, {
    bool settle = true,
  }) async {
    final repository = SamplePilgrimageRepository();
    final plan = await repository.loadActivePlan();
    final work = plan.works.first;
    await tester.pumpWidget(
      MaterialApp(
        key: UniqueKey(),
        theme: AppTheme.light(),
        home: WorkManagerScreen(
          plan: plan,
          repository: repository,
          settings: const AppSettings(),
          loadAnitabiPointTotals: load,
        ),
      ),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
    final count = plan.points.where((p) => p.work.id == work.id).length;
    final label = tester
        .widget<Text>(
          find.descendant(
            of: find.byKey(ValueKey('work-point-count-${work.id}')),
            matching: find.byType(Text),
          ),
        )
        .data!;
    return label.replaceFirst('$count', 'N');
  }

  testWidgets('shows loading, known, missing and failed totals', (
    tester,
  ) async {
    final pending = Completer<Map<int, int>>();
    expect(
      await badge(tester, () => pending.future, settle: false),
      '已加入 N · Anitabi 共 … 点位',
    );
    pending.complete(const {});

    expect(
      await badge(tester, () async => {115908: 582}),
      '已加入 N · Anitabi 共 582 点位',
    );
    expect(await badge(tester, () async => const {}), '已加入 N 点位');
    expect(
      await badge(tester, () async => throw Exception('offline')),
      '已加入 N 点位',
    );
  });
}
