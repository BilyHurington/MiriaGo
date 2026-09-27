import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/widgets.dart' show Orientation;

import '../../camera_reference/camera_zoom_capabilities.dart';
import '../../camera_reference/reference_image_bytes_stub.dart'
    if (dart.library.io) '../../camera_reference/reference_image_bytes_io.dart'
    as reference_image_bytes;
import '../../data/anitabi_image_fetcher.dart';
import '../../data/anitabi_image_url.dart';
import '../../data/bounded_image_decoder.dart';
import '../../plan/pilgrimage_models.dart';

// Ported from the old camerawesome_reference_screen.dart (aspect ratio and
// zoom helpers). Semantics are unchanged.

double _aspectRatioValue(CameraPhotoAspectRatio ratio) {
  return switch (ratio) {
    CameraPhotoAspectRatio.auto => 16 / 9,
    CameraPhotoAspectRatio.native => 4 / 3,
    CameraPhotoAspectRatio.landscape16x9 => 16 / 9,
    CameraPhotoAspectRatio.cinema21x9 => 21 / 9,
    CameraPhotoAspectRatio.standard4x3 => 4 / 3,
    CameraPhotoAspectRatio.photo3x2 => 3 / 2,
    CameraPhotoAspectRatio.portrait9x16 => 9 / 16,
    CameraPhotoAspectRatio.portrait9x21 => 9 / 21,
    CameraPhotoAspectRatio.portrait3x4 => 3 / 4,
    CameraPhotoAspectRatio.portrait2x3 => 2 / 3,
    CameraPhotoAspectRatio.square1x1 => 1,
    CameraPhotoAspectRatio.custom => 1,
  };
}

double _settingsAspectRatioValue(
  CameraPhotoAspectRatio ratio,
  AppSettings settings,
) {
  if (ratio != CameraPhotoAspectRatio.custom) {
    return _aspectRatioValue(ratio);
  }

  final width = settings.customCameraAspectRatioWidth;
  final height = settings.customCameraAspectRatioHeight;
  if (width <= 0 || height <= 0) {
    return 1;
  }
  return width / height;
}

/// Width / height of the captured photo (and of the camera stage).
///
/// `auto` follows the reference image; without a reference ratio it uses
/// the fallback ratio, where `native` follows the UI orientation.
double resolveCameraCaptureAspectRatio({
  required double? referenceAspectRatio,
  required AppSettings settings,
  required Orientation orientation,
}) {
  final configuredRatio = settings.cameraCaptureAspectRatio;
  final baseRatio = configuredRatio == CameraPhotoAspectRatio.auto
      ? referenceAspectRatio ??
            _fallbackAspectRatioValue(
              settings.cameraFallbackAspectRatio,
              settings,
              orientation,
            )
      : _settingsAspectRatioValue(configuredRatio, settings);
  if (baseRatio <= 0) {
    return 1;
  }
  return baseRatio;
}

double _fallbackAspectRatioValue(
  CameraPhotoAspectRatio ratio,
  AppSettings settings,
  Orientation orientation,
) {
  if (ratio == CameraPhotoAspectRatio.native) {
    return orientation == Orientation.landscape ? 4 / 3 : 3 / 4;
  }
  return _settingsAspectRatioValue(ratio, settings);
}

/// Whether the native camera crops the saved photo to the stage ratio.
bool shouldCropNativeCapture({
  required double? referenceAspectRatio,
  required AppSettings settings,
}) {
  if (settings.cameraCaptureAspectRatio != CameraPhotoAspectRatio.auto) {
    return true;
  }
  if (referenceAspectRatio != null && referenceAspectRatio > 0) {
    return true;
  }
  return settings.cameraFallbackAspectRatio != CameraPhotoAspectRatio.native;
}

typedef ReferenceAspectRatioResolver =
    Future<double?> Function({
      required Uint8List? bytes,
      required String? localPath,
      required String? url,
      required AnitabiImageSource imageSource,
    });

