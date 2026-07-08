import 'package:package_info_plus/package_info_plus.dart';

const miriagoAppVersion = '1.1.3+18';

Future<String> loadAppVersionLabel() async {
  final info = await PackageInfo.fromPlatform();
  return formatAppVersionLabel(
    version: info.version,
    buildNumber: info.buildNumber,
  );
}

String formatAppVersionLabel({
  required String version,
  required String buildNumber,
}) {
  final trimmedBuildNumber = buildNumber.trim();
  if (trimmedBuildNumber.isEmpty) {
    return version;
  }
  return '$version+$trimmedBuildNumber';
}
