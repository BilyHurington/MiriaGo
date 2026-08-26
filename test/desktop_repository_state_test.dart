import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/data/sample_pilgrimage_repository.dart';
import 'package:miriago/desktop/desktop_repository_state.dart';
import 'package:miriago/plan/pilgrimage_models.dart';

void main() {
  test('desktop persists plan action outside-tap preference', () {
    final repository = SamplePilgrimageRepository(
      settings: const AppSettings(dismissPlanActionsOnOutsideTap: false),
    );
    final encoded = encodeDesktopRepositoryState(repository.snapshot());

    final decoded = decodeDesktopRepositoryState(encoded);

    expect(decoded, isNotNull);
    expect(decoded!.settings.dismissPlanActionsOnOutsideTap, isFalse);
  });

  test('desktop persists appearance theme mode', () {
    final repository = SamplePilgrimageRepository(
      settings: const AppSettings(themeMode: AppThemeMode.dark),
    );
    final encoded = encodeDesktopRepositoryState(repository.snapshot());

    final decoded = decodeDesktopRepositoryState(encoded);

    expect(decoded, isNotNull);
    expect(decoded!.settings.themeMode, AppThemeMode.dark);
  });

  test('desktop persists sample uji-station zone chain', () {
    final encoded = encodeDesktopRepositoryState(
      SamplePilgrimageRepository().snapshot(),
    );

    final decoded = decodeDesktopRepositoryState(encoded);
    final chain = _ujiStationChain(decoded!.plans.single);

    expect(decoded.plans.single.currentGroupId, 'sample-group-uji-station');
    expect(chain.map((point) => point.name), _ujiStationChainNames);
    expect(chain.map((point) => point.groupOrderIndex), [0, 1, 2, 4, 5, 6]);
    expect(
      chain.map((point) => point.groupId),
      everyElement('sample-group-uji-station'),
    );
  });

  test('desktop repository state round-trips sample data', () async {
    final repository = SamplePilgrimageRepository();
    await repository.saveAppSettings(
      const AppSettings(
        uiScale: 1.25,
        cameraCaptureAspectRatio: CameraPhotoAspectRatio.landscape16x9,
        photoLocationStrategy: PhotoLocationStrategy.waitOnConfirmation,
        themeMode: AppThemeMode.dark,
        themePalette: AppThemePalette.miriaYellow,
        mapTileProvider: MapTileProvider.customMapLibreStyle,
        openFreeMapStyle: OpenFreeMapStyle.fiord,
        anitabiImageSource: AnitabiImageSource.mirror,
        anitabiSiteBaseUrl: 'https://site.example/anitabi',
        anitabiStaticDataBaseUrl: 'https://static.example/data',
        anitabiApiBaseUrl: 'https://api.example/v2',
        anitabiOfficialImageBaseUrl: 'https://images.example/official',
        anitabiMirrorImageBaseUrl: 'https://images.example/mirror',
        customXyzTileUrl: 'https://example.com/{z}/{x}/{y}.png',
        customMapLibreStyleUrl: 'https://example.com/style.json',
        saveVisitPhotoToGallery: false,
        autoSaveComparisonToGallery: true,
        comparisonShowPilgrimName: true,
        comparisonPilgrimName: 'BilyHurington',
        customThemeColorName: '湖蓝',
        customThemeColorValue: 0xFF168AAD,
        customThemeColors: [
          CustomThemeColor(name: '湖蓝', value: 0xFF168AAD),
          CustomThemeColor(name: '莓红', value: 0xFFC43D62),
        ],
        comparisonExportConfigJson: '{"outputWidth":"w1920"}',
        comparisonExportConfigMigrated: true,
        mapThumbnailVisibleThreshold: 55,
        mapThumbnailConcurrentLoads: 12,
        showPlanGroupProgress: false,
        dismissPlanActionsOnOutsideTap: false,
        hideCompletedPointsOnMap: false,
        mapMarkerClusteringEnabled: false,
        mapMarkerClusterRadius: 88,
        mapMarkerClusterMaxZoom: 20,
        mapGroupAreaRadiusMeters: 225,
        mapMarkerScale: 1.1,
        mapMaxZoom: 23,
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
    expect(decoded.settings.dismissPlanActionsOnOutsideTap, isFalse);
    expect(decoded.settings.themeMode, AppThemeMode.dark);
    expect(
      decoded.settings.cameraCaptureAspectRatio,
      CameraPhotoAspectRatio.landscape16x9,
    );
    expect(
      decoded.settings.photoLocationStrategy,
      PhotoLocationStrategy.waitOnConfirmation,
    );
    expect(decoded.settings.themePalette, AppThemePalette.miriaYellow);
    expect(
      decoded.settings.mapTileProvider,
      MapTileProvider.customMapLibreStyle,
    );
    expect(decoded.settings.openFreeMapStyle, OpenFreeMapStyle.fiord);
    expect(decoded.settings.anitabiImageSource, AnitabiImageSource.mirror);
    expect(decoded.settings.anitabiSiteBaseUrl, 'https://site.example/anitabi');
    expect(
      decoded.settings.anitabiStaticDataBaseUrl,
      'https://static.example/data',
    );
    expect(decoded.settings.anitabiApiBaseUrl, 'https://api.example/v2');
    expect(
      decoded.settings.anitabiOfficialImageBaseUrl,
      'https://images.example/official',
    );
    expect(
      decoded.settings.anitabiMirrorImageBaseUrl,
      'https://images.example/mirror',
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
    expect(decoded.settings.autoSaveComparisonToGallery, isTrue);
    expect(decoded.settings.comparisonShowPilgrimName, isTrue);
    expect(decoded.settings.comparisonPilgrimName, 'BilyHurington');
    expect(decoded.settings.customThemeColorName, '湖蓝');
    expect(decoded.settings.customThemeColorValue, 0xFF168AAD);
    expect(decoded.settings.customThemeColors, hasLength(2));
    expect(decoded.settings.customThemeColors[0].name, '湖蓝');
    expect(decoded.settings.customThemeColors[0].value, 0xFF168AAD);
    expect(decoded.settings.customThemeColors[1].name, '莓红');
    expect(decoded.settings.customThemeColors[1].value, 0xFFC43D62);
    expect(
      decoded.settings.comparisonExportConfigJson,
      '{"outputWidth":"w1920"}',
    );
    expect(decoded.settings.comparisonExportConfigMigrated, isTrue);
    expect(decoded.settings.mapThumbnailVisibleThreshold, 55);
    expect(decoded.settings.mapThumbnailConcurrentLoads, 12);
    expect(decoded.settings.showPlanGroupProgress, isFalse);
    expect(decoded.settings.hideCompletedPointsOnMap, isFalse);
    expect(decoded.settings.mapMarkerClusteringEnabled, isFalse);
    expect(decoded.settings.mapMarkerClusterRadius, 88);
    expect(decoded.settings.mapMarkerClusterMaxZoom, 20);
    expect(decoded.settings.mapGroupAreaRadiusMeters, 225);
    expect(decoded.settings.mapMarkerScale, 1.1);
    expect(decoded.settings.mapMaxZoom, 23);
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
      decoded.plans.single.points.map((point) => point.id),
      sourcePlan.points.map((point) => point.id),
    );
    expect(
      decoded.visitRecords.map((record) => record.id),
      source.visitRecords.map((record) => record.id),
    );
  });

  test('desktop repository state preserves plan list order', () async {
    final repository = SamplePilgrimageRepository();
    final second = await repository.createPlan(name: '第二计划', area: '京都');
    final third = await repository.createPlan(name: '第三计划', area: '东京');
    final source = repository.snapshot();
    final reordered = [source.plans.last, source.plans.first, source.plans[1]];
    final encoded = encodeDesktopRepositoryState(
      SamplePilgrimageRepositorySnapshot(
        plans: reordered,
        visitRecords: source.visitRecords,
        settings: source.settings,
        activePlanId: third.id,
      ),
    );

    final decoded = decodeDesktopRepositoryState(encoded);

    expect(decoded, isNotNull);
    expect(decoded!.plans.map((plan) => plan.id), [
      third.id,
      source.plans.first.id,
      second.id,
    ]);
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

    expect(decoded.settings.dismissPlanActionsOnOutsideTap, isTrue);
    expect(point.work.id, 'missing-work');
    expect(point.work.title, '未知作品');
    expect(point.work.title, isNot('不应该被绑定的作品'));
  });
}

const _ujiStationChainNames = [
  '井用机前步行道',
  '宇治桥',
  'JR 宇治站',
  '宇治文化中心 停车场',
  '宇治川河畔',
  '京阪宇治站前',
];

List<PilgrimagePoint> _ujiStationChain(PilgrimagePlan plan) {
  return [
    for (final point in plan.points)
      if (point.groupId == 'sample-group-uji-station') point,
  ]..sort(
    (left, right) =>
        (left.groupOrderIndex ?? 0).compareTo(right.groupOrderIndex ?? 0),
  );
}