/// Reads the reference image (session bytes → local file → remote URL) and
/// returns its width / height, or null when it cannot be read.
Future<double?> resolveReferenceAspectRatio({
  required Uint8List? bytes,
  required String? localPath,
  required String? url,
  required AnitabiImageSource imageSource,
}) async {
  try {
    final localBytes =
        bytes ??
        (localPath == null
            ? null
            : await reference_image_bytes.readReferenceImageBytes(localPath));
    if (localBytes != null) {
      return decodeImageAspectRatio(localBytes);
    }

    if (url == null || url.isEmpty) {
      return null;
    }

    final remoteBytes = await fetchAnitabiImageBytes(
      url,
      source: imageSource,
      timeout: const Duration(seconds: 5),
      maxBytes: maxImageEncodedBytes,
    );
    if (remoteBytes == null) {
      return null;
    }
    return decodeImageAspectRatio(Uint8List.fromList(remoteBytes));
  } catch (_) {
    return null;
  }
}

Future<double?> decodeImageAspectRatio(Uint8List bytes) async {
  try {
    final image = await probeBoundedImage(bytes);
    if (image.width <= 0 || image.height <= 0) {
      return null;
    }
    return image.width / image.height;
  } catch (_) {
    return null;
  }
}

/// The camera always shows the full-resolution Anitabi image.
String cameraReferenceFullResolutionDisplayUrl(String url) {
  return anitabiFullResolutionImageUrl(url) ?? url;
}

/// Zoom range the slider uses: the settings range intersected with the
/// device range; the device range when the intersection is empty.
(double, double) effectiveCameraZoomRange({
  required double deviceMinZoom,
  required double deviceMaxZoom,
  required AppSettings settings,
}) {
  final minZoom = math.max(deviceMinZoom, settings.cameraMinZoom);
  final maxZoom = math.min(deviceMaxZoom, settings.cameraMaxZoom);
  if (maxZoom <= minZoom) {
    return (deviceMinZoom, deviceMaxZoom);
  }
  return (minZoom, maxZoom);
}

/// Old zoom label: `1.0x`, `12x`.
String formatCameraZoom(double realZoom) {
  return '${realZoom.toStringAsFixed(realZoom < 10 ? 1 : 0)}x';
}

/// Quick zoom stops (DESIGN §10 Δ11) derived from the usable range: the
/// ultra-wide minimum when it is below 1×, then 1× / 2× / 3× / 5× / 10×
/// while they fit. At most five; empty when fewer than two fit.
List<double> cameraZoomPresets({
  required double minZoom,
  required double maxZoom,
}) {
  if (!minZoom.isFinite || !maxZoom.isFinite || maxZoom <= minZoom) {
    return const [];
  }
  const tolerance = 0.01;
  final presets = <double>[];
  if (minZoom < 0.95) {
    // Round up so the stop is always reachable (0.55 → 0.6).
    final wide = (minZoom * 10).ceil() / 10;
    presets.add(wide.clamp(minZoom, maxZoom).toDouble());
  }
  for (final stop in const [1.0, 2.0, 3.0, 5.0, 10.0]) {
    if (stop >= minZoom - tolerance && stop <= maxZoom + tolerance) {
      if (presets.every((p) => (p - stop).abs() > 0.05)) presets.add(stop);
    }
  }
  if (presets.length < 2) return const [];
  return presets.take(5).toList(growable: false);
}

/// Chip label for a preset: `0.6×`, `1×`, `2×`.
String formatZoomPreset(double zoom) {
  if (zoom < 1) return '${zoom.toStringAsFixed(1)}×';
  return zoom == zoom.roundToDouble()
      ? '${zoom.toInt()}×'
      : '${zoom.toStringAsFixed(1)}×';
}

/// Slider position (0…1, 1× at the midpoint when the range spans it) for
/// [realZoom].
double zoomSliderValue({
  required double minZoom,
  required double maxZoom,
  required double realZoom,
}) => cameraZoomSliderValueFromRealZoom(
  minZoom: minZoom,
  maxZoom: maxZoom,
  realZoom: realZoom,
);

double realZoomForSlider({
  required double minZoom,
  required double maxZoom,
  required double sliderValue,
}) => realZoomFromCameraSliderValue(
  minZoom: minZoom,
  maxZoom: maxZoom,
  sliderValue: sliderValue,
);
