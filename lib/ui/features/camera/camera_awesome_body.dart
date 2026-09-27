import 'dart:async';

import 'package:camerawesome/camerawesome_plugin.dart';
import 'package:flutter/material.dart';

import '../../../application/capture/capture_aspect_ratio.dart';
import '../../../application/capture/capture_session.dart';
import '../../../camera_reference/camera_storage_stub.dart'
    if (dart.library.io) '../../../camera_reference/camera_storage_io.dart'
    as camera_storage;
import '../../../camera_reference/native_camera_controller.dart';
import '../../../plan/pilgrimage_models.dart';
import 'camera_controls.dart';
import 'camera_layouts.dart';
import 'camera_stage.dart';

/// CameraAwesome fallback (Android when the native preview fails, native
/// desktop builds). Same rails as the native camera; the plugin preview is
/// padded into the measured stage rectangle so controls never cover it.
class CameraAwesomeBody extends StatefulWidget {
  const CameraAwesomeBody({
    required this.session,
    required this.actions,
    required this.landscape,
    this.nativeController,
    super.key,
  });

  final CaptureSession session;

  /// [CameraActions.onCapture] is ignored; the shutter drives the plugin.
  final CameraActions actions;
  final bool landscape;

  /// Kept for the Android EXIF writer fallback.
  final NativeCameraController? nativeController;

  @override
  State<CameraAwesomeBody> createState() => _CameraAwesomeBodyState();
}

class _CameraAwesomeBodyState extends State<CameraAwesomeBody> {
  final _bodyKey = GlobalKey(debugLabel: 'camera-awesome-body');
  final _previewSlotKey = GlobalKey(debugLabel: 'camera-awesome-preview');
  late final _AwesomeDeviceControls _device = _AwesomeDeviceControls(
    settings: () => widget.session.settings,
  );
  EdgeInsets _previewPadding = EdgeInsets.zero;
  late final SensorConfig _sensorConfig = SensorConfig.single(
    sensor: Sensor.position(SensorPosition.back),
    flashMode: FlashMode.auto,
    aspectRatio: _cameraAspectRatioFromDouble(
      widget.session.captureAspectRatio(
        widget.landscape ? Orientation.landscape : Orientation.portrait,
      ),
    ),
    zoom: 0,
  );

  @override
  void dispose() {
    _device.dispose();
    super.dispose();
  }

  Future<CaptureRequest> _buildPhotoPath(List<Sensor> sensors) async {
    final path = await camera_storage.buildVisitRecordPhotoPath();
    return SingleCaptureRequest(path, sensors.first);
  }

  void _handleCaptureEvent(MediaCapture event) {
    if (!event.isPicture || event.status != MediaCaptureStatus.success) {
      return;
    }
    final path = event.captureRequest.when(
      single: (single) => single.file?.path,
      multiple: (multiple) => multiple.fileBySensor.values.first?.path,
    );
    if (path == null) return;
    unawaited(
      widget.session.handleFallbackCapture(
        path,
        native: widget.nativeController,
      ),
    );
  }

  void _measurePreviewSlot() {
    if (!mounted) return;
    final body = _bodyKey.currentContext?.findRenderObject() as RenderBox?;
    final slot =
        _previewSlotKey.currentContext?.findRenderObject() as RenderBox?;
    if (body == null || slot == null || !body.hasSize || !slot.hasSize) {
      return;
    }
    final topLeft = slot.localToGlobal(Offset.zero, ancestor: body);
    final rect = topLeft & slot.size;
    final padding = EdgeInsets.fromLTRB(
      rect.left,
      rect.top,
      body.size.width - rect.right,
      body.size.height - rect.bottom,
    );
    if ((padding.left - _previewPadding.left).abs() > 0.5 ||
        (padding.top - _previewPadding.top).abs() > 0.5 ||
        (padding.right - _previewPadding.right).abs() > 0.5 ||
        (padding.bottom - _previewPadding.bottom).abs() > 0.5) {
      setState(() => _previewPadding = padding);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    return KeyedSubtree(
      key: _bodyKey,
      child: CameraAwesomeBuilder.custom(
        saveConfig: SaveConfig.photo(pathBuilder: _buildPhotoPath),
        sensorConfig: _sensorConfig,
        previewFit: CameraPreviewFit.contain,
        previewAlignment: Alignment.center,
        previewPadding: _previewPadding,
        enablePhysicalButton: true,
        onMediaCaptureEvent: _handleCaptureEvent,
        builder: (cameraState, preview) {
          _device.attach(cameraState);
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _measurePreviewSlot(),
          );
          final orientation = widget.landscape
              ? Orientation.landscape
              : Orientation.portrait;
          final stage = CameraStage(
            mode: session.mode,
            reference: session.reference,
            overlayOpacity: session.overlayOpacity,
            captureAspectRatio: session.captureAspectRatio(orientation),
            referenceScale: session.settings.referenceImageScale,
            transparentPreview: true,
            preview: SizedBox.expand(key: _previewSlotKey),
          );
          final actions = CameraActions(
            onBack: widget.actions.onBack,
            onPickReference: widget.actions.onPickReference,
            onPickGallery: widget.actions.onPickGallery,
            onPreferPortraitUi: widget.actions.onPreferPortraitUi,
            onPreferLandscapeUi: widget.actions.onPreferLandscapeUi,
            onCapture: () => cameraState.when(
              onPhotoMode: (photoState) => photoState.takePhoto(),
            ),
          );
          return widget.landscape
              ? CameraLandscapeLayout(
                  session: session,
                  device: _device,
                  stage: stage,
                  actions: actions,
                  background: Colors.transparent,
                )
              : CameraPortraitLayout(
                  session: session,
                  device: _device,
                  stage: stage,
                  actions: actions,
                  background: Colors.transparent,
                );
        },
      ),
    );
  }
}

