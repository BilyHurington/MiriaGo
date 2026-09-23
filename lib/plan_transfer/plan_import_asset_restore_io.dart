import 'dart:io';

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
  final root = Directory(
    p.join(documentsDirectory.path, 'imported_plan_assets'),
  );
  await root.create(recursive: true);
  if (await FileSystemEntity.type(root.path, followLinks: false) !=
      FileSystemEntityType.directory) {
    throw const FileSystemException('Import root must not be a link.');
  }
  // createTemp atomically reserves a fresh directory, independent of packageId.
  final importDirectory = await root.createTemp('import-');
  try {
    final restoredPaths = <String, String>{};
    final names = <String>{};
    for (final entry in importPackage.assetEntries.entries) {
      if (!isSafeRelativeAssetPath(entry.key)) {
        throw const FormatException('Unsafe imported asset path.');
      }
      final relativePath = normalizeAssetPathSeparators(entry.key);
      if (!names.add(relativePath.toLowerCase())) {
        throw const FormatException('Duplicate imported asset path.');
      }
      final localPath = p.joinAll([
        importDirectory.path,
        ...relativePath.split('/'),
      ]);
      final file = File(localPath);
      await file.parent.create(recursive: true);
      await file.create(exclusive: true);
      await file.writeAsBytes(entry.value, flush: true);
      restoredPaths[relativePath] = localPath;
    }
    return RestoredPlanImportAssets(
      restoredPaths,
      onDiscard: () async {
        await importDirectory.delete(recursive: true);
      },
    );
  } catch (_) {
    await importDirectory.delete(recursive: true);
    rethrow;
  }
}
