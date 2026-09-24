import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Cache key for a downloaded reference image URL.
///
/// 80 bits of SHA-256 keep accidental collisions negligible even for very
/// large caches (the previous 32-bit FNV key could collide at a few thousand
/// URLs and show one point another point's reference).
String referenceCacheKey(String url) =>
    sha256.convert(utf8.encode(url)).toString().substring(0, 20);

/// Key used by earlier versions; files named with it are still accepted.
String legacyReferenceCacheKey(String url) {
  var hash = 0x811c9dc5;
  for (final codeUnit in url.codeUnits) {
    hash ^= codeUnit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}

String referenceCacheFileName(String url) =>
    '${referenceCacheKey(url)}${referenceCacheExtension(url)}';

String legacyReferenceCacheFileName(String url) =>
    '${legacyReferenceCacheKey(url)}${referenceCacheExtension(url)}';

/// Whether [path] is the cache file for [url]. Current names must match
/// exactly; legacy names embed the old key (`<key>.jpg` or point-scoped
/// `<point>_<key>.jpg`).
bool referenceCachePathMatchesUrl(String path, String url) {
  final name = _baseName(path);
  return name == referenceCacheFileName(url) ||
      isLegacyReferenceCacheName(name, url);
}

bool isLegacyReferenceCacheName(String fileName, String url) =>
    !fileName.endsWith('.part') &&
    fileName.contains(legacyReferenceCacheKey(url));

String referenceCacheExtension(String url) {
  final path = Uri.tryParse(url)?.path ?? '';
  final slash = path.lastIndexOf('/');
  final dotIndex = path.lastIndexOf('.');
  if (dotIndex <= slash || dotIndex == path.length - 1) return '.jpg';
  final extension = path.substring(dotIndex).toLowerCase();
  if (extension.length > 8) return '.jpg';
  return extension;
}

String _baseName(String path) {
  final normalized = path.replaceAll('\\', '/');
  return normalized.substring(normalized.lastIndexOf('/') + 1);
}
