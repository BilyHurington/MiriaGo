import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/app_version.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  test('desktop version avoids the custom-scheme web plugin', () async {
    var queried = false;
    final version = await loadAppVersionLabel(
      desktopLauncherAvailable: true,
      packageInfoLoader: () async {
        queried = true;
        throw StateError('Origin requires http or https');
      },
    );
    expect(version, miriagoAppVersion);
    expect(queried, isFalse);
  });

  test('native and browser versions still use platform metadata', () async {
    final version = await loadAppVersionLabel(
      desktopLauncherAvailable: false,
      packageInfoLoader: () async => PackageInfo(
        appName: 'MiriaGo',
        packageName: 'test.miriago',
        version: '2.0.0',
        buildNumber: '42',
      ),
    );
    expect(version, '2.0.0+42');
  });

  test('version query failure cannot interrupt application startup', () async {
    expect(
      await loadAppVersionLabel(
        desktopLauncherAvailable: false,
        packageInfoLoader: () async => throw StateError('unavailable'),
      ),
      miriagoAppVersion,
    );
  });

  test('empty platform version uses the bundled version', () async {
    expect(
      await loadAppVersionLabel(
        desktopLauncherAvailable: false,
        packageInfoLoader: () async => PackageInfo(
          appName: '',
          packageName: '',
          version: '',
          buildNumber: '',
        ),
      ),
      miriagoAppVersion,
    );
  });

  test('formats app version with build number', () {
    expect(
      formatAppVersionLabel(version: '1.1.2', buildNumber: '13'),
      '1.1.2+13',
    );
  });

  test('formats app version without empty build number', () {
    expect(formatAppVersionLabel(version: '1.1.2', buildNumber: ''), '1.1.2');
  });
}
