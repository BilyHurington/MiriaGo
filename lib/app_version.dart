import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'desktop/tauri_bridge.dart';

const miriagoAppVersion = '1.1.6+23';

Future<String> loadAppVersionLabel({
  bool? desktopLauncherAvailable,
  Future<PackageInfo> Function()? packageInfoLoader,
}) async {
  // The web plugin cannot resolve version.json under Tauri's custom scheme.
  if (desktopLauncherAvailable ?? isTauriLauncherAvailable) {
    return miriagoAppVersion;
  }
  try {
    final info = await (packageInfoLoader ?? PackageInfo.fromPlatform)();
    if (info.version.trim().isEmpty) {
      return miriagoAppVersion;
    }
    return formatAppVersionLabel(
      version: info.version,
      buildNumber: info.buildNumber,
    );
  } catch (error) {
    debugPrint('App version query failed: $error');
    return miriagoAppVersion;
  }
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
