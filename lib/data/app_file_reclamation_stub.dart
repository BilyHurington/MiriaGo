import 'app_file_reclamation.dart';
import 'reference_cache_file_stub.dart' as cache;

/// Web and the Tauri desktop build. On desktop the app-created asset folders
/// (downloaded caches, imported package assets, uploaded reference images)
/// can be reclaimed through a delete command that checks the folder again in
/// Rust. Visit photos are only ever inside imported package assets there.
Future<AppFileReclamationResult> deleteUnreferencedOwnedFiles({
  required Set<String> candidates,
  required Iterable<String?> references,
  required Set<String> directoryNames,
}) async {
  if (!cache.isReferenceCacheCleanupSupported) {
    return AppFileReclamationResult.none;
  }
  final prefixes = [
    for (final name in _desktopReclaimableDirectories)
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

/// Must match `RECLAIMABLE_ASSET_PREFIXES` in src-tauri/src/commands.rs.
const _desktopReclaimableDirectories = [
  'reference_full',
  'reference_thumbnails',
  'imported_plan_assets',
  'user_reference_images',
  'user_references',
];
