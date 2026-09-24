import 'dart:io';

import '../data/app_file_reclamation.dart';
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
  // Run only after metadata deletion. Reference images are never deletion
  // candidates here, and the record's own reference is protected explicitly.
  final result = await reclaimUnreferencedAppFiles(
    repository: repository,
    candidatePaths: [
      record.photoPath,
      record.originalPhotoPath,
      record.gradedPhotoPath,
    ],
    protectedPaths: [record.referenceImagePath],
    ownedDirectories: const {
      AppOwnedDirectory.visitRecordImages,
      AppOwnedDirectory.gradedPhotos,
      AppOwnedDirectory.importedPlanAssets,
    },
  );
  // Every file was attempted; report the ones that are left behind.
  if (result.failedFileCount > 0) {
    throw FileSystemException(
      '${result.failedFileCount} visit photo(s) could not be deleted.',
    );
  }
}
