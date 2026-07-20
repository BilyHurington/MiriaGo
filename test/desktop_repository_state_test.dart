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
        openFreeMapStyle: OpenFreeMapStyle.fiord,
        anitabiImageSource: AnitabiImageSource.mirror,
        customXyzTileUrl: 'https://example.com/{z}/{x}/{y}.png',
        customMapLibreStyleUrl: 'https://example.com/style.json',
        saveVisitPhotoToGallery: false,
        autoSaveComparisonToGallery: true,
        comparisonShowPilgrimName: true,
        comparisonPilgrimName: 'BilyHurington',
        mapThumbnailVisibleThreshold: 55,
        mapThumbnailConcurrentLoads: 12,
      ),
    );
    final source = repository.snapshot();
    final originalWork = source.plans.single.works.first;
    final workWithCover = PilgrimageWork(
      id: originalWork.id,
      bangumiId: originalWork.bangumiId,
      bangumiSubjectType: BangumiSubjectType.anime,
      coverImageUrl: 'https://lain.bgm.tv/r/200/pic/cover/test.jpg',
      title: originalWork.title,
      subtitle: originalWork.subtitle,
      city: originalWork.city,
      source: originalWork.source,
    );
    final sourcePlan = source.plans.single.copyWith(
      memo: '桌面端备忘录',
      works: [workWithCover, ...source.plans.single.works.skip(1)],
    );
    final sourceWithMemo = SamplePilgrimageRepositorySnapshot(
      plans: [sourcePlan],
      visitRecords: source.visitRecords,
      settings: source.settings,
      activePlanId: source.activePlanId,
    );

    final encoded = encodeDesktopRepositoryState(sourceWithMemo);
    final decoded = decodeDesktopRepositoryState(encoded);

    expect(decoded, isNotNull);
    expect(decoded!.activePlanId, source.activePlanId);
    expect(decoded.settings.uiScale, 1.0);
    expect(
      decoded.settings.cameraCaptureAspectRatio,
      CameraPhotoAspectRatio.landscape16x9,
    );
    expect(decoded.settings.themePalette, AppThemePalette.miriaYellow);
    expect(
      decoded.settings.mapTileProvider,
      MapTileProvider.customMapLibreStyle,
    );
    expect(decoded.settings.openFreeMapStyle, OpenFreeMapStyle.fiord);
    expect(decoded.settings.anitabiImageSource, AnitabiImageSource.mirror);
    expect(
      decoded.settings.customXyzTileUrl,
      'https://example.com/{z}/{x}/{y}.png',
    );
    expect(
      decoded.settings.customMapLibreStyleUrl,
      'https://example.com/style.json',
    );
    expect(decoded.settings.saveVisitPhotoToGallery, isFalse);
    expect(decoded.settings.autoSaveComparisonToGallery, isTrue);
    expect(decoded.settings.comparisonShowPilgrimName, isTrue);
    expect(decoded.settings.comparisonPilgrimName, 'BilyHurington');
    expect(decoded.settings.mapThumbnailVisibleThreshold, 55);
    expect(decoded.settings.mapThumbnailConcurrentLoads, 12);
    expect(decoded.plans.single.id, source.plans.single.id);
    expect(decoded.plans.single.memo, '桌面端备忘录');
    expect(
      decoded.plans.single.works.first.coverImageUrl,
      workWithCover.coverImageUrl,
    );
    expect(
      decoded.plans.single.works.first.bangumiSubjectType,
      BangumiSubjectType.anime,
    );
    expect(
      decoded.plans.single.points.length,
      source.plans.single.points.length,
    );
    expect(
      decoded.visitRecords.map((record) => record.id),
      source.visitRecords.map((record) => record.id),
    );
  });

  test('desktop state uses unknown work fallback for missing work ids', () {
    final source = '''
{
  "schemaVersion": 1,
  "activePlanId": "desktop-plan",
  "settings": {},
  "plans": [
    {
      "id": "desktop-plan",
      "name": "桌面计划",
      "area": "测试地区",
      "createdAt": "2026-06-25T00:00:00.000",
      "updatedAt": "2026-06-25T00:00:00.000",
      "completedPointIds": [],
      "works": [
        {
          "id": "known-work",
          "title": "不应该被绑定的作品",
          "subtitle": "",
          "city": "",
          "source": "manual"
        }
      ],
      "groups": [],
      "points": [
        {
          "id": "orphan-point",
          "workId": "missing-work",
          "name": "孤立点位",
          "subtitle": "",
          "latitude": 35.0,
          "longitude": 135.0,
          "episodeLabel": "",
          "referenceLabel": "",
          "source": "manual"
        }
      ]
    }
  ],
  "visitRecords": []
}
''';

    final decoded = decodeDesktopRepositoryState(source);
    final point = decoded!.plans.single.points.single;

    expect(point.work.id, 'missing-work');
    expect(point.work.title, '未知作品');
    expect(point.work.title, isNot('不应该被绑定的作品'));
  });
}
