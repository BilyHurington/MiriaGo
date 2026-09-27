import 'dart:convert';

import '../desktop/tauri_bridge.dart' as tauri;
import '../desktop/desktop_asset_image.dart';
import '../plan/pilgrimage_models.dart';
import 'anitabi_image_fetcher.dart';
import 'anitabi_image_url.dart';
import 'bounded_image_decoder.dart';
import 'image_bytes.dart';
import 'reference_cache_naming.dart';

Future<String?> cacheReferenceThumbnail(
  PilgrimagePoint point, {
  AnitabiImageSource imageSource = AnitabiImageSource.auto,
}) async {
  if (!tauri.isTauriLauncherAvailable) {
    return null;
  }
  final url = anitabiThumbnailImageUrl(point.referenceImageUrl);
  if (url == null || url.isEmpty) {
    return null;
  }
  return _cacheTauriReferenceImage(
    url: url,
    imageSource: imageSource,
    namespace: 'reference_thumbnails',
    filename: referenceCacheFileName(url),
  );
}

Future<String?> ensureReferenceThumbnailCached(
  PilgrimagePoint point, {
  AnitabiImageSource imageSource = AnitabiImageSource.auto,
}) async {
  final thumbnailUrl = anitabiThumbnailImageUrl(point.referenceImageUrl);
  final existingPath = point.referenceThumbnailPath;
  if (existingPath != null &&
      thumbnailUrl != null &&
      isDesktopAssetPath(existingPath) &&
      _cachedPathMatchesUrl(existingPath, thumbnailUrl)) {
    try {
      final existing = await tauri.readDesktopAsset(path: existingPath);
      if (existing.dataBase64.isNotEmpty) {
        return existingPath;
      }
    } on Object {
      // Missing files are expected when data was restored without assets.
    }
  }
  return cacheReferenceThumbnail(point, imageSource: imageSource);
}

Future<String?> cacheReferenceFullImage(
  PilgrimagePoint point, {
  AnitabiImageSource imageSource = AnitabiImageSource.auto,
}) async {
  if (!tauri.isTauriLauncherAvailable) {
    return null;
  }
  final url = anitabiFullResolutionImageUrl(point.referenceImageUrl);
  if (url == null || url.isEmpty) {
    return null;
  }
  return _cacheTauriReferenceImage(
    url: url,
    imageSource: imageSource,
    namespace: 'reference_full',
    filename: referenceCacheFileName(url),
  );
}

Future<String?> _cacheTauriReferenceImage({
  required String url,
  required AnitabiImageSource imageSource,
  required String namespace,
  required String filename,
}) async {
  final path = 'assets/$namespace/$filename';
  for (final candidate in [
    path,
    'assets/$namespace/${legacyReferenceCacheFileName(url)}',
  ]) {
    try {
      final existing = await tauri.readDesktopAsset(path: candidate);
      final bytes = base64Decode(existing.dataBase64);
      if (isSupportedImageBytes(bytes) && looksCompleteImageBytes(bytes)) {
        return candidate;
      }
    } on Object {
      // Missing files are expected before the first cache attempt.
    }
  }

  final bytes = await fetchAnitabiImageBytes(
    url,
    source: imageSource,
    maxBytes:
        namespace == 'reference_thumbnails' &&
            anitabiThumbnailImageUrl(url) != anitabiFullResolutionImageUrl(url)
        ? 4 * 1024 * 1024
        : maxImageEncodedBytes,
  );
  if (bytes == null || !isSupportedImageBytes(bytes)) {
    return null;
  }

  // The desktop host writes assets atomically.
  await tauri.writeDesktopAsset(path: path, dataBase64: base64Encode(bytes));
  return path;
}

bool _cachedPathMatchesUrl(String path, String url) =>
    referenceCachePathMatchesUrl(path, url);

/// Desktop/web: nothing to prepare (Tauri writes atomically, no iCloud).
Future<void> prepareReferenceCacheStorage() async {}
