import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:miriago/data/reference_cache_file_io.dart';
import 'package:miriago/data/reference_image_cache_io.dart';
import 'package:miriago/plan/pilgrimage_models.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this.documentsPath);

  final String documentsPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => documentsPath;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'reuses legacy point-scoped full cache for the same image URL',
    () async {
      final tempDirectory = await Directory.systemTemp.createTemp(
        'miriago_shared_reference_cache_',
      );
      addTearDown(() async {
        if (tempDirectory.existsSync()) {
          await tempDirectory.delete(recursive: true);
        }
      });
      PathProviderPlatform.instance = _FakePathProviderPlatform(
        tempDirectory.path,
      );
      const imageUrl = 'https://image.anitabi.cn/points/shared.jpg';
      final hash = _stableUrlHash(imageUrl);
      final legacyFile = File(
        p.join(tempDirectory.path, 'reference_full', 'old-point_$hash.jpg'),
      );
      await legacyFile.parent.create(recursive: true);
      await legacyFile.writeAsBytes(const <int>[
        0xFF,
        0xD8,
        0xFF,
        0xD9,
      ], flush: true);
      const work = PilgrimageWork(
        id: 'work',
        title: 'Work',
        subtitle: '',
        city: '',
        source: WorkSource.bangumi,
      );
      const point = PilgrimagePoint(
        id: 'new-imported-point',
        work: work,
        name: 'Point',
        subtitle: '',
        position: LatLng(35, 139),
        episodeLabel: '',
        referenceLabel: '',
        source: PointSource.anitabi,
        referenceImageUrl: imageUrl,
      );

      final cachedPath = await cacheReferenceFullImage(point);

      expect(cachedPath, legacyFile.path);
      expect(
        File(
          p.join(tempDirectory.path, 'reference_full', '$hash.jpg'),
        ).existsSync(),
        isFalse,
      );
    },
  );

  test('accepts restored package full reference without URL hash', () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'miriago_imported_reference_cache_',
    );
    addTearDown(() async {
      if (tempDirectory.existsSync()) {
        await tempDirectory.delete(recursive: true);
      }
    });
    final file = File(
      p.join(
        tempDirectory.path,
        'imported_plan_assets',
        'package',
        'assets',
        'full_references',
        'point.jpg',
      ),
    );
    await file.parent.create(recursive: true);
    await file.writeAsBytes(const <int>[0xFF, 0xD8, 0xFF, 0xD9], flush: true);

    expect(
      referenceFullCacheFileIsCurrent(
        path: file.path,
        imageUrl: 'https://image.anitabi.cn/points/reference.jpg',
      ),
      isTrue,
    );
  });

  test('reuses restored package thumbnail without URL hash', () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'miriago_imported_thumbnail_cache_',
    );
    addTearDown(() async {
      if (tempDirectory.existsSync()) {
        await tempDirectory.delete(recursive: true);
      }
    });
    PathProviderPlatform.instance = _FakePathProviderPlatform(
      tempDirectory.path,
    );
    final file = File(
      p.join(
        tempDirectory.path,
        'imported_plan_assets',
        'package',
        'assets',
        'thumbnails',
        'point.jpg',
      ),
    );
    await file.parent.create(recursive: true);
    await file.writeAsBytes(const <int>[0xFF, 0xD8, 0xFF, 0xD9], flush: true);
    const work = PilgrimageWork(
      id: 'work',
      title: 'Work',
      subtitle: '',
      city: '',
      source: WorkSource.bangumi,
    );
    final point = PilgrimagePoint(
      id: 'point',
      work: work,
      name: 'Point',
      subtitle: '',
      position: const LatLng(35, 139),
      episodeLabel: '',
      referenceLabel: '',
      source: PointSource.anitabi,
      referenceImageUrl: 'https://image.anitabi.cn/points/reference.jpg',
      referenceThumbnailPath: file.path,
    );

    expect(await ensureReferenceThumbnailCached(point), file.path);
  });
}

String _stableUrlHash(String value) {
  var hash = 0x811c9dc5;
  for (final codeUnit in value.codeUnits) {
    hash ^= codeUnit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}
