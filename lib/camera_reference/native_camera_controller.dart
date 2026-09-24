import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:permission_handler/permission_handler.dart';

import 'photo_location.dart';

typedef NativeCameraChannelFactory = MethodChannel Function(int viewId);
typedef NativeCameraPermissionRequest = Future<bool> Function();

/// App-level channel that writes GPS EXIF without a live camera preview. Used
/// when the native preview is unavailable (CameraAwesome fallback).
const photoLocationChannel = MethodChannel('seichi/photo_location');

Future<bool> writePhotoLocationWithAppChannel(
  String path,
  PhotoLocationData location, {
  MethodChannel channel = photoLocationChannel,
}) async {
  try {
    return await channel.invokeMethod<bool>('writePhotoLocation', {
          'path': path,
          ...location.toPlatformArguments(),
        }) ??
        false;
  } catch (_) {
    return false;
  }
}

MethodChannel _defaultChannel(int viewId) =>
    MethodChannel('seichi/native_camera_preview_$viewId');

Future<bool> _defaultRequestCameraPermission() async {
  if (defaultTargetPlatform != TargetPlatform.android) {
    // iOS asks for camera access natively during `initialize`.
    return true;
  }
  return (await Permission.camera.request()).isGranted;
}

/// Drives the per-view native preview channel.
///
/// The platform view may be recreated (new view id) when the layout changes.
/// The native side removes the old channel handler as soon as it disposes the
/// old view, so every call on a stale channel must be tolerated and the new
/// view must receive the full session state again.
class NativeCameraController extends ChangeNotifier {
  NativeCameraController({
    NativeCameraChannelFactory? channelFactory,
    NativeCameraPermissionRequest? requestCameraPermission,
  }) : _channelFactory = channelFactory ?? _defaultChannel,
       _requestCameraPermission =
           requestCameraPermission ?? _defaultRequestCameraPermission;

  final NativeCameraChannelFactory _channelFactory;
  final NativeCameraPermissionRequest _requestCameraPermission;

  /// Stable key for the preview widget so layout switches reparent the
  /// platform view instead of creating a new native camera view.
  final GlobalKey previewKey = GlobalKey(debugLabel: 'native-camera-preview');

  MethodChannel? _channel;
  int? _viewId;
  var _attachGeneration = 0;
  var _disposed = false;
  var _ready = false;
  var _busy = false;
  var _captureInProgress = false;
  String? _error;
  var _minZoomRatio = 1.0;
  var _maxZoomRatio = 1.0;
  var _zoomRatio = 1.0;
  var _flashMode = 'auto';
  var _lensFacing = 'back';
  var _lensMode = 'backAuto';
  var _supportsTelephoto = false;
  var _captureAspectRatio = 1.0;
  var _cropCaptureToAspectRatio = true;
  double? _preferredInitialZoomRatio;
  double? _appliedCaptureAspectRatio;
  bool? _appliedCropCaptureToAspectRatio;
  double? _appliedInitialZoomRatio;
  var _configuringCapture = false;
  var _configurationGeneration = 0;
  Future<void>? _configurationFuture;

  bool get ready => _ready;
  bool get busy => _busy;
  String? get error => _error;
  double get minZoomRatio => _minZoomRatio;
  double get maxZoomRatio => _maxZoomRatio;
  double get zoomRatio => _zoomRatio;
  String get flashMode => _flashMode;
  String get lensFacing => _lensFacing;
  String get lensMode => _lensMode;
  bool get supportsTelephoto => _supportsTelephoto;
  bool get configuringCapture => _configuringCapture;
  bool get captureInProgress => _captureInProgress;
  @visibleForTesting
  int? get viewId => _viewId;

  /// Whether the shutter must look busy and ignore taps.
  bool get shutterBusy => _busy || _configuringCapture || _captureInProgress;

  Future<void> attach(int viewId) async {
    if (_disposed || (_channel != null && _viewId == viewId)) {
      return;
    }

    final generation = ++_attachGeneration;
    final previous = _channel;
    _channel = null;
    _viewId = viewId;
    _ready = false;
    _configuringCapture = false;
    _configurationFuture = null;
    // A new native view starts from its own defaults; nothing applied to the
    // previous view carries over.
    _appliedCaptureAspectRatio = null;
    _appliedCropCaptureToAspectRatio = null;
    _appliedInitialZoomRatio = null;
    _notify();
    if (previous != null) {
      await _disposeChannelQuietly(previous);
    }
    bool isStale() => _disposed || generation != _attachGeneration;
    if (isStale()) {
      return;
    }

    final bool granted;
    try {
      granted = await _requestCameraPermission();
    } catch (error) {
      if (isStale()) return;
      _error = '相机权限请求失败：$error';
      _notify();
      return;
    }
    if (isStale()) {
      return;
    }
    if (!granted) {
      _error = '需要相机权限';
      _notify();
      return;
    }

    final channel = _channelFactory(viewId);
    _channel = channel;
    try {
      final result = await channel.invokeMapMethod<String, Object?>(
        'initialize',
        {'targetAspectRatio': _captureAspectRatio},
      );
      if (isStale()) return;
      _applyZoomState(result);
      _ready = true;
      _error = null;
      await _scheduleCaptureConfiguration();
      if (isStale()) return;
      await _restoreFlashMode(channel);
    } on PlatformException catch (error) {
      if (isStale()) return;
      _error = error.message ?? '原生相机初始化失败';
    } catch (error) {
      if (isStale()) return;
      _error = '原生相机初始化失败：$error';
    }
    _notify();
  }

