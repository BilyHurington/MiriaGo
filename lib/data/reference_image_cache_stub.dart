import 'dart:convert';

import 'package:http/http.dart' as http;

import '../desktop/tauri_bridge.dart' as tauri;
import '../desktop/desktop_asset_image.dart';
import '../plan/pilgrimage_models.dart';
import 'anitabi_image_url.dart';
import 'image_bytes.dart';

Future<String?> cacheReferenceThumbnail(PilgrimagePoint point) async {
  if (!tauri.isTauriLauncherAvailable) {
    return null;
  }
  final url = anitabiThumbnailImageUrl(point.referenceImageUrl);
  if (url == null || url.isEmpty) {
    return null;
  }
  return _cacheTauriReferenceImage(
    url: url,
    namespace: 'reference_thumbnails',
    filename:
        '${_safeFileName(point.id)}_${_stableUrlHash(url)}${_extensionFromUrl(url)}',
  );
}

Future<String?> ensureReferenceThumbnailCached(PilgrimagePoint point) async {
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
  return cacheReferenceThumbnail(point);
}

Future<String?> cacheReferenceFullImage(PilgrimagePoint point) async {
  if (!tauri.isTauriLauncherAvailable) {
    return null;
  }
  final url = anitabiFullResolutionImageUrl(point.referenceImageUrl);
  if (url == null || url.isEmpty) {
    return null;
  }
  return _cacheTauriReferenceImage(
    url: url,
    namespace: 'reference_full',
    filename:
        '${_safeFileName(point.id)}_${_stableUrlHash(url)}${_extensionFromUrl(url)}',
  );
}

Future<String?> _cacheTauriReferenceImage({
  required String url,
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

  final response = await http.get(Uri.parse(url));
  if (response.statusCode < 200 || response.statusCode >= 300) {
    return null;
  }
  if (response.bodyBytes.isEmpty) {
    return null;
  }
  if (!isSupportedImageBytes(response.bodyBytes)) {
    return null;
  }

  await tauri.writeDesktopAsset(
    path: path,
    dataBase64: base64Encode(response.bodyBytes),
  );
  return path;
}

String _safeFileName(String value) {
  return value.replaceAll(RegExp(r'[^a-zA-Z0-9_.-]'), '_');
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
  return path.contains('_${_stableUrlHash(url)}');
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
