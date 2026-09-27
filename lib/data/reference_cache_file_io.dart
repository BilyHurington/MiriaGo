import 'dart:io';

import 'package:path/path.dart' as p;

import 'app_managed_file_paths_io.dart';
import 'anitabi_image_url.dart';
import 'reference_cache_naming.dart';

bool get isReferenceCacheCleanupSupported => true;

bool referenceCacheFileExists(String? path) {
  if (path == null || path.isEmpty) return false;
  final resolved = resolveExistingAppManagedFilePathSync(path) ?? path;
  final file = File(resolved);
  return file.existsSync() && file.lengthSync() > 0;
}

bool referenceFullCacheFileIsCurrent({
  required String? path,
  required String? imageUrl,
}) {
  final fullUrl = anitabiFullResolutionImageUrl(imageUrl);
  if (fullUrl == null || !referenceCacheFileExists(path)) return false;
  if (_isImportedFullReferencePath(path!)) return true;
  return referenceCachePathMatchesUrl(path, fullUrl);
}

bool _isImportedFullReferencePath(String path) {
  final normalized = path.replaceAll(r'\', '/').toLowerCase();
  return normalized.contains('/imported_plan_assets/') &&
      normalized.contains('/assets/full_references/');
}

Future<int> referenceCacheFileSize(String path) async {
  final resolved = resolveExistingAppManagedFilePathSync(path) ?? path;
  final file = File(resolved);
  if (!await file.exists()) return 0;
  return file.length();
}

Future<int> deleteReferenceCacheFile(String path) async {
  final resolved = resolveExistingAppManagedFilePathSync(path) ?? path;
  final file = File(resolved);
  if (!await file.exists()) return 0;
  final size = await file.length();
  await file.delete();
  return size;
}

/// Stable identity of a stored cache path, so the same file referenced under
/// an old app-container path and its current path compares equal.
String referenceCacheIdentity(String path) =>
    p.normalize(resolveExistingAppManagedFilePathSync(path) ?? path);
