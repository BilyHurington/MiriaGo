String normalizeAssetPathSeparators(String path) {
  return path.replaceAll(r'\', '/');
}

bool isSafeRelativeAssetPath(String? path) {
  if (path == null || path.isEmpty) {
    return false;
  }
  final normalized = normalizeAssetPathSeparators(path);
  if (!normalized.startsWith('assets/') ||
      normalized.endsWith('/') ||
      RegExp(r'[\x00-\x1f\x7f:<>"|?*]').hasMatch(normalized)) {
    return false;
  }
  return !normalized
      .split('/')
      .any(
        (segment) =>
            segment.isEmpty ||
            segment == '.' ||
            segment == '..' ||
            segment.endsWith('.') ||
            segment.endsWith(' ') ||
            RegExp(
              r'^(con|prn|aux|nul|com[1-9¹²³]|lpt[1-9¹²³])(?:\.|$)',
              caseSensitive: false,
            ).hasMatch(segment),
      );
}

bool isRuntimeManagedAssetPath(String path) {
  final normalized = normalizeAssetPathSeparators(path);
  return normalized.startsWith('assets/imported_plan_assets/') ||
      normalized.startsWith('assets/reference_full/') ||
      normalized.startsWith('assets/reference_thumbnails/') ||
      normalized.startsWith('assets/user_reference_images/') ||
      normalized.startsWith('assets/user_references/');
}

bool isImagePackageAssetPath(String path) {
  final normalized = normalizeAssetPathSeparators(path);
  return normalized.startsWith('assets/thumbnails/') ||
      normalized.startsWith('assets/full_references/') ||
      normalized.startsWith('assets/user_references/') ||
      normalized.startsWith('assets/visit_photos/') ||
      normalized.startsWith('assets/graded_photos/');
}
