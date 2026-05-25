import 'dart:async';
import 'dart:ui' as ui;

import 'package:camerawesome/camerawesome_plugin.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

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

  Uint8List? _localReferenceBytes;
  XFile? _galleryImage;
  AwesomeReferenceMode _mode = AwesomeReferenceMode.overlay;
  double? _referenceAspectRatio;
  int _referenceAspectRatioRequest = 0;
  late final ValueNotifier<double> _overlayOpacity;

  @override
  void initState() {
    super.initState();
    _overlayOpacity = ValueNotifier<double>(0.46);
    _refreshReferenceAspectRatio();
  }

  @override
  void didUpdateWidget(covariant CamerawesomeReferenceScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.point.id != widget.point.id ||
        oldWidget.point.referenceFullImagePath !=
            widget.point.referenceFullImagePath ||
        oldWidget.point.referenceImageUrl !=
            widget.point.referenceImageUrl) {
      _refreshReferenceAspectRatio();
    }
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _overlayOpacity.dispose();
    super.dispose();
  }

  // ── Reference image ──────────────────────────────────────────────────

  Future<void> _pickReferenceImage() async {
    final picked = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (picked == null || !mounted) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(() => _localReferenceBytes = bytes);
    await _refreshReferenceAspectRatio();
  }

  Future<void> _refreshReferenceAspectRatio() async {
    final requestId = ++_referenceAspectRatioRequest;
    final ratio = await _resolveReferenceAspectRatio(
      bytes: _localReferenceBytes,
      localPath: widget.point.referenceFullImagePath,
      url: anitabiFullResolutionImageUrl(widget.point.referenceImageUrl),
    );
    if (!mounted || requestId != _referenceAspectRatioRequest) return;
    setState(() => _referenceAspectRatio = ratio);
  }

  // ── Gallery & capture ────────────────────────────────────────────────

  Future<void> _pickGalleryImage() async {
    final picked = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (picked == null || !mounted) return;
    setState(() => _galleryImage = picked);
    await _openConfirmation(picked.path);
  }

  void _handleCapture(MediaCapture event) {
    if (!event.isPicture || event.status != MediaCaptureStatus.success) return;
    final path = event.captureRequest.when(
      single: (s) => s.file?.path,
      multiple: (m) => m.fileBySensor.values.first?.path,
    );
    if (path == null || !mounted) return;
    _openConfirmation(path);
  }

  Future<CaptureRequest> _buildPhotoPath(List<Sensor> sensors) async {
    final path = await camera_storage.buildReferencePhotoPath();
    return SingleCaptureRequest(path, sensors.first);
  }

  Future<void> _openConfirmation(String photoPath) async {
    if (!mounted) return;

    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

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

  // ── Aspect ratio ─────────────────────────────────────────────────────

  double? _captureAspectRatio() {
    final refRatio = _referenceAspectRatio;
    if (refRatio != null && refRatio > 0) return refRatio;
    return switch (widget.settings.cameraAspectRatio) {
      CameraPhotoAspectRatio.landscape16x9 => 16 / 9,
      CameraPhotoAspectRatio.standard4x3 => 4 / 3,
      CameraPhotoAspectRatio.square1x1 => 1,
      CameraPhotoAspectRatio.auto => 16 / 9,
    };
  }

  static Future<double?> _resolveReferenceAspectRatio({
    required Uint8List? bytes,
    required String? localPath,
    required String? url,
  }) async {
    Uint8List? data = bytes;
    if (data == null && localPath != null) {
      data = await reference_image_bytes.readReferenceImageBytes(localPath);
    }
    if (data == null && url != null) {
      try {
        final response = await http.get(Uri.parse(url));
        if (response.statusCode == 200) data = response.bodyBytes;
      } catch (_) {}
    }
    if (data == null) return null;

    final completer = Completer<double?>();
    ui.decodeImageFromList(data, (img) {
      if (img.width > 0 && img.height > 0) {
        completer.complete(img.width / img.height);
      } else {
        completer.complete(null);
      }
    });
    return completer.future;
  }

  // ── Build ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final reference = _ReferenceImageSource(
      bytes: _localReferenceBytes,
      localPath: widget.point.referenceFullImagePath,
      url: anitabiFullResolutionImageUrl(widget.point.referenceImageUrl),
    );
    final captureAspectRatio = _captureAspectRatio();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CameraAwesomeBuilder.awesome(
        saveConfig: SaveConfig.photo(pathBuilder: _buildPhotoPath),
        previewDecoratorBuilder: (state, preview) {
          return _ReferenceDecorator(
            mode: _mode,
            opacity: _overlayOpacity,
            reference: reference,
            aspectRatio: captureAspectRatio,
          );
        },
        topActionsBuilder: (state) => _TopActions(
          galleryImage: _galleryImage,
          onPickReference: _pickReferenceImage,
          onPickGallery: _pickGalleryImage,
          onModeChanged: (m) => setState(() => _mode = m),
          onOpacityChanged: (v) => _overlayOpacity.value = v,
          opacity: _overlayOpacity,
          mode: _mode,
          state: state,
        ),
        onMediaCaptureEvent: _handleCapture,
        previewFit: CameraPreviewFit.contain,
      ),
    );
  }
}

// ── Top actions bar ────────────────────────────────────────────────────

