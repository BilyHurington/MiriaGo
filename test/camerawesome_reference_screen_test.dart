import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/camera_reference/camerawesome_reference_screen.dart';
import 'package:miriago/camera_reference/native_camera_controller.dart';
import 'package:miriago/data/sample_pilgrimage_repository.dart';
import 'package:miriago/plan/pilgrimage_models.dart';
import 'package:miriago/plan/pilgrimage_plan_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late _FakePlatformViews platformViews;
  late _FakeCameraChannels cameras;

  setUp(() {
    platformViews = _FakePlatformViews(messenger)..install();
    cameras = _FakeCameraChannels(messenger);
  });

  tearDown(() {
    platformViews.uninstall();
    cameras.clear();
  });

  Future<NativeCameraController> pumpScreen(
    WidgetTester tester, {
    AppSettings settings = const AppSettings(
      photoLocationStrategy: PhotoLocationStrategy.disabled,
    ),
    PilgrimagePlanController? controller,
    Size size = const Size(400, 800),
    Future<bool> Function()? requestCameraPermission,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final nativeController = NativeCameraController(
      channelFactory: cameras.channel,
      requestCameraPermission: requestCameraPermission ?? () async => true,
    );
    addTearDown(nativeController.dispose);
    final plan = await SamplePilgrimageRepository().loadActivePlan();
    final point = plan.points.first.copyWith(
      referenceImageUrl: '',
      referenceFullImagePath: null,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: CamerawesomeReferenceScreen(
          point: point,
          settings: settings,
          controller: controller,
          nativeCameraController: nativeController,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    return nativeController;
  }

  testWidgets('composition guides toggle independently and survive rotation', (
    tester,
  ) async {
    final repository = SamplePilgrimageRepository(
      settings: const AppSettings(
        photoLocationStrategy: PhotoLocationStrategy.disabled,
        mapThumbnailConcurrentLoads: 4,
      ),
    );
    final planController = PilgrimagePlanController(
      plan: await repository.loadActivePlan(),
      visitRepository: repository,
    );
    addTearDown(planController.dispose);
    await pumpScreen(tester, controller: planController);
    await tester.pumpAndSettle();
    dynamic painter() => tester
        .widget<CustomPaint>(
          find.byKey(const ValueKey('camera-composition-guides')),
        )
        .painter;
    expect(painter().grid, isFalse);
    expect(painter().diagonals, isFalse);
    await tester.tap(find.byTooltip('九宫格'));
    await tester.pumpAndSettle();
    expect(painter().grid, isTrue);
    expect(painter().diagonals, isFalse);
    await tester.tap(find.byTooltip('对角线'));
    await tester.pumpAndSettle();
    expect(painter().grid, isTrue);
    expect(painter().diagonals, isTrue);
    final saved = await repository.loadAppSettings();
    expect(saved.cameraGridEnabled, isTrue);
    expect(saved.cameraDiagonalsEnabled, isTrue);
    expect(saved.mapThumbnailConcurrentLoads, 4);
    tester.view.physicalSize = const Size(800, 400);
    await tester.pumpAndSettle();
    expect(painter().grid, isTrue);
    expect(painter().diagonals, isTrue);
    final overlayRect = tester.getRect(find.byTooltip('叠影'));
    final splitRect = tester.getRect(find.byTooltip('上下'));
    final gridRect = tester.getRect(
      find.byKey(const ValueKey('camera-guide-九宫格')),
    );
    final diagonalRect = tester.getRect(
      find.byKey(const ValueKey('camera-guide-对角线')),
    );
    expect(gridRect.width, overlayRect.width);
    expect(gridRect.height, gridRect.width);
    expect(diagonalRect.width, closeTo(gridRect.width, 0.01));
    expect(diagonalRect.height, closeTo(gridRect.height, 0.01));
    expect(
      diagonalRect.top - gridRect.bottom,
      closeTo(splitRect.top - overlayRect.bottom, 0.01),
    );
    expect(
      gridRect.top - splitRect.bottom,
      closeTo(splitRect.top - overlayRect.bottom, 0.01),
    );
    expect(platformViews.created, hasLength(1));
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('九宫格'));
    await tester.pumpAndSettle();
    expect(painter().grid, isFalse);
    expect(painter().diagonals, isTrue);
  });

  testWidgets('saving one guide keeps the other button visually enabled', (
    tester,
  ) async {
    final repository = _DelayedGuideSettingsRepository();
    final planController = PilgrimagePlanController(
      plan: await repository.loadActivePlan(),
      visitRepository: repository,
    );
    addTearDown(planController.dispose);
    await pumpScreen(tester, controller: planController);
    await tester.pumpAndSettle();
    final diagonalFinder = find.byKey(const ValueKey('camera-guide-对角线'));
    final before = tester.widget<IconButton>(diagonalFinder);
    final beforeColor = before.style!.backgroundColor!.resolve({});
    await tester.tap(find.byTooltip('九宫格'));
    await tester.pump();
    final during = tester.widget<IconButton>(diagonalFinder);
    expect(during.onPressed, isNotNull);
    expect(during.style!.backgroundColor!.resolve({}), beforeColor);
    // A second tap while storage is pending must not change either guide.
    await tester.tap(diagonalFinder);
    await tester.pump();
    final dynamic painter = tester
        .widget<CustomPaint>(
          find.byKey(const ValueKey('camera-composition-guides')),
        )
        .painter;
    expect(painter.grid, isTrue);
    expect(painter.diagonals, isFalse);
    repository.gate.complete();
    await tester.pumpAndSettle();
    expect(tester.widget<IconButton>(diagonalFinder).onPressed, isNotNull);
    expect((await repository.loadAppSettings()).cameraGridEnabled, isTrue);
  });

  testWidgets('failed guide save restores the previous overlay', (
    tester,
  ) async {
    final repository = _FailingGuideSettingsRepository();
    final planController = PilgrimagePlanController(
      plan: await repository.loadActivePlan(),
      visitRepository: repository,
    );
    addTearDown(planController.dispose);
    await pumpScreen(tester, controller: planController);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('九宫格'));
    await tester.pumpAndSettle();
    final dynamic painter = tester
        .widget<CustomPaint>(
          find.byKey(const ValueKey('camera-composition-guides')),
        )
        .painter;
    expect(painter.grid, isFalse);
    expect(find.text('构图辅助设置保存失败，请重试'), findsOneWidget);
  });

  testWidgets('orientation changes keep the same native preview view', (
    tester,
  ) async {
    final controller = await pumpScreen(tester);
    expect(platformViews.created, hasLength(1));
    final viewId = controller.viewId;
    expect(viewId, isNotNull);
    expect(controller.ready, isTrue);

    tester.view.physicalSize = const Size(800, 400);
    await tester.pump();
    await tester.pump();
    expect(find.byTooltip('切换竖屏 UI'), findsOneWidget);

    tester.view.physicalSize = const Size(400, 800);
    await tester.pump();
    await tester.pump();
    expect(find.byTooltip('切换横屏 UI'), findsOneWidget);

    expect(platformViews.created, hasLength(1));
    expect(platformViews.disposed, isEmpty);
    expect(controller.viewId, viewId);
    expect(cameras.calls[viewId]!.where((call) => call == 'initialize'), [
      'initialize',
    ]);
  });

  testWidgets('denied camera access shows the settings panel and retries '
      'after returning from settings', (tester) async {
    var granted = false;
    const permissions = MethodChannel(
      'flutter.baseflow.com/permissions/methods',
    );
    var settingsOpened = 0;
    messenger.setMockMethodCallHandler(permissions, (call) async {
      if (call.method == 'openAppSettings') {
        settingsOpened += 1;
        return true;
      }
      if (call.method == 'checkPermissionStatus') {
        return granted ? 1 : 0;
      }
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(permissions, null));

    final controller = await pumpScreen(
      tester,
      requestCameraPermission: () async => granted,
    );
    await tester.pump();
    expect(controller.permissionDenied, isTrue);
    expect(find.byKey(const ValueKey('camera-permission-denied')), findsOne);
    expect(find.text('需要相机权限'), findsOneWidget);

    expect(
      find.byKey(const ValueKey('camera-permission-gallery')),
      findsOneWidget,
    );

    // Still refused: coming back leaves the panel.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const ValueKey('camera-permission-denied')), findsOne);

    await tester.tap(find.byKey(const ValueKey('camera-permission-settings')));
    await tester.pump();
    expect(settingsOpened, 1);

    granted = true;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(
      find.byKey(const ValueKey('camera-permission-denied')),
      findsNothing,
    );
    expect(controller.ready, isTrue);
    expect(controller.error, isNull);
  });

  testWidgets('重试 tries the camera again', (tester) async {
    var granted = false;
    final controller = await pumpScreen(
      tester,
      requestCameraPermission: () async => granted,
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('camera-permission-denied')), findsOne);

    granted = true;
    await tester.tap(find.byKey(const ValueKey('camera-permission-retry')));
    await tester.pump();
    await tester.pump();
    await tester.pump();
    expect(
      find.byKey(const ValueKey('camera-permission-denied')),
      findsNothing,
    );
    expect(controller.ready, isTrue);
  });

  testWidgets('iOS permission error shows the settings panel', (tester) async {
    cameras.denyCamera = true;
    final controller = await pumpScreen(tester);
    await tester.pump();
    expect(controller.permissionDenied, isTrue);
    expect(find.byKey(const ValueKey('camera-permission-denied')), findsOne);
    expect(find.textContaining('Camera permission'), findsNothing);
  });

  testWidgets('shutter ignores a second tap and surfaces capture errors', (
    tester,
  ) async {
    final capture = Completer<String?>();
    cameras.takePicture = () => capture.future;
    final controller = await pumpScreen(tester);
    final shutter = find.byWidgetPredicate(
      (widget) => widget.runtimeType.toString() == '_NativeCaptureButton',
    );
    expect(shutter, findsOneWidget);

    await tester.tap(shutter);
    await tester.pump();
    expect(controller.shutterBusy, isTrue);
    expect(
      find.descendant(
        of: shutter,
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );

    await tester.tap(shutter, warnIfMissed: false);
    await tester.pump();
    expect(cameras.takePictureCalls, 1);

    capture.completeError(PlatformException(code: 'capture_failed'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('拍摄失败，请重试'), findsOneWidget);
    expect(controller.shutterBusy, isFalse);
    expect(cameras.takePictureCalls, 1);
  });

  testWidgets('a failing settings load still shows the location prompt', (
    tester,
  ) async {
    final repository = _ThrowingSettingsRepository();
    final plan = await repository.loadActivePlan();
    final planController = PilgrimagePlanController(
      plan: plan,
      visitRepository: repository,
    );
    addTearDown(planController.dispose);

    final controller = await pumpScreen(
      tester,
      settings: const AppSettings(
        photoLocationStrategy: PhotoLocationStrategy.askOnFirstCapture,
        mapThumbnailConcurrentLoads: 7,
      ),
      controller: planController,
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final recent = find.byKey(const ValueKey('photo-location-choice-recent'));
    expect(recent, findsOneWidget);
    await tester.tap(recent);
    await tester.pumpAndSettle();

    // Saved on top of the snapshot the camera opened with.
    expect(
      repository.saved?.photoLocationStrategy,
      PhotoLocationStrategy.useRecentLocation,
    );
    expect(repository.saved?.mapThumbnailConcurrentLoads, 7);

    final shutter = find.byWidgetPredicate(
      (widget) => widget.runtimeType.toString() == '_NativeCaptureButton',
    );
    await tester.tap(shutter);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
    expect(find.textContaining('拍摄失败，请重试'), findsNothing);
    expect(
      find.byKey(const ValueKey('photo-location-choice-recent')),
      findsNothing,
    );
    expect(cameras.takePictureCalls, 1);
    expect(controller.shutterBusy, isFalse);
  });

  testWidgets('choosing a location strategy keeps persisted settings', (
    tester,
  ) async {
    final repository = SamplePilgrimageRepository(
      settings: const AppSettings(mapThumbnailConcurrentLoads: 4),
    );
    final plan = await repository.loadActivePlan();
    final planController = PilgrimagePlanController(
      plan: plan,
      visitRepository: repository,
    );
    addTearDown(planController.dispose);

    await pumpScreen(
      tester,
      // Stale snapshot from when the camera opened.
      settings: const AppSettings(mapThumbnailConcurrentLoads: 10),
      controller: planController,
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('photo-location-choice-recent')),
    );
    await tester.pumpAndSettle();

    final saved = await repository.loadAppSettings();
    expect(
      saved.photoLocationStrategy,
      PhotoLocationStrategy.useRecentLocation,
    );
    expect(saved.mapThumbnailConcurrentLoads, 4);
  });
}

class _ThrowingSettingsRepository extends SamplePilgrimageRepository {
  AppSettings? saved;

  @override
  Future<AppSettings> loadAppSettings() =>
      Future<AppSettings>.error(StateError('settings unavailable'));

  @override
  Future<void> saveAppSettings(AppSettings settings) async {
    saved = settings;
  }
}

class _FakePlatformViews {
  _FakePlatformViews(this.messenger);

  final TestDefaultBinaryMessenger messenger;
  final created = <int>[];
  final disposed = <int>[];

  void install() {
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
      call,
    ) async {
      final args = call.arguments;
      switch (call.method) {
        case 'create':
          created.add((args as Map)['id'] as int);
          return created.length;
        case 'resize':
          final map = args as Map;
          return <String, Object?>{
            'width': map['width'],
            'height': map['height'],
          };
        case 'dispose':
          disposed.add(args is Map ? args['id'] as int : args as int);
          return null;
      }
      return null;
    });
  }

  void uninstall() {
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
  }
}

