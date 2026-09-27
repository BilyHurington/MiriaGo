import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/camera_reference/native_camera_controller.dart';
import 'package:miriago/plan/pilgrimage_models.dart';
import 'package:miriago/ui/components/components.dart';
import 'package:miriago/ui/features/camera/camera_page.dart';

import '../../helpers/pump_app.dart' show TestSizes;
import 'camera_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  group('without a live camera (web)', () {
    for (final (size, scale) in [
      (TestSizes.phone, 1.0),
      (TestSizes.phoneLandscape, 1.0),
      (TestSizes.phoneSmall, 2.0),
      (TestSizes.phoneLandscape, 2.0),
      (TestSizes.desktop, 1.0),
    ]) {
      testWidgets('renders reference and gallery import at $size x$scale', (
        tester,
      ) async {
        setTestWindow(tester, size, textScale: scale);
        final stores = await FeatureTestStores.load();
        final point = stores.session.plan.points.first;
        await tester.pumpWidget(
          featureTestApp(
            stores: stores,
            home: CameraPage(pointId: point.id, capabilities: webCapabilities),
          ),
        );
        await tester.pump();
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(find.text('Web 预览不启动实时相机'), findsOneWidget);
        expect(find.text('从相册导入'), findsOneWidget);
        expect(find.text(point.name), findsOneWidget);
        expect(find.byTooltip('参考图'), findsOneWidget);
        // No shutter without a live camera.
        expect(find.byKey(const ValueKey('camera-shutter')), findsNothing);
      });
    }

    testWidgets('gallery import opens the confirmation without location', (
      tester,
    ) async {
      setTestWindow(tester, TestSizes.phone);
      final stores = await FeatureTestStores.load();
      final point = stores.session.plan.points.first;
      await tester.pumpWidget(
        featureTestApp(
          stores: stores,
          home: CameraPage(
            pointId: point.id,
            capabilities: webCapabilities,
            pickImage: () async => null,
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('从相册导入'));
      await tester.pump();
      // Cancelled picker: stays on the camera.
      expect(find.text('Web 预览不启动实时相机'), findsOneWidget);
    });

    testWidgets('unknown points show a message', (tester) async {
      setTestWindow(tester, TestSizes.phone);
      final stores = await FeatureTestStores.load();
      await tester.pumpWidget(
        featureTestApp(
          stores: stores,
          home: const CameraPage(pointId: 'missing'),
        ),
      );
      await tester.pump();
      expect(find.text('找不到这个点位'), findsOneWidget);
    });
  });

  group('native preview (android)', () {
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

    Future<(NativeCameraController, FeatureTestStores)> pumpCamera(
      WidgetTester tester, {
      Size size = const Size(400, 800),
      double textScale = 1,
      AppSettings settings = const AppSettings(
        photoLocationStrategy: PhotoLocationStrategy.disabled,
      ),
    }) async {
      setTestWindow(tester, size, textScale: textScale);
      final controller = NativeCameraController(
        channelFactory: cameras.channel,
        requestCameraPermission: () async => true,
      );
      addTearDown(controller.dispose);
      final stores = await FeatureTestStores.load(settings: settings);
      final point = stores.session.plan.points.first;
      await tester.pumpWidget(
        featureTestApp(
          stores: stores,
          capabilities: androidCapabilities,
          home: CameraPage(
            pointId: point.id,
            capabilities: androidCapabilities,
            nativeCameraController: controller,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      return (controller, stores);
    }

    testWidgets('orientation changes keep the same native preview view', (
      tester,
    ) async {
      final (controller, _) = await pumpCamera(tester);
      expect(platformViews.created, hasLength(1));
      final viewId = controller.viewId;
      expect(viewId, isNotNull);
      expect(controller.ready, isTrue);
      expect(find.byTooltip('切换横屏 UI'), findsOneWidget);

      tester.view.physicalSize = const Size(800, 400);
      await tester.pump();
      await tester.pump();
      expect(find.byTooltip('切换竖屏 UI'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // 上下 moves the preview into the lower frame (same platform view).
      await tester.tap(find.byKey(const ValueKey('camera-mode-split')));
      await tester.pump();

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

    testWidgets('landscape rails show zoom stops and the opacity slider', (
      tester,
    ) async {
      await pumpCamera(tester, size: TestSizes.phoneLandscape);
      expect(tester.takeException(), isNull);
      // Device 0.6–10 intersected with the default settings range.
      expect(
        find.byKey(const ValueKey('camera-zoom-preset-1×')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('camera-opacity-slider')), findsOne);
      expect(find.text('46%'), findsOneWidget);
      expect(find.byTooltip('闪光灯：自动'), findsOneWidget);
      // No dead 「检查照片」 button.
      expect(find.byTooltip('检查照片'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('camera-mode-split')));
      await tester.pump();
      expect(find.byKey(const ValueKey('camera-opacity-slider')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('camera-zoom-preset-2×')));
      await tester.pump();
      expect(cameras.zoomRequests.last, 2);
    });

    for (final (size, scale) in [
      (TestSizes.phoneLandscape, 2.0),
      (TestSizes.phoneSmall, 2.0),
      (const Size(568, 320), 1.0),
      (TestSizes.tablet, 1.0),
    ]) {
      testWidgets('no overflow at $size x$scale', (tester) async {
        await pumpCamera(tester, size: size, textScale: scale);
        expect(tester.takeException(), isNull);
        expect(find.byKey(const ValueKey('camera-shutter')), findsOneWidget);
      });
    }

    testWidgets('shutter ignores a second tap and surfaces capture errors', (
      tester,
    ) async {
      final capture = Completer<String?>();
      cameras.takePicture = () => capture.future;
      final (controller, stores) = await pumpCamera(tester);
      final shutter = find.byKey(const ValueKey('camera-shutter'));
      expect(shutter, findsOneWidget);

      await tester.tap(shutter);
      await tester.pump();
      expect(controller.shutterBusy, isTrue);
      expect(find.byType(ProgressRing), findsOneWidget);

      await tester.tap(shutter, warnIfMissed: false);
      await tester.pump();
      expect(cameras.takePictureCalls, 1);

      capture.completeError(PlatformException(code: 'capture_failed'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(toastTitles(stores), contains('拍摄失败，请重试。'));
      expect(controller.shutterBusy, isFalse);
      clearToasts(stores);
    });

    testWidgets('the location prompt opens once and saves the choice', (
      tester,
    ) async {
      final (_, stores) = await pumpCamera(
        tester,
        settings: const AppSettings(mapThumbnailConcurrentLoads: 4),
      );
      await tester.pumpAndSettle();
      expect(find.text('是否在巡礼照片中记录定位？'), findsOneWidget);
      expect(find.text('推荐'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('photo-location-choice-recent')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('photo-location-choice-recent')),
        findsNothing,
      );
      final saved = await stores.repository.loadAppSettings();
      expect(
        saved.photoLocationStrategy,
        PhotoLocationStrategy.useRecentLocation,
      );
      expect(saved.mapThumbnailConcurrentLoads, 4);
      expect(
        stores.settings.settings.photoLocationStrategy,
        PhotoLocationStrategy.useRecentLocation,
      );
    });
  });
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
  final zoomRequests = <double>[];
  final _channels = <int, MethodChannel>{};
  Future<String?> Function()? takePicture;
  var takePictureCalls = 0;

  MethodChannel channel(int viewId) {
    return _channels.putIfAbsent(viewId, () {
      final channel = MethodChannel('test/camera_page_native_$viewId');
      final log = calls.putIfAbsent(viewId, () => []);
      messenger.setMockMethodCallHandler(channel, (call) async {
        log.add(call.method);
        switch (call.method) {
          case 'initialize':
          case 'setZoomRatio':
          case 'setFlashMode':
            final requested = (call.arguments is Map)
                ? ((call.arguments as Map)['zoomRatio'] as num?)?.toDouble()
                : null;
            if (call.method == 'setZoomRatio' && requested != null) {
              zoomRequests.add(requested);
            }
            return <String, Object?>{
              'minZoomRatio': 0.6,
              'maxZoomRatio': 10.0,
              'zoomRatio': requested ?? 1.0,
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
