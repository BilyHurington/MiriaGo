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

    expect(manifest['appVersion'], '1.1.0+6');
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
    expect(
      recordJson['visitPhotoAsset'],
      'assets/visit_photos/${recordWithGrading.id}.jpg',
    );
    expect(
      recordJson['gradedPhotoAsset'],
      'assets/graded_photos/${recordWithGrading.id}.jpg',
    );
  });

  test(
    'uses thumbnail and full image URLs for remote reference fallbacks',
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
          return utf8.encode(url.contains('plan=h160') ? 'thumbnail' : 'full');
        },
      );

      final archive = ZipDecoder().decodeBytes(package.bytes);
      final thumbnail = archive
          .findFile('assets/thumbnails/${firstPoint.id}.jpg')!
          .readBytes()!;
      final fullReference = archive
          .findFile('assets/full_references/${firstPoint.id}.jpg')!
          .readBytes()!;

      expect(requestedUrls, [
        'https://image.anitabi.cn/user/1144/bangumi/484761/points/id.jpg?plan=h160',
        'https://image.anitabi.cn/user/1144/bangumi/484761/points/id.jpg',
      ]);
      expect(utf8.decode(thumbnail), 'thumbnail');
      expect(utf8.decode(fullReference), 'full');
    },
  );
}
