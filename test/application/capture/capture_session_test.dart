import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show Orientation;
import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/application/capture/capture_aspect_ratio.dart';
import 'package:miriago/application/capture/capture_session.dart';
import 'package:miriago/application/capture/visit_record_commit.dart';
import 'package:miriago/application/platform_capabilities.dart';
import 'package:miriago/application/settings_store.dart';
import 'package:miriago/camera_reference/native_camera_controller.dart';
import 'package:miriago/data/sample_pilgrimage_repository.dart';
import 'package:miriago/plan/pilgrimage_models.dart';

const _android = PlatformCapabilities(
  isWeb: false,
  isTauri: false,
  isAndroid: true,
  isIOS: false,
  isDesktopNative: false,
);
const _web = PlatformCapabilities(
  isWeb: true,
  isTauri: false,
  isAndroid: false,
  isIOS: false,
  isDesktopNative: false,
);
const _desktop = PlatformCapabilities(
  isWeb: false,
  isTauri: false,
  isAndroid: false,
  isIOS: false,
  isDesktopNative: true,
);

PilgrimagePoint _point({String? url = ''}) => samplePilgrimagePlan.points.first
    .copyWith(referenceImageUrl: url, referenceFullImagePath: null);

CaptureSession _session({
  AppSettings settings = const AppSettings(
    photoLocationStrategy: PhotoLocationStrategy.disabled,
  ),
  PlatformCapabilities capabilities = _android,
  PilgrimagePoint? point,
  ReferenceAspectRatioResolver? resolve,
  Future<AppSettings> Function()? load,
  Future<void> Function(PhotoLocationStrategy)? save,
  Future<String> Function(String)? copy,
  Future<DateTime?> Function(String)? readTime,
  List<String>? deleted,
}) {
  final session = CaptureSession(
    point: point ?? _point(),
    settings: settings,
    capabilities: capabilities,
    loadPersistedSettings: load,
    savePhotoLocationStrategy: save,
    resolveAspectRatio:
        resolve ??
        ({
          required bytes,
          required localPath,
          required url,
          required imageSource,
        }) async => null,
    referencePathCanDisplay: (_) => false,
    copyPhoto: copy ?? (path) async => '/records/$path',
    readCaptureTime: readTime ?? (_) async => null,
    deletePhoto: (path) => deleted?.add(path),
  );
  addTearDown(session.dispose);
  return session;
}