  Future<void> setZoomRatio(double ratio) async {
    final channel = _channel;
    if (channel == null || !_ready) {
      return;
    }

    _zoomRatio = ratio.clamp(_minZoomRatio, _maxZoomRatio);
    _notify();
    try {
      final result = await channel.invokeMapMethod<String, Object?>(
        'setZoomRatio',
        {'zoomRatio': _zoomRatio},
      );
      if (!identical(_channel, channel)) return;
      _applyZoomState(result);
    } catch (error) {
      debugPrint('Native camera zoom failed: $error');
    }
    _notify();
  }

  Future<void> configureCapture({
    required double captureAspectRatio,
    required bool cropCaptureToAspectRatio,
    required double preferredInitialZoomRatio,
  }) {
    final safeRatio = captureAspectRatio <= 0 ? 1.0 : captureAspectRatio;
    final safeZoom = preferredInitialZoomRatio <= 0
        ? 1.0
        : preferredInitialZoomRatio;
    final unchanged =
        (_captureAspectRatio - safeRatio).abs() < 0.001 &&
        _cropCaptureToAspectRatio == cropCaptureToAspectRatio &&
        ((_preferredInitialZoomRatio ?? -1) - safeZoom).abs() < 0.001;
    if (unchanged) {
      return _configurationFuture ?? Future<void>.value();
    }

    _captureAspectRatio = safeRatio;
    _cropCaptureToAspectRatio = cropCaptureToAspectRatio;
    _preferredInitialZoomRatio = safeZoom;
    _configurationGeneration += 1;
    return _scheduleCaptureConfiguration();
  }

  Future<void> cycleFlashMode() async {
    final nextMode = switch (_flashMode) {
      'auto' => 'on',
      'on' => 'torch',
      'torch' => 'off',
      _ => 'auto',
    };
    await setFlashMode(nextMode);
  }

  Future<void> setFlashMode(String mode) async {
    final channel = _channel;
    if (channel == null || !_ready) {
      return;
    }

    final previousMode = _flashMode;
    _flashMode = mode;
    _notify();
    try {
      await channel.invokeMethod<void>('setFlashMode', {'flashMode': mode});
    } catch (error) {
      debugPrint('Native camera flash change failed: $error');
      if (identical(_channel, channel) && _flashMode == mode) {
        // Keep the UI truthful: the native side did not switch.
        _flashMode = previousMode;
        _notify();
      }
    }
  }

  Future<void> switchLens() async {
    final channel = _channel;
    if (channel == null || !_ready) {
      return;
    }

    try {
      final result = await channel.invokeMapMethod<String, Object?>(
        'switchLens',
      );
      if (!identical(_channel, channel)) return;
      _applyZoomState(result);
      _appliedInitialZoomRatio = null;
      await _scheduleCaptureConfiguration();
    } catch (error) {
      debugPrint('Native camera lens switch failed: $error');
      try {
        final result = await channel.invokeMapMethod<String, Object?>(
          'getZoomState',
        );
        if (identical(_channel, channel)) _applyZoomState(result);
      } catch (_) {}
    }
    _notify();
  }

  /// Runs [action] unless another capture is already running. The shutter
  /// stays busy for the whole action, including the confirmation screen.
  Future<void> runExclusiveCapture(Future<void> Function() action) async {
    if (_captureInProgress || _disposed) {
      return;
    }
    _captureInProgress = true;
    _notify();
    try {
      await action();
    } finally {
      _captureInProgress = false;
      _notify();
    }
  }

  /// Returns null when the camera is not ready; throws on native failure.
  Future<String?> takePicture({PhotoLocationData? location}) async {
    final channel = _channel;
    if (channel == null || !_ready || _busy) {
      return null;
    }
    await (_configurationFuture ?? _scheduleCaptureConfiguration());
    if (_configuringCapture || !identical(_channel, channel) || !_ready) {
      return null;
    }

    _busy = true;
    _notify();
    try {
      return await channel.invokeMethod<String>('takePicture', {
        if (location != null) ...location.toPlatformArguments(),
      });
    } finally {
      _busy = false;
      _notify();
    }
  }

