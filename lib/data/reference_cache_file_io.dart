import 'dart:io';

import 'app_managed_file_paths_io.dart';
import 'anitabi_image_url.dart';

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
  return path.contains(_stableUrlHash(fullUrl));
}

bool _isImportedFullReferencePath(String path) {
  final normalized = path.replaceAll(r'\', '/').toLowerCase();
  return normalized.contains('/imported_plan_assets/') &&
      normalized.contains('/assets/full_references/');
}

String _stableUrlHash(String value) {
  var hash = 0x811c9dc5;
  for (final codeUnit in value.codeUnits) {
    hash ^= codeUnit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash.toRadixString(16).padLeft(8, '0');
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
