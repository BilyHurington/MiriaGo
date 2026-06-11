import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/data/sample_pilgrimage_repository.dart';
import 'package:miriago/desktop/desktop_repository_state.dart';
import 'package:miriago/plan/pilgrimage_models.dart';

void main() {
  test('desktop repository state round-trips sample data', () async {
    final repository = SamplePilgrimageRepository();
    await repository.saveAppSettings(
      const AppSettings(
        uiScale: 1.25,
        cameraCaptureAspectRatio: CameraPhotoAspectRatio.landscape16x9,
        themePalette: AppThemePalette.miriaYellow,
        mapTileProvider: MapTileProvider.customMapLibreStyle,
        customXyzTileUrl: 'https://example.com/{z}/{x}/{y}.png',
        customMapLibreStyleUrl: 'https://example.com/style.json',
        saveVisitPhotoToGallery: false,
      ),
    );
    final source = repository.snapshot();

    final encoded = encodeDesktopRepositoryState(source);
    final decoded = decodeDesktopRepositoryState(encoded);

    expect(decoded, isNotNull);
    expect(decoded!.activePlanId, source.activePlanId);
    expect(decoded.settings.uiScale, 1.25);
    expect(
      decoded.settings.cameraCaptureAspectRatio,
      CameraPhotoAspectRatio.landscape16x9,
    );
    expect(decoded.settings.themePalette, AppThemePalette.miriaYellow);
    expect(
      decoded.settings.mapTileProvider,
      MapTileProvider.customMapLibreStyle,
    );
    expect(
      decoded.settings.customXyzTileUrl,
      'https://example.com/{z}/{x}/{y}.png',
    );
    expect(
      decoded.settings.customMapLibreStyleUrl,
      'https://example.com/style.json',
    );
    expect(decoded.settings.saveVisitPhotoToGallery, isFalse);
    expect(decoded.plans.single.id, source.plans.single.id);
    expect(
      decoded.plans.single.points.length,
      source.plans.single.points.length,
    );
    expect(
      decoded.visitRecords.map((record) => record.id),
      source.visitRecords.map((record) => record.id),
    );
  });
}
