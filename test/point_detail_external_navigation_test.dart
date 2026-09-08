import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/app_theme.dart';
import 'package:miriago/data/sample_pilgrimage_repository.dart';
import 'package:miriago/map/map_navigation_launcher.dart';
import 'package:miriago/plan/pilgrimage_models.dart';
import 'package:miriago/point_detail/point_detail_sheet.dart';

void main() {
  Future<void> openDetail(
    WidgetTester tester, {
    required ExternalNavigationLauncher launch,
    NavigationApp app = NavigationApp.googleMaps,
    bool hasCoordinate = true,
  }) async {
    final plan = await SamplePilgrimageRepository().loadActivePlan();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: PointDetailSheet(
            point: plan.points.first.copyWith(
              position: hasCoordinate ? null : PilgrimagePoint.pendingPosition,
            ),
            status: VisitStatus.pending,
            onReplaceReference: (_, _) async {},
            navigationApp: app,
            navigationLauncher: MapNavigationLauncher(
              useAndroidGoogleMapsIntent: false,
              externalNavigationLauncher: launch,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  InkWell button(WidgetTester tester) => tester.widget<InkWell>(
    find.byKey(const ValueKey('point-detail-external-navigation-button')),
  );

  for (final app in NavigationApp.values) {
    testWidgets('detail launches selected external map ${app.name}', (
      tester,
    ) async {
      Uri? launched;
      await openDetail(
        tester,
        app: app,
        launch: (uri) async {
          launched = uri;
          return true;
        },
      );
      button(tester).onTap!();
      await tester.pumpAndSettle();
      final plan = await SamplePilgrimageRepository().loadActivePlan();
      expect(launched, walkingNavigationUri(plan.points.first, app));
      expect(find.byType(PointDetailSheet), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final throws in [false, true]) {
    testWidgets(
      'detail reports external launch ${throws ? 'exception' : 'failure'}',
      (tester) async {
        await openDetail(
          tester,
          launch: (_) async {
            if (throws) throw PlatformException(code: 'launch_failed');
            return false;
          },
        );
        button(tester).onTap!();
        await tester.pumpAndSettle();
        expect(
          find.text('无法打开${NavigationApp.googleMaps.label}'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('coordinate-less detail disables both navigation actions', (
    tester,
  ) async {
    await openDetail(
      tester,
      hasCoordinate: false,
      launch: (_) async {
        fail('Coordinate-less point must not launch navigation');
      },
    );
    expect(button(tester).onTap, isNull);
    expect(
      tester
          .widget<InkWell>(
            find.byKey(const ValueKey('point-detail-in-app-navigation-button')),
          )
          .onTap,
      isNull,
    );
  });
}
