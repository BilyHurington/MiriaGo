import 'package:camerawesome/camerawesome_plugin.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../app_theme.dart';
import '../plan/pilgrimage_models.dart';
import '../plan/pilgrimage_plan_controller.dart';
import 'camera_storage_stub.dart'
    if (dart.library.io) 'camera_storage_io.dart'
    as camera_storage;
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

  Uint8List? _localReferenceBytes;
  XFile? _galleryImage;
  AwesomeReferenceMode _mode = AwesomeReferenceMode.overlay;
  bool _landscapeLocked = false;

  @override
  void initState() {
    super.initState();
    _overlayOpacity = ValueNotifier<double>(0.46);
    _zoom = ValueNotifier<double>(0);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations(const []);
    _overlayOpacity.dispose();
    _zoom.dispose();
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
          referenceImageUrl: widget.point.referenceImageUrl,
        ),
      ),
    );
  }

  void _setZoom(CameraState state, double value) {
    final nextZoom = value.clamp(0.0, 1.0);
    _zoom.value = nextZoom;
    state.sensorConfig.setZoom(nextZoom);
  }

  Future<void> _toggleOrientation() async {
    final nextLandscapeLocked = !_landscapeLocked;
    setState(() {
      _landscapeLocked = nextLandscapeLocked;
    });

    await SystemChrome.setPreferredOrientations(
      nextLandscapeLocked
          ? const [
              DeviceOrientation.landscapeLeft,
              DeviceOrientation.landscapeRight,
            ]
          : const [DeviceOrientation.portraitUp],
    );
  }

  @override
  Widget build(BuildContext context) {
    final reference = _ReferenceImageSource(
      bytes: _localReferenceBytes,
      url: widget.point.referenceImageUrl,
    );
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;

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
          : CameraAwesomeBuilder.custom(
              saveConfig: SaveConfig.photo(pathBuilder: _buildPhotoPath),
              sensorConfig: SensorConfig.single(
                sensor: Sensor.position(SensorPosition.back),
                flashMode: FlashMode.auto,
                aspectRatio: _cameraAspectRatio(
                  widget.settings.cameraAspectRatio,
                ),
                zoom: _zoom.value,
              ),
              previewFit: isLandscape
                  ? CameraPreviewFit.cover
                  : CameraPreviewFit.contain,
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

CameraAspectRatios _cameraAspectRatio(CameraPhotoAspectRatio ratio) {
  return switch (ratio) {
    CameraPhotoAspectRatio.landscape16x9 => CameraAspectRatios.ratio_16_9,
    CameraPhotoAspectRatio.standard4x3 => CameraAspectRatios.ratio_4_3,
    CameraPhotoAspectRatio.square1x1 => CameraAspectRatios.ratio_1_1,
  };
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
  final bool landscapeLocked;
  final ValueChanged<AwesomeReferenceMode> onModeChanged;
  final ValueChanged<double> onOpacityChanged;
  final ValueChanged<double> onZoomChanged;
  final VoidCallback onPickReference;
  final VoidCallback onPickGallery;
  final VoidCallback onToggleOrientation;

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final landscapePanelWidth = (MediaQuery.sizeOf(context).width * 0.34).clamp(
      300.0,
      380.0,
    );

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
              isLandscape: isLandscape,
            );
          },
        ),
        SafeArea(
          child: isLandscape
              ? Stack(
                  children: [
                    Positioned(
                      left: 12,
                      top: 12,
                      bottom: 12,
                      child: _LandscapeCameraToolbar(
                        state: state,
                        landscapeLocked: landscapeLocked,
                        onPickReference: onPickReference,
                        onToggleOrientation: onToggleOrientation,
                      ),
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      bottom: 0,
                      width: landscapePanelWidth,
                      child: _CameraBottomPanel(
                        state: state,
                        mode: mode,
                        overlayOpacity: overlayOpacity,
                        zoom: zoom,
                        isLandscape: true,
                        galleryImage: galleryImage,
                        onModeChanged: onModeChanged,
                        onOpacityChanged: onOpacityChanged,
                        onZoomChanged: onZoomChanged,
                        onPickGallery: onPickGallery,
                      ),
                    ),
                  ],
                )
              : Column(
                  children: [
                    _CameraTopBar(
                      state: state,
                      landscapeLocked: landscapeLocked,
                      onPickReference: onPickReference,
                      onToggleOrientation: onToggleOrientation,
                    ),
                    const Spacer(),
                    _CameraBottomPanel(
                      state: state,
                      mode: mode,
                      overlayOpacity: overlayOpacity,
                      zoom: zoom,
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
  });

  final AwesomeReferenceMode mode;
  final _ReferenceImageSource reference;
  final double overlayOpacity;
  final bool isLandscape;

  @override
  Widget build(BuildContext context) {
    if (!reference.hasImage) {
      return const SizedBox.shrink();
    }

    return switch (mode) {
      AwesomeReferenceMode.overlay => IgnorePointer(
        child: Opacity(
          opacity: overlayOpacity,
          child: _ReferenceImageView(source: reference, fit: BoxFit.contain),
        ),
      ),
      AwesomeReferenceMode.split when isLandscape => Positioned(
        left: 82,
        top: 14,
        width: 220,
        height: 124,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.42),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white24),
          ),
          clipBehavior: Clip.antiAlias,
          child: _ReferenceImageView(source: reference, fit: BoxFit.contain),
        ),
      ),
      AwesomeReferenceMode.split => Align(
        alignment: Alignment.topCenter,
        child: SafeArea(
          bottom: false,
          child: Container(
            height: MediaQuery.sizeOf(context).height * 0.34,
            margin: const EdgeInsets.fromLTRB(12, 72, 12, 0),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.42),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white24),
            ),
            clipBehavior: Clip.antiAlias,
            child: _ReferenceImageView(source: reference, fit: BoxFit.contain),
          ),
        ),
      ),
      AwesomeReferenceMode.pinned when isLandscape => Positioned(
        left: 82,
        top: 14,
        width: 116,
        height: 154,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.42),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white24),
          ),
          clipBehavior: Clip.antiAlias,
          child: _ReferenceImageView(source: reference, fit: BoxFit.cover),
        ),
      ),
      AwesomeReferenceMode.pinned => Align(
        alignment: Alignment.topLeft,
        child: SafeArea(
          child: Container(
            width: 116,
            height: 154,
            margin: const EdgeInsets.fromLTRB(14, 82, 0, 0),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.42),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white24),
            ),
            clipBehavior: Clip.antiAlias,
            child: _ReferenceImageView(source: reference, fit: BoxFit.cover),
          ),
        ),
      ),
    };
  }
}

