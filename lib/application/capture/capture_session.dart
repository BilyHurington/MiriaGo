import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show Orientation;
import 'package:image_picker/image_picker.dart' show XFile;

import '../../camera_reference/auto_comparison_gallery_backup.dart';
import '../../camera_reference/camera_storage_stub.dart'
    if (dart.library.io) '../../camera_reference/camera_storage_io.dart'
    as camera_storage;
import '../../camera_reference/gallery_capture_time_stub.dart'
    if (dart.library.io) '../../camera_reference/gallery_capture_time_io.dart'
    as gallery_capture_time;
import '../../camera_reference/native_camera_controller.dart';
import '../../camera_reference/photo_location.dart';
import '../../data/anitabi_image_url.dart';
import '../../data/bounded_image_decoder.dart';
import '../../plan/pilgrimage_models.dart';
import '../../plan/reference_image_status.dart';
import '../../records/visit_record_file_ops_stub.dart'
    if (dart.library.io) '../../records/visit_record_file_ops_io.dart'
    as file_ops;
import '../../widgets/reference_image_source_stub.dart'
    if (dart.library.io) '../../widgets/reference_image_source_io.dart';
import '../platform_capabilities.dart';
import 'capture_aspect_ratio.dart';
import 'visit_record_commit.dart';

/// Reference presentation in the camera (the record stores the label).
/// The old 小窗 mode is not offered (DESIGN §8.5).
enum CaptureReferenceMode {
  overlay('叠影'),
  split('上下');

  const CaptureReferenceMode(this.label);
  final String label;
}

/// Where the reference image comes from, in priority order: the image
/// picked for this session → the cached full image → the remote URL.
@immutable
class CaptureReferenceSource {
  const CaptureReferenceSource({
    required this.bytes,
    required this.localPath,
    required this.url,
    required this.imageSource,
  });

  final Uint8List? bytes;
  final String? localPath;
  final String? url;
  final AnitabiImageSource imageSource;

  bool get hasImage => bytes != null || localPath != null || url != null;

  /// URL to draw (always full resolution in the camera).
  String? get displayUrl =>
      url == null ? null : cameraReferenceFullResolutionDisplayUrl(url!);
}

enum CaptureMessageKind { running, warning, error }

/// A toast the camera page should show.
@immutable
class CaptureMessage {
  const CaptureMessage(this.text, this.kind);
  final String text;
  final CaptureMessageKind kind;
}

/// Everything the confirmation page needs for one photo.
@immutable
class CaptureConfirmationRequest {
  const CaptureConfirmationRequest({
    required this.point,
    required this.photoPath,
    required this.referenceMode,
    required this.settings,
    required this.photoLocationStrategy,
    required this.saveVisitPhotoToGallery,
    required this.autoSaveComparisonToGallery,
    this.referenceBytes,
    this.referenceImagePath,
    this.referenceImageUrl,
    this.capturedAtOverride,
    this.writePhotoLocation,
    this.restoreLandscape,
  });

  final PilgrimagePoint point;
  final String photoPath;
  final String referenceMode;
  final Uint8List? referenceBytes;
  final String? referenceImagePath;
  final String? referenceImageUrl;
  final DateTime? capturedAtOverride;
  final AppSettings settings;
  final PhotoLocationStrategy photoLocationStrategy;
  final PhotoLocationWriter? writePhotoLocation;
  final bool saveVisitPhotoToGallery;
  final bool autoSaveComparisonToGallery;

  /// Orientation to restore afterwards; null → decided by the page.
  final bool? restoreLandscape;

  /// Deletes the unsaved capture (old `discardSourcePhoto`).
  Future<void> discardSourcePhoto() async =>
      file_ops.deleteVisitRecordLocalFile(photoPath);
}

typedef CaptureConfirmationOpener =
    Future<VisitRecordConfirmationResult?> Function(
      CaptureConfirmationRequest request,
    );
typedef PhotoLocationStrategyPrompt = Future<PhotoLocationStrategy?> Function();

