import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/camera_reference/visit_record_confirmation_screen.dart';
import 'package:miriago/plan/pilgrimage_models.dart';

void main() {
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  test('auto gallery backup only runs on supported mobile platforms', () {
    expect(const AppSettings().saveVisitPhotoToGallery, isTrue);

    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(shouldAutoSaveVisitPhotoToGallery(const AppSettings()), isTrue);

    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    expect(shouldAutoSaveVisitPhotoToGallery(const AppSettings()), isFalse);

    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(
      shouldAutoSaveVisitPhotoToGallery(
        const AppSettings(saveVisitPhotoToGallery: false),
      ),
      isFalse,
    );
  });
}