class _TopActions extends StatelessWidget {
  const _TopActions({
    required this.galleryImage,
    required this.onPickReference,
    required this.onPickGallery,
    required this.onModeChanged,
    required this.onOpacityChanged,
    required this.opacity,
    required this.mode,
    required this.state,
  });

  final XFile? galleryImage;
  final VoidCallback onPickReference;
  final VoidCallback onPickGallery;
  final ValueChanged<AwesomeReferenceMode> onModeChanged;
  final ValueChanged<double> onOpacityChanged;
  final ValueNotifier<double> opacity;
  final AwesomeReferenceMode mode;
  final CameraState state;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            _CompactIconButton(
              tooltip: '参考图',
              icon: Icons.image_outlined,
              onPressed: onPickReference,
            ),
            _CompactIconButton(
              tooltip: '相册',
              icon: Icons.photo_library_outlined,
              onPressed: onPickGallery,
            ),
            if (galleryImage != null)
              _ReviewButton(onTap: onPickGallery),
            const Spacer(),
            _ModeChip(
              label: '叠影',
              selected: mode == AwesomeReferenceMode.overlay,
              onTap: () => onModeChanged(AwesomeReferenceMode.overlay),
            ),
            _ModeChip(
              label: '上下',
              selected: mode == AwesomeReferenceMode.split,
              onTap: () => onModeChanged(AwesomeReferenceMode.split),
            ),
            _ModeChip(
              label: '小窗',
              selected: mode == AwesomeReferenceMode.pinned,
              onTap: () => onModeChanged(AwesomeReferenceMode.pinned),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactIconButton extends StatelessWidget {
  const _CompactIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, color: Colors.white),
    );
  }
}

class _ReviewButton extends StatelessWidget {
  const _ReviewButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Material(
        color: Colors.white24,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check, color: Colors.white, size: 16),
                SizedBox(width: 2),
                Text(
                  '已选',
                  style: TextStyle(color: Colors.white, fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: selected ? Colors.white24 : Colors.black26,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Reference decorator ────────────────────────────────────────────────

class _ReferenceDecorator extends StatelessWidget {
  const _ReferenceDecorator({
    required this.mode,
    required this.opacity,
    required this.reference,
    required this.aspectRatio,
  });

  final AwesomeReferenceMode mode;
  final ValueNotifier<double> opacity;
  final _ReferenceImageSource reference;
  final double? aspectRatio;

  @override
  Widget build(BuildContext context) {
    if (!reference.hasImage || aspectRatio == null) {
      return mode == AwesomeReferenceMode.overlay
          ? _OpacitySlider(opacity: opacity)
          : const SizedBox.shrink();
    }

    final refWidget = _ReferenceAspectBox(
      aspectRatio: aspectRatio,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: _ReferenceImageView(source: reference, fit: BoxFit.contain),
      ),
    );

    return switch (mode) {
      AwesomeReferenceMode.overlay => ValueListenableBuilder<double>(
        valueListenable: opacity,
        builder: (context, o, _) {
          return Stack(
            fit: StackFit.expand,
            children: [
              IgnorePointer(child: Opacity(opacity: o, child: refWidget)),
              _OpacitySlider(opacity: opacity),
            ],
          );
        },
      ),
      AwesomeReferenceMode.split => Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            left: 8,
            top: 8,
            right: 8,
            height: MediaQuery.of(context).size.height * 0.25,
            child: Material(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: refWidget,
              ),
            ),
          ),
        ],
      ),
      AwesomeReferenceMode.pinned => Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            left: 16,
            top: 64,
            width: 180,
            height: 120,
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(8),
              child: refWidget,
            ),
          ),
        ],
      ),
    };
  }
}

class _OpacitySlider extends StatelessWidget {
  const _OpacitySlider({required this.opacity});

  final ValueNotifier<double> opacity;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 12,
      top: 0,
      bottom: 0,
      child: Center(
        child: SizedBox(
          height: 200,
          child: ValueListenableBuilder<double>(
            valueListenable: opacity,
            builder: (context, o, _) {
              return RotatedBox(
                quarterTurns: 1,
                child: SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 4,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 10),
                    activeTrackColor: Colors.white,
                    inactiveTrackColor: Colors.white24,
                    thumbColor: Colors.white,
                    overlayColor: Colors.white.withValues(alpha: 0.12),
                  ),
                  child: Slider(
                    value: o,
                    min: 0.1,
                    max: 1.0,
                    onChanged: (v) => opacity.value = v,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ── Reference image helpers ────────────────────────────────────────────

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

class _ReferenceAspectBox extends StatelessWidget {
  const _ReferenceAspectBox({required this.aspectRatio, required this.child});

  final double? aspectRatio;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ratio = aspectRatio;
    if (ratio == null || ratio <= 0) return child;
    return AspectRatio(aspectRatio: ratio, child: child);
  }
}

class _ReferenceImageView extends StatelessWidget {
  const _ReferenceImageView({required this.source, this.fit = BoxFit.cover});

  final _ReferenceImageSource source;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    if (source.bytes != null) {
      return Image.memory(source.bytes!, fit: fit);
    }
    if (source.localPath != null) {
      return ReferenceThumbnail(
        localPath: source.localPath,
        imageUrl: null,
        placeholder: const SizedBox.shrink(),
        fit: fit,
      );
    }
    if (source.url != null) {
      return Image.network(
        source.url!,
        fit: fit,
        errorBuilder: (context, error, stack) => const SizedBox.shrink(),
      );
    }
    return const SizedBox.shrink();
  }
}