CameraAspectRatios _cameraAspectRatioFromDouble(double ratio) {
  final normalized = ratio >= 1 ? ratio : 1 / ratio;
  final distanceToSquare = (normalized - 1).abs();
  final distanceToFourThree = (normalized - 4 / 3).abs();
  final distanceToSixteenNine = (normalized - 16 / 9).abs();

  if (distanceToSquare <= distanceToFourThree &&
      distanceToSquare <= distanceToSixteenNine) {
    return CameraAspectRatios.ratio_1_1;
  }
  if (distanceToFourThree <= distanceToSixteenNine) {
    return CameraAspectRatios.ratio_4_3;
  }
  return CameraAspectRatios.ratio_16_9;
}

/// [CameraDeviceControls] over a CameraAwesome [CameraState]. Zoom is the
/// plugin's normalised 0…1 value mapped onto the device's real range; the
/// default 1× is re-applied after 250 ms and 900 ms (old calibration).
class _AwesomeDeviceControls extends ChangeNotifier
    implements CameraDeviceControls {
  _AwesomeDeviceControls({required this.settings});

  final AppSettings Function() settings;

  CameraState? _state;
  StreamSubscription<SensorConfig>? _configSubscription;
  StreamSubscription<FlashMode>? _flashSubscription;
  StreamSubscription<double>? _zoomSubscription;
  FlashMode _flash = FlashMode.auto;
  double _normalizedZoom = 0;
  double? _minZoom;
  double? _maxZoom;
  bool _defaultZoomApplied = false;
  int _calibration = 0;
  bool _disposed = false;

  void attach(CameraState state) {
    if (identical(state, _state)) return;
    _state = state;
    _defaultZoomApplied = false;
    _calibration++;
    unawaited(_configSubscription?.cancel());
    _configSubscription = state.sensorConfig$.listen(_bindConfig);
    _bindConfig(state.sensorConfig);
    unawaited(_loadZoomRange());
  }

  void _bindConfig(SensorConfig config) {
    unawaited(_flashSubscription?.cancel());
    unawaited(_zoomSubscription?.cancel());
    _flash = config.flashMode;
    _normalizedZoom = config.zoom;
    _flashSubscription = config.flashMode$.listen((mode) {
      _flash = mode;
      _notify();
    });
    _zoomSubscription = config.zoom$.listen((zoom) {
      _normalizedZoom = zoom;
      _notify();
    });
  }

  void _notify() {
    if (_disposed) return;
    // Streams may fire while the plugin builds; notify after the frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_disposed) notifyListeners();
    });
  }

  Future<void> _loadZoomRange() async {
    final double? minZoom;
    final double? maxZoom;
    try {
      minZoom = await CamerawesomePlugin.getMinZoom();
      maxZoom = await CamerawesomePlugin.getMaxZoom();
    } catch (_) {
      return;
    }
    if (_disposed || minZoom == null || maxZoom == null) return;
    _minZoom = minZoom;
    _maxZoom = maxZoom;
    _notify();
    _applyDefaultMainLensZoom(minZoom, maxZoom);
  }

  void _applyDefaultMainLensZoom(double minZoom, double maxZoom) {
    if (_defaultZoomApplied || maxZoom <= minZoom) return;
    final range = effectiveCameraZoomRange(
      deviceMinZoom: minZoom,
      deviceMaxZoom: maxZoom,
      settings: settings(),
    );
    final defaultZoom = 1.0.clamp(range.$1, range.$2).toDouble();
    _defaultZoomApplied = true;
    unawaited(setZoom(defaultZoom));
    final generation = ++_calibration;
    for (final delay in const [
      Duration(milliseconds: 250),
      Duration(milliseconds: 900),
    ]) {
      Future<void>.delayed(delay, () {
        if (_disposed || generation != _calibration) return;
        unawaited(setZoom(defaultZoom));
      });
    }
  }

  @override
  String get flashMode => switch (_flash) {
    FlashMode.none => 'off',
    FlashMode.on => 'on',
    FlashMode.auto => 'auto',
    FlashMode.always => 'torch',
  };

  @override
  Future<void> cycleFlash() async {
    _state?.sensorConfig.switchCameraFlash();
  }

  @override
  bool get telephoto => false;

  @override
  String get lensTooltip => '切换摄像头';

  @override
  Future<void> switchLens() async {
    final state = _state;
    if (state == null) return;
    await state.switchCameraSensor(
      zoom: state.sensorConfig.zoom,
      flash: state.sensorConfig.flashMode,
    );
  }

  @override
  bool get hasZoomRange => _minZoom != null && _maxZoom != null;

  @override
  double get deviceMinZoom => _minZoom ?? 1;

  @override
  double get deviceMaxZoom => _maxZoom ?? 1;

  @override
  double get zoom {
    final min = _minZoom;
    final max = _maxZoom;
    if (min == null || max == null) return 1;
    return min + (max - min) * _normalizedZoom;
  }

  @override
  Future<void> setZoom(double realZoom) async {
    final state = _state;
    final min = _minZoom;
    final max = _maxZoom;
    if (state == null || min == null || max == null || max <= min) return;
    final normalized = ((realZoom - min) / (max - min)).clamp(0.0, 1.0);
    _normalizedZoom = normalized;
    _notify();
    try {
      await state.sensorConfig.setZoom(normalized);
    } catch (error) {
      debugPrint('CameraAwesome zoom failed: $error');
    }
  }

  @override
  bool get shutterBusy => false;

  @override
  void dispose() {
    _disposed = true;
    unawaited(_configSubscription?.cancel());
    unawaited(_flashSubscription?.cancel());
    unawaited(_zoomSubscription?.cancel());
    super.dispose();
  }
}
