import 'dart:convert';

import 'package:http/http.dart' as http;

import '../desktop/tauri_bridge.dart' as tauri;
import '../plan/pilgrimage_models.dart';
import 'anitabi_image_url.dart';

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
    if (existing.dataBase64.isNotEmpty) {
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
