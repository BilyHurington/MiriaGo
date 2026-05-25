import 'dart:io';

import 'anitabi_image_url.dart';

bool referenceCacheFileExists(String? path) {
  if (path == null || path.isEmpty) {
    return false;
  }

  final file = File(path);
  return file.existsSync() && file.lengthSync() > 0;
}

bool referenceFullCacheFileIsCurrent({
  required String? path,
  required String? imageUrl,
}) {
  final fullUrl = anitabiFullResolutionImageUrl(imageUrl);
  if (fullUrl == null || !referenceCacheFileExists(path)) {
    return false;
  }

  return path!.contains(_stableUrlHash(fullUrl));
}

String _stableUrlHash(String value) {
  var hash = 0x811c9dc5;
  for (final codeUnit in value.codeUnits) {
    hash ^= codeUnit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}
