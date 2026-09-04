import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:miriago/data/reference_cache_cleanup.dart';
import 'package:miriago/data/sample_pilgrimage_repository.dart';
import 'package:miriago/plan/pilgrimage_models.dart';

void main() {
  test(
    'clears downloaded cache while preserving user and imported assets',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'miriago-cache-cleanup-',
      );
      addTearDown(() => root.delete(recursive: true));
      final full = File('${root.path}/reference_full/full.jpg');
      final thumbnail = File('${root.path}/reference_thumbnails/thumb.jpg');
      final uploaded = File('${root.path}/user_reference_images/upload.jpg');
      await full.create(recursive: true);
      await thumbnail.create(recursive: true);
      await uploaded.create(recursive: true);
      await full.writeAsBytes(List.filled(20, 1));
      await thumbnail.writeAsBytes(List.filled(10, 2));
      await uploaded.writeAsBytes(List.filled(30, 3));

      const work = PilgrimageWork(
        id: 'work',
        title: '作品',
        subtitle: '',
        city: '',
        source: WorkSource.manual,
      );
      final plan = PilgrimagePlan(
        id: 'plan',
        name: '计划',
        area: '东京',
        works: const [work],
        points: [
          PilgrimagePoint(
            id: 'downloaded',
            work: work,
            name: '下载缓存',
            subtitle: '',
            position: const LatLng(35, 139),
            episodeLabel: '',
            referenceLabel: '',
            referenceThumbnailPath: thumbnail.path,
            referenceFullImagePath: full.path,
          ),
          PilgrimagePoint(
            id: 'uploaded',
            work: work,
            name: '本地上传',
            subtitle: '',
            position: const LatLng(35.1, 139.1),
            episodeLabel: '',
            referenceLabel: '',
            referenceFullImagePath: uploaded.path,
          ),
          const PilgrimagePoint(
            id: 'imported',
            work: work,
            name: '导入资源',
            subtitle: '',
            position: LatLng(35.2, 139.2),
            episodeLabel: '',
            referenceLabel: '',
            referenceFullImagePath:
                'assets/imported_plan_assets/pkg/assets/full_references/a.jpg',
          ),
        ],
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      final repository = SamplePilgrimageRepository(plans: [plan]);
      final scan = await scanDownloadedReferenceCaches([plan]);
      expect(scan.fileCount, 1);
      expect(scan.byteCount, 20);

      final result = await cleanupDownloadedReferenceCaches(
        repository: repository,
        plans: [plan],
      );
      expect(result.deletedFileCount, 1);
      expect(await full.exists(), isFalse);
      expect(await thumbnail.exists(), isTrue);
      expect(await uploaded.exists(), isTrue);
      final updated = await repository.loadActivePlan();
      expect(updated.points[0].referenceFullImagePath, isNull);
      expect(updated.points[0].referenceThumbnailPath, thumbnail.path);
      expect(updated.points[1].referenceFullImagePath, uploaded.path);
      expect(
        updated.points[2].referenceFullImagePath,
        contains('imported_plan_assets'),
      );
    },
  );

  test(
    'clears stale full-cache metadata when the file is already gone',
    () async {
      const work = PilgrimageWork(
        id: 'work',
        title: '作品',
        subtitle: '',
        city: '',
        source: WorkSource.manual,
      );
      final plan = PilgrimagePlan(
        id: 'plan',
        name: '计划',
        area: '东京',
        works: const [work],
        points: [
          const PilgrimagePoint(
            id: 'stale',
            work: work,
            name: '失效缓存',
            subtitle: '',
            position: LatLng(35, 139),
            episodeLabel: '',
            referenceLabel: '',
            referenceFullImagePath: '/missing/miriago/reference_full/stale.jpg',
          ),
        ],
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      final repository = SamplePilgrimageRepository(plans: [plan]);

      final scan = await scanDownloadedReferenceCaches([plan]);
      expect(scan.fileCount, 1);
      expect(scan.byteCount, 0);

      final result = await cleanupDownloadedReferenceCaches(
        repository: repository,
        plans: [plan],
      );
      expect(result.deletedFileCount, 0);
      expect(result.failedFileCount, 0);
      final updated = await repository.loadActivePlan();
      expect(updated.points.single.referenceFullImagePath, isNull);
    },
  );
}
