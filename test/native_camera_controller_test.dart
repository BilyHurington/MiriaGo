import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/camera_reference/native_camera_controller.dart';
import 'package:miriago/camera_reference/photo_location.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late _FakeNativeViews views;

  setUp(() {
    views = _FakeNativeViews(messenger);
  });

  tearDown(() {
    views.clear();
    messenger.setMockMethodCallHandler(photoLocationChannel, null);
  });

  NativeCameraController createController() {
    return NativeCameraController(
      channelFactory: views.channel,
      requestCameraPermission: () async => true,
    );
  }

  test(
    're-attach survives a disposed old view and re-sends session state',
    () async {
      final controller = createController();
      addTearDown(controller.dispose);
      views.install(1, throwOnDispose: true);
      views.install(2);

      await controller.attach(1);
      await controller.configureCapture(
        captureAspectRatio: 4 / 3,
        cropCaptureToAspectRatio: false,
        preferredInitialZoomRatio: 2,
      );
      await controller.setFlashMode('off');
      expect(controller.ready, isTrue);
      expect(views.calls[1], contains('setFlashMode:off'));

      // Layout switch recreated the platform view: the old channel handler is
      // already gone and dispose throws MissingPluginException.
      await controller.attach(2);

      expect(controller.error, isNull);
      expect(controller.ready, isTrue);
      expect(controller.viewId, 2);
      expect(controller.flashMode, 'off');
      expect(views.calls[2], [
        'initialize',
        'setTargetAspectRatio:1.333',
        'setCropCaptureToAspectRatio:false',
        'setZoomRatio:2.0',
        'setFlashMode:off',
      ]);

      final path = await controller.takePicture();
      expect(path, '/photos/view-2.jpg');
      expect(views.calls[1]!.where((call) => call == 'takePicture'), isEmpty);
    },
  );

  test('re-attach works when the old view has no handler at all', () async {
    final controller = createController();
    addTearDown(controller.dispose);
    views.install(1);
    views.install(2);

    await controller.attach(1);
    await controller.setFlashMode('torch');
    views.remove(1);

    await controller.attach(2);

    expect(controller.ready, isTrue);
    expect(controller.error, isNull);
    expect(views.calls[2], contains('setFlashMode:torch'));
  });

  test('configuration in flight on a replaced view is re-applied', () async {
    final controller = createController();
    addTearDown(controller.dispose);
    final blockRatio = Completer<void>();
    views.install(1);
    views.install(2);

    await controller.attach(1);
    views.blockAspectRatio[1] = blockRatio.future;
    final pending = controller.configureCapture(
      captureAspectRatio: 16 / 9,
      cropCaptureToAspectRatio: true,
      preferredInitialZoomRatio: 1,
    );
    await Future<void>.delayed(Duration.zero);
    expect(controller.configuringCapture, isTrue);

    await controller.attach(2);
    blockRatio.complete();
    await pending;

    expect(controller.configuringCapture, isFalse);
    expect(views.calls[2], contains('setTargetAspectRatio:1.778'));
  });

  test('dispose tolerates a native view that is already gone', () async {
    final controller = createController();
    views.install(1, throwOnDispose: true);
    await controller.attach(1);

    controller.dispose();
    await Future<void>.delayed(Duration.zero);

    // Late native callbacks must not touch the disposed notifier.
    await controller.attach(3);
  });

  test('failed flash change keeps the previous mode', () async {
    final controller = createController();
    addTearDown(controller.dispose);
    views.install(1, failFlash: true);
    await controller.attach(1);

    await controller.setFlashMode('on');

    expect(controller.flashMode, 'auto');
  });

  test('exclusive capture ignores a second tap while busy', () async {
    final controller = createController();
    addTearDown(controller.dispose);
    final release = Completer<void>();
    var runs = 0;

    final first = controller.runExclusiveCapture(() async {
      runs += 1;
      await release.future;
    });
    expect(controller.shutterBusy, isTrue);
    await controller.runExclusiveCapture(() async => runs += 1);
    expect(runs, 1);

    release.complete();
    await first;
    expect(controller.shutterBusy, isFalse);
    await controller.runExclusiveCapture(() async => runs += 1);
    expect(runs, 2);
  });

  test('exclusive capture releases the shutter when capture throws', () async {
    final controller = createController();
    addTearDown(controller.dispose);
    views.install(1, failCapture: true);
    await controller.attach(1);

    Object? error;
    await controller.runExclusiveCapture(() async {
      try {
        await controller.takePicture();
      } catch (caught) {
        error = caught;
      }
    });

    expect(error, isA<PlatformException>());
    expect(controller.shutterBusy, isFalse);
    expect(controller.busy, isFalse);
  });

  test('camera_disposed during capture is an ordinary failure', () async {
    final controller = createController();
    addTearDown(controller.dispose);
    views.install(
      1,
      failCapture: true,
      captureErrorCode: nativeCameraDisposedErrorCode,
    );
    await controller.attach(1);
    expect(controller.ready, isTrue);

    Object? error;
    await controller.runExclusiveCapture(() async {
      try {
        await controller.takePicture();
      } catch (caught) {
        error = caught;
      }
    });

    expect(
      error,
      isA<PlatformException>().having(
        (e) => e.code,
        'code',
        nativeCameraDisposedErrorCode,
      ),
    );
    expect(controller.shutterBusy, isFalse);
    expect(controller.busy, isFalse);
    expect(controller.error, isNull);
    expect(controller.ready, isTrue);
  });

  test(
    'location writer falls back to the app channel without a preview',
    () async {
      final controller = createController();
      addTearDown(controller.dispose);
      final writes = <Object?>[];
      messenger.setMockMethodCallHandler(photoLocationChannel, (call) async {
        writes.add(call.arguments);
        return true;
      });

      final written = await controller.writePhotoLocation(
        '/photos/fallback.jpg',
        PhotoLocationData(
          latitude: 35,
          longitude: 139,
          accuracy: 8,
          timestamp: DateTime(2026, 9, 1),
        ),
      );

      expect(written, isTrue);
      expect(writes.single, containsPair('path', '/photos/fallback.jpg'));
    },
  );

  test('app channel writer reports false when unavailable', () async {
    final written = await writePhotoLocationWithAppChannel(
      '/photos/none.jpg',
      PhotoLocationData(
        latitude: 35,
        longitude: 139,
        accuracy: 8,
        timestamp: DateTime(2026, 9, 1),
      ),
    );

    expect(written, isFalse);
  });
}

