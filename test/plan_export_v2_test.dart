import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/app_version.dart';
import 'package:miriago/data/sample_pilgrimage_repository.dart';
import 'package:miriago/plan/pilgrimage_models.dart';
import 'package:miriago/plan/reference_full_cache_runner.dart';
import 'package:miriago/plan_transfer/plan_export_v2.dart';
import 'package:miriago/plan_transfer/plan_export_size_estimator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('exports bundled reference assets and record photos', () async {
    final repository = SamplePilgrimageRepository();
    final plan = await repository.loadActivePlan();
    final records = await repository.loadVisitRecords(plan.id);
    final recordWithGrading = records.firstWhere(
      (record) => record.gradedPhotoPath != null,
    );
    final firstPoint = plan.points.first;
    final exportPlan = plan.copyWith(
      points: [
        PilgrimagePoint(
          id: firstPoint.id,
          work: firstPoint.work,
          name: firstPoint.name,
          subtitle: firstPoint.subtitle,
          position: firstPoint.position,
          episodeLabel: firstPoint.episodeLabel,
          referenceLabel: firstPoint.referenceLabel,
          source: firstPoint.source,
          sourceId: firstPoint.sourceId,
          referenceImageUrl: firstPoint.referenceImageUrl,
          referenceThumbnailPath: 'docs/sample_images/铃音-记录详情页面-调色前.jpg',
          referenceFullImagePath: 'docs/sample_images/铃音-记录详情页面-调色后.jpg',
          sourceUrl: firstPoint.sourceUrl,
          note: '翻修后外观已有变化',
          groupId: firstPoint.groupId,
          groupOrderIndex: firstPoint.groupOrderIndex,
        ),
      ],
    );

    final package = await buildPlanExportV2Package(
      plan: exportPlan,
      visitRecords: [recordWithGrading],
      options: const PlanExportV2Options(
        mode: PlanExportV2Mode.planWithRecords,
        includeFullReferenceCache: true,
      ),
    );

    final archive = ZipDecoder().decodeBytes(package.bytes);
    final manifest =
        jsonDecode(utf8.decode(archive.findFile('manifest.json')!.readBytes()!))
            as Map<String, Object?>;
    final planJson =
        jsonDecode(utf8.decode(archive.findFile('plan.json')!.readBytes()!))
            as Map<String, Object?>;
    final planRoot = planJson['plan'] as Map<String, Object?>;
    final points = planRoot['points'] as List<Object?>;
    final visitRecords = planJson['visitRecords'] as List<Object?>;
    final pointJson = points.single as Map<String, Object?>;
    final recordJson = visitRecords.single as Map<String, Object?>;
    final assetCounts = manifest['assetCounts'] as Map<String, Object?>;

    expect(manifest['appVersion'], miriagoAppVersion);
    expect(archive.files.any((file) => file.name.startsWith('assets/')), true);
    expect(assetCounts['thumbnails'], 1);
    expect(assetCounts['fullReferences'], 1);
    expect(assetCounts['visitPhotos'], 1);
    expect(assetCounts['gradedPhotos'], 1);
    expect(
      pointJson['referenceThumbnailAsset'],
      'assets/thumbnails/${firstPoint.id}.jpg',
    );
    expect(
      pointJson['referenceFullReferenceAsset'],
      'assets/full_references/${firstPoint.id}.jpg',
    );
    expect(pointJson['note'], '翻修后外观已有变化');
    expect(
      recordJson['visitPhotoAsset'],
      'assets/visit_photos/${recordWithGrading.id}.jpg',
    );
    expect(
      recordJson['gradedPhotoAsset'],
      'assets/graded_photos/${recordWithGrading.id}.jpg',
    );
    expect(recordJson['workTitle'], recordWithGrading.workTitle);
    expect(recordJson['pointName'], recordWithGrading.pointName);
  });

  test(
    'plan export keeps thumbnails local but downloads requested full refs',
    () async {
      final repository = SamplePilgrimageRepository();
      final plan = await repository.loadActivePlan();
      final firstPoint = plan.points.first;
      const referenceUrl =
          'https://image.anitabi.cn/user/1144/bangumi/484761/points/id.jpg?plan=w300';
      final exportPlan = plan.copyWith(
        points: [
          PilgrimagePoint(
            id: firstPoint.id,
            work: firstPoint.work,
            name: firstPoint.name,
            subtitle: firstPoint.subtitle,
            position: firstPoint.position,
            episodeLabel: firstPoint.episodeLabel,
            referenceLabel: firstPoint.referenceLabel,
            source: firstPoint.source,
            sourceId: firstPoint.sourceId,
            referenceImageUrl: referenceUrl,
            sourceUrl: firstPoint.sourceUrl,
            groupId: firstPoint.groupId,
            groupOrderIndex: firstPoint.groupOrderIndex,
          ),
        ],
      );
      final requestedUrls = <String>[];

      final package = await buildPlanExportV2Package(
        plan: exportPlan,
        visitRecords: const [],
        options: const PlanExportV2Options(
          mode: PlanExportV2Mode.planOnly,
          includeFullReferenceCache: true,
        ),
        networkBytesReader: (url) async {
          requestedUrls.add(url);
          return _jpegBytes;
        },
      );

      final archive = ZipDecoder().decodeBytes(package.bytes);
      final manifest =
          jsonDecode(
                utf8.decode(archive.findFile('manifest.json')!.readBytes()!),
              )
              as Map<String, Object?>;
      final planJson =
          jsonDecode(utf8.decode(archive.findFile('plan.json')!.readBytes()!))
              as Map<String, Object?>;
      final planRoot = planJson['plan'] as Map<String, Object?>;
      final points = planRoot['points'] as List<Object?>;
      final pointJson = points.single as Map<String, Object?>;
      final assetCounts = manifest['assetCounts'] as Map<String, Object?>;

      expect(requestedUrls, [
        'https://image.anitabi.cn/user/1144/bangumi/484761/points/id.jpg',
      ]);
      expect(
        archive.findFile('assets/thumbnails/${firstPoint.id}.jpg'),
        isNull,
      );
      expect(
        archive.findFile('assets/full_references/${firstPoint.id}.jpg'),
        isNotNull,
      );
      expect(assetCounts['thumbnails'], 0);
      expect(assetCounts['fullReferences'], 1);
      expect(pointJson['referenceThumbnailAsset'], isNull);
      expect(
        pointJson['referenceFullReferenceAsset'],
        'assets/full_references/${firstPoint.id}.jpg',
      );
      expect(
        package.warningCounts[PlanExportWarningType.thumbnailMissing.key],
        1,
      );
    },
  );

  test('plan export skips full reference downloads unless requested', () async {
    final repository = SamplePilgrimageRepository();
    final plan = await repository.loadActivePlan();
    final firstPoint = plan.points.first;
    const referenceUrl =
        'https://image.anitabi.cn/user/1144/bangumi/484761/points/id.jpg?plan=w300';
    final exportPlan = plan.copyWith(
      points: [
        PilgrimagePoint(
          id: firstPoint.id,
          work: firstPoint.work,
          name: firstPoint.name,
          subtitle: firstPoint.subtitle,
          position: firstPoint.position,
          episodeLabel: firstPoint.episodeLabel,
          referenceLabel: firstPoint.referenceLabel,
          source: firstPoint.source,
          sourceId: firstPoint.sourceId,
          referenceImageUrl: referenceUrl,
          sourceUrl: firstPoint.sourceUrl,
          groupId: firstPoint.groupId,
          groupOrderIndex: firstPoint.groupOrderIndex,
        ),
      ],
    );
    final requestedUrls = <String>[];

    final package = await buildPlanExportV2Package(
      plan: exportPlan,
      visitRecords: const [],
      options: const PlanExportV2Options(
        mode: PlanExportV2Mode.planOnly,
        includeFullReferenceCache: false,
      ),
      networkBytesReader: (url) async {
        requestedUrls.add(url);
        return utf8.encode('unexpected network bytes');
      },
    );

    final archive = ZipDecoder().decodeBytes(package.bytes);
    final manifest =
        jsonDecode(utf8.decode(archive.findFile('manifest.json')!.readBytes()!))
            as Map<String, Object?>;
    final assetCounts = manifest['assetCounts'] as Map<String, Object?>;

    expect(requestedUrls, isEmpty);
    expect(archive.findFile('assets/thumbnails/${firstPoint.id}.jpg'), isNull);
    expect(
      archive.findFile('assets/full_references/${firstPoint.id}.jpg'),
      isNull,
    );
    expect(assetCounts['thumbnails'], 0);
    expect(assetCounts['fullReferences'], 0);
    expect(
      package.warningCounts[PlanExportWarningType.thumbnailMissing.key],
      1,
    );
    expect(
      package.warningCounts[PlanExportWarningType
          .fullReferenceDownloadFailed
          .key],
      isNull,
    );
  });

  test(
    'plan export warns when requested full reference download fails',
    () async {
      final repository = SamplePilgrimageRepository();
      final plan = await repository.loadActivePlan();
      final firstPoint = plan.points.first;
      const referenceUrl =
          'https://image.anitabi.cn/user/1144/bangumi/484761/points/id.jpg?plan=w300';
      final exportPlan = plan.copyWith(
        points: [
          firstPoint.copyWith(
            referenceImageUrl: referenceUrl,
            referenceThumbnailPath: null,
            referenceFullImagePath: null,
          ),
        ],
      );

      final package = await buildPlanExportV2Package(
        plan: exportPlan,
        visitRecords: const [],
        options: const PlanExportV2Options(
          mode: PlanExportV2Mode.planOnly,
          includeFullReferenceCache: true,
        ),
        networkBytesReader: (_) async => null,
      );

      final archive = ZipDecoder().decodeBytes(package.bytes);
      final manifest =
          jsonDecode(
                utf8.decode(archive.findFile('manifest.json')!.readBytes()!),
              )
              as Map<String, Object?>;
      final warningCounts = manifest['warningCounts'] as Map<String, Object?>;
      final assetCounts = manifest['assetCounts'] as Map<String, Object?>;

      expect(assetCounts['thumbnails'], 0);
      expect(assetCounts['fullReferences'], 0);
      expect(warningCounts[PlanExportWarningType.thumbnailMissing.key], 1);
      expect(
        warningCounts[PlanExportWarningType.fullReferenceDownloadFailed.key],
        1,
      );
      expect(
        package.warnings,
        contains(contains('full reference download failed')),
      );
    },
  );

  test(
    'local uploaded references with stale remote url do not download fallback assets',
    () async {
      final tempDirectory = await Directory.systemTemp.createTemp(
        'miriago_user_reference_',
      );
      addTearDown(() async {
        if (tempDirectory.existsSync()) {
          await tempDirectory.delete(recursive: true);
        }
      });
      final fullDirectory = Directory(
        '${tempDirectory.path}/user_reference_images/full',
      )..createSync(recursive: true);
      final thumbDirectory = Directory(
        '${tempDirectory.path}/user_reference_images/thumb',
      )..createSync(recursive: true);
      final fullFile = File('${fullDirectory.path}/point-1.jpg')
        ..writeAsBytesSync(_jpegBytes);
      final thumbFile = File('${thumbDirectory.path}/point-1.jpg')
        ..writeAsBytesSync(_jpegBytes);

      final repository = SamplePilgrimageRepository();
      final plan = await repository.loadActivePlan();
      final firstPoint = plan.points.first;
      const staleReferenceUrl =
          'https://image.anitabi.cn/user/1144/bangumi/484761/points/stale.jpg?plan=w300';
      final mixedPoint = firstPoint.copyWith(
        source: PointSource.anitabi,
        referenceImageUrl: staleReferenceUrl,
        referenceThumbnailPath: thumbFile.path,
        referenceFullImagePath: fullFile.path,
      );
      final exportPlan = plan.copyWith(points: [mixedPoint]);
      final requestedUrls = <String>[];

      final package = await buildPlanExportV2Package(
        plan: exportPlan,
        visitRecords: const [],
        options: const PlanExportV2Options(
          mode: PlanExportV2Mode.planOnly,
          includeFullReferenceCache: true,
        ),
        networkBytesReader: (url) async {
          requestedUrls.add(url);
          return _jpegBytes;
        },
      );

      final archive = ZipDecoder().decodeBytes(package.bytes);
      final manifest =
          jsonDecode(
                utf8.decode(archive.findFile('manifest.json')!.readBytes()!),
              )
              as Map<String, Object?>;
      final planJson =
          jsonDecode(utf8.decode(archive.findFile('plan.json')!.readBytes()!))
              as Map<String, Object?>;
      final planRoot = planJson['plan'] as Map<String, Object?>;
      final points = planRoot['points'] as List<Object?>;
      final pointJson = points.single as Map<String, Object?>;
      final assetCounts = manifest['assetCounts'] as Map<String, Object?>;

      expect(requestedUrls, isEmpty);
      expect(pointsNeedingFullReferenceCache([mixedPoint]), isEmpty);
      expect(assetCounts['thumbnails'], 1);
      expect(assetCounts['userReferenceImages'], 1);
      expect(assetCounts['fullReferences'], 0);
      expect(
        archive.findFile('assets/thumbnails/${firstPoint.id}.jpg'),
        isNotNull,
      );
      expect(
        archive.findFile('assets/user_references/${firstPoint.id}.jpg'),
        isNotNull,
      );
      expect(
        archive.findFile('assets/full_references/${firstPoint.id}.jpg'),
        isNull,
      );
      expect(pointJson['referenceImageUrl'], isNull);
      expect(
        pointJson['referenceThumbnailAsset'],
        'assets/thumbnails/${firstPoint.id}.jpg',
      );
      expect(
        pointJson['userReferenceAsset'],
        'assets/user_references/${firstPoint.id}.jpg',
      );
      expect(pointJson['referenceFullReferenceAsset'], isNull);

      final estimate = await estimatePlanExportV2Size(
        plan: exportPlan,
        visitRecords: const [],
        options: const PlanExportV2Options(
          mode: PlanExportV2Mode.planOnly,
          includeFullReferenceCache: true,
        ),
      );
      expect(estimate.missingThumbnailCount, 0);
      expect(estimate.missingFullReferenceCount, 0);
      expect(estimate.missingUserReferenceCount, 0);
      expect(estimate.hasUnknownLocalAssets, isFalse);
    },
  );

  test(
    'plan export warns when local uploaded reference file is missing',
    () async {
      final repository = SamplePilgrimageRepository();
      final plan = await repository.loadActivePlan();
      final firstPoint = plan.points.first.copyWith(
        source: PointSource.manual,
        referenceImageUrl: null,
        referenceThumbnailPath: '/missing/user_reference_images/thumb.jpg',
        referenceFullImagePath: '/missing/user_reference_images/full.jpg',
      );
      final exportPlan = plan.copyWith(points: [firstPoint]);

      final package = await buildPlanExportV2Package(
        plan: exportPlan,
        visitRecords: const [],
        options: const PlanExportV2Options(
          mode: PlanExportV2Mode.planOnly,
          includeFullReferenceCache: true,
        ),
      );

      final archive = ZipDecoder().decodeBytes(package.bytes);
      final manifest =
          jsonDecode(
                utf8.decode(archive.findFile('manifest.json')!.readBytes()!),
              )
              as Map<String, Object?>;
      final warningCounts = manifest['warningCounts'] as Map<String, Object?>;
      final assetCounts = manifest['assetCounts'] as Map<String, Object?>;

      expect(assetCounts['thumbnails'], 0);
      expect(assetCounts['userReferenceImages'], 0);
      expect(warningCounts[PlanExportWarningType.thumbnailMissing.key], 1);
      expect(warningCounts[PlanExportWarningType.userReferenceMissing.key], 1);

      final estimate = await estimatePlanExportV2Size(
        plan: exportPlan,
        visitRecords: const [],
        options: const PlanExportV2Options(
          mode: PlanExportV2Mode.planOnly,
          includeFullReferenceCache: true,
        ),
      );
      expect(estimate.missingThumbnailCount, 1);
      expect(estimate.missingUserReferenceCount, 1);
      expect(estimate.hasMissingCriticalAssets, isTrue);
    },
  );

  test('exports works with Bangumi subject types', () async {
    final now = DateTime(2026, 6, 18, 12);
    final plan = PilgrimagePlan(
      id: 'typed-works-plan',
      name: '分类作品计划',
      area: '测试地区',
      works: const [
        PilgrimageWork(
          id: 'anime-work',
          bangumiId: 1,
          bangumiSubjectType: BangumiSubjectType.anime,
          title: '动画作品',
          subtitle: 'Anime',
          city: '动画 / 2026',
          source: WorkSource.bangumi,
        ),
        PilgrimageWork(
          id: 'game-work',
          bangumiId: 2,
          bangumiSubjectType: BangumiSubjectType.game,
          title: '游戏作品',
          subtitle: 'Game',
          city: '游戏 / 2026',
          source: WorkSource.bangumi,
        ),
        PilgrimageWork(
          id: 'book-work',
          bangumiId: 3,
          bangumiSubjectType: BangumiSubjectType.book,
          title: '书籍作品',
          subtitle: 'Book',
          city: '书籍 / 2026',
          source: WorkSource.bangumi,
        ),
      ],
      points: const [],
      createdAt: now,
      updatedAt: now,
    );

    final package = await buildPlanExportV2Package(
      plan: plan,
      visitRecords: const [],
      options: const PlanExportV2Options(
        mode: PlanExportV2Mode.planOnly,
        includeFullReferenceCache: false,
      ),
      exportedAt: now,
    );

    final archive = ZipDecoder().decodeBytes(package.bytes);
    final planJson =
        jsonDecode(utf8.decode(archive.findFile('plan.json')!.readBytes()!))
            as Map<String, Object?>;
    final planRoot = planJson['plan'] as Map<String, Object?>;
    final works = planRoot['works'] as List<Object?>;

    expect(works.map((work) => (work as Map)['bangumiSubjectType']), [
      'anime',
      'game',
      'book',
    ]);
  });

  test(
    'plan export rejects non-image local cache and retries remote reference',
    () async {
      final tempDirectory = await Directory.systemTemp.createTemp(
        'miriago_bad_reference_',
      );
      addTearDown(() async {
        if (tempDirectory.existsSync()) {
          await tempDirectory.delete(recursive: true);
        }
      });
      final badFullFile = File('${tempDirectory.path}/bad-full.jpg')
        ..writeAsBytesSync(_htmlBytes);

      final repository = SamplePilgrimageRepository();
      final plan = await repository.loadActivePlan();
      final firstPoint = plan.points.first.copyWith(
        referenceImageUrl: 'https://image.anitabi.cn/points/1/full.jpg',
        referenceThumbnailPath: null,
        referenceFullImagePath: badFullFile.path,
      );
      final requestedUrls = <String>[];

      final package = await buildPlanExportV2Package(
        plan: plan.copyWith(points: [firstPoint]),
        visitRecords: const [],
        options: const PlanExportV2Options(
          mode: PlanExportV2Mode.planOnly,
          includeFullReferenceCache: true,
        ),
        networkBytesReader: (url) async {
          requestedUrls.add(url);
          return _jpegBytes;
        },
      );

      final archive = ZipDecoder().decodeBytes(package.bytes);
      final fullAsset = archive.findFile(
        'assets/full_references/${firstPoint.id}.jpg',
      );

      expect(requestedUrls, ['https://image.anitabi.cn/points/1/full.jpg']);
      expect(fullAsset, isNotNull);
      expect(fullAsset!.readBytes(), _jpegBytes);
    },
  );

  test('plan export rejects non-image remote reference response', () async {
    final repository = SamplePilgrimageRepository();
    final plan = await repository.loadActivePlan();
    final firstPoint = plan.points.first.copyWith(
      referenceImageUrl: 'https://image.anitabi.cn/points/1/full.jpg',
      referenceThumbnailPath: null,
      referenceFullImagePath: null,
      source: PointSource.anitabi,
    );

    final package = await buildPlanExportV2Package(
      plan: plan.copyWith(points: [firstPoint]),
      visitRecords: const [],
      options: const PlanExportV2Options(
        mode: PlanExportV2Mode.planOnly,
        includeFullReferenceCache: true,
      ),
      networkBytesReader: (_) async => _htmlBytes,
    );

    final archive = ZipDecoder().decodeBytes(package.bytes);
    final manifest =
        jsonDecode(utf8.decode(archive.findFile('manifest.json')!.readBytes()!))
            as Map<String, Object?>;
    final assetCounts = manifest['assetCounts'] as Map<String, Object?>;

    expect(
      archive.findFile('assets/full_references/${firstPoint.id}.jpg'),
      isNull,
    );
    expect(assetCounts['fullReferences'], 0);
    expect(
      package.warningCounts[PlanExportWarningType
          .fullReferenceDownloadFailed
          .key],
      1,
    );
  });
}

const _jpegBytes = <int>[0xFF, 0xD8, 0xFF, 0xD9];
final _htmlBytes = utf8.encode(
  '<!DOCTYPE html><html><body>MiriaGo</body></html>',
);
