import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/app_version.dart';

void main() {
  test('version checks accept Windows checkout line endings', () {
    const fixture = 'name = "miriago-desktop"\nversion = "1.2.3"';
    expect(normalizeLineEndings(fixture.replaceAll('\n', '\r\n')), fixture);
  });

  test('keeps Flutter and native platform versions aligned', () {
    final versionParts = miriagoAppVersion.split('+');
    expect(versionParts, hasLength(2));
    final versionName = versionParts[0];
    final buildNumber = versionParts[1];

    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('version: $miriagoAppVersion'));

    final androidGradle = File(
      'android/app/build.gradle.kts',
    ).readAsStringSync();
    expect(androidGradle, contains('versionCode = flutter.versionCode'));
    expect(androidGradle, contains('versionName = flutter.versionName'));

    final xcodeProject = File(
      'ios/Runner.xcodeproj/project.pbxproj',
    ).readAsStringSync();
    final xcodeBuildNumbers = RegExp(
      r'CURRENT_PROJECT_VERSION = ([^;]+);',
    ).allMatches(xcodeProject).map((match) => match.group(1)).toSet();
    expect(xcodeBuildNumbers, {'"\$(FLUTTER_BUILD_NUMBER)"', buildNumber});
    final marketingVersions = RegExp(
      r'MARKETING_VERSION = ([^;]+);',
    ).allMatches(xcodeProject).map((match) => match.group(1)).toSet();
    expect(marketingVersions, {versionName});

    final infoPlist = File('ios/Runner/Info.plist').readAsStringSync();
    expect(infoPlist, contains(r'$(FLUTTER_BUILD_NAME)'));
    expect(infoPlist, contains(r'$(FLUTTER_BUILD_NUMBER)'));

    final tauriConfig = jsonDecode(
      File('src-tauri/tauri.conf.json').readAsStringSync(),
    );
    expect(tauriConfig['version'], versionName);

    final cargoToml = File('src-tauri/Cargo.toml').readAsStringSync();
    expect(cargoToml, contains('version = "$versionName"'));
    final cargoLock = normalizeLineEndings(
      File('src-tauri/Cargo.lock').readAsStringSync(),
    );
    expect(
      cargoLock,
      contains('name = "miriago-desktop"\nversion = "$versionName"'),
    );
  });
}

String normalizeLineEndings(String text) => text.replaceAll('\r\n', '\n');
