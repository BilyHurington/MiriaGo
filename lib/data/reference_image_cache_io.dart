import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../plan/pilgrimage_models.dart';
import 'anitabi_image_fetcher.dart';
import 'anitabi_image_url.dart';
import 'app_managed_file_paths_io.dart';
import 'backup_exclusion_io.dart';
import 'bounded_image_decoder.dart';
import 'image_bytes.dart';
import 'reference_cache_naming.dart';

/// Anitabi thumbnails are small; anything larger is not a thumbnail.
const maxReferenceThumbnailBytes = 4 * 1024 * 1024;

Future<String?> cacheReferenceThumbnail(
  PilgrimagePoint point, {
  AnitabiImageSource imageSource = AnitabiImageSource.auto,
}) async {
  final url = point.referenceImageUrl;
  if (url == null || url.isEmpty) {
    return null;
  }

  final thumbnailUrl = anitabiThumbnailImageUrl(url);
  if (thumbnailUrl == null || thumbnailUrl.isEmpty) {
    return null;
  }
  return _cacheImage(
    url: thumbnailUrl,
    imageSource: imageSource,
    namespace: 'reference_thumbnails',
    // Unrecognised hosts have no thumbnail variant and serve the full image.
    maxBytes: thumbnailUrl == url
        ? maxImageEncodedBytes
        : maxReferenceThumbnailBytes,
  );
}

Future<String?> ensureReferenceThumbnailCached(
  PilgrimagePoint point, {
  AnitabiImageSource imageSource = AnitabiImageSource.auto,
}) async {
  final thumbnailUrl = anitabiThumbnailImageUrl(point.referenceImageUrl);
  final existingPath = resolveExistingAppManagedFilePathSync(
    point.referenceThumbnailPath,
  );
  if (existingPath != null &&
      thumbnailUrl != null &&
      (_cachedPathMatchesUrl(existingPath, thumbnailUrl) ||
          _isImportedThumbnailPath(existingPath))) {
    final file = File(existingPath);
    if (file.existsSync() && file.lengthSync() > 0) {
      return existingPath;
    }
  }
  return cacheReferenceThumbnail(point, imageSource: imageSource);
}

Future<String?> cacheReferenceFullImage(
  PilgrimagePoint point, {
  AnitabiImageSource imageSource = AnitabiImageSource.auto,
}) async {
  final url = anitabiFullResolutionImageUrl(point.referenceImageUrl);
  if (url == null || url.isEmpty) {
    return null;
  }

  return _cacheImage(
    url: url,
    imageSource: imageSource,
    namespace: 'reference_full',
    maxBytes: maxImageEncodedBytes,
  );
}

/// Downloads that are still in progress, by target file, so overlapping
/// requests for the same image share one download and one write.
final _inFlightCacheWrites = <String, Future<String?>>{};

Future<String?> _cacheImage({
  required String url,
  required AnitabiImageSource imageSource,
  required String namespace,
  required int maxBytes,
}) async {
  final directory = await getApplicationDocumentsDirectory();
  final cacheDirectory = Directory(p.join(directory.path, namespace));
  if (!cacheDirectory.existsSync()) {
    cacheDirectory.createSync(recursive: true);
  }
  await excludeDirectoryFromBackup(cacheDirectory.path);
  final path = p.join(cacheDirectory.path, referenceCacheFileName(url));
  final pending = _inFlightCacheWrites[path];
  if (pending != null) return pending;
  final work = _cacheImageInto(
    url: url,
    imageSource: imageSource,
    cacheDirectory: cacheDirectory,
    path: path,
    maxBytes: maxBytes,
  );
  _inFlightCacheWrites[path] = work;
  try {
    return await work;
  } finally {
    if (identical(_inFlightCacheWrites[path], work)) {
      _inFlightCacheWrites.remove(path);
    }
  }
}