/// Native camera channels answered in-process (ported from the old screen
/// test).
class _FakeCamera {
  _FakeCamera() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      switch (call.method) {
        case 'initialize':
        case 'setZoomRatio':
          return <String, Object?>{
            'minZoomRatio': 0.6,
            'maxZoomRatio': 10.0,
            'zoomRatio': 1.0,
          };
        case 'takePicture':
          takePictureCalls++;
          return takePicture?.call();
      }
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
  }

  final channel = const MethodChannel('test/capture_session_native');
  final calls = <String>[];
  Future<String?> Function()? takePicture;
  var takePictureCalls = 0;

  Future<NativeCameraController> readyController() async {
    final controller = NativeCameraController(
      channelFactory: (_) => channel,
      requestCameraPermission: () async => true,
    );
    addTearDown(controller.dispose);
    await controller.attach(1);
    return controller;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('aspect ratio', () {
    test('auto capture keeps a landscape reference ratio in portrait UI', () {
      expect(
        resolveCameraCaptureAspectRatio(
          referenceAspectRatio: 16 / 9,
          settings: const AppSettings(),
          orientation: Orientation.portrait,
        ),
        closeTo(16 / 9, 0.001),
      );
    });

    test('fixed landscape ratio stays landscape in portrait UI', () {
      expect(
        resolveCameraCaptureAspectRatio(
          referenceAspectRatio: null,
          settings: const AppSettings(
            cameraCaptureAspectRatio: CameraPhotoAspectRatio.landscape16x9,
          ),
          orientation: Orientation.portrait,
        ),
        closeTo(16 / 9, 0.001),
      );
    });

    test('native fallback follows the UI orientation without a reference', () {
      const settings = AppSettings(
        cameraCaptureAspectRatio: CameraPhotoAspectRatio.auto,
        cameraFallbackAspectRatio: CameraPhotoAspectRatio.native,
      );
      expect(
        resolveCameraCaptureAspectRatio(
          referenceAspectRatio: null,
          settings: settings,
          orientation: Orientation.portrait,
        ),
        closeTo(3 / 4, 0.001),
      );
      expect(
        resolveCameraCaptureAspectRatio(
          referenceAspectRatio: null,
          settings: settings,
          orientation: Orientation.landscape,
        ),
        closeTo(4 / 3, 0.001),
      );
    });

    test('custom ratio uses the configured sides and guards zero', () {
      expect(
        resolveCameraCaptureAspectRatio(
          referenceAspectRatio: 2,
          settings: const AppSettings(
            cameraCaptureAspectRatio: CameraPhotoAspectRatio.custom,
            customCameraAspectRatioWidth: 5,
            customCameraAspectRatioHeight: 4,
          ),
          orientation: Orientation.landscape,
        ),
        closeTo(5 / 4, 0.001),
      );
      expect(
        resolveCameraCaptureAspectRatio(
          referenceAspectRatio: null,
          settings: const AppSettings(
            cameraCaptureAspectRatio: CameraPhotoAspectRatio.custom,
            customCameraAspectRatioWidth: 0,
            customCameraAspectRatioHeight: 4,
          ),
          orientation: Orientation.landscape,
        ),
        1,
      );
    });

    test('native capture is cropped unless auto falls back to native', () {
      expect(
        shouldCropNativeCapture(
          referenceAspectRatio: null,
          settings: const AppSettings(
            cameraFallbackAspectRatio: CameraPhotoAspectRatio.native,
          ),
        ),
        isFalse,
      );
      expect(
        shouldCropNativeCapture(
          referenceAspectRatio: 1.5,
          settings: const AppSettings(
            cameraFallbackAspectRatio: CameraPhotoAspectRatio.native,
          ),
        ),
        isTrue,
      );
      expect(
        shouldCropNativeCapture(
          referenceAspectRatio: null,
          settings: const AppSettings(
            cameraCaptureAspectRatio: CameraPhotoAspectRatio.square1x1,
          ),
        ),
        isTrue,
      );
    });

    test('camera reference display keeps the full resolution Anitabi URL', () {
      expect(
        cameraReferenceFullResolutionDisplayUrl(
          'https://image.anitabi.cn/points/115908/demo.jpg?plan=h160',
        ),
        'https://image.anitabi.cn/points/115908/demo.jpg',
      );
    });

    test('shutter waits while the reference ratio is still loading', () async {
      final ratio = Completer<double?>();
      final session = _session(
        point: _point(url: 'https://image.anitabi.cn/points/1/a.jpg'),
        resolve:
            ({
              required bytes,
              required localPath,
              required url,
              required imageSource,
            }) => ratio.future,
      );
      session.start();
      expect(session.shouldWaitForReferenceAspectRatio, isTrue);
      final camera = _FakeCamera();
      final native = await camera.readyController();
      final messages = <CaptureMessage>[];
      session.onMessage = messages.add;
      await session.captureWithNativeCamera(native);
      expect(messages.single.text, '正在读取参考图比例，请稍后拍摄。');
      expect(camera.takePictureCalls, 0);
      ratio.complete(4 / 3);
      await Future<void>.delayed(Duration.zero);
      expect(session.shouldWaitForReferenceAspectRatio, isFalse);
      expect(
        session.captureAspectRatio(Orientation.portrait),
        closeTo(4 / 3, 1e-9),
      );
    });

    test('a session reference replaces the point reference', () async {
      final bytes = Uint8List.fromList([1, 2, 3]);
      Uint8List? seen;
      final session = _session(
        point: _point(url: 'https://image.anitabi.cn/points/1/a.jpg'),
        resolve:
            ({
              required bytes,
              required localPath,
              required url,
              required imageSource,
            }) async {
              seen = bytes;
              return 1;
            },
      );
      await session.useReferenceBytes(bytes);
      expect(seen, same(bytes));
      expect(session.reference.bytes, same(bytes));
      final request = session.confirmationRequestFor('/p.jpg', writer: null);
      expect(request.referenceBytes, same(bytes));
      expect(request.referenceImageUrl, isNull);
      expect(request.referenceMode, '叠影');
    });
  });

  group('zoom', () {
    test('presets come from the usable range', () {
      expect(cameraZoomPresets(minZoom: 0.6, maxZoom: 10), [0.6, 1, 2, 3, 5]);
      expect(cameraZoomPresets(minZoom: 0.5, maxZoom: 2.5), [0.5, 1, 2]);
      expect(cameraZoomPresets(minZoom: 1, maxZoom: 4), [1, 2, 3]);
      expect(cameraZoomPresets(minZoom: 1, maxZoom: 1.5), isEmpty);
      expect(cameraZoomPresets(minZoom: 2, maxZoom: 2), isEmpty);
      expect(formatZoomPreset(0.6), '0.6×');
      expect(formatZoomPreset(2), '2×');
    });

    test('effective range intersects settings and device', () {
      const settings = AppSettings(cameraMinZoom: 1, cameraMaxZoom: 5);
      expect(
        effectiveCameraZoomRange(
          deviceMinZoom: 0.6,
          deviceMaxZoom: 10,
          settings: settings,
        ),
        (1.0, 5.0),
      );
      // Empty intersection → device range.
      expect(
        effectiveCameraZoomRange(
          deviceMinZoom: 6,
          deviceMaxZoom: 10,
          settings: settings,
        ),
        (6.0, 10.0),
      );
      expect(formatCameraZoom(1), '1.0x');
      expect(formatCameraZoom(12), '12x');
    });

    test('1× sits at the slider midpoint', () {
      expect(
        zoomSliderValue(minZoom: 0.6, maxZoom: 10, realZoom: 1),
        closeTo(0.5, 1e-9),
      );
      expect(
        realZoomForSlider(minZoom: 0.6, maxZoom: 10, sliderValue: 0.5),
        closeTo(1, 1e-9),
      );
    });
  });

  group('location strategy', () {
    test(
      'a failing settings load still prompts and saves the choice',
      () async {
        PhotoLocationStrategy? saved;
        var prompts = 0;
        final session = _session(
          settings: const AppSettings(
            photoLocationStrategy: PhotoLocationStrategy.askOnFirstCapture,
          ),
          load: () => Future<AppSettings>.error(StateError('unavailable')),
          save: (strategy) async => saved = strategy,
        );
        session.promptPhotoLocationStrategy = () async {
          prompts++;
          return PhotoLocationStrategy.useRecentLocation;
        };
        expect(
          await session.ensurePhotoLocationStrategy(),
          PhotoLocationStrategy.useRecentLocation,
        );
        expect(prompts, 1);
        expect(saved, PhotoLocationStrategy.useRecentLocation);
        // Asked once per camera session.
        expect(
          await session.ensurePhotoLocationStrategy(),
          PhotoLocationStrategy.useRecentLocation,
        );
        expect(prompts, 1);
      },
    );

    test(
      'only the strategy is saved; settings changed meanwhile are kept',
      () async {
        final repository = SamplePilgrimageRepository(
          settings: const AppSettings(mapThumbnailConcurrentLoads: 4),
        );
        final store = SettingsStore(repository: repository);
        await store.load();
        final answer = Completer<PhotoLocationStrategy?>();
        final session = _session(
          settings: store.settings,
          load: repository.loadAppSettings,
          save: (strategy) => store.patch(
            (current) => current.copyWith(photoLocationStrategy: strategy),
          ),
        )..promptPhotoLocationStrategy = () => answer.future;
        final request = session.ensurePhotoLocationStrategy();
        await pumpEventQueue();
        // A settings change while the prompt is open (after the persisted
        // settings were read) must not be reverted by the save.
        await store.patch(
          (current) => current.copyWith(mapThumbnailConcurrentLoads: 9),
        );
        answer.complete(PhotoLocationStrategy.waitOnConfirmation);
        await request;
        await pumpEventQueue();
        expect(
          store.settings.photoLocationStrategy,
          PhotoLocationStrategy.waitOnConfirmation,
        );
        expect(store.settings.mapThumbnailConcurrentLoads, 9);
        final saved = await repository.loadAppSettings();
        expect(
          saved.photoLocationStrategy,
          PhotoLocationStrategy.waitOnConfirmation,
        );
        expect(saved.mapThumbnailConcurrentLoads, 9);
      },
    );

    test('a strategy chosen elsewhere is used without asking', () async {
      var prompts = 0;
      final session =
          _session(
              settings: const AppSettings(),
              load: () async => const AppSettings(
                photoLocationStrategy: PhotoLocationStrategy.disabled,
              ),
            )
            ..promptPhotoLocationStrategy = () async {
              prompts++;
              return null;
            };
      expect(
        await session.ensurePhotoLocationStrategy(),
        PhotoLocationStrategy.disabled,
      );
      expect(prompts, 0);
    });

    test(
      'concurrent requests share one prompt; dismissing returns null',
      () async {
        final answer = Completer<PhotoLocationStrategy?>();
        var prompts = 0;
        final session = _session(settings: const AppSettings())
          ..promptPhotoLocationStrategy = () {
            prompts++;
            return answer.future;
          };
        final first = session.ensurePhotoLocationStrategy();
        final second = session.ensurePhotoLocationStrategy();
        answer.complete(null);
        expect(await first, isNull);
        expect(await second, isNull);
        expect(prompts, 1);
      },
    );

    test('location writer depends on the platform', () async {
      final camera = _FakeCamera();
      final ready = await camera.readyController();
      final notReady = NativeCameraController(
        channelFactory: (_) => camera.channel,
      );
      addTearDown(notReady.dispose);
      expect(_session(capabilities: _web).photoLocationWriter(ready), isNull);
      expect(_session().photoLocationWriter(notReady), isNotNull);
      expect(
        _session(capabilities: _desktop).photoLocationWriter(notReady),
        isNull,
      );
      expect(
        _session(capabilities: _desktop).photoLocationWriter(ready),
        isNotNull,
      );
      final request = _session(capabilities: _web).confirmationRequestFor(
        '/p.jpg',
        writer: null,
        photoLocationStrategy: PhotoLocationStrategy.waitOnConfirmation,
      );
      expect(request.photoLocationStrategy, PhotoLocationStrategy.disabled);
      expect(request.saveVisitPhotoToGallery, isFalse);
    });
  });

  group('capture', () {
    test('the shutter is exclusive and failures end in one message', () async {
      final camera = _FakeCamera();
      final capture = Completer<String?>();
      camera.takePicture = () => capture.future;
      final native = await camera.readyController();
      final session = _session();
      final messages = <String>[];
      session.onMessage = (m) => messages.add(m.text);
      final first = session.captureWithNativeCamera(native);
      await Future<void>.delayed(Duration.zero);
      expect(native.shutterBusy, isTrue);
      await session.captureWithNativeCamera(native);
      expect(camera.takePictureCalls, 1);
      capture.completeError(PlatformException(code: 'capture_failed'));
      await first;
      expect(messages, ['拍摄失败，请重试。']);
      expect(native.shutterBusy, isFalse);
    });

    test('a camera that is not ready asks to retry later', () async {
      final camera = _FakeCamera()..takePicture = () async => null;
      final native = await camera.readyController();
      final messages = <String>[];
      final session = _session()..onMessage = (m) => messages.add(m.text);
      await session.captureWithNativeCamera(native);
      expect(messages, ['相机尚未就绪，请稍后再拍。']);
    });

    test(
      'the confirmation keeps the shutter busy and gets the strategy',
      () async {
        final camera = _FakeCamera()..takePicture = () async => '/tmp/shot.jpg';
        final native = await camera.readyController();
        final result = Completer<VisitRecordConfirmationResult?>();
        CaptureConfirmationRequest? opened;
        final session =
            _session(
                settings: const AppSettings(
                  photoLocationStrategy:
                      PhotoLocationStrategy.waitOnConfirmation,
                ),
              )
              ..openConfirmation = (request) {
                opened = request;
                return result.future;
              };
        final capture = session.captureWithNativeCamera(native);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);
        expect(opened?.photoPath, '/tmp/shot.jpg');
        expect(
          opened?.photoLocationStrategy,
          PhotoLocationStrategy.waitOnConfirmation,
        );
        expect(opened?.writePhotoLocation, isNotNull);
        expect(native.shutterBusy, isTrue);
        result.complete(VisitRecordConfirmationResult.saved);
        await capture;
        expect(native.shutterBusy, isFalse);
      },
    );

    test('a dismissed prompt skips the shutter', () async {
      final camera = _FakeCamera()..takePicture = () async => '/tmp/shot.jpg';
      final native = await camera.readyController();
      final session = _session(settings: const AppSettings())
        ..promptPhotoLocationStrategy = () async => null;
      await session.captureWithNativeCamera(native);
      expect(camera.takePictureCalls, 0);
    });

    test(
      'fallback captures without a strategy save without location',
      () async {
        CaptureConfirmationRequest? opened;
        final session = _session(settings: const AppSettings());
        session.promptPhotoLocationStrategy = () async => null;
        session.openConfirmation = (request) async {
          opened = request;
          return null;
        };
        await session.handleFallbackCapture('/tmp/awesome.jpg');
        expect(opened?.photoPath, '/tmp/awesome.jpg');
        expect(opened?.photoLocationStrategy, PhotoLocationStrategy.disabled);
      },
    );

    test('fallback strategy failure deletes the photo', () async {
      final deleted = <String>[];
      final messages = <String>[];
      final session = _session(settings: const AppSettings(), deleted: deleted);
      session.promptPhotoLocationStrategy = () async => throw StateError('x');
      session.onMessage = (m) => messages.add(m.text);
      await session.handleFallbackCapture('/tmp/awesome.jpg');
      expect(deleted, ['/tmp/awesome.jpg']);
      expect(messages, ['拍摄失败，请重试。']);
    });

    test('a disposed session deletes late captures', () async {
      final deleted = <String>[];
      final session = CaptureSession(
        point: _point(),
        settings: const AppSettings(),
        capabilities: _android,
        resolveAspectRatio:
            ({
              required bytes,
              required localPath,
              required url,
              required imageSource,
            }) async => null,
        deletePhoto: deleted.add,
      )..dispose();
      await session.handleFallbackCapture('/tmp/late.jpg');
      expect(deleted, ['/tmp/late.jpg']);
    });
  });

  group('gallery import', () {
    test(
      'copies the photo, keeps the EXIF time and writes no location',
      () async {
        final time = DateTime(2026, 8, 13, 9, 30);
        CaptureConfirmationRequest? opened;
        final session =
            _session(
                settings: const AppSettings(
                  photoLocationStrategy:
                      PhotoLocationStrategy.waitOnConfirmation,
                ),
                readTime: (_) async => time,
                copy: (path) async => '/records/copy.jpg',
              )
              ..openConfirmation = (request) async {
                opened = request;
                return null;
              };
        expect(
          await session.importGalleryPhoto(
            '/picked.jpg',
            restoreLandscape: true,
          ),
          isTrue,
        );
        expect(opened?.photoPath, '/records/copy.jpg');
        expect(opened?.capturedAtOverride, time);
        expect(opened?.photoLocationStrategy, PhotoLocationStrategy.disabled);
        expect(opened?.restoreLandscape, isTrue);
      },
    );

    test('a failed copy reports the old error', () async {
      final messages = <CaptureMessage>[];
      final session = _session(copy: (_) async => throw StateError('io'))
        ..onMessage = messages.add;
      expect(await session.importGalleryPhoto('/picked.jpg'), isFalse);
      expect(messages.single.text, '照片导入失败，请重新选择。');
      expect(messages.single.kind, CaptureMessageKind.error);
    });
  });
}
