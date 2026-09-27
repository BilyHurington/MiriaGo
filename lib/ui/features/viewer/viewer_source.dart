import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../../data/anitabi_image_fetcher.dart';
import '../../../data/image_bytes.dart';
import '../../../desktop/desktop_asset_image.dart';
import '../../../plan/pilgrimage_models.dart';
import 'viewer_files_stub.dart'
    if (dart.library.io) 'viewer_files_io.dart'
    as files;

/// Remote originals are read with this byte budget (old viewer).
const viewerMaxRemoteBytes = 64 * 1024 * 1024;

bool isBundledSampleImagePath(String path) =>
    path.startsWith('docs/sample_images/');

/// Full-size bytes of an image for saving (old `_resolveImageBytes`).
Future<Uint8List?> resolveViewerImageBytes({
  Uint8List? bytes,
  String? path,
  String? url,
  required AnitabiImageSource source,
}) async {
  if (bytes != null) return bytes;
  if (path != null) {
    if (isBundledSampleImagePath(path)) {
      final data = await rootBundle.load(path);
      return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    }
    if (kIsWeb && isDesktopAssetPath(path)) {
      return bytesFromDataUrl(await loadDesktopAssetDataUrl(path));
    }
    if (!kIsWeb) {
      final local = await files.readLocalViewerFile(path);
      if (local != null) return local;
    }
  }
  if (url == null || url.isEmpty) return null;
  final remote = await fetchAnitabiImageBytes(
    url,
    source: source,
    maxBytes: viewerMaxRemoteBytes,
  );
  return remote == null ? null : Uint8List.fromList(remote);
}

/// A local file path for sharing / gallery saving; writes a temporary copy
/// when the image is not already a local file (old `_resolveLocalImagePath`).
Future<String?> resolveViewerLocalPath({
  Uint8List? bytes,
  String? path,
  String? url,
  required AnitabiImageSource source,
}) async {
  if (path != null) {
    if (files.localViewerFileExists(path)) return path;
    if (isBundledSampleImagePath(path)) {
      final data = await rootBundle.load(path);
      return files.writeTemporaryViewerImage(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        extension: extensionFromUrl(path),
      );
    }
  }
  if (bytes != null) {
    return files.writeTemporaryViewerImage(
      bytes,
      extension: preferredImageExtension(bytes, fallbackPath: path),
    );
  }
  if (url == null || url.isEmpty) return null;
  try {
    final remote = await fetchAnitabiImageBytes(
      url,
      source: source,
      maxBytes: viewerMaxRemoteBytes,
    );
    if (remote == null) return null;
    return files.writeTemporaryViewerImage(
      Uint8List.fromList(remote),
      extension: extensionFromUrl(url),
    );
  } catch (_) {
    return null;
  }
}

Future<void> shareViewerFile(String path) => files.shareViewerFile(path);

String extensionFromUrl(String url) {
  final path = Uri.tryParse(url)?.path.toLowerCase() ?? url.toLowerCase();
  if (path.endsWith('.png')) return 'png';
  if (path.endsWith('.webp')) return 'webp';
  if (path.endsWith('.gif')) return 'gif';
  if (path.endsWith('.heic')) return 'heic';
  if (path.endsWith('.heif')) return 'heif';
  if (path.endsWith('.jpeg')) return 'jpg';
  return 'jpg';
}

/// Sniffs the file type from [bytes]; falls back to the path extension.
String preferredImageExtension(Uint8List? bytes, {String? fallbackPath}) {
  if (bytes != null) {
    if (isJpegBytes(bytes)) return 'jpg';
    if (isPngBytes(bytes)) return 'png';
    if (isWebpBytes(bytes)) return 'webp';
    if (bytes.length >= 6 &&
        String.fromCharCodes(bytes.take(6)).startsWith('GIF8')) {
      return 'gif';
    }
    if (bytes.length >= 12 &&
        String.fromCharCodes(bytes.sublist(4, 8)) == 'ftyp') {
      final brand = String.fromCharCodes(bytes.sublist(8, 12));
      if (const ['heic', 'heix', 'hevc', 'hevx'].contains(brand)) {
        return 'heic';
      }
      if (const ['mif1', 'msf1'].contains(brand)) return 'heif';
    }
  }
  return extensionFromUrl(fallbackPath ?? '');
}

String mimeTypeForImageExtension(String extension) => switch (extension) {
  'png' => 'image/png',
  'webp' => 'image/webp',
  'gif' => 'image/gif',
  'heic' => 'image/heic',
  'heif' => 'image/heif',
  _ => 'image/jpeg',
};

Uint8List? bytesFromDataUrl(String? dataUrl) {
  if (dataUrl == null || dataUrl.isEmpty) return null;
  final commaIndex = dataUrl.indexOf(',');
  if (commaIndex == -1) return null;
  final metadata = dataUrl.substring(0, commaIndex);
  if (!metadata.contains(';base64')) return null;
  return base64Decode(dataUrl.substring(commaIndex + 1));
}
