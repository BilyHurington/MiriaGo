import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:camerawesome/camerawesome_plugin.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../app_theme.dart';
import '../data/anitabi_image_url.dart';
import '../plan/pilgrimage_models.dart';
import '../plan/pilgrimage_plan_controller.dart';
import '../widgets/reference_thumbnail_stub.dart'
    if (dart.library.io) '../widgets/reference_thumbnail_io.dart';
import 'camera_storage_stub.dart'
    if (dart.library.io) 'camera_storage_io.dart'
    as camera_storage;
import 'reference_image_bytes_stub.dart'
    if (dart.library.io) 'reference_image_bytes_io.dart'
    as reference_image_bytes;
import 'visit_record_confirmation_screen.dart';

enum AwesomeReferenceMode { overlay, split, pinned }

extension AwesomeReferenceModeLabel on AwesomeReferenceMode {
  String get label {
    return switch (this) {
      AwesomeReferenceMode.overlay => '叠影',
      AwesomeReferenceMode.split => '上下',
      AwesomeReferenceMode.pinned => '小窗',
    };
  }
}

class CamerawesomeReferenceScreen extends StatefulWidget {
  const CamerawesomeReferenceScreen({
    required this.point,
    required this.settings,
    this.controller,
    super.key,
  });

  final PilgrimagePoint point;
  final AppSettings settings;
  final PilgrimagePlanController? controller;

  @override
  State<CamerawesomeReferenceScreen> createState() =>
      _CamerawesomeReferenceScreenState();
}

