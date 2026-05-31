import 'dart:math' as math;

import 'package:flutter/services.dart';

const double cameraZoomUpperLimit = 20;

class CameraZoomCapabilities {
  const CameraZoomCapabilities({required this.minZoom, required this.maxZoom});

  final double minZoom;
  final double maxZoom;

  static const fallback = CameraZoomCapabilities(minZoom: 0.6, maxZoom: 20);

  static const _channel = MethodChannel('seichi/camera_capabilities');

  static Future<CameraZoomCapabilities> load() async {
    try {
      final result = await _channel.invokeMapMethod<String, Object?>(
        'getBackCameraZoomRange',
      );
      final minZoom = (result?['minZoomRatio'] as num?)?.toDouble();
      final maxZoom = (result?['maxZoomRatio'] as num?)?.toDouble();
      if (minZoom == null || maxZoom == null || maxZoom <= 0) {
        return fallback;
      }
      return CameraZoomCapabilities(
        minZoom: minZoom.clamp(0.1, cameraZoomUpperLimit),
        maxZoom: maxZoom.clamp(1.0, cameraZoomUpperLimit),
      );
    } catch (_) {
      return fallback;
    }
  }
}

double cameraZoomSliderValueFromRealZoom({
  required double minZoom,
  required double maxZoom,
  required double realZoom,
}) {
  final min = minZoom.clamp(0.01, cameraZoomUpperLimit);
  final max = maxZoom.clamp(min, cameraZoomUpperLimit);
  final zoom = realZoom.clamp(min, max);
  final pivot = 1.0.clamp(min, max);
  if (max <= min) {
    return 0.5;
  }

  if (min < 1 && max > 1) {
    if (zoom <= pivot) {
      return 0.5 * _logProgress(min, pivot, zoom);
    }
    return 0.5 + 0.5 * _logProgress(pivot, max, zoom);
  }

  return _logProgress(min, max, zoom);
}

double realZoomFromCameraSliderValue({
  required double minZoom,
  required double maxZoom,
  required double sliderValue,
}) {
  final min = minZoom.clamp(0.01, cameraZoomUpperLimit);
  final max = maxZoom.clamp(min, cameraZoomUpperLimit);
  final value = sliderValue.clamp(0.0, 1.0);
  if (max <= min) {
    return min;
  }

  if (min < 1 && max > 1) {
    if (value <= 0.5) {
      return _logLerp(min, 1, value / 0.5);
    }
    return _logLerp(1, max, (value - 0.5) / 0.5);
  }

  return _logLerp(min, max, value);
}

double _logProgress(double min, double max, double value) {
  final safeMin = min.clamp(0.01, cameraZoomUpperLimit);
  final safeMax = max.clamp(safeMin, cameraZoomUpperLimit);
  if (safeMax <= safeMin) {
    return 0;
  }
  return (math.log(value.clamp(safeMin, safeMax) / safeMin) /
          math.log(safeMax / safeMin))
      .clamp(0.0, 1.0);
}

double _logLerp(double min, double max, double value) {
  final safeMin = min.clamp(0.01, cameraZoomUpperLimit);
  final safeMax = max.clamp(safeMin, cameraZoomUpperLimit);
  if (safeMax <= safeMin) {
    return safeMin;
  }
  return safeMin *
      math.pow(safeMax / safeMin, value.clamp(0.0, 1.0)).toDouble();
}
