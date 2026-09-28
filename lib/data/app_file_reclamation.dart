import 'dart:async';

import 'package:flutter/foundation.dart';

import '../plan/pilgrimage_models.dart';
import 'pilgrimage_repository.dart';
import 'app_file_reclamation_stub.dart'
    if (dart.library.io) 'app_file_reclamation_io.dart'
    as backend;

/// App-owned directories under Documents / Application Support whose files
/// may be reclaimed. Anything outside them (user-picked originals, external
/// paths, bundled assets) is never deleted.
enum AppOwnedDirectory {
  visitRecordImages('visit_record_images'),
  gradedPhotos('graded_photos'),
  importedPlanAssets('imported_plan_assets'),
  referenceFull('reference_full'),
  referenceThumbnails('reference_thumbnails'),
  userReferenceImages('user_reference_images'),

  /// Where uploads were stored before `user_reference_images`.
  legacyUserReferences('user_references');

  const AppOwnedDirectory(this.directoryName);
  final String directoryName;
}

/// Directories that hold files a point can own: downloaded or imported
/// reference caches and user uploaded reference images.
const pointOwnedDirectories = {
  AppOwnedDirectory.importedPlanAssets,
  AppOwnedDirectory.referenceFull,
  AppOwnedDirectory.referenceThumbnails,
  AppOwnedDirectory.userReferenceImages,
  AppOwnedDirectory.legacyUserReferences,
};

class AppFileReclamationResult {
  const AppFileReclamationResult({
    required this.deletedFileCount,
    required this.failedFileCount,
  });

  static const none = AppFileReclamationResult(
    deletedFileCount: 0,
    failedFileCount: 0,
  );

  final int deletedFileCount;
  final int failedFileCount;
}

/// Local file paths a point stores. The reference URL is a local path for
/// older user uploads; remote URLs never resolve to a file and are skipped.
Iterable<String?> pointFilePaths(PilgrimagePoint point) => [
  point.referenceThumbnailPath,
  point.referenceFullImagePath,
  point.referenceImageUrl,
];

Iterable<String?> visitRecordFilePaths(PilgrimageVisitRecord record) => [
  record.photoPath,
  record.originalPhotoPath,
  record.gradedPhotoPath,
  record.referenceImagePath,
];

/// Deletes [candidatePaths] that no plan point and no visit record of any
/// plan still references, and that resolve inside one of [ownedDirectories].
///
/// Call only after the metadata change that orphaned the candidates has
/// committed. Paths are compared after resolving app-container moves and
/// symlinks. A failed reference scan throws before anything is deleted; a
/// failure to delete one file does not stop the others.
Future<AppFileReclamationResult> reclaimUnreferencedAppFiles({
  required PilgrimageRepository repository,
  required Iterable<String?> candidatePaths,
  required Set<AppOwnedDirectory> ownedDirectories,
  Iterable<String?> protectedPaths = const [],
}) async {
  final candidates = {
    for (final path in candidatePaths)
      if (path != null && path.trim().isNotEmpty) path,
  };
  if (candidates.isEmpty || ownedDirectories.isEmpty) {
    return AppFileReclamationResult.none;
  }

  final references = <String?>[...protectedPaths];
  for (final plan in await repository.loadPlans()) {
    for (final point in plan.points) {
      references
        ..addAll(pointFilePaths(point))
        ..add(point.referenceImageUrl);
    }
    for (final record in await repository.loadVisitRecords(plan.id)) {
      references
        ..addAll(visitRecordFilePaths(record))
        ..add(record.referenceImageUrl);
    }
  }
  return backend.deleteUnreferencedOwnedFiles(
    candidates: candidates,
    references: references,
    directoryNames: {
      for (final directory in ownedDirectories) directory.directoryName,
    },
  );
}

/// Deletes a plan, then reclaims the files its points and visit records used
/// that nothing remaining references. Files are only touched after
/// [PilgrimageRepository.deletePlan] completed; if it throws, every file is
/// kept and the error is rethrown. Reclamation runs in the background unless
/// [awaitReclamation] is set.
Future<void> deletePlanReclaimingFiles({
  required PilgrimageRepository repository,
  required String planId,
  bool awaitReclamation = false,
}) async {
  final candidates = <String?>[];
  try {
    for (final plan in await repository.loadPlans()) {
      if (plan.id != planId) continue;
      for (final point in plan.points) {
        candidates.addAll(pointFilePaths(point));
      }
    }
    for (final record in await repository.loadVisitRecords(planId)) {
      candidates.addAll(visitRecordFilePaths(record));
    }
  } on Object catch (error) {
    // Collecting candidates must never block the deletion itself.
    debugPrint('Plan file collection skipped: $error');
  }

  await repository.deletePlan(planId);

  final reclamation = _reclaimQuietly(
    repository: repository,
    candidatePaths: candidates,
    ownedDirectories: AppOwnedDirectory.values.toSet(),
  );
  if (awaitReclamation) await reclamation;
}

/// Reclaims the reference files of points that were deleted successfully.
/// Visit records are kept by point deletion, so a record that still shows one
/// of these references keeps it alive. Never throws.
Future<void> reclaimDeletedPointFiles({
  required PilgrimageRepository repository,
  required Iterable<PilgrimagePoint> points,
}) {
  return _reclaimQuietly(
    repository: repository,
    candidatePaths: [for (final point in points) ...pointFilePaths(point)],
    ownedDirectories: pointOwnedDirectories,
  );
}

/// Updates [point] in its plan, then reclaims files [previous] used that the
/// updated point no longer does (e.g. after its reference image was
/// replaced) and nothing else references. Reclamation runs in the
/// background and never throws.
Future<PilgrimagePlan> updatePointReclaimingFiles({
  required PilgrimageRepository repository,
  required String planId,
  required PilgrimagePoint point,
  required PilgrimagePoint? previous,
  bool awaitReclamation = false,
}) async {
  final updatedPlan = await repository.updatePointInPlan(
    planId: planId,
    point: point,
  );
  final released = releasedPointFilePaths(previous: previous, current: point);
  if (released.isNotEmpty) {
    final reclamation = _reclaimQuietly(
      repository: repository,
      candidatePaths: released,
      ownedDirectories: pointOwnedDirectories,
    );
    if (awaitReclamation) {
      await reclamation;
    } else {
      unawaited(reclamation);
    }
  }
  return updatedPlan;
}

/// Paths [previous] stored that [current] no longer does.
List<String> releasedPointFilePaths({
  required PilgrimagePoint? previous,
  required PilgrimagePoint current,
}) {
  if (previous == null) {
    return const [];
  }
  final kept = pointFilePaths(current).toSet();
  return [
    for (final path in pointFilePaths(previous))
      if (path != null && path.trim().isNotEmpty && !kept.contains(path)) path,
  ];
}

Future<void> _reclaimQuietly({
  required PilgrimageRepository repository,
  required Iterable<String?> candidatePaths,
  required Set<AppOwnedDirectory> ownedDirectories,
}) async {
  try {
    final result = await reclaimUnreferencedAppFiles(
      repository: repository,
      candidatePaths: candidatePaths,
      ownedDirectories: ownedDirectories,
    );
    if (result.failedFileCount > 0) {
      debugPrint('File reclamation left ${result.failedFileCount} file(s).');
    }
  } on Object catch (error) {
    // Metadata is already committed; unreclaimed files are only wasted space.
    debugPrint('File reclamation skipped: $error');
  }
}
