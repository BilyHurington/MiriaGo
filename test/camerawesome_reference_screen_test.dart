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
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final nativeController = NativeCameraController(
      channelFactory: cameras.channel,
      requestCameraPermission: () async => true,
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

  MethodChannel channel(int viewId) {
    return _channels.putIfAbsent(viewId, () {
      final channel = MethodChannel('test/screen_native_$viewId');
      final log = calls.putIfAbsent(viewId, () => []);
      messenger.setMockMethodCallHandler(channel, (call) async {
        log.add(call.method);
        switch (call.method) {
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
