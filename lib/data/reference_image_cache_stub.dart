import 'dart:convert';

import '../desktop/tauri_bridge.dart' as tauri;
import '../desktop/desktop_asset_image.dart';
import '../plan/pilgrimage_models.dart';
import 'anitabi_image_fetcher.dart';
import 'anitabi_image_url.dart';
import 'image_bytes.dart';

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
    filename: '${_stableUrlHash(url)}${_extensionFromUrl(url)}',
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
    filename: '${_stableUrlHash(url)}${_extensionFromUrl(url)}',
  );
}

Future<String?> _cacheTauriReferenceImage({
  required String url,
  required AnitabiImageSource imageSource,
  required String namespace,
  required String filename,
}) async {
  final path = 'assets/$namespace/$filename';
  try {
    final existing = await tauri.readDesktopAsset(path: path);
    if (isSupportedImageBytes(base64Decode(existing.dataBase64))) {
      return path;
    }
  } on Object {
    // Missing files are expected before the first cache attempt.
  }

  final bytes = await fetchAnitabiImageBytes(url, source: imageSource);
  if (bytes == null || !isSupportedImageBytes(bytes)) {
    return null;
  }

  await tauri.writeDesktopAsset(path: path, dataBase64: base64Encode(bytes));
  return path;
}

String _stableUrlHash(String value) {
  var hash = 0x811c9dc5;
  for (final codeUnit in value.codeUnits) {
    hash ^= codeUnit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}

bool _cachedPathMatchesUrl(String path, String url) {
  return path.contains(_stableUrlHash(url));
}

String _extensionFromUrl(String url) {
  final path = Uri.tryParse(url)?.path ?? '';
  final dotIndex = path.lastIndexOf('.');
  if (dotIndex < 0 || dotIndex == path.length - 1) {
    return '.jpg';
  }
  final extension = path.substring(dotIndex).toLowerCase();
  if (extension.length > 8 || extension.contains('/')) {
    return '.jpg';
  }
  return extension;
}