class _FakeNativeViews {
  _FakeNativeViews(this.messenger);

  final TestDefaultBinaryMessenger messenger;
  final calls = <int, List<String>>{};
  final blockAspectRatio = <int, Future<void>>{};
  final _channels = <int, MethodChannel>{};

  MethodChannel channel(int viewId) =>
      _channels.putIfAbsent(viewId, () => MethodChannel('test/native_$viewId'));

  void install(
    int viewId, {
    bool throwOnDispose = false,
    bool failFlash = false,
    bool failCapture = false,
    String captureErrorCode = 'capture_failed',
  }) {
    final log = calls.putIfAbsent(viewId, () => []);
    messenger.setMockMethodCallHandler(channel(viewId), (call) async {
      final args = call.arguments as Map<Object?, Object?>?;
      switch (call.method) {
        case 'initialize':
          log.add('initialize');
          return _zoomState(1);
        case 'setTargetAspectRatio':
          await blockAspectRatio[viewId];
          final ratio = args!['targetAspectRatio']! as double;
          log.add('setTargetAspectRatio:${ratio.toStringAsFixed(3)}');
          return null;
        case 'setCropCaptureToAspectRatio':
          log.add('setCropCaptureToAspectRatio:${args!['enabled']}');
          return null;
        case 'setZoomRatio':
          final zoom = args!['zoomRatio']! as double;
          log.add('setZoomRatio:$zoom');
          return _zoomState(zoom);
        case 'setFlashMode':
          if (failFlash) {
            throw PlatformException(code: 'flash_failed');
          }
          log.add('setFlashMode:${args!['flashMode']}');
          return _zoomState(1);
        case 'takePicture':
          log.add('takePicture');
          if (failCapture) {
            throw PlatformException(code: captureErrorCode);
          }
          return '/photos/view-$viewId.jpg';
        case 'dispose':
          log.add('dispose');
          if (throwOnDispose) {
            throw MissingPluginException();
          }
          return null;
      }
      return null;
    });
  }

  void remove(int viewId) {
    messenger.setMockMethodCallHandler(channel(viewId), null);
  }

  void clear() {
    for (final channel in _channels.values) {
      messenger.setMockMethodCallHandler(channel, null);
    }
  }

  static Map<String, Object?> _zoomState(double zoom) => {
    'minZoomRatio': 1.0,
    'maxZoomRatio': 8.0,
    'zoomRatio': zoom,
    'lensFacing': 'back',
    'lensMode': 'backAuto',
    'supportsTelephoto': false,
  };
}
