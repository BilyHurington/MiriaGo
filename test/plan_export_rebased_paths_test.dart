import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:miriago/data/app_managed_file_paths_io.dart';
import 'package:miriago/plan/pilgrimage_models.dart';
import 'package:miriago/plan_transfer/plan_export_v2.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this.documentsPath);

  final String documentsPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => documentsPath;

  @override
  Future<String?> getApplicationSupportPath() async =>
      p.join(p.dirname(documentsPath), 'files');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDirectory;
  late String documentsPath;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'miriago_export_rebased_',
    );
    documentsPath = p.join(tempDirectory.path, 'Documents');
    PathProviderPlatform.instance = _FakePathProviderPlatform(documentsPath);
    setAppManagedFileBaseDirectoriesForTesting(null);
  });

  tearDown(() async {
    setAppManagedFileBaseDirectoriesForTesting(null);
    if (tempDirectory.existsSync()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('exports visit photo from rebased old app container path', () async {
    final currentPhoto = File(
      p.join(documentsPath, 'visit_record_images', 'legacy-photo.jpg'),
    );
    await currentPhoto.parent.create(recursive: true);
    await currentPhoto.writeAsBytes(_minimalJpegBytes(), flush: true);

    const work = PilgrimageWork(
      id: 'work-1',
      title: '测试作品',
      subtitle: '测试副标题',
      city: '测试市',
      source: WorkSource.manual,
    );
    const point = PilgrimagePoint(
      id: 'point-1',
      work: work,
      name: '测试点位',
      subtitle: '测试地点',
      position: LatLng(35, 135),
      episodeLabel: 'EP 1',
      referenceLabel: '手动',
      source: PointSource.manual,
    );
    final plan = PilgrimagePlan(
      id: 'plan-1',
      name: '路径修复计划',
      area: '测试市',
      works: const [work],
      points: const [point],
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    final record = PilgrimageVisitRecord(
      id: 'record-1',
      planId: plan.id,
      pointId: point.id,
      workId: work.id,
      photoPath:
          '/var/mobile/Containers/Data/Application/OLD/Documents/'
          'visit_record_images/legacy-photo.jpg',
      referenceMode: '上下',
      capturedAt: DateTime(2026),
    );

    final package = await buildPlanExportV2Package(
      plan: plan,
      visitRecords: [record],
      options: const PlanExportV2Options(
        mode: PlanExportV2Mode.planWithRecords,
        includeFullReferenceCache: false,
      ),
    );

    final archive = ZipDecoder().decodeBytes(package.bytes);
    expect(
      archive.files.any(
        (file) => file.name == 'assets/visit_photos/record-1.jpg',
      ),
      isTrue,
    );
    expect(package.warningCounts['visitPhotoMissing'] ?? 0, 0);
  });
}

List<int> _minimalJpegBytes() {
  return const <int>[0xFF, 0xD8, 0xFF, 0xD9];
}