/// Camera use case, ported from the old `CamerawesomeReferenceScreen`
/// state: reference resolution (incl. a session reference), capture aspect
/// ratio, the location strategy prompt, the exclusive capture pipeline and
/// gallery import.
///
/// UI work (pickers, sheets, routes, orientation) is delegated to the page
/// through [openConfirmation], [promptPhotoLocationStrategy] and
/// [onMessage].
class CaptureSession extends ChangeNotifier {
  CaptureSession({
    required this._point,
    required AppSettings settings,
    required this.capabilities,
    this.loadPersistedSettings,
    this.saveSettings,
    ReferenceAspectRatioResolver? resolveAspectRatio,
    bool Function(String? path)? referencePathCanDisplay,
    Future<DateTime?> Function(String path)? readCaptureTime,
    Future<String> Function(String path)? copyPhoto,
    void Function(String path)? deletePhoto,
  }) : _settings = settings,
       _photoLocationStrategy = settings.photoLocationStrategy,
       _resolveAspectRatio = resolveAspectRatio ?? resolveReferenceAspectRatio,
       _referencePathCanDisplay =
           referencePathCanDisplay ?? referenceImageLocalPathCanDisplay,
       _readCaptureTime =
           readCaptureTime ?? gallery_capture_time.readGalleryCaptureTime,
       _copyPhoto = copyPhoto ?? camera_storage.copyVisitRecordPhoto,
       _deletePhoto = deletePhoto ?? file_ops.deleteVisitRecordLocalFile;

  final PlatformCapabilities capabilities;

  /// Reads the persisted settings before asking for a location strategy.
  final Future<AppSettings> Function()? loadPersistedSettings;

  /// Persists settings after the user picked a strategy.
  final Future<void> Function(AppSettings settings)? saveSettings;

  final ReferenceAspectRatioResolver _resolveAspectRatio;
  final bool Function(String? path) _referencePathCanDisplay;
  final Future<DateTime?> Function(String path) _readCaptureTime;
  final Future<String> Function(String path) _copyPhoto;
  final void Function(String path) _deletePhoto;

  /// Shows the confirmation page for a capture; resolves with its result.
  CaptureConfirmationOpener? openConfirmation;

  /// Shows the 「是否在巡礼照片中记录定位？」 sheet.
  PhotoLocationStrategyPrompt? promptPhotoLocationStrategy;

  /// Toasts.
  ValueChanged<CaptureMessage>? onMessage;

  PilgrimagePoint _point;
  AppSettings _settings;
  Uint8List? _localReferenceBytes;
  CaptureReferenceMode _mode = CaptureReferenceMode.overlay;
  double? _referenceAspectRatio;
  bool _referenceAspectRatioLoading = false;
  int _referenceAspectRatioRequest = 0;
  PhotoLocationStrategy _photoLocationStrategy;
  Future<PhotoLocationStrategy?>? _photoLocationStrategyRequest;
  bool _disposed = false;

  /// Overlay opacity (default 46 %), separate so dragging does not rebuild
  /// the whole page.
  final ValueNotifier<double> overlayOpacity = ValueNotifier<double>(0.46);

  PilgrimagePoint get point => _point;
  AppSettings get settings => _settings;
  CaptureReferenceMode get mode => _mode;
  Uint8List? get localReferenceBytes => _localReferenceBytes;
  double? get referenceAspectRatio => _referenceAspectRatio;
  bool get referenceAspectRatioLoading => _referenceAspectRatioLoading;
  PhotoLocationStrategy get photoLocationStrategy => _photoLocationStrategy;
  bool get isDisposed => _disposed;

  String? get remoteReferenceImageUrl => hasRemoteReferenceImage(_point)
      ? anitabiFullResolutionImageUrl(_point.referenceImageUrl)
      : null;

  CaptureReferenceSource get reference {
    final fullPath = _point.referenceFullImagePath;
    return CaptureReferenceSource(
      bytes: _localReferenceBytes,
      localPath: _referencePathCanDisplay(fullPath) ? fullPath : null,
      url: remoteReferenceImageUrl,
      imageSource: _settings.anitabiImageSource,
    );
  }