class _CameraTopBar extends StatelessWidget {
  const _CameraTopBar({
    required this.state,
    required this.landscapeLocked,
    required this.onPickReference,
    required this.onToggleOrientation,
  });

  final CameraState state;
  final bool landscapeLocked;
  final VoidCallback onPickReference;
  final VoidCallback onToggleOrientation;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
      child: Row(
        children: [
          _CameraCircleButton(
            tooltip: '返回',
            icon: Icons.arrow_back,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          const Spacer(),
          _CameraCircleButton(
            tooltip: '参考图',
            icon: Icons.image_outlined,
            onPressed: onPickReference,
          ),
          const SizedBox(width: 8),
          _CameraCircleButton(
            tooltip: landscapeLocked ? '切换竖屏' : '切换横屏',
            icon: Icons.screen_rotation_alt_outlined,
            onPressed: onToggleOrientation,
          ),
          const SizedBox(width: 8),
          _CompactFlashButton(state: state),
          const SizedBox(width: 8),
          _CompactCameraSwitchButton(state: state),
        ],
      ),
    );
  }
}

class _LandscapeCameraToolbar extends StatelessWidget {
  const _LandscapeCameraToolbar({
    required this.state,
    required this.landscapeLocked,
    required this.onPickReference,
    required this.onToggleOrientation,
  });

