bool referenceCacheFileExists(String? path) => path != null && path.isNotEmpty;

bool referenceFullCacheFileIsCurrent({
  required String? path,
  required String? imageUrl,
}) =>
    path != null && path.isNotEmpty && imageUrl != null && imageUrl.isNotEmpty;
