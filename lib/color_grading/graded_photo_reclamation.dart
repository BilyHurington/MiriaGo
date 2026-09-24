import 'package:flutter/foundation.dart';

import '../data/app_file_reclamation.dart';
import '../data/pilgrimage_repository.dart';
import '../plan/pilgrimage_models.dart';

/// Runs [update], which stores [newGradedPath] as the record's graded photo.
///
/// After it commits, the replaced [previousGradedPath] is reclaimed if nothing
/// references it any more. If the repository proves the update was not
/// committed ([VisitRecordNotCommittedException]) the freshly written
/// [newGradedPath] is reclaimed instead. Any other failure leaves the outcome
/// uncertain, so both files are kept. File cleanup runs in the background
/// unless [awaitCleanup] is set.
Future<PilgrimageVisitRecord?> commitGradedPhoto({
  required PilgrimageRepository? repository,
  required String newGradedPath,
  required String? previousGradedPath,
  required Future<PilgrimageVisitRecord?> Function() update,
  bool awaitCleanup = false,
}) async {
  final PilgrimageVisitRecord? updated;
  try {
    updated = await update();
  } on VisitRecordNotCommittedException {
    final cleanup = _reclaimGradedPhoto(repository, newGradedPath);
    if (awaitCleanup) await cleanup;
    rethrow;
  }
  if (updated != null && previousGradedPath != newGradedPath) {
    final cleanup = _reclaimGradedPhoto(repository, previousGradedPath);
    if (awaitCleanup) await cleanup;
  }
  return updated;
}

/// Runs [clear] and, once it has committed, reclaims the graded photo it
/// dropped. A failed clear keeps the file.
Future<PilgrimageVisitRecord?> clearGradedPhoto({
  required PilgrimageRepository? repository,
  required String? previousGradedPath,
  required Future<PilgrimageVisitRecord?> Function() clear,
  bool awaitCleanup = false,
}) async {
  final updated = await clear();
  if (updated != null) {
    final cleanup = _reclaimGradedPhoto(repository, previousGradedPath);
    if (awaitCleanup) await cleanup;
  }
  return updated;
}

Future<void> _reclaimGradedPhoto(
  PilgrimageRepository? repository,
  String? path,
) async {
  if (repository == null || path == null) return;
  try {
    await reclaimUnreferencedAppFiles(
      repository: repository,
      candidatePaths: [path],
      ownedDirectories: const {AppOwnedDirectory.gradedPhotos},
    );
  } on Object catch (error) {
    debugPrint('Graded photo reclamation skipped: $error');
  }
}