  final CameraState state;
  final bool landscapeLocked;
  final VoidCallback onPickReference;
  final VoidCallback onToggleOrientation;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _CameraCircleButton(
          tooltip: '返回',
          icon: Icons.arrow_back,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        Column(
          children: [
            _CameraCircleButton(
              tooltip: '参考图',
              icon: Icons.image_outlined,
              onPressed: onPickReference,
            ),
            const SizedBox(height: 10),
            _CameraCircleButton(
              tooltip: landscapeLocked ? '切换竖屏' : '切换横屏',
              icon: Icons.screen_rotation_alt_outlined,
              onPressed: onToggleOrientation,
            ),
            const SizedBox(height: 10),
            _CompactFlashButton(state: state),
            const SizedBox(height: 10),
            _CompactCameraSwitchButton(state: state),
          ],
        ),
        const SizedBox(width: 44, height: 44),
      ],
    );
  }
}

class _CameraCircleButton extends StatelessWidget {
  const _CameraCircleButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
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
  const _CompactFlashButton({required this.state});

  final CameraState state;

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
              tooltip: '闪光灯',
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
  const _CompactCameraSwitchButton({required this.state});

  final CameraState state;

  @override
  Widget build(BuildContext context) {
    return _CameraCircleButton(
      tooltip: '切换摄像头',
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
    required this.overlayOpacity,
    required this.onZoomChanged,
    required this.onOpacityChanged,
  });

  final CameraState state;
  final ValueListenable<double> zoom;
  final ValueListenable<double> overlayOpacity;
  final ValueChanged<double> onZoomChanged;
  final ValueChanged<double> onOpacityChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _CameraZoomSlider(state: state, zoom: zoom, onChanged: onZoomChanged),
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
    required this.onChanged,
  });

  final CameraState state;
  final ValueListenable<double> zoom;
  final ValueChanged<double> onChanged;

  @override
  State<_CameraZoomSlider> createState() => _CameraZoomSliderState();
}

class _CameraZoomSliderState extends State<_CameraZoomSlider> {
  double? _minZoom;
  double? _maxZoom;
  bool _defaultZoomApplied = false;

  @override
  void initState() {
    super.initState();
    _loadZoomRange();
  }

  @override
  void didUpdateWidget(covariant _CameraZoomSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) {
      _defaultZoomApplied = false;
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
    _applyDefaultMainLensZoom(minZoom, maxZoom);
  }

  void _applyDefaultMainLensZoom(double minZoom, double maxZoom) {
    if (_defaultZoomApplied || minZoom >= 1 || maxZoom <= minZoom) {
      return;
    }

    final normalizedOneX = ((1 - minZoom) / (maxZoom - minZoom)).clamp(
      0.0,
      1.0,
    );
    _defaultZoomApplied = true;
    widget.onChanged(normalizedOneX);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: widget.zoom,
      builder: (context, normalizedZoom, child) {
        final minZoom = _minZoom;
        final maxZoom = _maxZoom;
        final label = minZoom == null || maxZoom == null
            ? '${(normalizedZoom * 100).round()}%'
            : _formatRealZoom(minZoom, maxZoom, normalizedZoom);
        return _SliderRow(
          icon: Icons.zoom_in_outlined,
          value: normalizedZoom,
          label: label,
          onChanged: widget.onChanged,
        );
      },
    );
  }
}

String _formatRealZoom(double minZoom, double maxZoom, double normalizedZoom) {
  final realZoom = minZoom + (maxZoom - minZoom) * normalizedZoom;
  return '${realZoom.toStringAsFixed(realZoom < 10 ? 1 : 0)}x';
}

class _ReferenceCaptureButton extends StatelessWidget {
  const _ReferenceCaptureButton({required this.state});

  final CameraState state;

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
          width: 72,
          height: 72,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 4),
          ),
          child: Container(
            width: 52,
            height: 52,
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

  final String tooltip;
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
  const _ReferenceImageSource({required this.bytes, required this.url});

  final Uint8List? bytes;
  final String? url;

  bool get hasImage => bytes != null || url != null;
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

    final url = source.url;
    if (url != null) {
      return Image.network(
        url,
        width: double.infinity,
        height: double.infinity,
        fit: fit,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) {
          return const _ReferenceError();
        },
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