  double captureAspectRatio(Orientation orientation) =>
      resolveCameraCaptureAspectRatio(
        referenceAspectRatio: _referenceAspectRatio,
        settings: _settings,
        orientation: orientation,
      );

  bool get cropNativeCapture => shouldCropNativeCapture(
    referenceAspectRatio: _referenceAspectRatio,
    settings: _settings,
  );

  /// Old `_shouldWaitForReferenceAspectRatio`.
  bool get shouldWaitForReferenceAspectRatio =>
      _settings.cameraCaptureAspectRatio == CameraPhotoAspectRatio.auto &&
      reference.hasImage &&
      _referenceAspectRatio == null &&
      _referenceAspectRatioLoading;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _emit(String text, CaptureMessageKind kind) {
    if (_disposed) return;
    onMessage?.call(CaptureMessage(text, kind));
  }

  /// Starts reading the reference ratio (old `initState`).
  void start() => unawaited(refreshReferenceAspectRatio());

  /// The point changed (plan refresh); re-read the ratio when its reference
  /// changed (old `didUpdateWidget`).
  void updatePoint(PilgrimagePoint point) {
    final old = _point;
    _point = point;
    if (old.id != point.id ||
        old.referenceFullImagePath != point.referenceFullImagePath ||
        old.referenceImageUrl != point.referenceImageUrl) {
      unawaited(refreshReferenceAspectRatio());
    }
    _notify();
  }

  /// Live settings changed; the strategy is only taken over while it is
  /// still "ask on first capture" locally.
  void updateSettings(AppSettings settings) {
    if (identical(settings, _settings)) return;
    _settings = settings;
    _notify();
  }

  void setMode(CaptureReferenceMode mode) {
    if (_mode == mode) return;
    _mode = mode;
    _notify();
  }

  void setOverlayOpacity(double value) {
    overlayOpacity.value = value.clamp(0.0, 1.0);
  }

  Future<void> refreshReferenceAspectRatio() async {
    final requestId = ++_referenceAspectRatioRequest;
    _referenceAspectRatioLoading = true;
    _notify();
    final ratio = await _resolveAspectRatio(
      bytes: _localReferenceBytes,
      localPath: _point.referenceFullImagePath,
      url: remoteReferenceImageUrl,
      imageSource: _settings.anitabiImageSource,
    );
    if (_disposed || requestId != _referenceAspectRatioRequest) {
      return;
    }
    _referenceAspectRatio = ratio;
    _referenceAspectRatioLoading = false;
    _notify();
  }

  /// Uses [picked] as this session's reference. Returns an error text for
  /// the toast, or null on success.
  Future<String?> usePickedReference(XFile picked) async {
    Uint8List bytes;
    try {
      bytes = await readImageStreamBounded(
        picked.openRead(),
        declaredLength: await picked.length(),
      );
      await probeBoundedImage(bytes);
    } catch (error) {
      return error is ImageBudgetException ? error.message : '参考图读取失败';
    }
    if (_disposed) return null;
    await useReferenceBytes(bytes);
    return null;
  }

  @visibleForTesting
  Future<void> useReferenceBytes(Uint8List bytes) async {
    _localReferenceBytes = bytes;
    _notify();
    await refreshReferenceAspectRatio();
  }

  /// Old `_ensurePhotoLocationStrategy`: one prompt at a time.
  Future<PhotoLocationStrategy?> ensurePhotoLocationStrategy() async {
    final activeRequest = _photoLocationStrategyRequest;
    if (activeRequest != null) {
      return activeRequest;
    }
    final request = _resolvePhotoLocationStrategy();
    _photoLocationStrategyRequest = request;
    try {
      return await request;
    } finally {
      if (identical(_photoLocationStrategyRequest, request)) {
        _photoLocationStrategyRequest = null;
      }
    }
  }

