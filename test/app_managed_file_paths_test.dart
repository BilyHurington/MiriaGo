import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/data/app_managed_file_paths_io.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform({
    required this.documentsPath,
    required this.supportPath,
  });

  final String documentsPath;
  final String supportPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => documentsPath;

  @override
  Future<String?> getApplicationSupportPath() async => supportPath;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDirectory;
  late String documentsPath;
  late String supportPath;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'miriago_managed_paths_',
    );
    documentsPath = p.join(tempDirectory.path, 'Documents');
    supportPath = p.join(tempDirectory.path, 'files');
    PathProviderPlatform.instance = _FakePathProviderPlatform(
      documentsPath: documentsPath,
      supportPath: supportPath,
    );
    setAppManagedFileBaseDirectoriesForTesting(null);
  });

  tearDown(() async {
    setAppManagedFileBaseDirectoriesForTesting(null);
    if (tempDirectory.existsSync()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('rebases old iOS Documents visit photo path', () async {
    final currentPhoto = File(
      p.join(documentsPath, 'visit_record_images', 'legacy.jpg'),
    );
    await currentPhoto.parent.create(recursive: true);
    await currentPhoto.writeAsBytes(<int>[1, 2, 3], flush: true);

    final resolution = await resolveAppManagedFilePath(
      '/var/mobile/Containers/Data/Application/OLD/Documents/'
      'visit_record_images/legacy.jpg',
    );

    expect(resolution.exists, isTrue);
    expect(resolution.rebased, isTrue);
    expect(resolution.resolvedPath, currentPhoto.path);
  });

  test('rebases old Android files visit photo path', () async {
    final currentPhoto = File(
      p.join(supportPath, 'visit_record_images', 'native.jpg'),
    );
    await currentPhoto.parent.create(recursive: true);
    await currentPhoto.writeAsBytes(<int>[4, 5, 6], flush: true);

    final resolution = await resolveAppManagedFilePath(
      '/data/user/0/app.miriago.miriago/files/visit_record_images/native.jpg',
    );

    expect(resolution.exists, isTrue);
    expect(resolution.rebased, isTrue);
    expect(resolution.resolvedPath, currentPhoto.path);
  });

  test(
    'keeps missing managed path unresolved without clearing original',
    () async {
      final resolution = await resolveAppManagedFilePath(
        '/var/mobile/Containers/Data/Application/OLD/Documents/'
        'graded_photos/missing.jpg',
      );

      expect(resolution.exists, isFalse);
      expect(resolution.rebased, isFalse);
      expect(resolution.resolvedPath, isNull);
      expect(resolution.originalPath, contains('graded_photos/missing.jpg'));
    },
  );
}
