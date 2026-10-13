import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/app_theme.dart';
import 'package:miriago/data/sample_pilgrimage_repository.dart';
import 'package:miriago/widgets/route_planner_skill_hint.dart';

void main() {
  testWidgets('skill notice has a compact rectangular target and wraps', (
    tester,
  ) async {
    final repository = SamplePilgrimageRepository();
    Future<void> render(double width, double scale) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: width,
                  child: RoutePlannerSkillLink(
                    repository: repository,
                    lead: '点位很多、懒得逐个整理？ ',
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await render(400, 1);
    final notice = find.byKey(const ValueKey('route-planner-skill-link'));
    expect(tester.widget<InkWell>(notice).borderRadius, BorderRadius.zero);
    expect(tester.getSize(notice).height, inInclusiveRange(40, 44));
    final close = tester.widget<IconButton>(
      find.byKey(const ValueKey('route-planner-skill-link-dismiss')),
    );
    expect(
      (close.style!.shape!.resolve({})! as RoundedRectangleBorder).borderRadius,
      BorderRadius.zero,
    );
    expect(tester.takeException(), isNull);
    await render(230, 2);
    expect(tester.takeException(), isNull);
    expect(tester.getSize(notice).height, greaterThan(40));
  });
}
