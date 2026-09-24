import 'app_file_reclamation.dart';
import 'reference_cache_file_stub.dart' as cache;

/// Web and the Tauri desktop build. The desktop bridge only exposes a safe
/// delete for downloaded reference caches (`assets/reference_full/`,
/// `assets/reference_thumbnails/`), validated again by the Rust command.
/// Imported package assets, user reference images and visit photos have no
/// delete command there, so those files are intentionally kept.
Future<AppFileReclamationResult> deleteUnreferencedOwnedFiles({
  required Set<String> candidates,
  required Iterable<String?> references,
  required Set<String> directoryNames,
}) async {
  if (!cache.isReferenceCacheCleanupSupported) {
    return AppFileReclamationResult.none;
  }
  final prefixes = [
    for (final name in const ['reference_full', 'reference_thumbnails'])
      if (directoryNames.contains(name)) 'assets/$name/',
  ];
  if (prefixes.isEmpty) return AppFileReclamationResult.none;

  final referenced = {
    for (final path in references)
      if (path != null && path.isNotEmpty) cache.referenceCacheIdentity(path),
  };
  var deleted = 0;
  var failed = 0;
  for (final path in candidates) {
    final identity = cache.referenceCacheIdentity(path);
    if (!prefixes.any(identity.startsWith) ||
        identity.split('/').contains('..') ||
        referenced.contains(identity)) {
      continue;
    }
    try {
      if (await cache.deleteReferenceCacheFile(identity) > 0) deleted++;
    } on Object {
      failed++;
    }
  }
  return AppFileReclamationResult(
    deletedFileCount: deleted,
    failedFileCount: failed,
  );
}
