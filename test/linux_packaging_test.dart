import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group(
    'Linux artifact packaging',
    () {
      late Directory root;
      late Directory release;
      late Directory output;

      setUp(() async {
        root = Directory.systemTemp.createTempSync('miriago-linux-package-');
        release = Directory('${root.path}/release with spaces')..createSync();
        output = Directory('${root.path}/output');
        final exe = File('${release.path}/miriago-desktop')
          ..writeAsStringSync('#!/bin/sh\nexit 0\n');
        final chmod = await Process.run('chmod', ['+x', exe.path]);
        expect(chmod.exitCode, 0);
        for (final entry in {
          'appimage': 'AppImage',
          'deb': 'deb',
          'rpm': 'rpm',
        }.entries) {
          File('${release.path}/bundle/${entry.key}/app.${entry.value}')
            ..createSync(recursive: true)
            ..writeAsStringSync('fixture');
        }
      });
      tearDown(() => root.deleteSync(recursive: true));

      Future<ProcessResult> package() => Process.run('bash', [
        'tool/package_linux.sh',
        release.path,
        output.path,
        '1.1.6',
      ]);

      test(
        'creates four nonempty artifacts and preserves portable folder',
        () async {
          final result = await package();
          expect(
            result.exitCode,
            0,
            reason: '${result.stdout}\n${result.stderr}',
          );
          for (final ext in ['zip', 'AppImage', 'deb', 'rpm']) {
            expect(
              File('${output.path}/MiriaGo-v1.1.6-linux-x64.$ext').lengthSync(),
              greaterThan(0),
            );
          }
          final zip = await Process.run('unzip', [
            '-Z1',
            '${output.path}/MiriaGo-v1.1.6-linux-x64.zip',
          ]);
          expect(zip.exitCode, 0);
          expect(zip.stdout, contains('MiriaGo-linux/MiriaGoData/'));
          expect(zip.stdout, contains('MiriaGo-linux/MiriaGo'));
        },
      );
      for (final entry in {
        'appimage': 'AppImage',
        'deb': 'deb',
        'rpm': 'rpm',
      }.entries) {
        test('fails before publication if ${entry.key} is missing', () async {
          File(
            '${release.path}/bundle/${entry.key}/app.${entry.value}',
          ).deleteSync();
          expect((await package()).exitCode, isNot(0));
          expect(output.existsSync(), isFalse);
        });
      }
      test('rejects empty and ambiguous bundles', () async {
        final rpm = File('${release.path}/bundle/rpm/app.rpm');
        rpm.writeAsStringSync('');
        expect((await package()).exitCode, isNot(0));
        rpm.writeAsStringSync('fixture');
        File(
          '${release.path}/bundle/rpm/other.rpm',
        ).writeAsStringSync('fixture');
        expect((await package()).exitCode, isNot(0));
        expect(output.existsSync(), isFalse);
      });
      test('rejects absent executable', () async {
        File('${release.path}/miriago-desktop').deleteSync();
        expect((await package()).exitCode, isNot(0));
      });
    },
    skip: Platform.isWindows ? 'POSIX packaging runs on Linux/macOS' : false,
  );
}
