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
  final result = await restoreDesktopImportAssets(
    packageId: _packageId(importPackage),
    sourceName: importPackage.sourceName,
    assetsBase64: {
      for (final entry in importPackage.assetEntries.entries)
        normalizeAssetPathSeparators(entry.key): base64Encode(entry.value),
    },
  );
  return {
    for (final entry in result.restoredPaths.entries)
      normalizeAssetPathSeparators(entry.key): normalizeAssetPathSeparators(
        entry.value,
      ),
  };
}

String? _packageId(PlanImportPackage importPackage) {
  final value = importPackage.manifest['packageId'];
  if (value is String && value.trim().isNotEmpty) {
    return value;
  }
  return null;
}