  /// The early prompt when the camera opens; the shutter asks again when
  /// it fails.
  void askPhotoLocationStrategyEarly() {
    unawaited(
      ensurePhotoLocationStrategy().catchError((Object error) {
        debugPrint('Could not resolve photo location strategy: $error');
        return null;
      }),
    );
  }

  Future<PhotoLocationStrategy?> _resolvePhotoLocationStrategy() async {
    AppSettings? persistedSettings;
    if (_photoLocationStrategy == PhotoLocationStrategy.askOnFirstCapture) {
      try {
        persistedSettings = await loadPersistedSettings?.call();
      } catch (error) {
        // Still ask: failing every shutter tap would never show the prompt.
        // The choice is then saved on top of the settings snapshot.
        debugPrint('Could not load settings for location strategy: $error');
      }
      final persistedStrategy = persistedSettings?.photoLocationStrategy;
      if (persistedStrategy != null &&
          persistedStrategy != PhotoLocationStrategy.askOnFirstCapture) {
        _photoLocationStrategy = persistedStrategy;
      }
    }
    if (_photoLocationStrategy != PhotoLocationStrategy.askOnFirstCapture) {
      return _photoLocationStrategy;
    }
    if (_disposed) {
      return null;
    }

    final selected = await promptPhotoLocationStrategy?.call();
    if (selected == null || _disposed) {
      return null;
    }

    _photoLocationStrategy = selected;
    _notify();
    final save = saveSettings;
    if (save != null) {
      try {
        // The snapshot is from when the camera opened; only the strategy
        // may change on top of the persisted settings.
        await save(
          (persistedSettings ?? _settings).copyWith(
            photoLocationStrategy: selected,
          ),
        );
      } catch (error) {
        debugPrint('Could not persist photo location strategy: $error');
      }
    }
    return selected;
  }

  /// Native preview writer when available; on Android it falls back to the
  /// app-level EXIF channel, so the CameraAwesome fallback can still save
  /// locations. Null when no writer exists on this platform.
  PhotoLocationWriter? photoLocationWriter(NativeCameraController? native) {
    if (capabilities.isWeb || native == null) {
      return null;
    }
    if (native.ready || capabilities.isAndroid) {
      return native.writePhotoLocation;
    }
    return null;
  }

  /// Builds the confirmation request for [photoPath] (old
  /// `_openConfirmation` arguments).
  CaptureConfirmationRequest confirmationRequestFor(
    String photoPath, {
    required PhotoLocationWriter? writer,
    DateTime? capturedAtOverride,
    PhotoLocationStrategy photoLocationStrategy =
        PhotoLocationStrategy.disabled,
    bool? restoreLandscape,
  }) {
    final bytes = _localReferenceBytes;
    return CaptureConfirmationRequest(
      point: _point,
      photoPath: photoPath,
      referenceMode: _mode.label,
      referenceBytes: bytes,
      referenceImagePath: _point.referenceFullImagePath,
      referenceImageUrl: bytes != null ? null : remoteReferenceImageUrl,
      capturedAtOverride: capturedAtOverride,
      settings: _settings.copyWith(
        photoLocationStrategy: _photoLocationStrategy,
      ),
      photoLocationStrategy: writer == null
          ? PhotoLocationStrategy.disabled
          : photoLocationStrategy,
      writePhotoLocation: writer,
      saveVisitPhotoToGallery:
          capabilities.canSaveToGallery &&
          shouldAutoSaveVisitPhotoToGallery(_settings),
      autoSaveComparisonToGallery:
          capabilities.canSaveToGallery &&
          shouldAutoSaveComparisonToGallery(_settings),
      restoreLandscape: restoreLandscape,
    );
  }

  Future<VisitRecordConfirmationResult?> _openConfirmation(
    String photoPath, {
    required NativeCameraController? native,
    DateTime? capturedAtOverride,
    bool? restoreLandscape,
    PhotoLocationStrategy photoLocationStrategy =
        PhotoLocationStrategy.disabled,
  }) async {
    final opener = openConfirmation;
    if (_disposed || opener == null) {
      _deletePhoto(photoPath);
      return null;
    }
    return opener(
      confirmationRequestFor(
        photoPath,
        writer: photoLocationWriter(native),
        capturedAtOverride: capturedAtOverride,
        photoLocationStrategy: photoLocationStrategy,
        restoreLandscape: restoreLandscape,
      ),
    );
  }