  Future<bool> writePhotoLocation(
    String path,
    PhotoLocationData location,
  ) async {
    final channel = _channel;
    if (channel == null || !_ready) {
      return writePhotoLocationWithAppChannel(path, location);
    }
    try {
      return await channel.invokeMethod<bool>('writePhotoLocation', {
            'path': path,
            ...location.toPlatformArguments(),
          }) ??
          false;
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _attachGeneration += 1;
    final channel = _channel;
    _channel = null;
    _ready = false;
    if (channel != null) {
      unawaited(_disposeChannelQuietly(channel));
    }
    super.dispose();
  }

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  Future<void> _disposeChannelQuietly(MethodChannel channel) async {
    try {
      await channel.invokeMethod<void>('dispose');
    } on MissingPluginException {
      // The native view already disposed itself and removed its handler.
    } on PlatformException catch (error) {
      debugPrint('Native camera dispose failed: ${error.message}');
    } catch (error) {
      debugPrint('Native camera dispose failed: $error');
    }
  }

  Future<void> _restoreFlashMode(MethodChannel channel) async {
    try {
      await channel.invokeMethod<void>('setFlashMode', {
        'flashMode': _flashMode,
      });
    } catch (error) {
      debugPrint('Native camera flash restore failed: $error');
      if (identical(_channel, channel)) {
        // A fresh native view defaults to auto.
        _flashMode = 'auto';
      }
    }
  }

  void _applyZoomState(Map<String, Object?>? state) {
    if (state == null) {
      return;
    }

    _minZoomRatio = (state['minZoomRatio'] as num?)?.toDouble() ?? 1;
    _maxZoomRatio = (state['maxZoomRatio'] as num?)?.toDouble() ?? 1;
    _zoomRatio = (state['zoomRatio'] as num?)?.toDouble() ?? 1;
    _lensFacing = state['lensFacing'] as String? ?? _lensFacing;
    _lensMode = state['lensMode'] as String? ?? _lensMode;
    _supportsTelephoto =
        (state['supportsTelephoto'] as bool?) ?? _supportsTelephoto;
  }

  Future<void> _scheduleCaptureConfiguration() {
    final existing = _configurationFuture;
    if (existing != null) {
      return existing;
    }
    late final Future<void> future;
    future = _runCaptureConfiguration().whenComplete(() {
      if (identical(_configurationFuture, future)) {
        _configurationFuture = null;
      }
    });
    _configurationFuture = future;
    return future;
  }

  Future<void> _runCaptureConfiguration() async {
    final channel = _channel;
    if (channel == null || !_ready) {
      return;
    }
    bool current() => identical(_channel, channel) && _ready;

    _configuringCapture = true;
    _notify();
    try {
      var appliedGeneration = -1;
      while (current() && appliedGeneration != _configurationGeneration) {
        final generation = _configurationGeneration;
        final captureAspectRatio = _captureAspectRatio;
        final cropCaptureToAspectRatio = _cropCaptureToAspectRatio;
        final preferredZoom = _preferredInitialZoomRatio;

        if (((_appliedCaptureAspectRatio ?? -1) - captureAspectRatio).abs() >=
            0.001) {
          await channel.invokeMethod<void>('setTargetAspectRatio', {
            'targetAspectRatio': captureAspectRatio,
          });
          if (!current()) return;
          _appliedCaptureAspectRatio = captureAspectRatio;
        }

        if (_appliedCropCaptureToAspectRatio != cropCaptureToAspectRatio) {
          await channel.invokeMethod<void>('setCropCaptureToAspectRatio', {
            'enabled': cropCaptureToAspectRatio,
          });
          if (!current()) return;
          _appliedCropCaptureToAspectRatio = cropCaptureToAspectRatio;
        }

        if (preferredZoom != null && _maxZoomRatio > _minZoomRatio) {
          final clampedZoom = preferredZoom.clamp(_minZoomRatio, _maxZoomRatio);
          if (((_appliedInitialZoomRatio ?? -1) - clampedZoom).abs() >= 0.001) {
            final result = await channel.invokeMapMethod<String, Object?>(
              'setZoomRatio',
              {'zoomRatio': clampedZoom},
            );
            if (!current()) return;
            _applyZoomState(result);
            _appliedInitialZoomRatio = clampedZoom;
          }
        }

        appliedGeneration = generation;
      }
    } finally {
      // A superseded run must not clear the flag owned by the new view.
      if (identical(_channel, channel) || _channel == null) {
        _configuringCapture = false;
        _notify();
      }
    }
  }
}
