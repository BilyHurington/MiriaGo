import 'dart:convert';

import '../data/reference_asset_paths.dart';
import '../desktop/tauri_bridge.dart';
import 'plan_import_package.dart';

bool get supportsPlanImportAssetRestore => isTauriLauncherAvailable;

Future<Map<String, String>> restorePlanImportAssets(
  PlanImportPackage importPackage,
) async {
  if (!isTauriLauncherAvailable || importPackage.assetEntries.isEmpty) {
    return const {};
  }
  final names = <String>{};
  for (final name in importPackage.assetEntries.keys) {
    if (!isSafeRelativeAssetPath(name) ||
        !names.add(normalizeAssetPathSeparators(name).toLowerCase())) {
      throw const FormatException('Unsafe or duplicate imported asset path.');
    }
  }
  final result = await restoreDesktopImportAssets(
    // Metadata only; the native restore command owns directory allocation.
    packageId: importPackage.manifest['packageId'] is String
        ? importPackage.manifest['packageId'] as String
        : null,
    sourceName: importPackage.sourceName,
    assetsBase64: {
      for (final entry in importPackage.assetEntries.entries)
        normalizeAssetPathSeparators(entry.key): base64Encode(entry.value),
    },
  );
  final paths = {
    for (final entry in result.restoredPaths.entries)
      normalizeAssetPathSeparators(entry.key): normalizeAssetPathSeparators(
        entry.value,
      ),
  };
  final token = result.restoreToken;
  return RestoredPlanImportAssets(
    paths,
    canDiscardAfterRepositoryRead: false,
    onDiscard: () async {
      if (token == null) {
        throw StateError('Desktop restore did not return a cleanup token.');
      }
      await cleanupDesktopImportAssets(restoreToken: token);
    },
    onFinalize: token == null
        ? null
        : () => finalizeDesktopImportAssets(restoreToken: token),
  );
}