class _CamerawesomeReferenceScreenState
    extends State<CamerawesomeReferenceScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  late final ValueNotifier<double> _overlayOpacity;
  late final ValueNotifier<double> _zoom;
  late final _NativeCameraController _nativeCameraController;

  Uint8List? _localReferenceBytes;
  XFile? _galleryImage;
  AwesomeReferenceMode _mode = AwesomeReferenceMode.overlay;
  bool _landscapeLocked = false;
  bool _nativeCameraFailed = false;
  double? _referenceAspectRatio;
  int _referenceAspectRatioRequest = 0;

  @override
  void initState() {
    super.initState();
    _overlayOpacity = ValueNotifier<double>(0.46);
    _zoom = ValueNotifier<double>(0);
    _nativeCameraController = _NativeCameraController();
    _refreshReferenceAspectRatio();
  }

  @override
  void didUpdateWidget(covariant CamerawesomeReferenceScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.point.id != widget.point.id ||
        oldWidget.point.referenceFullImagePath !=
            widget.point.referenceFullImagePath ||
        oldWidget.point.referenceImageUrl != widget.point.referenceImageUrl) {
      _refreshReferenceAspectRatio();
    }
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _overlayOpacity.dispose();
    _zoom.dispose();
    _nativeCameraController.dispose();
    super.dispose();
  }

  Future<CaptureRequest> _buildPhotoPath(List<Sensor> sensors) async {
    final path = await camera_storage.buildReferencePhotoPath();
    return SingleCaptureRequest(path, sensors.first);
  }

  Future<void> _pickReferenceImage() async {
    final picked = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (picked == null || !mounted) {
      return;
    }

    final bytes = await picked.readAsBytes();
    if (!mounted) {
      return;
    }

    setState(() {
      _localReferenceBytes = bytes;
    });
    await _refreshReferenceAspectRatio();
  }

  Future<void> _refreshReferenceAspectRatio() async {
    final requestId = ++_referenceAspectRatioRequest;
    final ratio = await _resolveReferenceAspectRatio(
      bytes: _localReferenceBytes,
      localPath: widget.point.referenceFullImagePath,
      url: anitabiFullResolutionImageUrl(widget.point.referenceImageUrl),
    );
    if (!mounted || requestId != _referenceAspectRatioRequest) {
      return;
    }

    setState(() {
      _referenceAspectRatio = ratio;
    });
  }

  Future<void> _pickGalleryImage() async {
    final picked = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (picked == null || !mounted) {
      return;
    }

    setState(() {
      _galleryImage = picked;
    });
    await _openConfirmation(picked.path);
  }

  Future<void> _handleCaptureEvent(MediaCapture event) async {
    if (!event.isPicture || event.status != MediaCaptureStatus.success) {
      return;
    }

    final path = event.captureRequest.when(
      single: (single) => single.file?.path,
      multiple: (multiple) => multiple.fileBySensor.values.first?.path,
    );
    if (path == null || !mounted) {
      return;
    }

    await _openConfirmation(path);
  }

  Future<void> _openConfirmation(String photoPath) async {
    if (!mounted) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => VisitRecordConfirmationScreen(
          point: widget.point,
          controller: widget.controller,
          photoPath: photoPath,
          referenceMode: _mode.label,
          referenceBytes: _localReferenceBytes,
          referenceImagePath: widget.point.referenceFullImagePath,
          referenceImageUrl: anitabiFullResolutionImageUrl(
            widget.point.referenceImageUrl,
          ),
        ),
      ),
    );
  }

  void _setZoom(CameraState state, double value) {
    final nextZoom = value.clamp(0.0, 1.0);
    _zoom.value = nextZoom;
    state.sensorConfig.setZoom(nextZoom);
  }

  void _toggleOrientation() {
    setState(() {
      _landscapeLocked = !_landscapeLocked;
    });
  }

  bool get _shouldUseNativeCamera {
    return !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android &&
        !_nativeCameraFailed;
  }

  @override
  Widget build(BuildContext context) {
    final reference = _ReferenceImageSource(
      bytes: _localReferenceBytes,
      localPath: widget.point.referenceFullImagePath,
      url: anitabiFullResolutionImageUrl(widget.point.referenceImageUrl),
    );
    final captureAspectRatio = _captureAspectRatio(
      referenceAspectRatio: _referenceAspectRatio,
      settings: widget.settings,
      landscapeLocked: _landscapeLocked,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: kIsWeb
          ? _WebCameraFallback(
              point: widget.point,
              reference: reference,
              galleryImage: _galleryImage,
              mode: _mode,
              overlayOpacity: _overlayOpacity.value,
              onModeChanged: (mode) => setState(() => _mode = mode),
              onOpacityChanged: (value) => _overlayOpacity.value = value,
              onPickReference: _pickReferenceImage,
              onPickGallery: _pickGalleryImage,
            )
          : _shouldUseNativeCamera
          ? _NativeReferenceCameraBody(
              point: widget.point,
              controller: _nativeCameraController,
              reference: reference,
              galleryImage: _galleryImage,
              mode: _mode,
              overlayOpacity: _overlayOpacity,
              settings: widget.settings,
              captureAspectRatio: captureAspectRatio,
              landscapeLocked: _landscapeLocked,
              onNativeUnavailable: () {
                setState(() => _nativeCameraFailed = true);
              },
              onModeChanged: (mode) => setState(() => _mode = mode),
              onOpacityChanged: (value) => _overlayOpacity.value = value,
              onCapture: () async {
                final path = await _nativeCameraController.takePicture();
                if (path != null) {
                  await _openConfirmation(path);
                }
              },
              onPickReference: _pickReferenceImage,
              onPickGallery: _pickGalleryImage,
              onToggleOrientation: _toggleOrientation,
            )
          : CameraAwesomeBuilder.custom(
              saveConfig: SaveConfig.photo(pathBuilder: _buildPhotoPath),
              sensorConfig: SensorConfig.single(
                sensor: Sensor.position(SensorPosition.back),
                flashMode: FlashMode.auto,
                aspectRatio: _cameraAspectRatioFromDouble(captureAspectRatio),
                zoom: _zoom.value,
              ),
              previewFit: CameraPreviewFit.contain,
              previewAlignment: Alignment.center,
              enablePhysicalButton: true,
              onMediaCaptureEvent: _handleCaptureEvent,
              builder: (cameraState, preview) {
                return _ReferenceCameraOverlay(
                  point: widget.point,
                  state: cameraState,
                  reference: reference,
                  galleryImage: _galleryImage,
                  mode: _mode,
                  overlayOpacity: _overlayOpacity,
                  zoom: _zoom,
                  settings: widget.settings,
                  landscapeLocked: _landscapeLocked,
                  onModeChanged: (mode) => setState(() => _mode = mode),
                  onOpacityChanged: (value) => _overlayOpacity.value = value,
                  onZoomChanged: (value) => _setZoom(cameraState, value),
                  onPickReference: _pickReferenceImage,
                  onPickGallery: _pickGalleryImage,
                  onToggleOrientation: _toggleOrientation,
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

double _defaultLandscapeAspectRatio(CameraPhotoAspectRatio ratio) {
  return switch (ratio) {
    CameraPhotoAspectRatio.landscape16x9 => 16 / 9,
    CameraPhotoAspectRatio.standard4x3 => 4 / 3,
    CameraPhotoAspectRatio.square1x1 => 1,
  };
}

double _captureAspectRatio({
  required double? referenceAspectRatio,
  required AppSettings settings,
  required bool landscapeLocked,
}) {
  final baseRatio =
      referenceAspectRatio ??
      _defaultLandscapeAspectRatio(settings.cameraAspectRatio);
  if (baseRatio <= 0) {
    return 1;
  }
  if (landscapeLocked || baseRatio <= 1) {
    return baseRatio;
  }
  return 1 / baseRatio;
}

Future<double?> _resolveReferenceAspectRatio({
  required Uint8List? bytes,
  required String? localPath,
  required String? url,
}) async {
  final localBytes =
      bytes ??
      (localPath == null
          ? null
          : await reference_image_bytes.readReferenceImageBytes(localPath));
  if (localBytes != null) {
    return _decodeImageAspectRatio(localBytes);
  }

  if (url == null || url.isEmpty) {
    return null;
  }

  try {
    final provider = NetworkImage(url);
    final completer = Completer<ImageInfo>();
    final stream = provider.resolve(ImageConfiguration.empty);
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (image, synchronousCall) {
        if (!completer.isCompleted) {
          completer.complete(image);
        }
        stream.removeListener(listener);
      },
      onError: (error, stackTrace) {
        if (!completer.isCompleted) {
          completer.completeError(error, stackTrace);
        }
        stream.removeListener(listener);
      },
    );
    stream.addListener(listener);
    final imageInfo = await completer.future.timeout(
      const Duration(seconds: 5),
    );
    final width = imageInfo.image.width;
    final height = imageInfo.image.height;
    if (width <= 0 || height <= 0) {
      return null;
    }
    return width / height;
  } catch (_) {
    return null;
  }
}

Future<double?> _decodeImageAspectRatio(Uint8List bytes) async {
  try {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    if (image.width <= 0 || image.height <= 0) {
      return null;
    }
    return image.width / image.height;
  } catch (_) {
    return null;
  }
}

class _NativeCameraController extends ChangeNotifier {
  MethodChannel? _channel;
  int? _viewId;
  var _ready = false;
  var _busy = false;
  String? _error;
  var _minZoomRatio = 1.0;
  var _maxZoomRatio = 1.0;
  var _zoomRatio = 1.0;
  var _flashMode = 'auto';
  var _lensFacing = 'back';
  var _captureAspectRatio = 1.0;

  bool get ready => _ready;
  bool get busy => _busy;
  String? get error => _error;
  double get minZoomRatio => _minZoomRatio;
  double get maxZoomRatio => _maxZoomRatio;
  double get zoomRatio => _zoomRatio;
  String get flashMode => _flashMode;
  String get lensFacing => _lensFacing;

  Future<void> attach(int viewId) async {
    if (_channel != null && _viewId == viewId) {
      return;
    }

    if (_channel != null) {
      await _channel!.invokeMethod<void>('dispose');
      _channel = null;
      _ready = false;
    }

    final permission = await Permission.camera.request();
    if (!permission.isGranted) {
      _error = '需要相机权限';
      notifyListeners();
      return;
    }

    _viewId = viewId;
    _channel = MethodChannel('seichi/native_camera_preview_$viewId');
    try {
      final result = await _channel!.invokeMapMethod<String, Object?>(
        'initialize',
        {'targetAspectRatio': _captureAspectRatio},
      );
      _applyZoomState(result);
      _ready = true;
      _error = null;
    } catch (error) {
      _error = '原生相机初始化失败';
    }
    notifyListeners();
  }

  Future<void> setZoomRatio(double ratio) async {
    final channel = _channel;
    if (channel == null || !_ready) {
      return;
    }

    _zoomRatio = ratio.clamp(_minZoomRatio, _maxZoomRatio);
    notifyListeners();
    final result = await channel.invokeMapMethod<String, Object?>(
      'setZoomRatio',
      {'zoomRatio': _zoomRatio},
    );
    _applyZoomState(result);
    notifyListeners();
  }

  Future<void> setCaptureAspectRatio(double ratio) async {
    final safeRatio = ratio <= 0 ? 1.0 : ratio;
    if ((_captureAspectRatio - safeRatio).abs() < 0.001) {
      return;
    }

    _captureAspectRatio = safeRatio;
    final channel = _channel;
    if (channel == null || !_ready) {
      return;
    }
    await channel.invokeMethod<void>('setTargetAspectRatio', {
      'targetAspectRatio': _captureAspectRatio,
    });
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

    _flashMode = mode;
    notifyListeners();
    await channel.invokeMethod<void>('setFlashMode', {'flashMode': mode});
  }

  Future<void> switchCamera() async {
    final channel = _channel;
    if (channel == null || !_ready) {
      return;
    }

    final result = await channel.invokeMapMethod<String, Object?>(
      'switchCamera',
    );
    _applyZoomState(result);
    notifyListeners();
  }

  Future<String?> takePicture() async {
    final channel = _channel;
    if (channel == null || !_ready || _busy) {
      return null;
    }

    _busy = true;
    notifyListeners();
    try {
      return await channel.invokeMethod<String>('takePicture');
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _channel?.invokeMethod<void>('dispose');
    super.dispose();
  }

  void _applyZoomState(Map<String, Object?>? state) {
    if (state == null) {
      return;
    }

    _minZoomRatio = (state['minZoomRatio'] as num?)?.toDouble() ?? 1;
    _maxZoomRatio = (state['maxZoomRatio'] as num?)?.toDouble() ?? 1;
    _zoomRatio = (state['zoomRatio'] as num?)?.toDouble() ?? 1;
    _lensFacing = state['lensFacing'] as String? ?? _lensFacing;
  }
}

class _NativeReferenceCameraBody extends StatelessWidget {
  const _NativeReferenceCameraBody({
    required this.point,
    required this.controller,
    required this.reference,
    required this.galleryImage,
    required this.mode,
    required this.overlayOpacity,
    required this.settings,
    required this.captureAspectRatio,
    required this.landscapeLocked,
    required this.onNativeUnavailable,
    required this.onModeChanged,
    required this.onOpacityChanged,
    required this.onCapture,
    required this.onPickReference,
    required this.onPickGallery,
    required this.onToggleOrientation,
  });

  final PilgrimagePoint point;
  final _NativeCameraController controller;
  final _ReferenceImageSource reference;
  final XFile? galleryImage;
  final AwesomeReferenceMode mode;
  final ValueListenable<double> overlayOpacity;
  final AppSettings settings;
  final double captureAspectRatio;
  final bool landscapeLocked;
  final VoidCallback onNativeUnavailable;
  final ValueChanged<AwesomeReferenceMode> onModeChanged;
  final ValueChanged<double> onOpacityChanged;
  final Future<void> Function() onCapture;
  final VoidCallback onPickReference;
  final VoidCallback onPickGallery;
  final VoidCallback onToggleOrientation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        unawaited(controller.setCaptureAspectRatio(captureAspectRatio));
        if (controller.error != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            onNativeUnavailable();
          });
        }

        if (landscapeLocked) {
          return Stack(
            fit: StackFit.expand,
            children: [
              _NativeCameraPreview(controller: controller),
              ValueListenableBuilder<double>(
                valueListenable: overlayOpacity,
                builder: (context, opacity, child) {
                  return _ReferenceModeLayer(
                    mode: mode,
                    reference: reference,
                    overlayOpacity: opacity,
                    isLandscape: true,
                    targetAspectRatio: captureAspectRatio,
                  );
                },
              ),
              SafeArea(
                child: _NativeLandscapeCameraLayout(
                  controller: controller,
                  mode: mode,
                  overlayOpacity: overlayOpacity,
                  settings: settings,
                  galleryImage: galleryImage,
                  onModeChanged: onModeChanged,
                  onOpacityChanged: onOpacityChanged,
                  onCapture: onCapture,
                  onPickReference: onPickReference,
                  onPickGallery: onPickGallery,
                  onToggleOrientation: onToggleOrientation,
                ),
              ),
            ],
          );
        }

        return SafeArea(
          child: Column(
            children: [
              _NativeCameraTopBar(
                controller: controller,
                isLandscapeUi: false,
                onPickReference: onPickReference,
                onToggleOrientation: onToggleOrientation,
              ),
              Expanded(
                child: Center(
                  child: _NativePreviewFrame(
                    controller: controller,
                    reference: reference,
                    mode: mode,
                    overlayOpacity: overlayOpacity,
                    captureAspectRatio: captureAspectRatio,
                  ),
                ),
              ),
              _NativeCameraBottomPanel(
                controller: controller,
                mode: mode,
                overlayOpacity: overlayOpacity,
                settings: settings,
                galleryImage: galleryImage,
                onModeChanged: onModeChanged,
                onOpacityChanged: onOpacityChanged,
                onCapture: onCapture,
                onPickGallery: onPickGallery,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _NativePreviewFrame extends StatelessWidget {
  const _NativePreviewFrame({
    required this.controller,
    required this.reference,
    required this.mode,
    required this.overlayOpacity,
    required this.captureAspectRatio,
  });

  final _NativeCameraController controller;
  final _ReferenceImageSource reference;
  final AwesomeReferenceMode mode;
  final ValueListenable<double> overlayOpacity;
  final double captureAspectRatio;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: AspectRatio(
        aspectRatio: captureAspectRatio,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white12),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _NativeCameraPreview(controller: controller),
              ValueListenableBuilder<double>(
                valueListenable: overlayOpacity,
                builder: (context, opacity, child) {
                  return _ReferenceModeLayer(
                    mode: mode,
                    reference: reference,
                    overlayOpacity: opacity,
                    isLandscape: false,
                    constrainToBounds: true,
                    targetAspectRatio: captureAspectRatio,
                  );
                },
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NativeCameraPreview extends StatelessWidget {
  const _NativeCameraPreview({required this.controller});

  final _NativeCameraController controller;

  @override
  Widget build(BuildContext context) {
    return AndroidView(
      viewType: 'seichi/native_camera_preview',
      onPlatformViewCreated: controller.attach,
    );
  }
}

class _NativeCameraTopBar extends StatelessWidget {
  const _NativeCameraTopBar({
    required this.controller,
    required this.isLandscapeUi,
    required this.onPickReference,
    required this.onToggleOrientation,
  });

  final _NativeCameraController controller;
  final bool isLandscapeUi;
  final VoidCallback onPickReference;
  final VoidCallback onToggleOrientation;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
      child: Row(
        children: [
          _CameraCircleButton(
            tooltip: isLandscapeUi ? null : '返回',
            icon: Icons.arrow_back,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          const Spacer(),
          _CameraCircleButton(
            tooltip: isLandscapeUi ? null : '参考图',
            icon: Icons.image_outlined,
            onPressed: onPickReference,
          ),
          const SizedBox(width: 8),
          _CameraCircleButton(
            tooltip: isLandscapeUi ? null : '切换横屏 UI',
            icon: Icons.screen_rotation_alt_outlined,
            onPressed: onToggleOrientation,
          ),
          const SizedBox(width: 8),
          _NativeFlashButton(
            controller: controller,
            showTooltip: !isLandscapeUi,
          ),
          const SizedBox(width: 8),
          _CameraCircleButton(
            tooltip: isLandscapeUi ? null : '切换摄像头',
            icon: Icons.cameraswitch_outlined,
            onPressed: controller.switchCamera,
          ),
        ],
      ),
    );
  }
}

class _NativeCameraBottomPanel extends StatelessWidget {
  const _NativeCameraBottomPanel({
    required this.controller,
    required this.mode,
    required this.overlayOpacity,
    required this.settings,
    required this.galleryImage,
    required this.onModeChanged,
    required this.onOpacityChanged,
    required this.onCapture,
    required this.onPickGallery,
  });

  final _NativeCameraController controller;
  final AwesomeReferenceMode mode;
  final ValueListenable<double> overlayOpacity;
  final AppSettings settings;
  final XFile? galleryImage;
  final ValueChanged<AwesomeReferenceMode> onModeChanged;
  final ValueChanged<double> onOpacityChanged;
  final Future<void> Function() onCapture;
  final VoidCallback onPickGallery;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(0, 0, 0, 6),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.58),
        border: const Border(top: BorderSide(color: Colors.white12)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ModeSelector(mode: mode, onChanged: onModeChanged),
          const SizedBox(height: 6),
          _NativeZoomAndOpacityControls(
            controller: controller,
            settings: settings,
            overlayOpacity: overlayOpacity,
            onOpacityChanged: onOpacityChanged,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _CameraActionButton(
                tooltip: '相册导入',
                icon: galleryImage == null
                    ? Icons.photo_library_outlined
                    : Icons.photo_library,
                onPressed: onPickGallery,
              ),
              const Spacer(),
              _NativeCaptureButton(busy: controller.busy, onPressed: onCapture),
              const Spacer(),
              if (galleryImage == null)
                const SizedBox(width: 50)
              else
                _CameraActionButton(
                  tooltip: '检查照片',
                  icon: Icons.fact_check_outlined,
                  onPressed: () {},
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NativeLandscapeCameraLayout extends StatelessWidget {
  const _NativeLandscapeCameraLayout({
    required this.controller,
    required this.mode,
    required this.overlayOpacity,
    required this.settings,
    required this.galleryImage,
    required this.onModeChanged,
    required this.onOpacityChanged,
    required this.onCapture,
    required this.onPickReference,
    required this.onPickGallery,
    required this.onToggleOrientation,
  });

  final _NativeCameraController controller;
  final AwesomeReferenceMode mode;
  final ValueListenable<double> overlayOpacity;
  final AppSettings settings;
  final XFile? galleryImage;
  final ValueChanged<AwesomeReferenceMode> onModeChanged;
  final ValueChanged<double> onOpacityChanged;
  final Future<void> Function() onCapture;
  final VoidCallback onPickReference;
  final VoidCallback onPickGallery;
  final VoidCallback onToggleOrientation;

  @override
  Widget build(BuildContext context) {
    return _LandscapeCanvas(
      child: Stack(
        children: [
          _NativeCameraTopBar(
            controller: controller,
            isLandscapeUi: true,
            onPickReference: onPickReference,
            onToggleOrientation: onToggleOrientation,
          ),
          Positioned(
            left: 14,
            right: 14,
            bottom: 14,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: _NativeLandscapeControlPanel(
                    controller: controller,
                    mode: mode,
                    overlayOpacity: overlayOpacity,
                    settings: settings,
                    onModeChanged: onModeChanged,
                    onOpacityChanged: onOpacityChanged,
                  ),
                ),
                const SizedBox(width: 14),
                _NativeLandscapeCaptureRail(
                  controller: controller,
                  galleryImage: galleryImage,
                  onPickGallery: onPickGallery,
                  onCapture: onCapture,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NativeLandscapeControlPanel extends StatelessWidget {
  const _NativeLandscapeControlPanel({
    required this.controller,
    required this.mode,
    required this.overlayOpacity,
    required this.settings,
    required this.onModeChanged,
    required this.onOpacityChanged,
  });

  final _NativeCameraController controller;
  final AwesomeReferenceMode mode;
  final ValueListenable<double> overlayOpacity;
  final AppSettings settings;
  final ValueChanged<AwesomeReferenceMode> onModeChanged;
  final ValueChanged<double> onOpacityChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        child: Row(
          children: [
            _ModeSelector(mode: mode, onChanged: onModeChanged),
            const SizedBox(width: 14),
            Expanded(
              child: _NativeZoomAndOpacityControls(
                controller: controller,
                settings: settings,
                overlayOpacity: overlayOpacity,
                onOpacityChanged: onOpacityChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NativeLandscapeCaptureRail extends StatelessWidget {
  const _NativeLandscapeCaptureRail({
    required this.controller,
    required this.galleryImage,
    required this.onPickGallery,
    required this.onCapture,
  });

  final _NativeCameraController controller;
  final XFile? galleryImage;
  final VoidCallback onPickGallery;
  final Future<void> Function() onCapture;

  @override
  Widget build(BuildContext context) {
    final hasGalleryImage = galleryImage != null;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _CameraActionButton(
              tooltip: null,
              icon: hasGalleryImage
                  ? Icons.photo_library
                  : Icons.photo_library_outlined,
              onPressed: onPickGallery,
            ),
            const SizedBox(width: 18),
            _NativeCaptureButton(
              busy: controller.busy,
              compact: true,
              onPressed: onCapture,
            ),
            if (hasGalleryImage) ...[
              const SizedBox(width: 18),
              _CameraActionButton(
                tooltip: null,
                icon: Icons.fact_check_outlined,
                onPressed: () {},
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NativeFlashButton extends StatelessWidget {
  const _NativeFlashButton({
    required this.controller,
    required this.showTooltip,
  });

  final _NativeCameraController controller;
  final bool showTooltip;

  @override
  Widget build(BuildContext context) {
    final icon = switch (controller.flashMode) {
      'off' => Icons.flash_off,
      'on' => Icons.flash_on,
      'torch' => Icons.flashlight_on,
      _ => Icons.flash_auto,
    };

    return _CameraCircleButton(
      tooltip: showTooltip ? '闪光灯' : null,
      icon: icon,
      onPressed: controller.cycleFlashMode,
    );
  }
}

class _NativeZoomAndOpacityControls extends StatelessWidget {
  const _NativeZoomAndOpacityControls({
    required this.controller,
    required this.settings,
    required this.overlayOpacity,
    required this.onOpacityChanged,
  });

  final _NativeCameraController controller;
  final AppSettings settings;
  final ValueListenable<double> overlayOpacity;
  final ValueChanged<double> onOpacityChanged;

  @override
  Widget build(BuildContext context) {
    final minZoom = math.max(controller.minZoomRatio, settings.cameraMinZoom);
    final maxZoom = math.min(controller.maxZoomRatio, settings.cameraMaxZoom);
    final effectiveMin = maxZoom <= minZoom ? controller.minZoomRatio : minZoom;
    final effectiveMax = maxZoom <= minZoom ? controller.maxZoomRatio : maxZoom;
    final sliderValue = _sliderValueFromRealZoom(
      minZoom: effectiveMin,
      maxZoom: effectiveMax,
      realZoom: controller.zoomRatio,
    );

    return Column(
      children: [
        _SliderRow(
          icon: Icons.zoom_in_outlined,
          value: sliderValue,
          label: _formatRealZoom(controller.zoomRatio),
          onChanged: (value) {
            controller.setZoomRatio(
              _realZoomFromSliderValue(
                minZoom: effectiveMin,
                maxZoom: effectiveMax,
                sliderValue: value,
              ),
            );
          },
        ),
        ValueListenableBuilder<double>(
          valueListenable: overlayOpacity,
          builder: (context, opacity, child) {
            return _SliderRow(
              icon: Icons.opacity,
              value: opacity,
              label: '${(opacity * 100).round()}%',
              onChanged: onOpacityChanged,
            );
          },
        ),
      ],
    );
  }
}

class _NativeCaptureButton extends StatelessWidget {
  const _NativeCaptureButton({
    required this.busy,
    required this.onPressed,
    this.compact = false,
  });

  final bool busy;
  final bool compact;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.32),
      shape: const CircleBorder(),
      elevation: 0,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: busy ? null : onPressed,
        child: Container(
          width: compact ? 62 : 72,
          height: compact ? 62 : 72,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: compact ? 3 : 4),
          ),
          child: busy
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Container(
                  width: compact ? 44 : 52,
                  height: compact ? 44 : 52,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
        ),
      ),
    );
  }
}

double _realZoomFromSliderValue({
  required double minZoom,
  required double maxZoom,
  required double sliderValue,
}) {
  final safeMin = math.max(minZoom, 0.01);
  final safeMax = math.max(maxZoom, safeMin);
  if (safeMax <= safeMin) {
    return safeMin;
  }
  return safeMin * math.pow(safeMax / safeMin, sliderValue).toDouble();
}

double _sliderValueFromRealZoom({
  required double minZoom,
  required double maxZoom,
  required double realZoom,
}) {
  final safeMin = math.max(minZoom, 0.01);
  final safeMax = math.max(maxZoom, safeMin);
  if (safeMax <= safeMin) {
    return 0;
  }
  return (math.log(realZoom.clamp(safeMin, safeMax) / safeMin) /
          math.log(safeMax / safeMin))
      .clamp(0.0, 1.0);
}

class _ReferenceCameraOverlay extends StatelessWidget {
  const _ReferenceCameraOverlay({
    required this.point,
    required this.state,
    required this.reference,
    required this.galleryImage,
    required this.mode,
    required this.overlayOpacity,
    required this.zoom,
    required this.settings,
    required this.landscapeLocked,
    required this.onModeChanged,
    required this.onOpacityChanged,
    required this.onZoomChanged,
    required this.onPickReference,
    required this.onPickGallery,
    required this.onToggleOrientation,
  });

  final PilgrimagePoint point;
  final CameraState state;
  final _ReferenceImageSource reference;
  final XFile? galleryImage;
  final AwesomeReferenceMode mode;
  final ValueListenable<double> overlayOpacity;
  final ValueListenable<double> zoom;
  final AppSettings settings;
  final bool landscapeLocked;
  final ValueChanged<AwesomeReferenceMode> onModeChanged;
  final ValueChanged<double> onOpacityChanged;
  final ValueChanged<double> onZoomChanged;
  final VoidCallback onPickReference;
  final VoidCallback onPickGallery;
  final VoidCallback onToggleOrientation;

  @override
  Widget build(BuildContext context) {
    final usesLandscapeUi =
        landscapeLocked ||
        MediaQuery.orientationOf(context) == Orientation.landscape;

    return Stack(
      fit: StackFit.expand,
      children: [
        ValueListenableBuilder<double>(
          valueListenable: overlayOpacity,
          builder: (context, opacity, child) {
            return _ReferenceModeLayer(
              mode: mode,
              reference: reference,
              overlayOpacity: opacity,
              isLandscape: usesLandscapeUi,
            );
          },
        ),
        SafeArea(
          child: usesLandscapeUi
              ? _LandscapeCameraLayout(
                  state: state,
                  mode: mode,
                  overlayOpacity: overlayOpacity,
                  zoom: zoom,
                  settings: settings,
                  galleryImage: galleryImage,
                  onModeChanged: onModeChanged,
                  onOpacityChanged: onOpacityChanged,
                  onZoomChanged: onZoomChanged,
                  onPickReference: onPickReference,
                  onPickGallery: onPickGallery,
                  onToggleOrientation: onToggleOrientation,
                )
              : Column(
                  children: [
                    _CameraTopBar(
                      state: state,
                      isLandscapeUi: false,
                      onPickReference: onPickReference,
                      onToggleOrientation: onToggleOrientation,
                    ),
                    const Spacer(),
                    _CameraBottomPanel(
                      state: state,
                      mode: mode,
                      overlayOpacity: overlayOpacity,
                      zoom: zoom,
                      settings: settings,
                      isLandscape: false,
                      galleryImage: galleryImage,
                      onModeChanged: onModeChanged,
                      onOpacityChanged: onOpacityChanged,
                      onZoomChanged: onZoomChanged,
                      onPickGallery: onPickGallery,
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _ReferenceModeLayer extends StatelessWidget {
  const _ReferenceModeLayer({
    required this.mode,
    required this.reference,
    required this.overlayOpacity,
    required this.isLandscape,
    this.constrainToBounds = false,
    this.targetAspectRatio,
  });

  final AwesomeReferenceMode mode;
  final _ReferenceImageSource reference;
  final double overlayOpacity;
  final bool isLandscape;
  final bool constrainToBounds;
  final double? targetAspectRatio;

  @override
  Widget build(BuildContext context) {
    if (!reference.hasImage) {
      return const SizedBox.shrink();
    }

    if (isLandscape) {
      return _LandscapeReferenceModeLayer(
        mode: mode,
        reference: reference,
        overlayOpacity: overlayOpacity,
        targetAspectRatio: targetAspectRatio,
      );
    }

    return switch (mode) {
      AwesomeReferenceMode.overlay => IgnorePointer(
        child: Opacity(
          opacity: overlayOpacity,
          child: _ReferenceAspectBox(
            aspectRatio: targetAspectRatio,
            child: _ReferenceImageView(source: reference, fit: BoxFit.contain),
          ),
        ),
      ),
      AwesomeReferenceMode.split =>
        constrainToBounds
            ? Align(
                alignment: Alignment.topCenter,
                child: FractionallySizedBox(
                  heightFactor: 0.48,
                  widthFactor: 1,
                  child: _ReferenceFrame(
                    margin: const EdgeInsets.all(8),
                    child: _ReferenceAspectBox(
                      aspectRatio: targetAspectRatio,
                      child: _ReferenceImageView(
                        source: reference,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              )
            : Align(
                alignment: Alignment.topCenter,
                child: SafeArea(
                  bottom: false,
                  child: _ReferenceFrame(
                    height: MediaQuery.sizeOf(context).height * 0.34,
                    margin: const EdgeInsets.fromLTRB(12, 72, 12, 0),
                    child: _ReferenceAspectBox(
                      aspectRatio: targetAspectRatio,
                      child: _ReferenceImageView(
                        source: reference,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),
      AwesomeReferenceMode.pinned =>
        constrainToBounds
            ? Align(
                alignment: Alignment.topLeft,
                child: FractionallySizedBox(
                  widthFactor: 0.38,
                  heightFactor: 0.38,
                  child: _ReferenceFrame(
                    margin: const EdgeInsets.all(8),
                    child: _ReferenceAspectBox(
                      aspectRatio: targetAspectRatio,
                      child: _ReferenceImageView(
                        source: reference,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              )
            : Align(
                alignment: Alignment.topLeft,
                child: SafeArea(
                  child: _ReferenceFrame(
                    width: 116,
                    height: 154,
                    margin: const EdgeInsets.fromLTRB(14, 82, 0, 0),
                    child: _ReferenceAspectBox(
                      aspectRatio: targetAspectRatio,
                      child: _ReferenceImageView(
                        source: reference,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),
    };
  }
}

class _ReferenceAspectBox extends StatelessWidget {
  const _ReferenceAspectBox({required this.child, this.aspectRatio});

  final Widget child;
  final double? aspectRatio;

  @override
  Widget build(BuildContext context) {
    final ratio = aspectRatio;
    if (ratio == null) {
      return child;
    }

    return Center(
      child: AspectRatio(aspectRatio: ratio, child: child),
    );
  }
}

class _ReferenceFrame extends StatelessWidget {
  const _ReferenceFrame({
    required this.child,
    this.width,
    this.height,
    this.margin = EdgeInsets.zero,
  });

  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

class _LandscapeReferenceModeLayer extends StatelessWidget {
  const _LandscapeReferenceModeLayer({
    required this.mode,
    required this.reference,
    required this.overlayOpacity,
    this.targetAspectRatio,
  });

  final AwesomeReferenceMode mode;
  final _ReferenceImageSource reference;
  final double overlayOpacity;
  final double? targetAspectRatio;

  @override
  Widget build(BuildContext context) {
    return _LandscapeCanvas(
      child: Stack(
        fit: StackFit.expand,
        children: [
          switch (mode) {
            AwesomeReferenceMode.overlay => IgnorePointer(
              child: Opacity(
                opacity: overlayOpacity,
                child: _ReferenceAspectBox(
                  aspectRatio: targetAspectRatio,
                  child: _ReferenceImageView(
                    source: reference,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            AwesomeReferenceMode.split => Positioned(
              left: 16,
              right: 180,
              top: 66,
              height: 132,
              child: _LandscapeReferenceFrame(
                child: _ReferenceAspectBox(
                  aspectRatio: targetAspectRatio,
                  child: _ReferenceImageView(
                    source: reference,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            AwesomeReferenceMode.pinned => Positioned(
              left: 16,
              top: 72,
              width: 220,
              height: 124,
              child: _LandscapeReferenceFrame(
                child: _ReferenceAspectBox(
                  aspectRatio: targetAspectRatio,
                  child: _ReferenceImageView(
                    source: reference,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          },
        ],
      ),
    );
  }
}

class _LandscapeCanvas extends StatelessWidget {
  const _LandscapeCanvas({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Center(
          child: RotatedBox(
            quarterTurns: 1,
            child: SizedBox(
              width: constraints.maxHeight,
              height: constraints.maxWidth,
              child: child,
            ),
          ),
        );
      },
    );
  }
}

class _LandscapeReferenceFrame extends StatelessWidget {
  const _LandscapeReferenceFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

class _CameraTopBar extends StatelessWidget {
  const _CameraTopBar({
    required this.state,
    required this.isLandscapeUi,
    required this.onPickReference,
    required this.onToggleOrientation,
  });

  final CameraState state;
  final bool isLandscapeUi;
  final VoidCallback onPickReference;
  final VoidCallback onToggleOrientation;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
      child: Row(
        children: [
          _CameraCircleButton(
            tooltip: isLandscapeUi ? null : '返回',
            icon: Icons.arrow_back,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          const Spacer(),
          _CameraCircleButton(
            tooltip: isLandscapeUi ? null : '参考图',
            icon: Icons.image_outlined,
            onPressed: onPickReference,
          ),
          const SizedBox(width: 8),
          _CameraCircleButton(
            tooltip: isLandscapeUi ? null : '切换横屏 UI',
            icon: Icons.screen_rotation_alt_outlined,
            onPressed: onToggleOrientation,
          ),
          const SizedBox(width: 8),
          _CompactFlashButton(state: state, showTooltip: !isLandscapeUi),
          const SizedBox(width: 8),
          _CompactCameraSwitchButton(state: state, showTooltip: !isLandscapeUi),
        ],
      ),
    );
  }
}

class _LandscapeCameraLayout extends StatelessWidget {
  const _LandscapeCameraLayout({
    required this.state,
    required this.mode,
    required this.overlayOpacity,
    required this.zoom,
    required this.settings,
    required this.galleryImage,
    required this.onModeChanged,
    required this.onOpacityChanged,
    required this.onZoomChanged,
    required this.onPickReference,
    required this.onPickGallery,
    required this.onToggleOrientation,
  });

  final CameraState state;
  final AwesomeReferenceMode mode;
  final ValueListenable<double> overlayOpacity;
  final ValueListenable<double> zoom;
  final AppSettings settings;
  final XFile? galleryImage;
  final ValueChanged<AwesomeReferenceMode> onModeChanged;
  final ValueChanged<double> onOpacityChanged;
  final ValueChanged<double> onZoomChanged;
  final VoidCallback onPickReference;
  final VoidCallback onPickGallery;
  final VoidCallback onToggleOrientation;

  @override
  Widget build(BuildContext context) {
    return _LandscapeCanvas(
      child: Stack(
        children: [
          _CameraTopBar(
            state: state,
            isLandscapeUi: true,
            onPickReference: onPickReference,
            onToggleOrientation: onToggleOrientation,
          ),
          Positioned(
            left: 14,
            right: 14,
            bottom: 14,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: _LandscapeControlPanel(
                    state: state,
                    mode: mode,
                    overlayOpacity: overlayOpacity,
                    zoom: zoom,
                    settings: settings,
                    onModeChanged: onModeChanged,
                    onOpacityChanged: onOpacityChanged,
                    onZoomChanged: onZoomChanged,
                  ),
                ),
                const SizedBox(width: 14),
                _LandscapeCaptureRail(
                  state: state,
                  galleryImage: galleryImage,
                  onPickGallery: onPickGallery,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LandscapeControlPanel extends StatelessWidget {
  const _LandscapeControlPanel({
    required this.state,
    required this.mode,
    required this.overlayOpacity,
    required this.zoom,
    required this.settings,
    required this.onModeChanged,
    required this.onOpacityChanged,
    required this.onZoomChanged,
  });

  final CameraState state;
  final AwesomeReferenceMode mode;
  final ValueListenable<double> overlayOpacity;
  final ValueListenable<double> zoom;
  final AppSettings settings;
  final ValueChanged<AwesomeReferenceMode> onModeChanged;
  final ValueChanged<double> onOpacityChanged;
  final ValueChanged<double> onZoomChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        child: Row(
          children: [
            _ModeSelector(mode: mode, onChanged: onModeChanged),
            const SizedBox(width: 14),
            Expanded(
              child: _ZoomAndOpacityControls(
                state: state,
                zoom: zoom,
                settings: settings,
                overlayOpacity: overlayOpacity,
                onZoomChanged: onZoomChanged,
                onOpacityChanged: onOpacityChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LandscapeCaptureRail extends StatelessWidget {
  const _LandscapeCaptureRail({
    required this.state,
    required this.galleryImage,
    required this.onPickGallery,
  });

  final CameraState state;
  final XFile? galleryImage;
  final VoidCallback onPickGallery;

  @override
  Widget build(BuildContext context) {
    final hasGalleryImage = galleryImage != null;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _CameraActionButton(
              tooltip: null,
              icon: hasGalleryImage
                  ? Icons.photo_library
                  : Icons.photo_library_outlined,
              onPressed: onPickGallery,
            ),
            const SizedBox(width: 18),
            _ReferenceCaptureButton(state: state, compact: true),
            if (hasGalleryImage) ...[
              const SizedBox(width: 18),
              _CameraActionButton(
                tooltip: null,
                icon: Icons.fact_check_outlined,
                onPressed: () {},
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CameraCircleButton extends StatelessWidget {
  const _CameraCircleButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String? tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton.filled(
      tooltip: tooltip,
      style: IconButton.styleFrom(
        backgroundColor: Colors.black.withValues(alpha: 0.38),
        foregroundColor: Colors.white,
        minimumSize: const Size(44, 44),
        shape: const CircleBorder(),
      ),
      onPressed: onPressed,
      icon: Icon(icon, size: 21),
    );
  }
}

class _CompactFlashButton extends StatelessWidget {
  const _CompactFlashButton({required this.state, required this.showTooltip});

  final CameraState state;
  final bool showTooltip;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<SensorConfig>(
      stream: state.sensorConfig$,
      initialData: state.sensorConfig,
      builder: (context, snapshot) {
        final sensorConfig = snapshot.data ?? state.sensorConfig;
        return StreamBuilder<FlashMode>(
          stream: sensorConfig.flashMode$,
          initialData: sensorConfig.flashMode,
          builder: (context, flashSnapshot) {
            final flashMode = flashSnapshot.data ?? sensorConfig.flashMode;
            final icon = switch (flashMode) {
              FlashMode.none => Icons.flash_off,
              FlashMode.on => Icons.flash_on,
              FlashMode.auto => Icons.flash_auto,
              FlashMode.always => Icons.flashlight_on,
            };

            return _CameraCircleButton(
              tooltip: showTooltip ? '闪光灯' : null,
              icon: icon,
              onPressed: sensorConfig.switchCameraFlash,
            );
          },
        );
      },
    );
  }
}

class _CompactCameraSwitchButton extends StatelessWidget {
  const _CompactCameraSwitchButton({
    required this.state,
    required this.showTooltip,
  });

  final CameraState state;
  final bool showTooltip;

  @override
  Widget build(BuildContext context) {
    return _CameraCircleButton(
      tooltip: showTooltip ? '切换摄像头' : null,
      icon: Icons.cameraswitch_outlined,
      onPressed: () => state.switchCameraSensor(
        zoom: state.sensorConfig.zoom,
        flash: state.sensorConfig.flashMode,
      ),
    );
  }
}

class _CameraBottomPanel extends StatelessWidget {
  const _CameraBottomPanel({
    required this.state,
    required this.mode,
    required this.overlayOpacity,
    required this.zoom,
    required this.settings,
    required this.isLandscape,
    required this.galleryImage,
    required this.onModeChanged,
    required this.onOpacityChanged,
    required this.onZoomChanged,
    required this.onPickGallery,
  });

  final CameraState state;
  final AwesomeReferenceMode mode;
  final ValueListenable<double> overlayOpacity;
  final ValueListenable<double> zoom;
  final AppSettings settings;
  final bool isLandscape;
  final XFile? galleryImage;
  final ValueChanged<AwesomeReferenceMode> onModeChanged;
  final ValueChanged<double> onOpacityChanged;
  final ValueChanged<double> onZoomChanged;
  final VoidCallback onPickGallery;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.fromLTRB(0, 0, 0, isLandscape ? 0 : 6),
      padding: EdgeInsets.fromLTRB(20, 14, 20, isLandscape ? 14 : 18),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.58),
        border: const Border(top: BorderSide(color: Colors.white12)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ModeSelector(mode: mode, onChanged: onModeChanged),
          const SizedBox(height: 6),
          _ZoomAndOpacityControls(
            state: state,
            zoom: zoom,
            settings: settings,
            overlayOpacity: overlayOpacity,
            onZoomChanged: onZoomChanged,
            onOpacityChanged: onOpacityChanged,
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _CameraActionButton(
                tooltip: '相册导入',
                icon: galleryImage == null
                    ? Icons.photo_library_outlined
                    : Icons.photo_library,
                onPressed: onPickGallery,
              ),
              const Spacer(),
              _ReferenceCaptureButton(state: state),
              const Spacer(),
              _CameraActionButton(
                tooltip: '检查照片',
                icon: Icons.fact_check_outlined,
                onPressed: galleryImage == null ? null : () {},
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ModeSelector extends StatelessWidget {
  const _ModeSelector({required this.mode, required this.onChanged});

  final AwesomeReferenceMode mode;
  final ValueChanged<AwesomeReferenceMode> onChanged;

  @override
  Widget build(BuildContext context) {
    const modes = [
      (AwesomeReferenceMode.overlay, Icons.layers_outlined, '叠影'),
      (AwesomeReferenceMode.split, Icons.splitscreen_outlined, '上下'),
      (
        AwesomeReferenceMode.pinned,
        Icons.picture_in_picture_alt_outlined,
        '小窗',
      ),
    ];

    return Container(
      height: 34,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final entry in modes)
            _ModeChip(
              selected: mode == entry.$1,
              icon: entry.$2,
              label: entry.$3,
              onTap: () => onChanged(entry.$1),
            ),
        ],
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      customBorder: const StadiumBorder(),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: selected ? AppColors.textPrimary : Colors.white70,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: selected ? AppColors.textPrimary : Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ZoomAndOpacityControls extends StatelessWidget {
  const _ZoomAndOpacityControls({
    required this.state,
    required this.zoom,
    required this.settings,
    required this.overlayOpacity,
    required this.onZoomChanged,
    required this.onOpacityChanged,
  });

  final CameraState state;
  final ValueListenable<double> zoom;
  final AppSettings settings;
  final ValueListenable<double> overlayOpacity;
  final ValueChanged<double> onZoomChanged;
  final ValueChanged<double> onOpacityChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _CameraZoomSlider(
          state: state,
          zoom: zoom,
          settings: settings,
          onChanged: onZoomChanged,
        ),
        ValueListenableBuilder<double>(
          valueListenable: overlayOpacity,
          builder: (context, opacity, child) {
            return _SliderRow(
              icon: Icons.opacity,
              value: opacity,
              label: '${(opacity * 100).round()}%',
              onChanged: onOpacityChanged,
            );
          },
        ),
      ],
    );
  }
}

class _CameraZoomSlider extends StatefulWidget {
  const _CameraZoomSlider({
    required this.state,
    required this.zoom,
    required this.settings,
    required this.onChanged,
  });

  final CameraState state;
  final ValueListenable<double> zoom;
  final AppSettings settings;
  final ValueChanged<double> onChanged;

  @override
  State<_CameraZoomSlider> createState() => _CameraZoomSliderState();
}

class _CameraZoomSliderState extends State<_CameraZoomSlider> {
  double? _minZoom;
  double? _maxZoom;
  bool _defaultZoomApplied = false;
  var _zoomCalibrationGeneration = 0;

  @override
  void initState() {
    super.initState();
    _loadZoomRange();
  }

  @override
  void didUpdateWidget(covariant _CameraZoomSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state ||
        oldWidget.settings.cameraMinZoom != widget.settings.cameraMinZoom ||
        oldWidget.settings.cameraMaxZoom != widget.settings.cameraMaxZoom) {
      _defaultZoomApplied = false;
      _zoomCalibrationGeneration += 1;
      _loadZoomRange();
    }
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
    if (!mounted || minZoom == null || maxZoom == null) {
      return;
    }

    setState(() {
      _minZoom = minZoom;
      _maxZoom = maxZoom;
    });
    _applyDefaultMainLensZoom(minZoom, maxZoom, delayed: false);
  }

  void _applyDefaultMainLensZoom(
    double minZoom,
    double maxZoom, {
    required bool delayed,
  }) {
    if (_defaultZoomApplied || maxZoom <= minZoom) {
      return;
    }

    final effectiveRange = _effectiveZoomRange(minZoom, maxZoom);
    final defaultZoom = 1.0.clamp(effectiveRange.$1, effectiveRange.$2);
    final normalizedOneX = _normalizedFromRealZoom(
      minZoom,
      maxZoom,
      defaultZoom,
    );
    _defaultZoomApplied = true;
    widget.onChanged(normalizedOneX);
    if (!delayed) {
      _scheduleMainLensZoomCalibration(normalizedOneX);
    }
  }

  void _scheduleMainLensZoomCalibration(double normalizedOneX) {
    final generation = ++_zoomCalibrationGeneration;
    Future<void>.delayed(const Duration(milliseconds: 250), () {
      if (!mounted || generation != _zoomCalibrationGeneration) {
        return;
      }
      widget.onChanged(normalizedOneX);
    });
    Future<void>.delayed(const Duration(milliseconds: 900), () {
      if (!mounted || generation != _zoomCalibrationGeneration) {
        return;
      }
      widget.onChanged(normalizedOneX);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: widget.zoom,
      builder: (context, normalizedZoom, child) {
        final minZoom = _minZoom;
        final maxZoom = _maxZoom;
        final sliderValue = minZoom == null || maxZoom == null
            ? normalizedZoom
            : _sliderValueFromNormalized(minZoom, maxZoom, normalizedZoom);
        final label = minZoom == null || maxZoom == null
            ? '${(normalizedZoom * 100).round()}%'
            : _formatRealZoom(
                _realZoomFromSliderValue(minZoom, maxZoom, sliderValue),
              );
        return _SliderRow(
          icon: Icons.zoom_in_outlined,
          value: sliderValue,
          label: label,
          onChanged: minZoom == null || maxZoom == null
              ? widget.onChanged
              : (value) => widget.onChanged(
                  _normalizedFromSliderValue(minZoom, maxZoom, value),
                ),
        );
      },
    );
  }

  (double, double) _effectiveZoomRange(
    double deviceMinZoom,
    double deviceMaxZoom,
  ) {
    final minZoom = math.max(deviceMinZoom, widget.settings.cameraMinZoom);
    final maxZoom = math.min(deviceMaxZoom, widget.settings.cameraMaxZoom);
    if (maxZoom <= minZoom) {
      return (deviceMinZoom, deviceMaxZoom);
    }
    return (minZoom, maxZoom);
  }

  double _realZoomFromSliderValue(
    double deviceMinZoom,
    double deviceMaxZoom,
    double sliderValue,
  ) {
    final range = _effectiveZoomRange(deviceMinZoom, deviceMaxZoom);
    final minZoom = math.max(range.$1, 0.01);
    final maxZoom = math.max(range.$2, minZoom);
    if (maxZoom <= minZoom) {
      return minZoom;
    }

    return minZoom * math.pow(maxZoom / minZoom, sliderValue).toDouble();
  }

  double _sliderValueFromNormalized(
    double deviceMinZoom,
    double deviceMaxZoom,
    double normalizedZoom,
  ) {
    final realZoom =
        deviceMinZoom + (deviceMaxZoom - deviceMinZoom) * normalizedZoom;
    final range = _effectiveZoomRange(deviceMinZoom, deviceMaxZoom);
    final minZoom = math.max(range.$1, 0.01);
    final maxZoom = math.max(range.$2, minZoom);
    if (maxZoom <= minZoom) {
      return 0;
    }

    return (math.log(realZoom.clamp(minZoom, maxZoom) / minZoom) /
            math.log(maxZoom / minZoom))
        .clamp(0.0, 1.0);
  }

  double _normalizedFromSliderValue(
    double deviceMinZoom,
    double deviceMaxZoom,
    double sliderValue,
  ) {
    final realZoom = _realZoomFromSliderValue(
      deviceMinZoom,
      deviceMaxZoom,
      sliderValue,
    );
    return _normalizedFromRealZoom(deviceMinZoom, deviceMaxZoom, realZoom);
  }

  double _normalizedFromRealZoom(
    double deviceMinZoom,
    double deviceMaxZoom,
    double realZoom,
  ) {
    if (deviceMaxZoom <= deviceMinZoom) {
      return 0;
    }

    return ((realZoom - deviceMinZoom) / (deviceMaxZoom - deviceMinZoom)).clamp(
      0.0,
      1.0,
    );
  }
}

String _formatRealZoom(double realZoom) {
  return '${realZoom.toStringAsFixed(realZoom < 10 ? 1 : 0)}x';
}

class _ReferenceCaptureButton extends StatelessWidget {
  const _ReferenceCaptureButton({required this.state, this.compact = false});

  final CameraState state;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.32),
      shape: const CircleBorder(),
      elevation: 0,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => state.when(
          onPhotoMode: (photoState) {
            photoState.takePhoto();
          },
        ),
        child: Container(
          width: compact ? 62 : 72,
          height: compact ? 62 : 72,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: compact ? 3 : 4),
          ),
          child: Container(
            width: compact ? 44 : 52,
            height: compact ? 44 : 52,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}

class _CameraActionButton extends StatelessWidget {
  const _CameraActionButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String? tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      style: IconButton.styleFrom(
        foregroundColor: onPressed == null ? Colors.white30 : Colors.white,
        backgroundColor: Colors.white.withValues(alpha: 0.12),
        disabledBackgroundColor: Colors.white.withValues(alpha: 0.06),
        minimumSize: const Size(50, 50),
        shape: const CircleBorder(),
      ),
      onPressed: onPressed,
      icon: Icon(icon, size: 24),
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.icon,
    required this.value,
    required this.label,
    required this.onChanged,
  });

  final IconData icon;
  final double value;
  final String label;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.white70),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: Colors.white,
              inactiveTrackColor: Colors.white24,
              thumbColor: Colors.white,
              overlayColor: Colors.white12,
              trackHeight: 3,
            ),
            child: Slider(value: value.clamp(0, 1), onChanged: onChanged),
          ),
        ),
        SizedBox(
          width: 44,
          child: Text(
            label,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
        ),
      ],
    );
  }
}

class _WebCameraFallback extends StatelessWidget {
  const _WebCameraFallback({
    required this.point,
    required this.reference,
    required this.galleryImage,
    required this.mode,
    required this.overlayOpacity,
    required this.onModeChanged,
    required this.onOpacityChanged,
    required this.onPickReference,
    required this.onPickGallery,
  });

  final PilgrimagePoint point;
  final _ReferenceImageSource reference;
  final XFile? galleryImage;
  final AwesomeReferenceMode mode;
  final double overlayOpacity;
  final ValueChanged<AwesomeReferenceMode> onModeChanged;
  final ValueChanged<double> onOpacityChanged;
  final VoidCallback onPickReference;
  final VoidCallback onPickGallery;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          _FallbackTopBar(point: point, onPickReference: onPickReference),
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const _FallbackPreview(),
                  _ReferenceModeLayer(
                    mode: mode,
                    reference: reference,
                    overlayOpacity: overlayOpacity,
                    isLandscape: false,
                  ),
                ],
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(0, 0, 0, 6),
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.78),
              border: const Border(top: BorderSide(color: Colors.white12)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ModeSelector(mode: mode, onChanged: onModeChanged),
                const SizedBox(height: 6),
                _SliderRow(
                  icon: Icons.opacity,
                  value: overlayOpacity,
                  label: '${(overlayOpacity * 100).round()}%',
                  onChanged: onOpacityChanged,
                ),
                Row(
                  children: [
                    _CameraActionButton(
                      tooltip: '相册导入',
                      icon: galleryImage == null
                          ? Icons.photo_library_outlined
                          : Icons.photo_library,
                      onPressed: onPickGallery,
                    ),
                    const Spacer(),
                    const Icon(
                      Icons.photo_camera_outlined,
                      color: Colors.white,
                      size: 36,
                    ),
                    const Spacer(),
                    const SizedBox(width: 48),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FallbackTopBar extends StatelessWidget {
  const _FallbackTopBar({required this.point, required this.onPickReference});

  final PilgrimagePoint point;
  final VoidCallback onPickReference;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: '返回',
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back),
          ),
          Expanded(
            child: Text(
              point.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
          ),
          IconButton(
            tooltip: '参考图',
            onPressed: onPickReference,
            icon: const Icon(Icons.image_outlined),
          ),
        ],
      ),
    );
  }
}

class _FallbackPreview extends StatelessWidget {
  const _FallbackPreview();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: AppColors.surfaceMuted,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.photo_camera_outlined, color: AppColors.accentDark),
            SizedBox(height: 8),
            Text(
              'Web 预览不启动实时相机',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReferenceImageSource {
  const _ReferenceImageSource({
    required this.bytes,
    required this.localPath,
    required this.url,
  });

  final Uint8List? bytes;
  final String? localPath;
  final String? url;

  bool get hasImage => bytes != null || localPath != null || url != null;
}

class _ReferenceImageView extends StatelessWidget {
  const _ReferenceImageView({required this.source, required this.fit});

  final _ReferenceImageSource source;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final bytes = source.bytes;
    if (bytes != null) {
      return Image.memory(
        bytes,
        width: double.infinity,
        height: double.infinity,
        fit: fit,
        gaplessPlayback: true,
      );
    }

    if (source.localPath != null || source.url != null) {
      return ReferenceThumbnail(
        localPath: source.localPath,
        imageUrl: source.url,
        placeholder: const _ReferenceError(),
        width: double.infinity,
        height: double.infinity,
        fit: fit,
      );
    }

    return const SizedBox.shrink();
  }
}

class _ReferenceError extends StatelessWidget {
  const _ReferenceError();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: AppColors.surfaceMuted,
      child: Center(
        child: Icon(Icons.broken_image_outlined, color: AppColors.accentDark),
      ),
    );
  }
}