class _FakeCameraChannels {
  _FakeCameraChannels(this.messenger);

  final TestDefaultBinaryMessenger messenger;
  final calls = <int, List<String>>{};
  final _channels = <int, MethodChannel>{};
  Future<String?> Function()? takePicture;
  var takePictureCalls = 0;
  var denyCamera = false;

  MethodChannel channel(int viewId) {
    return _channels.putIfAbsent(viewId, () {
      final channel = MethodChannel('test/screen_native_$viewId');
      final log = calls.putIfAbsent(viewId, () => []);
      messenger.setMockMethodCallHandler(channel, (call) async {
        log.add(call.method);
        switch (call.method) {
          case 'initialize' when denyCamera:
            throw PlatformException(
              code: nativeCameraPermissionDeniedErrorCode,
              message: 'Camera permission is not granted.',
            );
          case 'initialize':
          case 'setZoomRatio':
          case 'setFlashMode':
            return <String, Object?>{
              'minZoomRatio': 1.0,
              'maxZoomRatio': 4.0,
              'zoomRatio': 1.0,
            };
          case 'takePicture':
            takePictureCalls += 1;
            return takePicture?.call();
        }
        return null;
      });
      return channel;
    });
  }

  void clear() {
    for (final channel in _channels.values) {
      messenger.setMockMethodCallHandler(channel, null);
    }
  }
}

class _FailingGuideSettingsRepository extends SamplePilgrimageRepository {
  @override
  Future<void> saveAppSettings(AppSettings settings) async {
    throw StateError('settings write failed');
  }
}

class _DelayedGuideSettingsRepository extends SamplePilgrimageRepository {
  final gate = Completer<void>();

  @override
  Future<void> saveAppSettings(AppSettings settings) async {
    await gate.future;
    await super.saveAppSettings(settings);
  }
}
