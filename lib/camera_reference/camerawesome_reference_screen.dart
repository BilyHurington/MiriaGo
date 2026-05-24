import 'package:camerawesome/camerawesome_plugin.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../app_theme.dart';
import '../plan/pilgrimage_models.dart';
import 'camera_storage_stub.dart'
    if (dart.library.io) 'camera_storage_io.dart' as camera_storage;

enum AwesomeReferenceMode { overlay, split, pinned }

class CamerawesomeReferenceScreen extends StatefulWidget {
  const CamerawesomeReferenceScreen({required this.point, super.key});

  final PilgrimagePoint point;

  @override
  State<CamerawesomeReferenceScreen> createState() =>
      _CamerawesomeReferenceScreenState();
}

class _CamerawesomeReferenceScreenState
    extends State<CamerawesomeReferenceScreen> {
  final ImagePicker _imagePicker = ImagePicker();

  XFile? _localReferenceImage;
  XFile? _galleryImage;
  AwesomeReferenceMode _mode = AwesomeReferenceMode.overlay;
  double _overlayOpacity = 0.46;
  double _zoom = 0;

  Future<CaptureRequest> _buildPhotoPath(List<Sensor> sensors) async {
    final path = await camera_storage.buildReferencePhotoPath();
    return SingleCaptureRequest(path, sensors.first);
  }

  Future<void> _pickReferenceImage() async {
    final picked = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (picked == null || !mounted) {
      return;
    }

    setState(() {
      _localReferenceImage = picked;
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已导入相册图片')));
  }

  void _handleCaptureEvent(MediaCapture event) {
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

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('照片已保存：$path')));
  }

  void _setZoom(CameraState state, double value) {
    final nextZoom = value.clamp(0.0, 1.0);
    setState(() => _zoom = nextZoom);
    state.sensorConfig.setZoom(nextZoom);
  }

  @override
  Widget build(BuildContext context) {
    final reference = _ReferenceImageSource(
      file: _localReferenceImage,
      url: widget.point.referenceImageUrl,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: kIsWeb
          ? _WebCameraFallback(
              point: widget.point,
              reference: reference,
              galleryImage: _galleryImage,
              mode: _mode,
              overlayOpacity: _overlayOpacity,
              onModeChanged: (mode) => setState(() => _mode = mode),
              onOpacityChanged: (value) =>
                  setState(() => _overlayOpacity = value),
              onPickReference: _pickReferenceImage,
              onPickGallery: _pickGalleryImage,
            )
          : CameraAwesomeBuilder.custom(
              saveConfig: SaveConfig.photo(pathBuilder: _buildPhotoPath),
              sensorConfig: SensorConfig.single(
                sensor: Sensor.position(SensorPosition.back),
                flashMode: FlashMode.auto,
                aspectRatio: CameraAspectRatios.ratio_4_3,
                zoom: _zoom,
              ),
              previewFit: CameraPreviewFit.contain,
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
                  onModeChanged: (mode) => setState(() => _mode = mode),
                  onOpacityChanged: (value) =>
                      setState(() => _overlayOpacity = value),
                  onZoomChanged: (value) => _setZoom(cameraState, value),
                  onPickReference: _pickReferenceImage,
                  onPickGallery: _pickGalleryImage,
                );
              },
            ),
    );
  }
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
    required this.onModeChanged,
    required this.onOpacityChanged,
    required this.onZoomChanged,
    required this.onPickReference,
    required this.onPickGallery,
  });

  final PilgrimagePoint point;
  final CameraState state;
  final _ReferenceImageSource reference;
  final XFile? galleryImage;
  final AwesomeReferenceMode mode;
  final double overlayOpacity;
  final double zoom;
  final ValueChanged<AwesomeReferenceMode> onModeChanged;
  final ValueChanged<double> onOpacityChanged;
  final ValueChanged<double> onZoomChanged;
  final VoidCallback onPickReference;
  final VoidCallback onPickGallery;

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;

    return Stack(
      fit: StackFit.expand,
      children: [
        _ReferenceModeLayer(
          mode: mode,
          reference: reference,
          overlayOpacity: overlayOpacity,
        ),
        SafeArea(
          child: Column(
            children: [
              _CameraTopBar(
                point: point,
                state: state,
                onPickReference: onPickReference,
              ),
              const Spacer(),
              _CameraBottomPanel(
                state: state,
                mode: mode,
                overlayOpacity: overlayOpacity,
                zoom: zoom,
                isLandscape: isLandscape,
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
  });

  final AwesomeReferenceMode mode;
  final _ReferenceImageSource reference;
  final double overlayOpacity;

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
      AwesomeReferenceMode.split => Align(
        alignment: Alignment.topCenter,
        child: SafeArea(
          bottom: false,
          child: Container(
            height: MediaQuery.sizeOf(context).height * 0.36,
            margin: const EdgeInsets.fromLTRB(12, 64, 12, 0),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: _ReferenceImageView(source: reference, fit: BoxFit.contain),
          ),
        ),
      ),
      AwesomeReferenceMode.pinned => Align(
        alignment: Alignment.topLeft,
        child: SafeArea(
          child: Container(
            width: 132,
            height: 176,
            margin: const EdgeInsets.fromLTRB(16, 76, 0, 0),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
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
    required this.point,
    required this.state,
    required this.onPickReference,
  });

  final PilgrimagePoint point;
  final CameraState state;
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  point.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
                Text(
                  '${point.work.title} / ${point.referenceLabel}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: '参考图',
            onPressed: onPickReference,
            icon: const Icon(Icons.image_outlined),
          ),
          _CompactFlashButton(state: state),
          _CompactCameraSwitchButton(state: state),
        ],
      ),
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

            return IconButton(
              tooltip: '闪光灯',
              onPressed: sensorConfig.switchCameraFlash,
              icon: Icon(icon),
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
    return IconButton(
      tooltip: '切换摄像头',
      onPressed: () => state.switchCameraSensor(
        zoom: state.sensorConfig.zoom,
        flash: state.sensorConfig.flashMode,
      ),
      icon: const Icon(Icons.cameraswitch_outlined),
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
  final double overlayOpacity;
  final double zoom;
  final bool isLandscape;
  final XFile? galleryImage;
  final ValueChanged<AwesomeReferenceMode> onModeChanged;
  final ValueChanged<double> onOpacityChanged;
  final ValueChanged<double> onZoomChanged;
  final VoidCallback onPickGallery;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.fromLTRB(12, 0, 12, isLandscape ? 12 : 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ModeSelector(mode: mode, onChanged: onModeChanged),
          const SizedBox(height: 8),
          _ZoomAndOpacityControls(
            zoom: zoom,
            overlayOpacity: overlayOpacity,
            onZoomChanged: onZoomChanged,
            onOpacityChanged: onOpacityChanged,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              IconButton.outlined(
                tooltip: '相册导入',
                onPressed: onPickGallery,
                icon: Icon(
                  galleryImage == null
                      ? Icons.photo_library_outlined
                      : Icons.photo_library,
                ),
              ),
              const Spacer(),
              _ReferenceCaptureButton(state: state),
              const Spacer(),
              IconButton.outlined(
                tooltip: '检查照片',
                onPressed: galleryImage == null ? null : () {},
                icon: const Icon(Icons.fact_check_outlined),
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
    return SegmentedButton<AwesomeReferenceMode>(
      segments: const [
        ButtonSegment(
          value: AwesomeReferenceMode.overlay,
          icon: Icon(Icons.layers_outlined, size: 18),
          label: Text('叠影'),
        ),
        ButtonSegment(
          value: AwesomeReferenceMode.split,
          icon: Icon(Icons.splitscreen_outlined, size: 18),
          label: Text('上下'),
        ),
        ButtonSegment(
          value: AwesomeReferenceMode.pinned,
          icon: Icon(Icons.picture_in_picture_alt_outlined, size: 18),
          label: Text('小窗'),
        ),
      ],
      selected: {mode},
      onSelectionChanged: (selection) => onChanged(selection.first),
      showSelectedIcon: false,
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        textStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _ZoomAndOpacityControls extends StatelessWidget {
  const _ZoomAndOpacityControls({
    required this.zoom,
    required this.overlayOpacity,
    required this.onZoomChanged,
    required this.onOpacityChanged,
  });

  final double zoom;
  final double overlayOpacity;
  final ValueChanged<double> onZoomChanged;
  final ValueChanged<double> onOpacityChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SliderRow(
          icon: Icons.zoom_in_outlined,
          value: zoom,
          label: '${(1 + zoom * 4).toStringAsFixed(1)}x',
          onChanged: onZoomChanged,
        ),
        _SliderRow(
          icon: Icons.opacity,
          value: overlayOpacity,
          label: '${(overlayOpacity * 100).round()}%',
          onChanged: onOpacityChanged,
        ),
      ],
    );
  }
}

class _ReferenceCaptureButton extends StatelessWidget {
  const _ReferenceCaptureButton({required this.state});

  final CameraState state;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.accent,
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => state.when(onPhotoMode: (photoState) {
          photoState.takePhoto();
        }),
        child: Container(
          width: 76,
          height: 76,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.surface, width: 5),
          ),
          child: const Icon(
            Icons.photo_camera,
            color: AppColors.surface,
            size: 30,
          ),
        ),
      ),
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
        Icon(icon, size: 18, color: AppColors.textSecondary),
        Expanded(
          child: Slider(value: value.clamp(0, 1), onChanged: onChanged),
        ),
        SizedBox(
          width: 44,
          child: Text(
            label,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: AppColors.textSecondary,
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
                  ),
                ],
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ModeSelector(mode: mode, onChanged: onModeChanged),
                _SliderRow(
                  icon: Icons.opacity,
                  value: overlayOpacity,
                  label: '${(overlayOpacity * 100).round()}%',
                  onChanged: onOpacityChanged,
                ),
                Row(
                  children: [
                    IconButton.outlined(
                      tooltip: '相册导入',
                      onPressed: onPickGallery,
                      icon: Icon(
                        galleryImage == null
                            ? Icons.photo_library_outlined
                            : Icons.photo_library,
                      ),
                    ),
                    const Spacer(),
                    const Icon(Icons.photo_camera_outlined),
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
  const _ReferenceImageSource({required this.file, required this.url});

  final XFile? file;
  final String? url;

  bool get hasImage => file != null || url != null;
}

class _ReferenceImageView extends StatelessWidget {
  const _ReferenceImageView({required this.source, required this.fit});

  final _ReferenceImageSource source;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final file = source.file;
    if (file != null) {
      return FutureBuilder<Uint8List>(
        future: file.readAsBytes(),
        builder: (context, snapshot) {
          final bytes = snapshot.data;
          if (bytes == null) {
            return const Center(child: CircularProgressIndicator());
          }

          return Image.memory(
            bytes,
            width: double.infinity,
            height: double.infinity,
            fit: fit,
          );
        },
      );
    }

    final url = source.url;
    if (url != null) {
      return Image.network(
        url,
        width: double.infinity,
        height: double.infinity,
        fit: fit,
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
