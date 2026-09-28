import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/camera_reference/photo_location.dart';
import 'package:miriago/camera_reference/photo_location_save_io.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class _Paths extends PathProviderPlatform {
  _Paths(this.path);
  final String path;
  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late File source;
  final location = PhotoLocationData(
    latitude: 35,
    longitude: 139,
    accuracy: 8,
    timestamp: DateTime.utc(2026, 9, 22),
  );
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('location-save-test-');
    final previous = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _Paths(directory.path);
    addTearDown(() => PathProviderPlatform.instance = previous);
    source = await File(
      p.join(directory.path, 'original.jpg'),
    ).writeAsBytes([1, 2, 3, 4]);
  });
  tearDown(() => directory.delete(recursive: true));

  test(
    'writer only sees an isolated copy; original is unchanged while pending',
    () async {
      final gate = Completer<bool>();
      final entered = Completer<String>();
      final future = preparePhotoLocation(
        sourcePath: source.path,
        location: location,
        writer: (path, value) async {
          expect(value, same(location));
          expect(path, isNot(source.path));
          await File(path).writeAsBytes([9, 8]);
          entered.complete(path);
          return gate.future;
        },
      );
      final path = await entered.future;
      expect(await source.readAsBytes(), [1, 2, 3, 4]);
      gate.complete(true);
      final result = await future;
      expect(result.path, path);
      expect(result.written, isTrue);
      expect(await File(path).readAsBytes(), [9, 8]);
    },
  );

  for (final throwsError in [false, true]) {
    test('failed writer ($throwsError) removes only its copy', () async {
      final root = await Directory(
        p.join(directory.path, 'visit_record_images'),
      ).create();
      final existing = await File(
        p.join(root.path, 'old.jpg'),
      ).writeAsBytes([7]);
      late String working;
      final result = await preparePhotoLocation(
        sourcePath: source.path,
        location: location,
        writer: (path, _) async {
          working = path;
          await File(path).writeAsBytes([0]);
          if (throwsError) throw StateError('partial metadata write');
          return false;
        },
      );
      expect(result.written, isFalse);
      expect(result.path, source.path);
      expect(File(working).parent.existsSync(), isFalse);
      expect(await source.readAsBytes(), [1, 2, 3, 4]);
      expect(await existing.readAsBytes(), [7]);
    });
  }

  test('separate successful saves never overwrite each other', () async {
    Future<PreparedPhotoLocation> prepare() => preparePhotoLocation(
      sourcePath: source.path,
      location: location,
      writer: (_, _) async => true,
    );
    final first = await prepare();
    final second = await prepare();
    expect(first.path, isNot(second.path));
    expect(await File(first.path).readAsBytes(), [1, 2, 3, 4]);
    expect(await File(second.path).readAsBytes(), [1, 2, 3, 4]);
  });

  test(
    'missing source cleans preparation directory and permits retry',
    () async {
      await source.delete();
      Future<PreparedPhotoLocation> prepare() => preparePhotoLocation(
        sourcePath: source.path,
        location: location,
        writer: (_, _) async => true,
      );
      await expectLater(prepare(), throwsA(isA<FileSystemException>()));
      expect(
        Directory(p.join(directory.path, 'visit_record_images')).listSync(),
        isEmpty,
      );
      await source.writeAsBytes([1]);
      expect((await prepare()).written, isTrue);
    },
  );
}
