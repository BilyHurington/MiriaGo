import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/camera_reference/visit_record_confirmation_screen.dart';
import 'package:miriago/camera_reference/photo_location.dart';
import 'package:miriago/data/sample_pilgrimage_repository.dart';
import 'package:miriago/plan/pilgrimage_models.dart';
import 'package:miriago/plan/pilgrimage_plan_controller.dart';

void main() {
  testWidgets('returns null when record confirmation is cancelled', (
    tester,
  ) async {
    final fixture = await _fixture();
    addTearDown(fixture.controller.dispose);
    final route = await _pumpConfirmation(tester, fixture);

    tester
        .widget<TextButton>(
          find.ancestor(
            of: find.text('取消', skipOffstage: false),
            matching: find.byType(TextButton, skipOffstage: false),
          ),
        )
        .onPressed!();
    await tester.pumpAndSettle();

    expect(await route.popped, isNull);
  });

  for (final testCase in [
    ('保存记录', VisitRecordConfirmationResult.saved),
    ('保存并标记完成', VisitRecordConfirmationResult.completed),
  ]) {
    testWidgets('returns ${testCase.$2.name} after ${testCase.$1}', (
      tester,
    ) async {
      final fixture = await _fixture();
      addTearDown(fixture.controller.dispose);
      final route = await _pumpConfirmation(tester, fixture);

      final button = tester.widget<ButtonStyleButton>(
        find.ancestor(
          of: find.text(testCase.$1, skipOffstage: false),
          matching: find.byType(
            testCase.$2 == VisitRecordConfirmationResult.saved
                ? FilledButton
                : OutlinedButton,
            skipOffstage: false,
          ),
        ),
      );
      button.onPressed!();
      await tester.pumpAndSettle();

      expect(await route.popped, testCase.$2);
    });
  }

  testWidgets('waits for location and writes it before enabling save', (
    tester,
  ) async {
    final fixture = await _fixture();
    addTearDown(fixture.controller.dispose);
    final completer = Completer<PhotoLocationData>();
    PhotoLocationData? writtenLocation;
    await _pumpConfirmation(
      tester,
      fixture,
      photoLocationStrategy: PhotoLocationStrategy.waitOnConfirmation,
      resolvePhotoLocation: () => completer.future,
      writePhotoLocation: (path, location) async {
        writtenLocation = location;
        return true;
      },
      settle: false,
    );

    expect(find.text('正在获取拍摄位置...'), findsOneWidget);
    final saveButton = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(saveButton.onPressed, isNull);

    final location = PhotoLocationData(
      latitude: 35,
      longitude: 139,
      accuracy: 5,
      timestamp: DateTime(2026, 8, 13),
    );
    completer.complete(location);
    await tester.pumpAndSettle();

    expect(writtenLocation, same(location));
    expect(find.text('已写入照片定位信息'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
  });

  testWidgets('skip location waits no longer and keeps save enabled', (
    tester,
  ) async {
    final fixture = await _fixture();
    addTearDown(fixture.controller.dispose);
    await _pumpConfirmation(
      tester,
      fixture,
      photoLocationStrategy: PhotoLocationStrategy.waitOnConfirmation,
      resolvePhotoLocation: () => Completer<PhotoLocationData>().future,
      writePhotoLocation: (_, _) async => true,
      settle: false,
    );

    expect(find.text('正在获取拍摄位置...'), findsOneWidget);
    expect(find.text('跳过'), findsOneWidget);
    expect(
      find.ancestor(of: find.text('跳过'), matching: find.byType(OutlinedButton)),
      findsOneWidget,
    );
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );

    await tester.tap(find.text('跳过'));
    await tester.pump();

    expect(find.text('已跳过定位，本次照片不会写入位置。'), findsOneWidget);
    expect(find.text('跳过'), findsNothing);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
  });
}

class _Fixture {
  const _Fixture({required this.controller});

  final PilgrimagePlanController controller;
}

Future<_Fixture> _fixture() async {
  final repository = SamplePilgrimageRepository();
  final plan = await repository.loadActivePlan();
  return _Fixture(
    controller: PilgrimagePlanController(
      plan: plan,
      visitRepository: repository,
    ),
  );
}

Future<Route<dynamic>> _pumpConfirmation(
  WidgetTester tester,
  _Fixture fixture, {
  PhotoLocationStrategy photoLocationStrategy = PhotoLocationStrategy.disabled,
  Future<PhotoLocationData> Function()? resolvePhotoLocation,
  PhotoLocationWriter? writePhotoLocation,
  bool settle = true,
}) async {
  tester.view.physicalSize = const Size(800, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final point = fixture.controller.plan.points.first;
  final observer = _ConfirmationRouteObserver();
  await tester.pumpWidget(
    MaterialApp(
      initialRoute: '/confirm',
      navigatorObservers: [observer],
      routes: {
        '/': (_) => const Scaffold(),
        '/confirm': (_) => VisitRecordConfirmationScreen(
          point: point,
          controller: fixture.controller,
          photoPath: '/tmp/test-visit-photo.jpg',
          referenceMode: '叠影',
          settings: const AppSettings(),
          photoLocationStrategy: photoLocationStrategy,
          resolvePhotoLocation: resolvePhotoLocation,
          writePhotoLocation: writePhotoLocation,
        ),
      },
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump();
  }
  return observer.confirmationRoute;
}

class _ConfirmationRouteObserver extends NavigatorObserver {
  late Route<dynamic> confirmationRoute;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    if (route.settings.name == '/confirm') {
      confirmationRoute = route;
    }
  }
}