Future<String?> _cacheImageInto({
  required String url,
  required AnitabiImageSource imageSource,
  required Directory cacheDirectory,
  required String path,
  required int maxBytes,
}) async {
  if (await _isCompleteCachedImage(File(path))) return path;
  // Files cached by earlier versions keep working under their old names.
  final legacyNames = _legacyCacheNames(cacheDirectory);
  for (final name in legacyNames) {
    if (!isLegacyReferenceCacheName(name, url)) continue;
    final candidate = File(p.join(cacheDirectory.path, name));
    if (await _isCompleteCachedImage(candidate)) return candidate.path;
  }

  final bytes = await fetchAnitabiImageBytes(
    url,
    source: imageSource,
    maxBytes: maxBytes,
  );
  if (bytes == null || !isSupportedImageBytes(bytes)) {
    return null;
  }

  // Write next to the target and rename, so an interrupted write never
  // leaves a truncated file under the cache name.
  final temporary = File(
    '$path.${DateTime.now().microsecondsSinceEpoch}.${_random.nextInt(1 << 32)}.part',
  );
  try {
    await temporary.writeAsBytes(bytes, flush: true);
    await temporary.rename(path);
  } on Object {
    try {
      if (await temporary.exists()) await temporary.delete();
    } on Object {
      // Best effort; a stray .part file is ignored by cache lookups.
    }
    rethrow;
  }
  return path;
}

final _random = Random();

/// File names written before the current naming scheme, listed once per
/// cache directory per session (instead of on every cache miss). New files
/// never use legacy names, so the list only goes stale by files
/// disappearing, which lookups tolerate.
final _legacyNamesByDirectory = <String, List<String>>{};

List<String> _legacyCacheNames(Directory directory) {
  return _legacyNamesByDirectory[directory.path] ??= () {
    try {
      return [
        for (final entry in directory.listSync(followLinks: false))
          if (entry is File)
            if (p.basename(entry.path) case final name
                when !name.endsWith('.part') &&
                    !RegExp(r'^[0-9a-f]{20}\.').hasMatch(name))
              name,
      ];
    } on FileSystemException {
      // An unreadable directory simply has no reusable legacy files.
      return const <String>[];
    }
  }();
}

/// Housekeeping for the reference caches, run once at startup: exclude the
/// re-downloadable cache folders from iCloud backup (also those created by
/// earlier versions) and remove temporary files left by interrupted writes.
Future<void> prepareReferenceCacheStorage() async {
  try {
    final documents = await getApplicationDocumentsDirectory();
    final cutoff = DateTime.now().subtract(const Duration(minutes: 10));
    for (final namespace in const ['reference_full', 'reference_thumbnails']) {
      final directory = Directory(p.join(documents.path, namespace));
      if (!await directory.exists()) continue;
      await excludeDirectoryFromBackup(directory.path);
      await for (final entry in directory.list(followLinks: false)) {
        if (entry is File &&
            entry.path.endsWith('.part') &&
            !_inFlightCacheWrites.keys.any(entry.path.startsWith) &&
            (await entry.lastModified()).isBefore(cutoff)) {
          try {
            await entry.delete();
          } on FileSystemException {
            // Try again on a later start.
          }
        }
      }
    }
  } on Object catch (error) {
    debugPrint('Reference cache housekeeping skipped: $error');
  }
}

/// A cache file is usable when it exists and holds a complete image. Earlier
/// versions wrote cache files in place, so a file cut short by an interrupted
/// write can still start with a valid header.
Future<bool> _isCompleteCachedImage(File file) async {
  try {
    if (!file.existsSync()) return false;
    final bytes = await file.readAsBytes();
    return isSupportedImageBytes(bytes) && looksCompleteImageBytes(bytes);
  } on FileSystemException {
    return false;
  }
}

bool _cachedPathMatchesUrl(String path, String url) =>
    referenceCachePathMatchesUrl(path, url);

bool _isImportedThumbnailPath(String path) {
  final normalized = path.replaceAll(r'\', '/').toLowerCase();
  return normalized.contains('/imported_plan_assets/') &&
      normalized.contains('/assets/thumbnails/');
}
