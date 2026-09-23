import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../data/app_managed_file_paths_io.dart';
import '../data/pilgrimage_repository.dart';
import '../plan/pilgrimage_models.dart';

bool visitRecordLocalFileExists(String path) {
  final resolvedPath = resolveExistingAppManagedFilePathSync(path) ?? path;
  return File(resolvedPath).existsSync();
}

// Only for a newly captured, cancelled photo that has not become a record.
void deleteVisitRecordLocalFile(String path) {
  try {
    final resolvedPath = resolveExistingAppManagedFilePathSync(path) ?? path;
    File(resolvedPath).deleteSync();
  } catch (_) {}
}

Future<void> deleteUnreferencedVisitRecordPhotos({
  required PilgrimageVisitRecord record,
  required PilgrimageRepository repository,
}) async {
  // Run only after metadata deletion. Reference images are never deletion candidates.
  final candidates = <String>{};
  for (final path in [
    record.photoPath,
    record.originalPhotoPath,
    record.gradedPhotoPath,
  ]) {
    final resolved = await _canonicalFile(path);
    if (resolved != null) candidates.add(resolved);
  }
  if (candidates.isEmpty) return;

  final references = <String?>[];
  for (final plan in await repository.loadPlans()) {
    for (final point in plan.points) {
      references.addAll([
        point.referenceThumbnailPath,
        point.referenceFullImagePath,
        point.referenceImageUrl,
      ]);
    }
    for (final remaining in await repository.loadVisitRecords(plan.id)) {
      references.addAll([
        remaining.photoPath,
        remaining.originalPhotoPath,
        remaining.gradedPhotoPath,
        remaining.referenceImagePath,
      ]);
    }
  }
  references.add(record.referenceImagePath);
  for (final path in references) {
    final resolved = await _canonicalFile(path);
    if (resolved != null) candidates.remove(resolved);
  }

  final roots = <String>[];
  final directories = [
    await getApplicationDocumentsDirectory(),
    await getApplicationSupportDirectory(),
  ];
  for (final directory in directories) {
    for (final name in [
      'visit_record_images',
      'graded_photos',
      'imported_plan_assets',
    ]) {
      final root = Directory(p.join(directory.path, name));
      if (await root.exists()) {
        // Do not grant ownership to a symlink pointing outside the app directory.
        final canonicalBase = await directory.resolveSymbolicLinks();
        final canonicalRoot = await root.resolveSymbolicLinks();
        if (p.isWithin(canonicalBase, canonicalRoot)) roots.add(canonicalRoot);
      }
    }
  }
  for (final path in candidates) {
    if (roots.any((root) => p.isWithin(root, path))) {
      await File(path).delete();
    }
  }
}

Future<String?> _canonicalFile(String? path) async {
  final resolution = await resolveAppManagedFilePath(path);
  final resolved = resolution.resolvedPath;
  if (resolved == null) return null;
  return File(resolved).resolveSymbolicLinks();
}
