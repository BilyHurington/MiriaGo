import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/camera_reference/camerawesome_reference_screen.dart';
import 'package:miriago/plan/pilgrimage_models.dart';

void main() {
  test('auto capture keeps landscape reference ratio in portrait UI', () {
    final ratio = resolveCameraCaptureAspectRatio(
      referenceAspectRatio: 16 / 9,
      settings: const AppSettings(),
      orientation: Orientation.portrait,
    );

    expect(ratio, closeTo(16 / 9, 0.001));
  });

  test('fixed landscape capture ratio stays landscape in portrait UI', () {
    final ratio = resolveCameraCaptureAspectRatio(
      referenceAspectRatio: null,
      settings: const AppSettings(
        cameraCaptureAspectRatio: CameraPhotoAspectRatio.landscape16x9,
      ),
      orientation: Orientation.portrait,
    );

    expect(ratio, closeTo(16 / 9, 0.001));
  });

  test(
    'native fallback ratio follows portrait UI when no reference exists',
    () {
      final ratio = resolveCameraCaptureAspectRatio(
        referenceAspectRatio: null,
        settings: const AppSettings(
          cameraCaptureAspectRatio: CameraPhotoAspectRatio.auto,
          cameraFallbackAspectRatio: CameraPhotoAspectRatio.native,
        ),
        orientation: Orientation.portrait,
      );

      expect(ratio, closeTo(3 / 4, 0.001));
    },
  );
}