  void _showCaptureFailed() => _emit('拍摄失败，请重试。', CaptureMessageKind.error);

  /// Native shutter. The shutter stays busy until the confirmation page
  /// closes; every failure ends in 「拍摄失败，请重试。」.
  Future<void> captureWithNativeCamera(NativeCameraController native) {
    return native.runExclusiveCapture(() async {
      try {
        await _captureWithNativeCameraExclusive(native);
      } catch (error, stackTrace) {
        // The shutter drops this future, so every failure (settings lookup,
        // capture, confirmation) must end here instead of escaping as an
        // unhandled async error. runExclusiveCapture resets the busy state.
        debugPrint('Native camera capture failed: $error\n$stackTrace');
        _showCaptureFailed();
      }
    });
  }

  Future<void> _captureWithNativeCameraExclusive(
    NativeCameraController native,
  ) async {
    if (shouldWaitForReferenceAspectRatio) {
      _emit('正在读取参考图比例，请稍后拍摄。', CaptureMessageKind.running);
      return;
    }
    final strategy = await ensurePhotoLocationStrategy();
    if (strategy == null || _disposed) {
      return;
    }
    // Take the picture first; location is resolved on the confirmation
    // screen so a slow GPS fix never delays the shutter. Native failures
    // (including a preview disposed mid-capture) throw into the caller.
    final path = await native.takePicture();
    if (path == null) {
      _emit('相机尚未就绪，请稍后再拍。', CaptureMessageKind.warning);
      return;
    }
    await _openConfirmation(
      path,
      native: native,
      photoLocationStrategy: strategy,
    );
  }

  /// CameraAwesome delivered a photo at [path] (old `_handleCaptureEvent`).
  Future<void> handleFallbackCapture(
    String path, {
    NativeCameraController? native,
  }) async {
    if (_disposed) {
      _deletePhoto(path);
      return;
    }

    // The photo already exists; a dismissed strategy prompt only skips
    // location for this photo instead of dropping the capture.
    PhotoLocationStrategy? strategy;
    try {
      strategy = await ensurePhotoLocationStrategy();
    } catch (error, stackTrace) {
      // CameraAwesome drops this future, so a failure must end here; nobody
      // else will open or clean up the captured file.
      debugPrint('Capture strategy lookup failed: $error\n$stackTrace');
      _deletePhoto(path);
      _showCaptureFailed();
      return;
    }
    try {
      await _openConfirmation(
        path,
        native: native,
        photoLocationStrategy: strategy ?? PhotoLocationStrategy.disabled,
      );
    } catch (error, stackTrace) {
      debugPrint('Opening capture confirmation failed: $error\n$stackTrace');
      _showCaptureFailed();
    }
  }

  /// Imports a gallery photo picked at [pickedPath]: reads the EXIF time,
  /// copies it into `visit_record_images` and opens the confirmation
  /// without location. Returns false when the copy failed (the page then
  /// restores the orientation itself).
  Future<bool> importGalleryPhoto(
    String pickedPath, {
    NativeCameraController? native,
    bool? restoreLandscape,
  }) async {
    final capturedAt = await _readCaptureTime(pickedPath);
    String photoPath;
    try {
      photoPath = await _copyPhoto(pickedPath);
    } catch (_) {
      _emit('照片导入失败，请重新选择。', CaptureMessageKind.error);
      return false;
    }
    await _openConfirmation(
      photoPath,
      native: native,
      capturedAtOverride: capturedAt,
      restoreLandscape: restoreLandscape,
    );
    return true;
  }

  @override
  void dispose() {
    _disposed = true;
    overlayOpacity.dispose();
    super.dispose();
  }
}
