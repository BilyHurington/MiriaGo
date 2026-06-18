import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/data/sample_pilgrimage_repository.dart';
import 'package:miriago/plan/pilgrimage_models.dart';
import 'package:miriago/plan_transfer/plan_export_v2.dart';

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

    expect(manifest['appVersion'], '1.1.2+13');
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

  test('plan export fetches remote thumbnail fallback', () async {
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
        return utf8.encode('network bytes for $url');
      },
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
    final pointJson = points.single as Map<String, Object?>;
    final assetCounts = manifest['assetCounts'] as Map<String, Object?>;

    expect(requestedUrls, [
      'https://image.anitabi.cn/user/1144/bangumi/484761/points/id.jpg?plan=h160',
      'https://image.anitabi.cn/user/1144/bangumi/484761/points/id.jpg',
    ]);
    expect(
      archive.findFile('assets/thumbnails/${firstPoint.id}.jpg'),
      isNotNull,
    );
    expect(
      archive.findFile('assets/full_references/${firstPoint.id}.jpg'),
      isNotNull,
    );
    expect(assetCounts['thumbnails'], 1);
    expect(assetCounts['fullReferences'], 1);
    expect(
      pointJson['referenceThumbnailAsset'],
      'assets/thumbnails/${firstPoint.id}.jpg',
    );
    expect(
      pointJson['referenceFullReferenceAsset'],
      'assets/full_references/${firstPoint.id}.jpg',
    );
  });

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

    expect(requestedUrls, [
      'https://image.anitabi.cn/user/1144/bangumi/484761/points/id.jpg?plan=h160',
    ]);
    expect(
      archive.findFile('assets/thumbnails/${firstPoint.id}.jpg'),
      isNotNull,
    );
    expect(
      archive.findFile('assets/full_references/${firstPoint.id}.jpg'),
      isNull,
    );
    expect(assetCounts['thumbnails'], 1);
    expect(assetCounts['fullReferences'], 0);
  });

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
}
