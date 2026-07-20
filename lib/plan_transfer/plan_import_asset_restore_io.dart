import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../data/reference_asset_paths.dart';
import 'plan_import_package.dart';

const supportsPlanImportAssetRestore = true;

Future<Map<String, String>> restorePlanImportAssets(
  PlanImportPackage importPackage,
) async {
  if (importPackage.assetEntries.isEmpty) {
    return const {};
  }

  final documentsDirectory = await getApplicationDocumentsDirectory();
  final importDirectory = Directory(
    p.join(
      documentsDirectory.path,
      'imported_plan_assets',
      _safeDirectoryName(_packageDirectoryName(importPackage)),
    ),
  );
  await importDirectory.create(recursive: true);

  final restoredPaths = <String, String>{};
  for (final entry in importPackage.assetEntries.entries) {
    final relativePath = normalizeAssetPathSeparators(entry.key);
    final segments = relativePath.split('/');
    if (segments.isEmpty || segments.first != 'assets') {
      continue;
    }
    final localPath = p.joinAll([importDirectory.path, ...segments]);
    final file = File(localPath);
    await file.parent.create(recursive: true);
    final alreadyRestored =
        file.existsSync() &&
        file.lengthSync() == entry.value.length &&
        listEquals(await file.readAsBytes(), entry.value);
    if (!alreadyRestored) {
      await file.writeAsBytes(entry.value, flush: true);
    }
    restoredPaths[relativePath] = localPath;
  }
  return restoredPaths;
}

String _packageDirectoryName(PlanImportPackage importPackage) {
  final packageId = importPackage.manifest['packageId'];
  if (packageId is String && packageId.trim().isNotEmpty) {
    return packageId;
  }
  final timestamp =
      importPackage.exportedAt?.microsecondsSinceEpoch.toString() ??
      DateTime.now().microsecondsSinceEpoch.toString();
  return '${importPackage.sourceName}_$timestamp';
}

String _safeDirectoryName(String value) {
  final safe = value
      .replaceAll(RegExp(r'[\\/:*?"<>|\s]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
  return safe.isEmpty ? 'imported_package' : safe;
}
