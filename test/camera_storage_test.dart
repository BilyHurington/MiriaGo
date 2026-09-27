import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/camera_reference/camera_storage_io.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this.documentsPath);

  final String documentsPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => documentsPath;
}

void main() {
  late Directory tempDirectory;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('miriago_camera_');
    PathProviderPlatform.instance = _FakePathProviderPlatform(
      p.join(tempDirectory.path, 'documents'),
    );
  });

  tearDown(() async {
    if (tempDirectory.existsSync()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test(
    'copies picked visit photo into stable visit record directory',
    () async {
      final source = File(p.join(tempDirectory.path, 'picker-cache.jpg'));
      await source.writeAsBytes(<int>[1, 2, 3, 4], flush: true);

      final storedPath = await copyVisitRecordPhoto(source.path);
      final storedFile = File(storedPath);

      expect(storedPath, isNot(source.path));
      expect(p.basename(p.dirname(storedPath)), 'visit_record_images');
      expect(p.extension(storedPath), '.jpg');
      expect(storedFile.existsSync(), isTrue);
      expect(await storedFile.readAsBytes(), <int>[1, 2, 3, 4]);
    },
  );

  test('builds camera capture path in stable visit record directory', () async {
    final capturePath = await buildVisitRecordPhotoPath(extension: '.png');

    expect(p.basename(p.dirname(capturePath)), 'visit_record_images');
    expect(p.extension(capturePath), '.png');
  });
}
